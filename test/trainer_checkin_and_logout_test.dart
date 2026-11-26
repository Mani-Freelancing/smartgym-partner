import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo_application/apps/customer_app/customer_drawer.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_drawer.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_orders_leads_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_trainer_attendance_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/partner_app_root.dart';
import 'package:flutter_demo_application/apps/partner_app/trainer/screens/trainer_absent_radar_screen.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/domain/models/partner_role.dart';
import 'package:flutter_demo_application/domain/models/trainer_attendance_log.dart';
import 'package:flutter_demo_application/domain/models/trainer_profile.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_bloc.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_event.dart';

void main() {
  test('TrainerProfile formats duty check-in copy cleanly and auto-resets next day', () {
    expect(
      TrainerProfile.formatCheckInTime(DateTime(2026, 11, 26, 16, 25)),
      '04:25 PM',
    );
    expect(
      TrainerProfile.formatCheckInTime(DateTime(2026, 11, 26, 0, 5)),
      '12:05 AM',
    );
    expect(
      TrainerProfile.formatCheckInRecord(DateTime(2026, 11, 26, 16, 25)),
      '2026-11-26 • 04:25 PM',
    );

    const legacyCheckedIn = TrainerProfile(
      id: 't1',
      name: 'Coach Vikram',
      specialty: 'Strength',
      morningCheckInTime: 'Checked In Now',
      isOnDuty: true,
    );
    expect(legacyCheckedIn.needsCheckInTimestampUpgrade, isTrue);
    expect(legacyCheckedIn.radarDutySubtitle, 'Checked in today');
    expect(legacyCheckedIn.ownerDutyBadgeText, 'ON DUTY • TODAY');

    const datedCheckedIn = TrainerProfile(
      id: 't2',
      name: 'Coach Arjun',
      specialty: 'HIIT',
      morningCheckInTime: '2026-11-26 • 04:25 PM',
      isOnDuty: true,
    );
    expect(datedCheckedIn.displayCheckInTime, '04:25 PM');
    expect(
      datedCheckedIn.isCheckedInToday(DateTime(2026, 11, 26, 21, 0)),
      isTrue,
    );
    expect(
      datedCheckedIn.radarDutySubtitleFor(DateTime(2026, 11, 26, 21, 0)),
      'Checked in at 04:25 PM',
    );
    expect(
      datedCheckedIn.ownerDutyBadgeTextFor(DateTime(2026, 11, 26, 21, 0)),
      'ON DUTY • 04:25 PM',
    );
    // Next calendar day automatically resets to off duty
    expect(
      datedCheckedIn.isCheckedInToday(DateTime(2026, 11, 27, 8, 0)),
      isFalse,
    );
    expect(
      datedCheckedIn.radarDutySubtitleFor(DateTime(2026, 11, 27, 8, 0)),
      'Not Checked In Today',
    );
    expect(
      datedCheckedIn.ownerDutyBadgeTextFor(DateTime(2026, 11, 27, 8, 0)),
      'OFF DUTY',
    );

    const offDuty = TrainerProfile(
      id: 't3',
      name: 'Coach Sameer',
      specialty: 'Mobility',
      morningCheckInTime: 'Not Checked In',
      isOnDuty: false,
    );
    expect(offDuty.radarDutySubtitle, 'Not Checked In Today');
    expect(offDuty.ownerDutyBadgeText, 'OFF DUTY');
  });

  testWidgets('TrainerAbsentRadarScreen and OwnerOrdersLeadsScreen show exact check-in time', (
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
          id: 't_legacy',
          name: 'Coach Vikram',
          specialty: 'Strength',
          morningCheckInTime: 'Checked In Now',
          isOnDuty: true,
        ),
        TrainerProfile(
          id: 't_off',
          name: 'Coach Sameer',
          specialty: 'Mobility',
          morningCheckInTime: 'Not Checked In',
          isOnDuty: false,
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
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Checked in at Checked In Now'), findsNothing);
    expect(find.text('Checked in today'), findsOneWidget);
    expect(find.text('Not Checked In Today'), findsOneWidget);

    await tester.tap(find.text('Scan Duty QR'));
    await tester.pump();
    final updatedRecord = bloc.state.trainers[1].morningCheckInTime!;
    expect(
      updatedRecord,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2} • \d{2}:\d{2} (AM|PM)$')),
    );
    final updatedClock = bloc.state.trainers[1].displayCheckInTime;
    expect(find.text('Checked in at $updatedClock'), findsOneWidget);

    // Owner Trainers tab also sees exact "Checked in at <time>" clearly
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
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Checked in at $updatedClock'), findsOneWidget);
    expect(find.textContaining(updatedClock), findsOneWidget);
    expect(find.text('ON DUTY'), findsNWidgets(2));
    expect(find.text('OFF DUTY'), findsNothing);
    expect(find.text('Checked in today'), findsOneWidget);
  });

  testWidgets('Logout asks confirmation popup for Trainer, Owner, and Customer categories', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Trainer header Logout
    final trainerBloc = SmartGymBloc(repository: GymRepository());
    addTearDown(trainerBloc.close);
    trainerBloc.add(
      const LoginPartnerEvent(
        role: PartnerRole.trainer,
        phone: '+919111111111',
        trainerName: 'Coach Vikram',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: trainerBloc,
          child: const PartnerAppRoot(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Logout'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Log Out?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to log out of this account?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('logout_cancel_btn')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(trainerBloc.state.isPartnerLoggedIn, isTrue);

    await tester.tap(find.text('Logout'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('logout_confirm_btn')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(trainerBloc.state.isPartnerLoggedIn, isFalse);

    // 2. Owner drawer Logout
    final ownerBloc = SmartGymBloc(repository: GymRepository());
    addTearDown(ownerBloc.close);
    ownerBloc.add(
      const LoginPartnerEvent(
        role: PartnerRole.owner,
        phone: '+919849012345',
      ),
    );
    final ownerScaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: ownerBloc,
          child: Scaffold(
            key: ownerScaffoldKey,
            drawer: const OwnerDrawer(),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    ownerScaffoldKey.currentState!.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Logout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Log Out?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('logout_confirm_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ownerBloc.state.isPartnerLoggedIn, isFalse);

    // 3. Customer drawer Logout
    final customerBloc = SmartGymBloc(repository: GymRepository());
    addTearDown(customerBloc.close);
    customerBloc.add(
      const LoginPartnerEvent(
        role: PartnerRole.trainer,
        phone: '+919333333333',
      ),
    );
    final custScaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: customerBloc,
          child: Scaffold(
            key: custScaffoldKey,
            drawer: const CustomerDrawer(),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    custScaffoldKey.currentState!.openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Logout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Log Out?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('logout_confirm_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(customerBloc.state.isPartnerLoggedIn, isFalse);
  });

  test('TrainerAttendanceLog formats Today, Yesterday, and past dates cleanly', () {
    final now = DateTime(2026, 11, 26, 17, 0);
    final todayLog = TrainerAttendanceLog.fromDateTime(
      trainerId: 't1',
      trainerName: 'Coach Karthik',
      eventType: 'duty_checkin',
      at: DateTime(2026, 11, 26, 16, 25),
    );
    final yesterdayLog = TrainerAttendanceLog.fromDateTime(
      trainerId: 't1',
      trainerName: 'Coach Karthik',
      eventType: 'login',
      at: DateTime(2026, 11, 25, 9, 10),
    );
    final olderLog = TrainerAttendanceLog.fromDateTime(
      trainerId: 't1',
      trainerName: 'Coach Karthik',
      eventType: 'duty_checkin',
      at: DateTime(2026, 11, 20, 6, 15),
    );

    expect(todayLog.dateKey, '2026-11-26');
    expect(todayLog.timeLabel, '04:25 PM');
    expect(todayLog.eventLabel, 'Duty Check-In');
    expect(todayLog.formattedDateLabelFor(now), 'Today • 26 Nov 2026');
    expect(yesterdayLog.eventLabel, 'App Login');
    expect(yesterdayLog.formattedDateLabelFor(now), 'Yesterday • 25 Nov 2026');
    expect(olderLog.formattedDateLabelFor(now), '20 Nov 2026');
  });

  testWidgets(
    'Trainer logins & duty check-ins save chronologically and Owner sees newest-to-past history from Trainers tab and Drawer',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bloc = SmartGymBloc(repository: GymRepository());
      addTearDown(bloc.close);

      final initialCount = bloc.state.trainerAttendanceLogs.length;
      bloc.add(
        const LoginPartnerEvent(
          role: PartnerRole.trainer,
          phone: '+919111111111',
          trainerName: 'Coach Karthik Reddy',
        ),
      );
      await tester.pump();
      expect(bloc.state.trainerAttendanceLogs.length, initialCount + 1);
      expect(bloc.state.trainerAttendanceLogs.first.eventType, 'login');
      expect(
        bloc.state.trainerAttendanceLogs.first.trainerName,
        'Coach Karthik Reddy',
      );

      bloc.add(const MarkTrainerDutyCheckInEvent(2));
      await tester.pump();
      expect(bloc.state.trainerAttendanceLogs.length, initialCount + 2);
      expect(bloc.state.trainerAttendanceLogs.first.eventType, 'duty_checkin');
      expect(
        bloc.state.trainerAttendanceLogs.first.trainerName,
        'Coach Sameer Khan',
      );

      // 1. From Trainers tab top History button -> shows newest date on top down to past dates
      final shellScaffoldKey = GlobalKey<ScaffoldState>();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: bloc,
            child: Scaffold(
              key: shellScaffoldKey,
              drawer: const OwnerDrawer(),
              body: const OwnerOrdersLeadsScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byKey(const ValueKey('owner_trainer_history_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(OwnerTrainerAttendanceScreen), findsOneWidget);
      expect(find.text('Trainer Login History'), findsOneWidget);
      expect(
        find.text('NEWEST TO OLDEST CHECK-IN & LOGIN LOGS'),
        findsOneWidget,
      );
      expect(find.textContaining('TODAY •'), findsOneWidget);
      expect(find.textContaining('YESTERDAY •'), findsOneWidget);

      // Verify newest date header renders higher (smaller dy) than Yesterday
      final todayY = tester.getTopLeft(find.textContaining('TODAY •')).dy;
      final yesterdayY =
          tester.getTopLeft(find.textContaining('YESTERDAY •')).dy;
      expect(todayY, lessThan(yesterdayY));

      // Back to Trainers tab, open history pre-filtered to Coach Arjun Varma (tr_2)
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trainer_history_tr_2')));
      await tester.pumpAndSettle();

      expect(find.text('Coach Arjun Varma'), findsWidgets);
      expect(find.text('Coach Sameer Khan'), findsWidgets);
      // Selected filter chip excludes Sameer Khan's Duty Check-In row in the list
      final sameerInCard = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Coach Sameer Khan'),
      );
      expect(sameerInCard, findsOneWidget); // Only the filter chip

      // Switch filter to All Trainers -> Sameer Khan entries appear in the list too
      await tester.tap(find.text('All Trainers'));
      await tester.pumpAndSettle();
      expect(sameerInCard, findsNWidgets(3)); // Chip + Today check-in + past seed log

      // 2. OwnerDrawer also exposes Trainer Login History directly
      await tester.pageBack();
      await tester.pumpAndSettle();
      shellScaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trainer Login History'));
      await tester.pumpAndSettle();
      expect(find.byType(OwnerTrainerAttendanceScreen), findsOneWidget);
    },
  );
}
