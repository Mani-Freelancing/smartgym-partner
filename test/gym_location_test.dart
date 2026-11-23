import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_demo_application/apps/partner_app/auth/partner_onboarding_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_shell_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_audit_log_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_revenue_screen.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/data/services/gym_location_service.dart';
import 'package:flutter_demo_application/data/services/onboarding_draft_service.dart';
import 'package:flutter_demo_application/domain/models/gym_fee_plan.dart';
import 'package:flutter_demo_application/domain/models/gym_member.dart';
import 'package:flutter_demo_application/domain/models/gym_tenant.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_bloc.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_event.dart';

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
    expect(find.text('Total Monthly Revenue (Memberships + Personal Training)'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Online / UPI'), findsOneWidget);
    expect(find.text('Active Members'), findsOneWidget);
    expect(find.text('Expiring Soon'), findsOneWidget);
    expect(find.text('Walk-In Leads'), findsOneWidget);
    expect(find.text('Pending Dues'), findsOneWidget);
    expect(find.text('Enroll Member'), findsOneWidget);
    expect(find.byKey(const ValueKey('open_audit_log_btn')), findsNothing);
    expect(find.byKey(const ValueKey('audit_log_search_input')), findsNothing);
    expect(find.text('Complete your gym setup'), findsNothing);
    expect(find.text('Pin Your Gym Location'), findsNothing);
    expect(find.text('Back to Setup Launchpad'), findsNothing);

    final scrollState =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
    await tester.pump();
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

    expect(find.text('₹9,000'), findsOneWidget);
    expect(find.text('₹7,000'), findsOneWidget);
    expect(find.text('₹2,000'), findsOneWidget);
    expect(find.text('4/80 IN FLOOR'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_active')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_expiring')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_walkins')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_metric_dues')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_enroll_member_btn')), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);

    // Search, full directory & redundant Audit Log button should not appear on Home
    expect(find.byKey(const ValueKey('open_audit_log_btn')), findsNothing);
    expect(find.byKey(const ValueKey('audit_log_search_input')), findsNothing);
    expect(find.text('Rohan Verma'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('home_metric_active')));
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
}
