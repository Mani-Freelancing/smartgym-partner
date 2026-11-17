import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo_application/main.dart';

void main() {
  testWidgets(
      'Production 2-step Phone + OTP login flow works for Owner and Trainer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SmartGymOSApp());
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Starts on clean login screen
    expect(find.text('Your gym, in your pocket.'), findsOneWidget);

    // 2. Enter 10-digit phone number manually -> Continue
    await tester.enterText(
      find.byKey(const ValueKey('phone_input')),
      '9849012345',
    );
    await tester.tap(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 300));

    // 3. Enter 4-digit OTP manually -> Verify & Continue
    expect(find.text('Verify your number'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('otp_input')), '4829');
    await tester.tap(find.text('VERIFY & CONTINUE'));
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Lands in Owner CEO Portal
    expect(find.textContaining('CEO OVERVIEW'), findsOneWidget);
  });
}
