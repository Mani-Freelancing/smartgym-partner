import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo_application/apps/customer_app/auth/customer_login_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/auth/partner_login_screen.dart';
import 'package:flutter_demo_application/core/config/app_config.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/data/services/phone_auth_service.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_bloc.dart';

class _FailingPhoneAuthService extends PhoneAuthService {
  final FirebaseAuthException exceptionToSend;

  _FailingPhoneAuthService(this.exceptionToSend);

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onError,
    void Function(UserCredential credential)? onAutoVerified,
  }) async {
    onError(PhoneAuthService.formatAuthError(exceptionToSend));
  }
}

void main() {
  test('PhoneAuthService formats staging auth errors and detects offline test errors', () {
    AppConfig.resetForTesting();
    addTearDown(AppConfig.resetForTesting);
    AppConfig.syncFromFirebaseProjectId('smartgym-os-staging');

    expect(
      PhoneAuthService.formatAuthError(
        FirebaseAuthException(code: 'operation-not-allowed'),
      ),
      contains('smartgym-os-staging'),
    );
    expect(
      PhoneAuthService.formatAuthError(
        FirebaseAuthException(code: 'app-not-authorized'),
      ),
      contains('SHA-1'),
    );
    expect(
      PhoneAuthService.isOfflineTestError(
        '[core/no-app] No Firebase App \'[DEFAULT]\' has been created',
      ),
      isTrue,
    );
    expect(
      PhoneAuthService.isOfflineTestError(
        FirebaseAuthException(code: 'operation-not-allowed'),
      ),
      isFalse,
    );
  });

  testWidgets('PartnerLoginScreen and CustomerLoginScreen surface OTP errors instead of hiding them', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AppConfig.resetForTesting();
    addTearDown(AppConfig.resetForTesting);
    AppConfig.syncFromFirebaseProjectId('smartgym-os-staging');

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    final failingAuth = _FailingPhoneAuthService(
      FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'Phone provider disabled',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: PartnerLoginScreen(authService: failingAuth),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('phone_input')),
      '9849012345',
    );
    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(
      find.textContaining('Phone sign-in is disabled for Firebase project (smartgym-os-staging)'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: CustomerLoginScreen(authService: failingAuth),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('customer_phone_input')),
      '9849012345',
    );
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();

    expect(
      find.textContaining('Phone sign-in is disabled for Firebase project (smartgym-os-staging)'),
      findsOneWidget,
    );
  });
}
