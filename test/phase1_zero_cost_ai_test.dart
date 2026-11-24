import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_demo_application/apps/customer_app/screens/customer_pass_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_add_member_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/shared/upi_payment_proof_section.dart';
import 'package:flutter_demo_application/apps/partner_app/trainer/screens/trainer_absent_radar_screen.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/data/services/rupee_glyph_detector.dart';
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

    // Status bar clock/battery, date year & masked bank digits must NOT beat paid hero
    final statusBarAndDateNoise = UpiProofOcrService.parseExtractedText(
      '15:02\n85\n24 Nov 2026\nCompleted\n2,000\nPaid to IMFIT Gym\nBank **** 4521\nUPI Ref: 432918273645',
    );
    expect(statusBarAndDateNoise.amountInr, 2000);

    // Common ML Kit Latin ₹ misreads (F / R / 7-fused / space thousands / dot thousands / trail /-)
    expect(
      UpiProofOcrService.parseExtractedText(
        'Paid F1,500 to IMFIT\nRef 432918273645',
      ).amountInr,
      1500,
    );
    expect(
      UpiProofOcrService.parseExtractedText(
        'Paid ₹1 500/-\nTransaction Successful',
      ).amountInr,
      1500,
    );
    expect(
      UpiProofOcrService.parseExtractedText(
        'Paid ₹1.500\nTransaction Successful',
      ).amountInr,
      1500,
    );
    expect(
      UpiProofOcrService.parseExtractedText(
        'Paid 1,500\n24 Nov 2026\nA/c XX4521',
      ).amountInr,
      1500,
    );
    expect(
      UpiProofOcrService.parseExtractedText(
        'Payment Successful\n71,500\nTo IMFIT Gym',
        expectedAmount: 1500,
      ).amountInr,
      1500,
    );
    // Genuine lower amount stays blocked (tamper protection intact!)
    expect(
      UpiProofOcrService.parseExtractedText(
        'Payment Successful\nPaid ₹500\nTo IMFIT Gym',
        expectedAmount: 2000,
      ).amountInr,
      500,
    );

    // Top-aligned small ₹ next to tall hero digits still pairs spatially
    final topAlignedRupee = UpiProofOcrService.extractAmountNearRupeeBoxes([
      (text: '₹', box: const Rect.fromLTWH(40, 178, 20, 24)),
      (text: '2,000', box: const Rect.fromLTWH(68, 176, 130, 68)),
    ]);
    expect(topAlignedRupee, 2000);
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

  test('RupeeGlyphDetector & UpiProofOcrService distinguish ₹300 from real 7300/2300/3300/7/2/3/F/R across fonts and themes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Helper: rasterizes an arbitrary Canvas callback to DecodedRgbaImage.
    Future<DecodedRgbaImage> rasterize({
      required int width,
      required int height,
      required void Function(Canvas canvas) paint,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(byteData, isNotNull);
      final decoded = await RupeeGlyphDetector.decodeBytes(
        byteData!.buffer.asUint8List(),
      );
      expect(decoded, isNotNull);
      return decoded!;
    }

    RecognizedText buildSingleLineOcr(String lineText, Rect box) {
      final pts = <math.Point<int>>[
        math.Point<int>(box.left.round(), box.top.round()),
        math.Point<int>(box.right.round(), box.top.round()),
        math.Point<int>(box.right.round(), box.bottom.round()),
        math.Point<int>(box.left.round(), box.bottom.round()),
      ];
      return RecognizedText(
        text: lineText,
        blocks: [
          TextBlock(
            text: lineText,
            lines: [
              TextLine(
                text: lineText,
                elements: [
                  TextElement(
                    text: lineText,
                    symbols: const [],
                    boundingBox: box,
                    recognizedLanguages: const ['en'],
                    cornerPoints: pts,
                    confidence: 0.9,
                    angle: 0,
                  ),
                ],
                boundingBox: box,
                recognizedLanguages: const ['en'],
                cornerPoints: pts,
                confidence: 0.9,
                angle: 0,
              ),
            ],
            boundingBox: box,
            recognizedLanguages: const ['en'],
            cornerPoints: pts,
          ),
        ],
      );
    }

    // 1. Deterministic vector-drawn ₹ vs 7 bitmap test (runs in any environment).
    Future<({DecodedRgbaImage image, Rect box})> renderVectorGlyphPair({
      required bool drawRupee,
      required Color bg,
      required Color fg,
    }) async {
      const box = Rect.fromLTWH(20, 20, 140, 48);
      final image = await rasterize(
        width: 180,
        height: 88,
        paint: (canvas) {
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 180, 88),
            Paint()..color = bg,
          );
          final p = Paint()
            ..color = fg
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke;
          if (drawRupee) {
            // Two top horizontal bars + upper curve + diagonal lower-right tail.
            canvas.drawLine(const Offset(24, 24), const Offset(48, 24), p);
            canvas.drawLine(const Offset(24, 33), const Offset(48, 33), p);
            canvas.drawArc(
              const Rect.fromLTWH(24, 24, 20, 18),
              -1.3,
              2.6,
              false,
              p,
            );
            canvas.drawLine(const Offset(26, 42), const Offset(46, 62), p);
          } else {
            // Genuine '7': single top bar + diagonal down-left stroke.
            canvas.drawLine(const Offset(24, 24), const Offset(48, 24), p);
            canvas.drawLine(const Offset(47, 25), const Offset(28, 62), p);
          }
          // Trailing "300" digits
          canvas.drawArc(const Rect.fromLTWH(58, 24, 22, 18), -2.2, 3.6, false, p);
          canvas.drawArc(const Rect.fromLTWH(58, 42, 22, 19), -1.4, 3.6, false, p);
          canvas.drawOval(const Rect.fromLTWH(90, 24, 22, 38), p);
          canvas.drawOval(const Rect.fromLTWH(122, 24, 22, 38), p);
        },
      );
      return (image: image, box: box);
    }

    final vecRupeeLight = await renderVectorGlyphPair(
      drawRupee: true,
      bg: const Color(0xFFFAF9F6),
      fg: const Color(0xFF111111),
    );
    expect(
      RupeeGlyphDetector.isRupeeGlyph(
        vecRupeeLight.image,
        vecRupeeLight.box,
        isolateFirstGlyph: true,
      ),
      isTrue,
      reason: 'Vector ₹300 on light background should match ₹ glyph: '
          '${RupeeGlyphDetector.analyzeRegion(vecRupeeLight.image, vecRupeeLight.box, isolateFirstGlyph: true)}',
    );
    // Even if default fee field is 1500, pixel verification strips misread `7` -> 300!
    final vecOcrCorrected = UpiProofOcrService.parseRecognizedTextWithImage(
      buildSingleLineOcr('7300', vecRupeeLight.box),
      rgbaImage: vecRupeeLight.image,
      expectedAmount: 1500,
    );
    expect(vecOcrCorrected.amountInr, 300);

    final vecSevenDark = await renderVectorGlyphPair(
      drawRupee: false,
      bg: const Color(0xFF150B24),
      fg: Colors.white,
    );
    expect(
      RupeeGlyphDetector.isRupeeGlyph(
        vecSevenDark.image,
        vecSevenDark.box,
        isolateFirstGlyph: true,
      ),
      isFalse,
      reason: 'Genuine 7300 on dark background must NOT be misclassified as ₹: '
          '${RupeeGlyphDetector.analyzeRegion(vecSevenDark.image, vecSevenDark.box, isolateFirstGlyph: true)}',
    );
    // Real `7300` keeps 7300 on a payment receipt even when enteredAmount is 300!
    final vecRealSevenReceipt = RecognizedText(
      text: 'Payment Successful\n7300\nUPI Ref: 669407427418',
      blocks: [
        TextBlock(
          text: 'Payment Successful\n7300',
          lines: [
            TextLine(
              text: 'Payment Successful',
              elements: [
                TextElement(
                  text: 'Payment',
                  symbols: const [],
                  boundingBox: const Rect.fromLTWH(20, 2, 70, 14),
                  recognizedLanguages: const ['en'],
                  cornerPoints: const [],
                  confidence: 0.9,
                  angle: 0,
                ),
                TextElement(
                  text: 'Successful',
                  symbols: const [],
                  boundingBox: const Rect.fromLTWH(96, 2, 70, 14),
                  recognizedLanguages: const ['en'],
                  cornerPoints: const [],
                  confidence: 0.9,
                  angle: 0,
                ),
              ],
              boundingBox: const Rect.fromLTWH(20, 2, 146, 14),
              recognizedLanguages: const ['en'],
              cornerPoints: const [],
              confidence: 0.9,
              angle: 0,
            ),
            TextLine(
              text: '7300',
              elements: [
                TextElement(
                  text: '7300',
                  symbols: const [],
                  boundingBox: vecSevenDark.box,
                  recognizedLanguages: const ['en'],
                  cornerPoints: const [],
                  confidence: 0.9,
                  angle: 0,
                ),
              ],
              boundingBox: vecSevenDark.box,
              recognizedLanguages: const ['en'],
              cornerPoints: const [],
              confidence: 0.9,
              angle: 0,
            ),
          ],
          boundingBox: const Rect.fromLTWH(20, 2, 146, 66),
          recognizedLanguages: const ['en'],
          cornerPoints: const [],
        ),
      ],
    );
    final vecOcrRealSeven = UpiProofOcrService.parseRecognizedTextWithImage(
      vecRealSevenReceipt,
      rgbaImage: vecSevenDark.image,
      expectedAmount: 300,
    );
    expect(vecOcrRealSeven.amountInr, 7300);

    // 2. Real Roboto font TextPainter tests (PhonePe/GPay/Paytm typography, light + dark).
    final fontFiles = <String, String>{
      'TestRobotoRegular':
          '/Applications/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      'TestRobotoMedium':
          '/Applications/flutter/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf',
      'TestRobotoBold':
          '/Applications/flutter/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf',
    };
    for (final entry in fontFiles.entries) {
      final f = File(entry.value);
      if (!f.existsSync()) continue;
      final bytes = await f.readAsBytes();
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();

      Future<({DecodedRgbaImage image, Rect box})> renderFontText(
        String text, {
        required Color bg,
        required Color fg,
        double fontSize = 56,
      }) async {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: entry.key,
              fontSize: fontSize,
              color: fg,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        const pad = 24.0;
        final w = (tp.width + pad * 2).ceil();
        final h = (tp.height + pad * 2).ceil();
        final img = await rasterize(
          width: w,
          height: h,
          paint: (canvas) {
            canvas.drawRect(
              Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
              Paint()..color = bg,
            );
            tp.paint(canvas, const Offset(pad, pad));
          },
        );
        return (
          image: img,
          box: Rect.fromLTWH(pad - 2, pad - 2, tp.width + 4, tp.height + 4),
        );
      }

      for (final theme in [
        (name: 'light', bg: Colors.white, fg: const Color(0xFF141414)),
        (name: 'dark', bg: const Color(0xFF1A1025), fg: Colors.white),
      ]) {
        for (final size in [28.0, 56.0]) {
          final rupee300 = await renderFontText(
            '₹300',
            bg: theme.bg,
            fg: theme.fg,
            fontSize: size,
          );
          final singleRupee = await renderFontText(
            '₹',
            bg: theme.bg,
            fg: theme.fg,
            fontSize: size,
          );
          expect(
            RupeeGlyphDetector.isRupeeGlyph(
              singleRupee.image,
              singleRupee.box,
              isolateFirstGlyph: false,
            ),
            isTrue,
            reason: '${entry.key} ${theme.name} ${size}px ₹ metrics: '
                '${RupeeGlyphDetector.analyzeRegion(singleRupee.image, singleRupee.box)}',
          );
          expect(
            RupeeGlyphDetector.isRupeeGlyph(
              rupee300.image,
              rupee300.box,
              isolateFirstGlyph: true,
            ),
            isTrue,
            reason: '${entry.key} ${theme.name} ${size}px ₹300 metrics: '
                '${RupeeGlyphDetector.analyzeRegion(rupee300.image, rupee300.box, isolateFirstGlyph: true)}',
          );

          final ocrFixed = UpiProofOcrService.parseRecognizedTextWithImage(
            buildSingleLineOcr('7300', rupee300.box),
            rgbaImage: rupee300.image,
            expectedAmount: 1500,
          );
          expect(ocrFixed.amountInr, 300);

          for (final negCompound in ['7300', '2300', '3300']) {
            final sample = await renderFontText(
              negCompound,
              bg: theme.bg,
              fg: theme.fg,
              fontSize: size,
            );
            expect(
              RupeeGlyphDetector.isRupeeGlyph(
                sample.image,
                sample.box,
                isolateFirstGlyph: true,
              ),
              isFalse,
              reason: '${entry.key} ${theme.name} ${size}px $negCompound metrics: '
                  '${RupeeGlyphDetector.analyzeRegion(sample.image, sample.box, isolateFirstGlyph: true)}',
            );
          }
          for (final negSingle in ['7', '2', '3', 'F', 'R', 'T', 'E', 'Z']) {
            final sample = await renderFontText(
              negSingle,
              bg: theme.bg,
              fg: theme.fg,
              fontSize: size,
            );
            expect(
              RupeeGlyphDetector.isRupeeGlyph(
                sample.image,
                sample.box,
                isolateFirstGlyph: false,
              ),
              isFalse,
              reason: '${entry.key} ${theme.name} ${size}px $negSingle metrics: '
                  '${RupeeGlyphDetector.analyzeRegion(sample.image, sample.box)}',
            );
          }
        }
      }
    }

    // 3. Real user-uploaded CRED payment screenshot verification when present.
    final credFile = File(
      '/Users/mani/.gemini/antigravity/brain/fb52a5ba-eb36-48d2-8bd5-74f488c2c817/.user_uploaded/media_1795513345971_a92d7f3b.jpg',
    );
    if (credFile.existsSync()) {
      final credBytes = await credFile.readAsBytes();
      final credRgba = await RupeeGlyphDetector.decodeBytes(credBytes);
      expect(credRgba, isNotNull);
      expect(credRgba!.width, 656);
      expect(credRgba.height, 1024);

      // In the 656x1024 CRED receipt, `₹300` sits dead center around x:[240..420], y:[465..555].
      const heroBox = Rect.fromLTRB(240, 465, 420, 555);
      final metrics = RupeeGlyphDetector.analyzeRegion(
        credRgba,
        heroBox,
        isolateFirstGlyph: true,
      );
      expect(
        RupeeGlyphDetector.isRupeeGlyph(
          credRgba,
          heroBox,
          isolateFirstGlyph: true,
        ),
        isTrue,
        reason: 'CRED ₹300 hero metrics: $metrics',
      );

      // Simulate ML Kit Latin misreading CRED's centered `₹300` as `7300`.
      const txnBox = Rect.fromLTRB(60, 970, 595, 1005);
      final fakeCredOcr = RecognizedText(
        text: 'Mani paid\nMydeen D\n9360056026@slc\n7300\npaid securely by CRED\n24 NOV 2026, 11:19AM | TXN ID: 669407427418',
        blocks: [
          TextBlock(
            text: '7300',
            lines: [
              TextLine(
                text: '7300',
                elements: [
                  TextElement(
                    text: '7300',
                    symbols: const [],
                    boundingBox: heroBox,
                    recognizedLanguages: const ['en'],
                    cornerPoints: const [],
                    confidence: 0.9,
                    angle: 0,
                  ),
                ],
                boundingBox: heroBox,
                recognizedLanguages: const ['en'],
                cornerPoints: const [],
                confidence: 0.9,
                angle: 0,
              ),
              TextLine(
                text: '24 NOV 2026, 11:19AM | TXN ID: 669407427418',
                elements: [
                  TextElement(
                    text: '669407427418',
                    symbols: const [],
                    boundingBox: txnBox,
                    recognizedLanguages: const ['en'],
                    cornerPoints: const [],
                    confidence: 0.9,
                    angle: 0,
                  ),
                ],
                boundingBox: txnBox,
                recognizedLanguages: const ['en'],
                cornerPoints: const [],
                confidence: 0.9,
                angle: 0,
              ),
            ],
            boundingBox: heroBox,
            recognizedLanguages: const ['en'],
            cornerPoints: const [],
          ),
        ],
      );
      final parsedCred = UpiProofOcrService.parseRecognizedTextWithImage(
        fakeCredOcr,
        rgbaImage: credRgba,
        expectedAmount: 1500, // default entered fee differs from ₹300!
      );
      expect(parsedCred.amountInr, 300);
      expect(parsedCred.utr, '669407427418');
      expect(parsedCred.hasPixelVerification, isTrue);

      // Tight CRED hero crop + Android TextSymbol boundingBox path.
      const tightCredBox = Rect.fromLTRB(260, 485, 398, 535);
      const rupeeSymbolBox = Rect.fromLTRB(260, 485, 294, 535);
      const digitsBox = Rect.fromLTRB(295, 485, 398, 535);
      expect(
        RupeeGlyphDetector.isRupeeGlyph(
          credRgba,
          tightCredBox,
          isolateFirstGlyph: true,
        ),
        isTrue,
        reason: 'CRED tight ₹300 metrics: '
            '${RupeeGlyphDetector.analyzeRegion(credRgba, tightCredBox, isolateFirstGlyph: true)}',
      );
      final androidSymbolsCredOcr = RecognizedText(
        text: 'Mani paid\n7300\nTXN ID: 669407427418',
        blocks: [
          TextBlock(
            text: '7300',
            lines: [
              TextLine(
                text: '7300',
                elements: [
                  TextElement(
                    text: '7300',
                    symbols: [
                      TextSymbol(
                        text: '7',
                        boundingBox: rupeeSymbolBox,
                        recognizedLanguages: const ['en'],
                        cornerPoints: const [],
                        confidence: 0.9,
                        angle: 0,
                      ),
                      TextSymbol(
                        text: '3',
                        boundingBox: const Rect.fromLTRB(295, 485, 329, 535),
                        recognizedLanguages: const ['en'],
                        cornerPoints: const [],
                        confidence: 0.9,
                        angle: 0,
                      ),
                      TextSymbol(
                        text: '0',
                        boundingBox: const Rect.fromLTRB(330, 485, 363, 535),
                        recognizedLanguages: const ['en'],
                        cornerPoints: const [],
                        confidence: 0.9,
                        angle: 0,
                      ),
                      TextSymbol(
                        text: '0',
                        boundingBox: const Rect.fromLTRB(364, 485, 398, 535),
                        recognizedLanguages: const ['en'],
                        cornerPoints: const [],
                        confidence: 0.9,
                        angle: 0,
                      ),
                    ],
                    boundingBox: tightCredBox,
                    recognizedLanguages: const ['en'],
                    cornerPoints: const [],
                    confidence: 0.9,
                    angle: 0,
                  ),
                ],
                boundingBox: tightCredBox,
                recognizedLanguages: const ['en'],
                cornerPoints: const [],
                confidence: 0.9,
                angle: 0,
              ),
            ],
            boundingBox: tightCredBox,
            recognizedLanguages: const ['en'],
            cornerPoints: const [],
          ),
        ],
      );
      expect(
        UpiProofOcrService.parseRecognizedTextWithImage(
          androidSymbolsCredOcr,
          rgbaImage: credRgba,
          expectedAmount: 1500,
        ).amountInr,
        300,
      );

      // Split `7` + `300` adjacent tokens also normalize to `₹ 300`.
      final splitTokenCredOcr = RecognizedText(
        text: '7 300',
        blocks: [
          TextBlock(
            text: '7 300',
            lines: [
              TextLine(
                text: '7 300',
                elements: [
                  TextElement(
                    text: '7',
                    symbols: const [],
                    boundingBox: rupeeSymbolBox,
                    recognizedLanguages: const ['en'],
                    cornerPoints: const [],
                    confidence: 0.9,
                    angle: 0,
                  ),
                  TextElement(
                    text: '300',
                    symbols: const [],
                    boundingBox: digitsBox,
                    recognizedLanguages: const ['en'],
                    cornerPoints: const [],
                    confidence: 0.9,
                    angle: 0,
                  ),
                ],
                boundingBox: tightCredBox,
                recognizedLanguages: const ['en'],
                cornerPoints: const [],
                confidence: 0.9,
                angle: 0,
              ),
            ],
            boundingBox: tightCredBox,
            recognizedLanguages: const ['en'],
            cornerPoints: const [],
          ),
        ],
      );
      expect(
        UpiProofOcrService.parseRecognizedTextWithImage(
          splitTokenCredOcr,
          rgbaImage: credRgba,
          expectedAmount: 1500,
        ).amountInr,
        300,
      );
    }
  });
}
