import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_demo_application/apps/partner_app/auth/partner_onboarding_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/analytics/owner_analytics_engine.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_drawer.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_shell_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_audit_log_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_orders_leads_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_revenue_screen.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/data/services/gym_location_service.dart';
import 'package:flutter_demo_application/data/services/onboarding_draft_service.dart';
import 'package:flutter_demo_application/domain/models/gym_fee_plan.dart';
import 'package:flutter_demo_application/domain/models/gym_member.dart';
import 'package:flutter_demo_application/domain/models/gym_tenant.dart';
import 'package:flutter_demo_application/domain/models/removed_record.dart';
import 'package:flutter_demo_application/domain/models/trainer_profile.dart';
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
    expect(w1.buckets.length, 7);
    expect(w1.buckets.every((b) => b.label != 'AI+'), isTrue);

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
  });

  testWidgets('Owner Home Analytics Studio switches timeframes, chart types, and custom calendar cleanly', (
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

    // Assumption-based AI Gym Copilot & forecast points are removed
    expect(find.byKey(const ValueKey('ai_copilot_card')), findsNothing);
    expect(find.byKey(const ValueKey('ai_brief_btn')), findsNothing);
    expect(find.text('AI GYM COPILOT'), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  test('Daily floor crowd auto-resets to 0 on a new calendar day and starts fresh on check-in', () async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final todayKey = GymTenant.dateKeyFor(now);
    final yesterdayKey = GymTenant.dateKeyFor(yesterday);

    final staleGym = GymTenant(
      id: 'gym_daily_reset',
      name: 'Pulse Barbell',
      area: 'Kondapur',
      headTrainer: 'Mani',
      brandColor: const Color(0xFFE5C158),
      activeCrowd: 22,
      crowdDate: yesterdayKey,
      maxCapacity: 60,
      monthlyFee: 2000,
      ptFee: 5000,
    );

    expect(staleGym.activeCrowdForDate(yesterday), 22);
    expect(staleGym.activeCrowdForDate(now), 0);
    expect(staleGym.isCrowdStaleForDate(now), isTrue);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    bloc.add(SyncGymTenantEvent(staleGym));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.liveCrowd, 0);
    expect(bloc.state.currentGym.activeCrowd, 0);
    expect(bloc.state.currentGym.crowdDate, todayKey);

    // First morning QR check-in increments from 0 -> 1 rather than adding to yesterday's 22
    bloc.add(const SimulateQrCheckInEvent());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.liveCrowd, 1);
    expect(bloc.state.currentGym.activeCrowd, 1);
    expect(bloc.state.currentGym.crowdDate, todayKey);
  });

  testWidgets('Removed Staff & Members empty bottom sheet spans full width with no outer margins', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            key: scaffoldKey,
            drawer: const OwnerDrawer(),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();

    final removedItem = find.text('Removed Staff & Members');
    await tester.scrollUntilVisible(
      removedItem,
      200,
      scrollable: find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(removedItem);
    await tester.pumpAndSettle();

    expect(find.text('Removed Staff & Members (0)'), findsOneWidget);
    expect(find.text('No removed trainers or members yet.'), findsOneWidget);

    final sheetRect = tester.getRect(find.byType(BottomSheet));
    expect(sheetRect.left, 0.0);
    expect(sheetRect.right, 390.0);
  });

  testWidgets('OwnerAuditLogScreen renews expired member plan and updates fee & validity', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);
    bloc.add(
      const SyncMembersEvent([
        GymMember(
          id: 'm_exp',
          name: 'Vikram Das',
          phone: '+919800077788',
          planTitle: 'Monthly Regular',
          feePaid: 1500,
          dueAmount: 0,
          joinedDate: '20 Oct 2026',
          expiryDate: '19 Nov 2026',
          daysLeft: -2,
          isPtClient: false,
          addedByTrainer: 'Owner',
          paymentMode: 'Cash',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const OwnerAuditLogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('renew_member_m_exp')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('renew_member_m_exp')));
    await tester.pumpAndSettle();

    expect(find.text('Renew Vikram Das'), findsOneWidget);

    // Online renewal without screenshot proof stays blocked
    await tester.tap(find.byKey(const ValueKey('renew_mode_online')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('renew_submit_btn')));
    await tester.pump();
    expect(
      find.text('Please upload UPI screenshot proof for Online renewal.'),
      findsOneWidget,
    );

    // Cash renewal succeeds and extends validity
    await tester.tap(find.byKey(const ValueKey('renew_mode_cash')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('renew_fee_input')),
      '2200',
    );
    await tester.tap(find.byKey(const ValueKey('renew_submit_btn')));
    await tester.pumpAndSettle();

    final renewed = bloc.state.members.firstWhere((m) => m.id == 'm_exp');
    expect(renewed.feePaid, 2200);
    expect(renewed.daysLeft, greaterThanOrEqualTo(28));
    expect(renewed.isExpired, isFalse);
  });

  testWidgets('OwnerOrdersLeadsScreen edits trainer PT commission & shift and omits duplicate removed section', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);
    bloc.add(
      const SyncTrainersEvent([
        TrainerProfile(
          id: 'tr_edit_1',
          name: 'Coach Arjun',
          phone: '+919800044455',
          specialty: 'Strength',
          shiftSlot: 'Morning (6–10 AM)',
          isOnDuty: true,
          morningCheckInTime: '06:00 AM',
          commissionPercent: 50,
        ),
      ]),
    );
    bloc.add(
      const SyncMembersEvent([
        GymMember(
          id: 'm_pt_1',
          name: 'Meera Nair',
          phone: '+919800055566',
          planTitle: 'PT VIP',
          feePaid: 6000,
          joinedDate: '01 Nov 2026',
          expiryDate: '01 Dec 2026',
          daysLeft: 10,
          assignedTrainer: 'Coach Arjun',
          isPtClient: true,
          addedByTrainer: 'Owner',
        ),
      ]),
    );
    bloc.add(
      const SyncRemovedRecordsEvent([
        RemovedRecord(
          id: 'rem_1',
          type: 'member',
          name: 'Old Member',
          phone: '+919800099900',
          details: 'Monthly • ₹1500',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: const OwnerOrdersLeadsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Duplicate Removed Staff & Members list was cleaned out of Trainers tab, and Keep Base Fee is ON by default
    expect(find.textContaining('REMOVED STAFF & MEMBERS'), findsNothing);
    expect(bloc.state.currentGym.ptSplitExcludesBaseFee, isTrue);
    expect(find.text('Owner: ₹4000  |  Trainer: ₹2000'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trainer_menu_tr_edit_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Commission & Shift'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Coach Arjun'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('edit_trainer_comm_input')),
      '40',
    );
    await tester.tap(find.text('Evening (5–9:30 PM)'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit_trainer_save_btn')));
    await tester.pumpAndSettle();

    final updated = bloc.state.trainers.first;
    expect(updated.commissionPercent, 40);
    expect(updated.shiftSlot, 'Evening (5–9:30 PM)');
    expect(find.text('Assigned PT (1) • 40% Split'), findsOneWidget);
    expect(find.text('Owner: ₹4400  |  Trainer: ₹1600'), findsOneWidget);

    // 100% quick chip in Edit Commission sets full PT add-on payout while keeping ₹2000 base fee for Owner
    await tester.tap(find.byKey(const ValueKey('trainer_menu_tr_edit_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Commission & Shift'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('edit_trainer_comm_100')));
    await tester.tap(find.byKey(const ValueKey('edit_trainer_comm_100')));
    await tester.pump();
    expect(
      find.text('PT Split Preview: Coach gets 100% (Freelance PT) • Owner gets 0%'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('edit_trainer_save_btn')));
    await tester.pumpAndSettle();
    expect(bloc.state.trainers.first.commissionPercent, 100);
    expect(find.text('Owner: ₹2000  |  Trainer: ₹4000'), findsOneWidget);
    expect(
      find.text('Base ₹2000 kept 100% by Owner • Split on ₹4000 PT add-on'),
      findsOneWidget,
    );

    // Toggling off applies 100% to whole PT package fee; toggling back on restores base-fee separation
    await tester.tap(find.byKey(const ValueKey('trainers_exclude_base_switch')));
    await tester.pumpAndSettle();
    expect(bloc.state.currentGym.ptSplitExcludesBaseFee, isFalse);
    expect(find.text('Owner: ₹0  |  Trainer: ₹6000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('trainers_exclude_base_switch')));
    await tester.pumpAndSettle();
    expect(bloc.state.currentGym.ptSplitExcludesBaseFee, isTrue);
    expect(find.text('Owner: ₹2000  |  Trainer: ₹4000'), findsOneWidget);
    expect(
      find.text('Base ₹2000 kept 100% by Owner • Split on ₹4000 PT add-on'),
      findsOneWidget,
    );
  });

  testWidgets('CEO Overview shows Coach Payout vs Net Owner Revenue and Add Trainer has 100% chip', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);

    bloc.add(
      const SyncGymTenantEvent(
        GymTenant(
          id: 'gym_net_1',
          name: 'Apex Iron',
          area: 'Hitech',
          headTrainer: 'Owner',
          brandColor: Color(0xFFE5C158),
          activeCrowd: 2,
          maxCapacity: 60,
          monthlyFee: 1500,
          ptFee: 6000,
          ptSplitExcludesBaseFee: true,
        ),
      ),
    );
    bloc.add(
      const SyncTrainersEvent([
        TrainerProfile(
          id: 'tr_100',
          name: 'Coach Dev',
          phone: '+919800088899',
          specialty: 'Freelance PT',
          isOnDuty: true,
          morningCheckInTime: '06:00 AM',
          commissionPercent: 100,
        ),
      ]),
    );
    bloc.add(
      const SyncMembersEvent([
        GymMember(
          id: 'm_pt',
          name: 'Karan',
          phone: '+919800011111',
          planTitle: 'PT VIP',
          feePaid: 6000,
          joinedDate: 'Today',
          expiryDate: '30d from today',
          daysLeft: 30,
          assignedTrainer: 'Coach Dev',
          isPtClient: true,
          addedByTrainer: 'Owner',
        ),
        GymMember(
          id: 'm_reg',
          name: 'Neha',
          phone: '+919800022222',
          planTitle: 'Monthly',
          feePaid: 2000,
          joinedDate: 'Today',
          expiryDate: '30d from today',
          daysLeft: 30,
          isPtClient: false,
          addedByTrainer: 'Owner',
        ),
      ]),
    );

    final report = OwnerAnalyticsEngine.buildReport(
      state: bloc.state,
      range: AnalyticsRange.month1,
    );
    // Wait a tick if events are queued asynchronously
    await tester.pump();
    final syncedReport = OwnerAnalyticsEngine.buildReport(
      state: bloc.state,
      range: AnalyticsRange.month1,
    );
    expect(syncedReport.totalPeriodRevenue, 8000);
    // Base ₹1500 of m_pt + ₹2000 of m_reg = ₹3500 Net Owner; ₹4500 Coach Payout
    expect(syncedReport.coachPayout, 4500);
    expect(syncedReport.ownerNetRevenue, 3500);
    // Suppress unused warning on pre-pump report if any
    expect(report.range, AnalyticsRange.month1);

    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            key: scaffoldKey,
            drawer: const OwnerDrawer(),
            body: const OwnerRevenueScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('hero_net_owner_chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('hero_coach_payout_chip')), findsOneWidget);
    expect(find.text('Net Owner'), findsOneWidget);
    expect(find.text('₹3,500'), findsOneWidget);
    expect(find.text('Coach Payout'), findsOneWidget);
    expect(find.text('₹4,500'), findsOneWidget);

    // Drawer -> Add Trainer sheet includes 100% quick chip
    scaffoldKey.currentState!.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Add Trainer by Phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('add_trainer_comm_100')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('add_trainer_comm_100')));
    await tester.tap(find.byKey(const ValueKey('add_trainer_comm_100')));
    await tester.pump();
    final tf = tester.widget<TextField>(
      find.byKey(const ValueKey('add_trainer_comm_input')),
    );
    expect(tf.controller?.text, '100');
  });
}
