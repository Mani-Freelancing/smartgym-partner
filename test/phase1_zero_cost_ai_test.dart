import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo_application/apps/customer_app/screens/customer_pass_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_add_member_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/shared/upi_payment_proof_section.dart';
import 'package:flutter_demo_application/apps/partner_app/trainer/screens/trainer_absent_radar_screen.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/data/services/upi_proof_ocr_service.dart';
import 'package:flutter_demo_application/domain/models/gym_member.dart';
import 'package:flutter_demo_application/domain/models/gym_tenant.dart';
import 'package:flutter_demo_application/domain/services/member_intelligence_service.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_bloc.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_event.dart';

void main() {
  test('UpiProofOcrService parses UTR, amount, and failed/pending statuses', () {
    final gpay = UpiProofOcrService.parseExtractedText(
      'Payment Successful\nPaid ₹2,000.00\nTo IMFIT Gym • +91 9849012345\nUPI Ref No: 432918273645',
    );
    expect(gpay.utr, '432918273645');
    expect(gpay.amountInr, 2000);
    expect(gpay.isStatusFailedOrPending, isFalse);

    final phonePe = UpiProofOcrService.parseExtractedText(
      'Transaction Successful\nRs. 1,500\nTransaction ID: T261124123456789012',
    );
    expect(phonePe.utr, 'T261124123456789012');
    expect(phonePe.amountInr, 1500);
    expect(phonePe.isStatusFailedOrPending, isFalse);

    final pending = UpiProofOcrService.parseExtractedText(
      'Payment Pending\nAmount: ₹1500\nUTR: 998877665544',
    );
    expect(pending.isStatusFailedOrPending, isTrue);
    expect(pending.utr, '998877665544');
    expect(pending.amountInr, 1500);

    final splitRupeeLine = UpiProofOcrService.parseExtractedText(
      'Paid to IMFIT Gym\n₹\n2,500\nUPI Ref No: 432918273645',
    );
    expect(splitRupeeLine.amountInr, 2500);

    final suffixRupee = UpiProofOcrService.parseExtractedText(
      '2,000 ₹\nPaid successfully',
    );
    expect(suffixRupee.amountInr, 2000);

    final ignoresCashbackAndNonRupeeNumbers =
        UpiProofOcrService.parseExtractedText(
      'Win ₹50 cashback\nPaid ₹2,000\nUPI Ref: 432918273645',
    );
    expect(ignoresCashbackAndNonRupeeNumbers.amountInr, 2000);

    final noRupeeSymbol = UpiProofOcrService.parseExtractedText(
      'Paid 24 Nov 2026\nPhone: 9849012345',
    );
    expect(noRupeeSymbol.amountInr, isNull);

    final spatialAmount = UpiProofOcrService.extractAmountNearRupeeBoxes([
      (text: '88', box: const Rect.fromLTWH(300, 10, 30, 16)),
      (text: '₹', box: const Rect.fromLTWH(40, 200, 24, 48)),
      (text: '1,500', box: const Rect.fromLTWH(72, 198, 120, 52)),
      (text: 'Cashback ₹25', box: const Rect.fromLTWH(40, 500, 120, 18)),
    ]);
    expect(spatialAmount, 1500);

    final misreadQuestionMark = UpiProofOcrService.parseExtractedText(
      '? 1,500\nPaid to IMFIT Gym\nUPI Ref: 112233445566',
    );
    expect(misreadQuestionMark.amountInr, 1500);

    final vectorIconDroppedRupee = UpiProofOcrService.parseExtractedText(
      'Payment Successful\nTo IMFIT Gym\n2,000\nUPI Ref: 432918273645',
    );
    expect(vectorIconDroppedRupee.amountInr, 2000);

    final heroSpatialWithoutRupee = UpiProofOcrService.extractAmountNearRupeeBoxes([
      (text: 'Payment Successful', box: const Rect.fromLTWH(40, 80, 180, 18)),
      (text: '2,500', box: const Rect.fromLTWH(80, 140, 130, 54)),
      (text: '24', box: const Rect.fromLTWH(40, 240, 30, 14)),
    ]);
    expect(heroSpatialWithoutRupee, 2500);
  });

  test('UpiProofOcrService.auditProof detects duplicate UTR, mismatch, and verified proofs', () {
    const existing = [
      GymMember(
        id: 'm1',
        name: 'Rahul Sharma',
        gender: 'Male',
        phone: '+919849011111',
        planTitle: '1 Month Regular',
        feePaid: 2000,
        joinedDate: '20 Nov 2026',
        expiryDate: '20 Dec 2026',
        daysLeft: 26,
        isPtClient: false,
        addedByTrainer: 'Owner',
        paymentMode: 'Online',
        paymentReference: '432918273645',
      ),
    ];

    final duplicate = UpiProofOcrService.auditProof(
      extracted: const UpiProofExtraction(utr: '432918273645', amountInr: 2000),
      enteredAmount: 2000,
      existingMembers: existing,
    );
    expect(duplicate.isBlocked, isTrue);
    expect(duplicate.headline, 'Duplicate UTR Detected');
    expect(duplicate.duplicateMemberName, 'Mr. Rahul Sharma');

    final mismatch = UpiProofOcrService.auditProof(
      extracted: const UpiProofExtraction(utr: '111122223333', amountInr: 1000),
      enteredAmount: 2000,
      existingMembers: existing,
    );
    expect(mismatch.severity, UpiProofSeverity.blocked);
    expect(mismatch.isBlocked, isTrue);
    expect(mismatch.headline, 'Amount Mismatch Error');

    final verified = UpiProofOcrService.auditProof(
      extracted: const UpiProofExtraction(utr: '111122223333', amountInr: 2000),
      enteredAmount: 2000,
      existingMembers: existing,
    );
    expect(verified.severity, UpiProofSeverity.verified);
    expect(verified.isBlocked, isFalse);

    final missingAmount = UpiProofOcrService.auditProof(
      extracted: const UpiProofExtraction(utr: '111122223333'),
      enteredAmount: 2000,
      existingMembers: existing,
    );
    expect(missingAmount.severity, UpiProofSeverity.blocked);
    expect(missingAmount.isBlocked, isTrue);
    expect(missingAmount.headline, 'Amount Not Detected Error');
  });

  test('MemberIntelligenceService scores churn risks and forecasts hourly rush windows', () {
    const members = [
      GymMember(
        id: 'm_healthy',
        name: 'Aarav',
        gender: 'Male',
        phone: '+919800000001',
        planTitle: 'PT VIP',
        feePaid: 5000,
        joinedDate: '20 Nov 2026',
        expiryDate: '20 Dec 2026',
        daysLeft: 26,
        isPtClient: true,
        addedByTrainer: 'Owner',
      ),
      GymMember(
        id: 'm_risk',
        name: 'Sam Nair',
        gender: 'Transgender',
        phone: '+919800000002',
        planTitle: '1 Month Regular',
        feePaid: 1500,
        dueAmount: 500,
        joinedDate: '24 Oct 2026',
        expiryDate: '23 Nov 2026',
        daysLeft: -1,
        isPtClient: false,
        addedByTrainer: 'Owner',
      ),
    ];

    final risks = MemberIntelligenceService.evaluateChurnRisks(
      members: members,
      gymName: 'IMFIT Gym',
    );
    expect(risks.length, 1);
    expect(risks.first.member.id, 'm_risk');
    expect(risks.first.score, 95);
    expect(risks.first.level, ChurnRiskLevel.critical);
    expect(risks.first.suggestedWhatsAppMessage, contains('Mx. Sam Nair'));

    final hourly = List<int>.filled(24, 2);
    hourly[18] = 20;
    hourly[19] = 24;
    hourly[20] = 18;
    hourly[13] = 0;
    hourly[14] = 0;
    hourly[15] = 0;

    final gym = GymTenant(
      id: 'g1',
      name: 'IMFIT Gym',
      area: 'Madhapur',
      headTrainer: 'Karthik',
      brandColor: const Color(0xFF00E676),
      activeCrowd: 10,
      maxCapacity: 60,
      monthlyFee: 2000,
      ptFee: 5000,
      hourlyCheckIns: hourly,
    );
    final forecast = MemberIntelligenceService.forecastRushHours(
      gym,
      now: DateTime(2026, 11, 24, 14, 0),
    );
    expect(forecast.isUsingLiveHistory, isTrue);
    expect(forecast.peakHoursLabel, '6 PM–9 PM');
    expect(forecast.quietestWindowLabel, '1 PM–4 PM');
    expect(forecast.isCurrentHourBusy, isFalse);
  });

  test('SmartGymBloc records hourly check-in bucket on SimulateQrCheckInEvent', () async {
    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    final hour = DateTime.now().hour;
    final before = bloc.state.currentGym.hourlyCheckIns.length == 24
        ? bloc.state.currentGym.hourlyCheckIns[hour]
        : 0;

    bloc.add(const SimulateQrCheckInEvent());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.currentGym.hourlyCheckIns.length, 24);
    expect(bloc.state.currentGym.hourlyCheckIns[hour], before + 1);
  });

  testWidgets('OwnerAddMemberScreen & UpiPaymentProofSection enforce amount match without manual UTR input', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final valid1x1Png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );

    const existing = [
      GymMember(
        id: 'm_dup',
        name: 'Priya Das',
        gender: 'Female',
        phone: '+919849099999',
        planTitle: '1 Month Regular',
        feePaid: 2000,
        joinedDate: '20 Nov 2026',
        expiryDate: '20 Dec 2026',
        daysLeft: 26,
        isPtClient: false,
        addedByTrainer: 'Owner',
        paymentMode: 'Online',
        paymentReference: '432918273645',
      ),
    ];

    // 1. Amount mismatch shows red error and no manual UTR TextField exists.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: UpiPaymentProofSection(
              proofBytes: valid1x1Png,
              ocrExtraction: const UpiProofExtraction(
                utr: '998877665544',
                amountInr: 1000,
              ),
              enteredAmount: 2000,
              existingMembers: existing,
              onProofSelected: (_) {},
              onError: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('upi_proof_upload_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('upi_utr_input')), findsNothing);
    expect(find.byKey(const ValueKey('upi_audit_banner')), findsOneWidget);
    expect(find.text('Payment Screenshot Attached'), findsOneWidget);
    expect(find.text('Amount Mismatch Error'), findsOneWidget);
    expect(
      find.text('Paid Entered: ₹2000  •  Screenshot: ₹1000'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Screenshot shows ₹1000, but Amount Paid is ₹2000. Amounts must match.',
      ),
      findsOneWidget,
    );

    // 2. Duplicate UTR is blocked.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: UpiPaymentProofSection(
              proofBytes: valid1x1Png,
              ocrExtraction: const UpiProofExtraction(
                utr: '432918273645',
                amountInr: 2000,
              ),
              enteredAmount: 2000,
              existingMembers: existing,
              onProofSelected: (_) {},
              onError: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Duplicate UTR Detected'), findsOneWidget);
    expect(find.textContaining('Ms. Priya Das'), findsOneWidget);

    // 3. Matching amount and fresh UTR is verified.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: UpiPaymentProofSection(
              proofBytes: valid1x1Png,
              ocrExtraction: const UpiProofExtraction(
                utr: '998877665544',
                amountInr: 2000,
              ),
              enteredAmount: 2000,
              existingMembers: existing,
              onProofSelected: (_) {},
              onError: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('UPI Proof Verified'), findsOneWidget);
    expect(
      find.text('UTR 998877665544 • ₹2000 matched on-device'),
      findsOneWidget,
    );

    // 4. OwnerAddMemberScreen Online mode has no manual UTR TextField.
    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const OwnerAddMemberScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final onlineChip = find.text('Online / UPI');
    await tester.ensureVisible(onlineChip);
    await tester.pump();
    await tester.tap(onlineChip);
    await tester.pump();
    expect(find.byKey(const ValueKey('upi_proof_upload_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('upi_utr_input')), findsNothing);
  });

  testWidgets('TrainerAbsentRadarScreen & CustomerPassScreen render Churn Shield and Rush Forecast', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);
    bloc.add(
      const SyncMembersEvent([
        GymMember(
          id: 'm_at_risk',
          name: 'Sam Nair',
          gender: 'Transgender',
          phone: '+919800033333',
          planTitle: '1 Month Regular',
          feePaid: 1500,
          dueAmount: 500,
          joinedDate: '24 Oct 2026',
          expiryDate: '23 Nov 2026',
          daysLeft: -1,
          isPtClient: false,
          addedByTrainer: 'Owner',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const TrainerAbsentRadarScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('CHURN SHIELD • LIVE AT-RISK MEMBERS (1)'),
      findsOneWidget,
    );
    expect(find.text('Mx. Sam Nair'), findsOneWidget);
    expect(find.text('RISK 95%'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const CustomerPassScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final strip = find.byKey(const ValueKey('rush_forecast_strip'));
    await tester.scrollUntilVisible(strip, 300);
    await tester.pump();
    expect(strip, findsOneWidget);
    expect(find.textContaining('Quiet: 1–4 PM'), findsOneWidget);
  });
}
