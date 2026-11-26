import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';

class PhoneAuthService {
  final FirebaseAuth? _injectedAuth;
  String? _verificationId;

  PhoneAuthService({FirebaseAuth? auth}) : _injectedAuth = auth;

  FirebaseAuth get _auth => _injectedAuth ?? FirebaseAuth.instance;

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (e) {
      debugPrint('[AUTH][PhoneAuthService.currentUser ERROR] $e');
      return null;
    }
  }

  String _projectLabel() {
    try {
      return _auth.app.options.projectId;
    } catch (_) {
      return AppConfig.firebaseProjectId;
    }
  }

  /// True when Firebase is uninitialized in an offline unit/widget test.
  static bool isOfflineTestError(Object error) {
    final msg = error.toString();
    return msg.contains('no-app') ||
        msg.contains('FirebaseApp') ||
        msg.contains('has not been initialized');
  }

  /// Converts FirebaseAuth errors into clear actionable messages while
  /// preserving detailed server feedback for debugging.
  static String formatAuthError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'operation-not-allowed' =>
          'Phone sign-in is disabled for Firebase project (${AppConfig.firebaseProjectId}). Enable Phone provider in Firebase Auth Console.',
        'app-not-authorized' || 'invalid-app-credential' =>
          'App SHA-1/package is not authorized on Firebase (${AppConfig.firebaseProjectId}). Add Android SHA-1 or test phone number in Firebase Console.',
        'missing-client-identifier' =>
          'Missing app verification (Play Integrity / SHA-1 / reCAPTCHA) for ${AppConfig.firebaseProjectId}.',
        'too-many-requests' =>
          'Too many OTP attempts from this device/number. Try again later or use a Firebase test phone number.',
        'invalid-phone-number' =>
          'Invalid phone number format. Check the 10-digit mobile number.',
        'invalid-verification-code' || 'invalid-credential' =>
          'Invalid OTP. Please check the 6-digit code and try again.',
        'session-expired' || 'code-expired' =>
          'OTP session expired. Tap Edit/Change number and request a new OTP.',
        'network-request-failed' =>
          'Network error contacting Firebase Auth. Check internet connection.',
        _ => '${error.message ?? "Phone verification failed"} (${error.code})',
      };
    }
    return error.toString();
  }

  /// Triggers Firebase SMS OTP to [phoneNumber] (e.g. "+919849012345").
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onError,
    void Function(UserCredential credential)? onAutoVerified,
  }) async {
    final project = _projectLabel();
    debugPrint(
      '[AUTH][PhoneAuthService.sendOtp] START env=${AppConfig.environmentName} '
      'project=$project phone=$phoneNumber',
    );
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint(
            '[AUTH][PhoneAuthService.sendOtp -> verificationCompleted] '
            'project=$project phone=$phoneNumber provider=${credential.providerId} '
            'signInMethod=${credential.signInMethod}',
          );
          try {
            final userCred = await _auth.signInWithCredential(credential);
            debugPrint(
              '[AUTH][PhoneAuthService.sendOtp -> autoSignIn SUCCESS] '
              'uid=${userCred.user?.uid} phone=${userCred.user?.phoneNumber}',
            );
            onAutoVerified?.call(userCred);
          } catch (e, st) {
            debugPrint(
              '[AUTH][PhoneAuthService.sendOtp -> autoSignIn ERROR] $e\n$st',
            );
            onError(formatAuthError(e));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint(
            '[AUTH][PhoneAuthService.sendOtp -> verificationFailed] '
            'project=$project phone=$phoneNumber code=${e.code} '
            'message=${e.message}',
          );
          onError(formatAuthError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          debugPrint(
            '[AUTH][PhoneAuthService.sendOtp -> codeSent] '
            'project=$project phone=$phoneNumber '
            'verificationIdLen=${verificationId.length} resendToken=$resendToken',
          );
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          debugPrint(
            '[AUTH][PhoneAuthService.sendOtp -> codeAutoRetrievalTimeout] '
            'project=$project phone=$phoneNumber '
            'verificationIdLen=${verificationId.length}',
          );
        },
      );
      debugPrint(
        '[AUTH][PhoneAuthService.sendOtp] verifyPhoneNumber call returned '
        '(awaiting callback) phone=$phoneNumber',
      );
    } catch (e, st) {
      debugPrint(
        '[AUTH][PhoneAuthService.sendOtp THROW] project=$project '
        'phone=$phoneNumber error=$e\n$st',
      );
      rethrow;
    }
  }

  /// Verifies the 6-digit SMS [smsCode] against the stored verification ID.
  Future<UserCredential> verifyOtp({
    required String smsCode,
    String? verificationId,
  }) async {
    final auth = _auth;
    final verId = verificationId ?? _verificationId;
    final project = _projectLabel();
    debugPrint(
      '[AUTH][PhoneAuthService.verifyOtp] START project=$project '
      'smsCodeLen=${smsCode.length} hasVerId=${verId != null}',
    );
    if (verId == null) {
      debugPrint(
        '[AUTH][PhoneAuthService.verifyOtp ERROR] missing-verification-id',
      );
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Verification session expired. Please request a new OTP.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verId,
      smsCode: smsCode,
    );
    try {
      final userCred = await auth.signInWithCredential(credential);
      debugPrint(
        '[AUTH][PhoneAuthService.verifyOtp SUCCESS] project=$project '
        'uid=${userCred.user?.uid} phone=${userCred.user?.phoneNumber}',
      );
      return userCred;
    } catch (e, st) {
      debugPrint(
        '[AUTH][PhoneAuthService.verifyOtp ERROR] project=$project error=$e\n$st',
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    debugPrint(
      '[AUTH][PhoneAuthService.signOut] uid=${currentUser?.uid} '
      'phone=${currentUser?.phoneNumber}',
    );
    await _auth.signOut();
  }
}
