import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  User? get currentUser => _auth.currentUser;

  /// Triggers Firebase SMS OTP to [phoneNumber] (e.g. "+919849012345").
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onError,
    void Function(UserCredential credential)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final userCred = await _auth.signInWithCredential(credential);
        onAutoVerified?.call(userCred);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Phone verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Verifies the 6-digit SMS [smsCode] against the stored verification ID.
  Future<UserCredential> verifyOtp({
    required String smsCode,
    String? verificationId,
  }) async {
    final verId = verificationId ?? _verificationId;
    if (verId == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Verification session expired. Please request a new OTP.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
