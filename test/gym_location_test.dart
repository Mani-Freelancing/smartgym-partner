import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_demo_application/apps/partner_app/auth/partner_onboarding_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/analytics/owner_analytics_engine.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_shell_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_audit_log_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_revenue_screen.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/data/services/gym_location_service.dart';
import 'package:flutter_demo_application/data/services/onboarding_draft_service.dart';
import 'package:flutter_demo_application/domain/models/gym_fee_plan.dart';
import 'package:flutter_demo_application/domain/models/gym_member.dart';
import 'package:flutter_demo_application/domain/models/gym_tenant.dart';
import 'package:flutter_demo_application/domain/models/walk_in_enquiry.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_bloc.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_event.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_state.dart';

void main() {
  test('GymLocationService formats meters and kilometers cleanly', () {
    expect(GymLocationService.formatDistance(42.4), '42 m');
    expect(GymLocationService.formatDistance(999.0), '999 m');
    expect(GymLocationService.formatDistance(1400.0), '1.4 km');
    expect(GymLocationService.formatDistance(2360.0), '2.4 km');
    expect(GymLocationService.formatDistance(12400.0), '12 km');
  });

  test('GymLocationService parses Photon and Nominatim place results accurately', () {
    final photonHits = GymLocationService.parsePhotonResponse({
      'features': [
        {
          'geometry': {
            'coordinates': [78.3908, 17.4485],
          },
          'properties': {
            'name': 'Cyber Towers',
            'street': 'HITEC City Main Road',
            'city': 'Hyderabad',
            'state': 'Telangana',
          },
        },
      ],
    });
    expect(photonHits.length, 1);
    expect(photonHits.first.title, 'Cyber Towers');
    expect(photonHits.first.latitude, 17.4485);
    expect(photonHits.first.longitude, 78.3908);
    expect(photonHits.first.subtitle, contains('Hyderabad'));

    final nominatimHits = GymLocationService.parseNominatimResponse([
      {
        'lat': '13.0827',
        'lon': '80.2707',
        'name': 'Marina Beach',
        'display_name': 'Marina Beach, Triplicane, Chennai, Tamil Nadu',
      },
    ]);
    expect(nominatimHits.length, 1);
    expect(nominatimHits.first.title, 'Marina Beach');
    expect(nominatimHits.first.latitude, 13.0827);
    expect(nominatimHits.first.longitude, 80.2707);
    expect(nominatimHits.first.subtitle, 'Triplicane, Chennai, Tamil Nadu');

    final plainPair = GymLocationService.parseCoordinatePair('17.44852, 78.39081');
    expect(plainPair?.latitude, 17.44852);
    expect(plainPair?.longitude, 78.39081);

    final gmapsUrlPair = GymLocationService.parseCoordinatePair(
      'https://www.google.com/maps/place/Gym/@13.0827,80.2707,17z',
    );
    expect(gmapsUrlPair?.latitude, 13.0827);
    expect(gmapsUrlPair?.longitude, 80.2707);

    final exactPinPair = GymLocationService.parseCoordinatePair(
      'https://www.google.com/maps/place/Gym/@13.0800,80.2700,17z/data=!3m1!1e3!3d13.08275!4d80.27075',
    );
    expect(exactPinPair?.latitude, 13.08275);
    expect(exactPinPair?.longitude, 80.27075);

    expect(
      GymLocationService.parseCoordinatePair('<div>12, 24</div>', allowBarePair: false),
      isNull,
    );
    expect(GymLocationService.parseCoordinatePair('95.0, 78.0'), isNull);
    expect(GymLocationService.parseCoordinatePair('0, 0'), isNull);
  });

  test('GymFeePlan resolves multi-tier pricing and OnboardingDraft round-trips custom plans', () {
    final defaults = GymFeePlan.defaultPlans(monthlyFee: 1500, ptFee: 6000);
    expect(defaults.length, 5);
    expect(
      GymFeePlan.matchPriceForDuration(defaults, months: 3, isPt: false),
      4000,
    );
    expect(
      GymFeePlan.matchPriceForDuration(defaults, months: 12, isPt: false),
      12000,
    );
    expect(GymFeePlan.resolveMonthlyFee(defaults), 1500);
    expect(GymFeePlan.resolvePtFee(defaults), 6000);

    final withCustom = [
      ...defaults,
      const GymFeePlan(
        id: 'custom_couple',
        name: 'Couple Plan',
        price: 2500,
        durationDays: 30,
        durationMonths: 1,
        isCustom: true,
      ),
    ];
    final draft = OnboardingDraft(
      ownerStep: 1,
      gymName: 'Iron Pulse',
      feePlans: withCustom,
    );
    final decoded = OnboardingDraft.fromJson(draft.toJson());
    expect(decoded.feePlans.length, 6);
    expect(decoded.feePlans.last.name, 'Couple Plan');
    expect(decoded.feePlans.last.price, 2500);
    expect(decoded.feePlans.last.isCustom, isTrue);
  });

  test('UpdateGymSettingsEvent stores, updates, and clears GPS geofence', () async {
    final bloc = SmartGymBloc(repository: GymRepository());
    expect(bloc.state.currentGym.hasLocation, isFalse);
    expect(bloc.state.currentGym.requireGpsCheckIn, isTrue);
    expect(bloc.state.currentGym.checkInRadiusMeters, 100);

    bloc.add(
      const UpdateGymSettingsEvent(
        name: 'Mani Fit Studio',
        area: 'Chennai',
        monthlyFee: 1500,
        ptFee: 5000,
        maxCapacity: 60,
        latitude: 13.0827,
        longitude: 80.2707,
        checkInRadiusMeters: 150,
        requireGpsCheckIn: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.currentGym.hasLocation, isTrue);
    expect(bloc.state.currentGym.latitude, 13.0827);
    expect(bloc.state.currentGym.longitude, 80.2707);
    expect(bloc.state.currentGym.checkInRadiusMeters, 150);

    bloc.add(
      const UpdateGymSettingsEvent(
        name: 'Mani Fit Studio',
        area: 'Chennai',
        monthlyFee: 1500,
        ptFee: 5000,
        maxCapacity: 60,
        clearLocation: true,
        requireGpsCheckIn: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.currentGym.hasLocation, isFalse);
    expect(bloc.state.currentGym.requireGpsCheckIn, isFalse);

    await bloc.close();
  });

  testWidgets('PartnerOnboardingScreen walks Owner horizontally through 3 steps and resumes draft after restart', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const PartnerOnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('Gym Info'), findsOneWidget);
    expect(find.text('Fees'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);

    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
    }

    await tapVisible(find.text('SAVE & NEXT'));
    await tester.pump();
    expect(find.text('Please fill in all 3 fields to continue.'), findsOneWidget);

    final step1Fields = find.byType(TextField);
    await tester.enterText(step1Fields.at(0), 'Iron Pulse Gym');
    await tester.enterText(step1Fields.at(1), 'Madhapur, Hyderabad');
    await tester.enterText(step1Fields.at(2), 'Mani');
    await tapVisible(find.text('SAVE & NEXT'));
    await tester.pumpAndSettle();

    // Step 2: Multi-tier Fees, Custom Packages & Capacity
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('1 Month Regular'), findsOneWidget);
    expect(find.text('3 Months Quarterly'), findsOneWidget);
    expect(find.text('6 Months Half-Yearly'), findsOneWidget);
    expect(find.text('1 Year Annual'), findsOneWidget);
    expect(find.text('Personal Training VIP'), findsOneWidget);
    expect(find.text('ADD CUSTOM PLAN'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('plan_price_plan_1m')),
      '2200',
    );
    await tapVisible(find.text('+ Couple Plan (₹2500)'));
    await tester.pump();
    expect(find.text('Couple Plan'), findsOneWidget);

    await tapVisible(find.text('SAVE & NEXT'));
    await tester.pumpAndSettle();

    // Step 3: Exactly 2 differentiated options (Use Current Location OR Paste from Google Maps), no manual Lat/Lng inputs
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('step3_lat_input')), findsNothing);
    expect(find.byKey(const ValueKey('step3_lng_input')), findsNothing);
    expect(find.text('OPTION 1 • WHEN AT GYM'), findsOneWidget);
    expect(find.text('Use Current Location'), findsOneWidget);
    expect(find.text('OPTION 2 • FROM GOOGLE MAPS'), findsOneWidget);
    expect(find.text('Paste from Google Maps'), findsOneWidget);
    expect(find.text('How to copy Google Maps link?'), findsOneWidget);
    expect(find.text('LAUNCH MY GYM'), findsOneWidget);

    await tapVisible(find.byKey(const ValueKey('toggle_lat_lng_guide')));
    await tester.pump();
    expect(find.text('Open Google Maps'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('step3_maps_link_input')),
      'https://www.google.com/maps/place/IronPulse/@17.44852,78.39081,17z',
    );
    await tester.pumpAndSettle();

    // After fetching coordinates, both options hide and Confirmed card + Edit button appear
    expect(find.text('Gym Location Added'), findsOneWidget);
    expect(find.textContaining('17.44852, 78.39081'), findsOneWidget);
    expect(find.byKey(const ValueKey('step3_edit_location_btn')), findsOneWidget);
    expect(find.text('OPTION 1 • WHEN AT GYM'), findsNothing);
    expect(find.text('OPTION 2 • FROM GOOGLE MAPS'), findsNothing);

    // Tapping Edit reveals the two options again
    await tapVisible(find.byKey(const ValueKey('step3_edit_location_btn')));
    await tester.pump();
    expect(find.text('OPTION 1 • WHEN AT GYM'), findsOneWidget);
    expect(find.text('OPTION 2 • FROM GOOGLE MAPS'), findsOneWidget);

    // Simulate closing the app cleanly & reopening onto onboarding
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const PartnerOnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Must resume automatically at Step 3 with Confirmed card (options collapsed)
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.text('Resumed where you left off'), findsOneWidget);
    expect(find.text('Gym Location Added'), findsOneWidget);
    expect(find.textContaining('17.44852, 78.39081'), findsOneWidget);
    expect(find.text('OPTION 1 • WHEN AT GYM'), findsNothing);

    await tapVisible(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('2200'), findsOneWidget);
    expect(find.text('Couple Plan'), findsOneWidget);

    // Reset wipes draft and returns to Step 1
    await tapVisible(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    final clearedDraft = await OnboardingDraftService.loadDraft('');
    expect(clearedDraft, isNull);
  });

  testWidgets('Day-1 owner with 0 members sees standard CEO Overview dashboard directly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const OwnerRevenueScreen(),
          ),
        ),
      ),
    );
    bloc.add(const SyncMembersEvent([]));
    bloc.add(
      const SyncGymTenantEvent(
        GymTenant(
          id: 'new_gym_1',
          name: 'Iron Pulse Gym',
          area: 'Madhapur, Hyderabad',
          headTrainer: 'Mani',
          brandColor: Color(0xFFE5C158),
          activeCrowd: 0,
          maxCapacity: 60,
          monthlyFee: 1800,
          ptFee: 6000,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('IRON PULSE GYM • CEO OVERVIEW'), findsOneWidget);
    expect(find.text('0/60 IN FLOOR'), findsOneWidget);
    expect(find.text('Last 30 Days Collection'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Online / UPI'), findsOneWidget);
    expect(find.text('Active Members'), findsOneWidget);
    expect(find.text('Expiring Soon'), findsOneWidget);
    expect(find.text('Walk-In Leads'), findsOneWidget);
    expect(find.text('Pending Dues'), findsOneWidget);
    expect(find.byKey(const ValueKey('open_audit_log_btn')), findsNothing);
    expect(find.byKey(const ValueKey('audit_log_search_input')), findsNothing);
    expect(find.text('Complete your gym setup'), findsNothing);
    expect(find.text('Pin Your Gym Location'), findsNothing);
    expect(find.text('Back to Setup Launchpad'), findsNothing);

    final scrollState =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('Enroll Member'), findsOneWidget);
    expect(
      find.text(
        'No gym members added yet.\nTap Enroll Member above to add your first paid member and start tracking collections live.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Owner Home splits summary metrics from separate Audit Log screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const OwnerRevenueScreen(),
          ),
        ),
      ),
    );
    bloc.add(
      const SyncGymTenantEvent(
        GymTenant(
          id: 'gym_split_1',
          name: 'Apex Barbell',
          area: 'Jubilee Hills',
          headTrainer: 'Vikram',
          brandColor: Color(0xFFE5C158),
          activeCrowd: 4,
          maxCapacity: 80,
          monthlyFee: 2000,
          ptFee: 7000,
        ),
      ),
    );
    bloc.add(
      const SyncMembersEvent([
        GymMember(
          id: 'm1',
          name: 'Rohan Verma',
          phone: '+919800011122',
          planTitle: 'Monthly Plan',
          feePaid: 2000,
          joinedDate: '01 Nov',
          expiryDate: '01 Dec',
          daysLeft: 20,
          isPtClient: false,
          addedByTrainer: 'Owner',
          paymentMode: 'Online',
        ),
        GymMember(
          id: 'm2',
          name: 'Sneha Nair',
          phone: '+919800033344',
          planTitle: 'Quarterly PT',
          feePaid: 5000,
          dueAmount: 500,
          joinedDate: '15 Sep',
          expiryDate: '25 Nov',
          daysLeft: 2,
          isPtClient: true,
          assignedTrainer: 'Arjun',
          addedByTrainer: 'Arjun',
          paymentMode: 'Cash',
        ),
        GymMember(
          id: 'm3',
          name: 'Kiran Rao',
          phone: '+919800055566',
          planTitle: 'Monthly Plan',
          feePaid: 2000,
          joinedDate: '10 Oct',
          expiryDate: '10 Nov',
          daysLeft: 0,
          isPtClient: false,
          addedByTrainer: 'Owner',
          paymentMode: 'Cash',
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Total Enrolled: ₹9,000'), findsOneWidget);
    expect(find.text('Last 30 Days Collection'), findsOneWidget);
    expect(find.text('₹2,000'), findsAtLeastNWidgets(1));
    expect(find.text('4/80 IN FLOOR'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_active')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_expiring')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_walkins')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_dues')), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);

    // Search, full directory & redundant Audit Log button should not appear on Home
    expect(find.byKey(const ValueKey('open_audit_log_btn')), findsNothing);
    expect(find.byKey(const ValueKey('audit_log_search_input')), findsNothing);
    expect(find.text('Rohan Verma'), findsNothing);

    final scrollState =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(const ValueKey('home_enroll_member_btn')), findsOneWidget);

    scrollState.position.jumpTo(0);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home_metric_active')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(OwnerAuditLogScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('audit_log_search_input')), findsOneWidget);
    expect(find.text('Apex Barbell • 3 of 3 shown'), findsOneWidget);
    expect(find.text('Rohan Verma'), findsOneWidget);
    expect(find.text('Sneha Nair'), findsOneWidget);

    await tester.tap(find.text('Dues'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Apex Barbell • 1 of 3 shown'), findsOneWidget);
    expect(find.text('Sneha Nair'), findsOneWidget);
    expect(find.text('Rohan Verma'), findsNothing);
  });

  testWidgets('OwnerShellScreen 3-tab Owner Pulse switches Home, pre-filtered Audit Log, and Trainers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const OwnerShellScreen(),
        ),
      ),
    );
    bloc.add(
      const SyncGymTenantEvent(
        GymTenant(
          id: 'gym_shell_1',
          name: 'Apex Barbell',
          area: 'Jubilee Hills',
          headTrainer: 'Vikram',
          brandColor: Color(0xFFE5C158),
          activeCrowd: 4,
          maxCapacity: 80,
          monthlyFee: 2000,
          ptFee: 7000,
        ),
      ),
    );
    bloc.add(
      const SyncMembersEvent([
        GymMember(
          id: 'm1',
          name: 'Rohan Verma',
          phone: '+919800011122',
          planTitle: 'Monthly Plan',
          feePaid: 2000,
          joinedDate: '01 Nov',
          expiryDate: '01 Dec',
          daysLeft: 20,
          isPtClient: false,
          addedByTrainer: 'Owner',
          paymentMode: 'Online',
        ),
        GymMember(
          id: 'm2',
          name: 'Sneha Nair',
          phone: '+919800033344',
          planTitle: 'Quarterly PT',
          feePaid: 5000,
          dueAmount: 500,
          joinedDate: '15 Sep',
          expiryDate: '25 Nov',
          daysLeft: 2,
          isPtClient: true,
          assignedTrainer: 'Arjun',
          addedByTrainer: 'Arjun',
          paymentMode: 'Cash',
        ),
        GymMember(
          id: 'm3',
          name: 'Kiran Rao',
          phone: '+919800055566',
          planTitle: 'Monthly Plan',
          feePaid: 2000,
          joinedDate: '10 Oct',
          expiryDate: '10 Nov',
          daysLeft: 0,
          isPtClient: false,
          addedByTrainer: 'Owner',
          paymentMode: 'Cash',
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('owner_nav_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('owner_nav_audit')), findsOneWidget);
    expect(find.byKey(const ValueKey('owner_nav_trainers')), findsOneWidget);

    // Tapping Expiring Soon switches directly to Audit Log tab filtered to Expiring
    await tester.tap(find.byKey(const ValueKey('home_metric_expiring')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('WHO JOINED & AUDIT LOG'), findsOneWidget);
    expect(find.text('2 of 3 shown'), findsOneWidget);
    expect(find.text('Sneha Nair'), findsOneWidget);
    expect(find.text('Kiran Rao'), findsOneWidget);
    expect(find.text('Rohan Verma'), findsNothing);

    // Filter to Dues inside embedded tab
    await tester.tap(find.text('Dues'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('1 of 3 shown'), findsOneWidget);
    expect(find.text('Sneha Nair'), findsOneWidget);

    // Return to Home tab, then tap Walk-In Leads to jump to Trainers tab
    await tester.tap(find.byKey(const ValueKey('owner_nav_home')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('home_metric_walkins')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TRAINER DUTY, PT CLIENTS & COMMISSION SPLIT'), findsOneWidget);
  });

  test('OwnerAnalyticsEngine computes 1W, 1M, 2M, Custom windows and AI insights accurately', () {
    final now = DateTime(2026, 11, 23);
    expect(
      OwnerAnalyticsEngine.parseDate('Today, 09:30 AM', now: now),
      DateTime(2026, 11, 23),
    );
    expect(
      OwnerAnalyticsEngine.parseDate('12 Nov 2026', now: now),
      DateTime(2026, 11, 12),
    );
    expect(
      OwnerAnalyticsEngine.parseDate('18 Oct', now: now),
      DateTime(2026, 10, 18),
    );

    final state = SmartGymState(
      gyms: const [
        GymTenant(
          id: 'g_ai',
          name: 'Titan Forge',
          area: 'Indiranagar',
          headTrainer: 'Karan',
          brandColor: Color(0xFFE5C158),
          activeCrowd: 24,
          maxCapacity: 30,
          monthlyFee: 2000,
          ptFee: 6000,
        ),
      ],
      members: const [
        GymMember(
          id: 'm_today',
          name: 'Aarav',
          phone: '+919800000001',
          planTitle: 'PT VIP',
          feePaid: 5000,
          joinedDate: 'Today, 10:00 AM',
          expiryDate: '23 Dec 2026',
          daysLeft: 30,
          isPtClient: true,
          addedByTrainer: 'Owner',
          paymentMode: 'Online',
        ),
        GymMember(
          id: 'm_15d',
          name: 'Bhavna',
          phone: '+919800000002',
          planTitle: 'Quarterly',
          feePaid: 3000,
          dueAmount: 500,
          joinedDate: '08 Nov 2026',
          expiryDate: '26 Nov 2026',
          daysLeft: 3,
          isPtClient: false,
          addedByTrainer: 'Owner',
          paymentMode: 'Cash',
        ),
        GymMember(
          id: 'm_45d',
          name: 'Charan',
          phone: '+919800000003',
          planTitle: 'Monthly',
          feePaid: 2000,
          joinedDate: '09 Oct 2026',
          expiryDate: '09 Nov 2026',
          daysLeft: 20,
          isPtClient: false,
          addedByTrainer: 'Owner',
          paymentMode: 'Cash',
        ),
      ],
      trainers: const [],
      enquiries: const [
        WalkInEnquiry(
          id: 'e1',
          name: 'Divya',
          phone: '+919800000004',
          interestedPlan: 'Monthly (₹2000)',
          loggedByTrainer: 'Karan',
          timeLabel: 'Today',
        ),
      ],
      machineGuides: const [],
      mealQueue: const [],
      missingMembers: const [],
    );

    final w1 = OwnerAnalyticsEngine.buildReport(
      state: state,
      range: AnalyticsRange.week1,
      now: now,
    );
    expect(w1.totalPeriodRevenue, 5000);
    expect(w1.periodJoins, 1);
    expect(w1.buckets.last.isForecast, isTrue);

    final m1 = OwnerAnalyticsEngine.buildReport(
      state: state,
      range: AnalyticsRange.month1,
      now: now,
    );
    expect(m1.totalPeriodRevenue, 8000);
    expect(m1.periodJoins, 2);

    final m2 = OwnerAnalyticsEngine.buildReport(
      state: state,
      range: AnalyticsRange.months2,
      now: now,
    );
    expect(m2.totalPeriodRevenue, 10000);
    expect(m2.periodJoins, 3);

    final custom = OwnerAnalyticsEngine.buildReport(
      state: state,
      range: AnalyticsRange.custom,
      customRange: DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
      ),
      now: now,
    );
    expect(custom.totalPeriodRevenue, 2000);
    expect(custom.periodJoins, 1);

    expect(m1.healthScore, inInclusiveRange(0, 100));
    expect(m1.insights.any((i) => i.id == 'collect_dues'), isTrue);
    expect(m1.insights.any((i) => i.id == 'renewal_risk'), isTrue);
    expect(m1.insights.any((i) => i.id == 'lead_pipeline'), isTrue);
    expect(m1.insights.any((i) => i.id == 'crowd_peak'), isTrue);
  });

  testWidgets('Owner Home Analytics Studio switches timeframes, chart types, and AI Brief cleanly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const OwnerRevenueScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final scrollState =
        tester.state<ScrollableState>(find.byType(Scrollable).first);

    // Analytics lives directly inside the starting CEO OVERVIEW card with no duplicate card
    expect(find.text('ANALYTICS STUDIO'), findsNothing);
    expect(find.textContaining('CEO OVERVIEW'), findsOneWidget);
    expect(find.text('Last 30 Days Collection'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('range_chip_1w')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Last 7 Days Collection'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('range_chip_2m')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Last 2 Months Collection'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chart_type_bar')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('chart_type_mix')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('UPI / Online'), findsAtLeastNWidgets(1));
    expect(find.text('Cash Floor'), findsOneWidget);
    expect(find.text('PT VIP Plans'), findsOneWidget);
    expect(find.text('Regular Plans'), findsOneWidget);

    // Custom animated bottom-sheet calendar opens on tap, switches presets/months & applies
    await tester.tap(find.byKey(const ValueKey('range_chip_custom')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('custom_range_sheet')), findsOneWidget);
    expect(find.text('CUSTOM DATE STUDIO'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom_range_apply_btn')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('custom_range_prev_month')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('custom_range_preset_90d')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Apply (90 Days)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('custom_range_apply_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Custom (90 d) Collection'), findsOneWidget);

    // Scroll to AI Copilot card & open Full AI Brief
    scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
    await tester.pump();
    expect(find.byKey(const ValueKey('ai_copilot_card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai_brief_btn')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('AI CEO Forecast & Health Brief'), findsOneWidget);
    expect(find.text('PROJECTED NEXT 30-DAY RUN-RATE'), findsOneWidget);
    expect(find.text('Retention Health'), findsOneWidget);
    expect(find.text('Cash Collection Score'), findsOneWidget);
  });
}
