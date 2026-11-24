import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_add_member_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_audit_log_screen.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/domain/models/gym_member.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_bloc.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_event.dart';

void main() {
  test('MemberGender and GymMember.respectfulName apply respectful titles', () {
    const maleMember = GymMember(
      id: 'm1',
      name: 'Rahul Sharma',
      gender: 'Male',
      phone: '+919849012345',
      planTitle: '1 Month Regular',
      feePaid: 1500,
      joinedDate: '24 Nov 2026',
      expiryDate: '24 Dec 2026',
      daysLeft: 30,
      isPtClient: false,
      addedByTrainer: 'Owner',
    );
    expect(maleMember.genderLabel, 'Male');
    expect(maleMember.honorific, 'Mr.');
    expect(maleMember.respectfulName, 'Mr. Rahul Sharma');

    const femaleMember = GymMember(
      id: 'm2',
      name: 'Sneha Reddy',
      gender: 'Female',
      phone: '+919849012346',
      planTitle: '1 Month Regular',
      feePaid: 1500,
      joinedDate: '24 Nov 2026',
      expiryDate: '24 Dec 2026',
      daysLeft: 30,
      isPtClient: false,
      addedByTrainer: 'Owner',
    );
    expect(femaleMember.genderLabel, 'Female');
    expect(femaleMember.honorific, 'Ms.');
    expect(femaleMember.respectfulName, 'Ms. Sneha Reddy');

    const transMember = GymMember(
      id: 'm3',
      name: 'Sam Nair',
      gender: 'trans',
      phone: '+919849012347',
      planTitle: '1 Month Regular',
      feePaid: 1500,
      joinedDate: '24 Nov 2026',
      expiryDate: '24 Dec 2026',
      daysLeft: 30,
      isPtClient: false,
      addedByTrainer: 'Owner',
    );
    expect(transMember.genderLabel, 'Transgender');
    expect(transMember.honorific, 'Mx.');
    expect(transMember.respectfulName, 'Mx. Sam Nair');

    const alreadyPrefixed = GymMember(
      id: 'm4',
      name: 'Mx. Sam Nair',
      gender: 'Transgender',
      phone: '+919849012348',
      planTitle: '1 Month Regular',
      feePaid: 1500,
      joinedDate: '24 Nov 2026',
      expiryDate: '24 Dec 2026',
      daysLeft: 30,
      isPtClient: false,
      addedByTrainer: 'Owner',
    );
    expect(alreadyPrefixed.respectfulName, 'Mx. Sam Nair');

    const legacyMember = GymMember(
      id: 'm5',
      name: 'Arjun',
      phone: '+919849012349',
      planTitle: '1 Month Regular',
      feePaid: 1500,
      joinedDate: '24 Nov 2026',
      expiryDate: '24 Dec 2026',
      daysLeft: 30,
      isPtClient: false,
      addedByTrainer: 'Owner',
    );
    expect(legacyMember.genderLabel, '');
    expect(legacyMember.respectfulName, 'Arjun');
  });

  testWidgets(
      'OwnerAddMemberScreen requires gender and enrolls Transgender member with Mx. title',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);
    bloc.add(const SyncMembersEvent([]));

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const OwnerAddMemberScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Enroll Paid Member'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Male (Mr.)'), findsOneWidget);
    expect(find.text('Female (Ms.)'), findsOneWidget);
    expect(find.text('Transgender (Mx.)'), findsOneWidget);

    // Default 1 Month Regular plan chip is selected on open, and no duplicate duration row exists.
    final defaultPlanContainer = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('fee_plan_chip_plan_1m')),
        matching: find.byType(Container),
      ),
    );
    final defaultPlanBox = defaultPlanContainer.decoration! as BoxDecoration;
    expect(defaultPlanBox.border?.top.color, const Color(0xFFE5C158));
    expect(find.text('1 Mo'), findsNothing);
    expect(find.text('3 Mos'), findsNothing);
    expect(find.text('6 Mos'), findsNothing);
    expect(find.text('12 Mos'), findsNothing);

    // Tapping 3 Months Quarterly selects that package and updates duration.
    final qPlanChip = find.byKey(const ValueKey('fee_plan_chip_plan_3m'));
    await tester.ensureVisible(qPlanChip);
    await tester.pump();
    await tester.tap(qPlanChip);
    await tester.pump();
    final qPlanContainer = tester.widget<Container>(
      find.descendant(
        of: qPlanChip,
        matching: find.byType(Container),
      ),
    );
    final qPlan = bloc.state.currentGym.effectiveFeePlans
        .firstWhere((p) => p.id == 'plan_3m');
    final qPlanBox = qPlanContainer.decoration! as BoxDecoration;
    expect(qPlanBox.border?.top.color, const Color(0xFFE5C158));
    expect(find.text('₹${qPlan.price}'), findsOneWidget);
    expect(find.textContaining('3 Months'), findsWidgets);

    // Switch back to 1 Month Regular for enrollment.
    final oneMonthChip = find.byKey(const ValueKey('fee_plan_chip_plan_1m'));
    await tester.ensureVisible(oneMonthChip);
    await tester.pump();
    await tester.tap(oneMonthChip);
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('enroll_name_input')),
      'Sam Nair',
    );
    await tester.enterText(
      find.byKey(const ValueKey('enroll_phone_input')),
      '9849012345',
    );
    await tester.pump();

    final submitBtn = find.byKey(const ValueKey('enroll_submit_btn'));
    await tester.ensureVisible(submitBtn);
    await tester.pump();
    await tester.tap(submitBtn);
    await tester.pump();

    expect(find.text('Please select member gender.'), findsOneWidget);
    expect(bloc.state.members, isEmpty);

    final transChip = find.byKey(const ValueKey('gender_chip_transgender'));
    await tester.ensureVisible(transChip);
    await tester.pump();
    await tester.tap(transChip);
    await tester.pump();

    expect(find.text('TRANSGENDER'), findsOneWidget);
    expect(find.text('Mx. Sam Nair'), findsOneWidget);

    await tester.ensureVisible(submitBtn);
    await tester.pump();
    await tester.tap(submitBtn);
    await tester.pump();

    expect(bloc.state.members.length, 1);
    final saved = bloc.state.members.first;
    expect(saved.name, 'Sam Nair');
    expect(saved.gender, 'Transgender');
    expect(saved.respectfulName, 'Mx. Sam Nair');
    expect(saved.planTitle, '1 Month Regular');

    expect(find.text('Member Enrolled!'), findsOneWidget);
    expect(find.text('Gender: Transgender'), findsOneWidget);
    expect(find.textContaining('Mx. Sam Nair'), findsWidgets);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('OwnerAuditLogScreen renders respectful titles and gender tags',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bloc = SmartGymBloc(repository: GymRepository());
    addTearDown(bloc.close);
    bloc.add(
      const SyncMembersEvent([
        GymMember(
          id: 'g1',
          name: 'Arjun Rao',
          gender: 'Male',
          phone: '+919800011111',
          planTitle: 'Monthly Plan',
          feePaid: 1500,
          joinedDate: '24 Nov 2026',
          expiryDate: '24 Dec 2026',
          daysLeft: 30,
          isPtClient: false,
          addedByTrainer: 'Owner',
        ),
        GymMember(
          id: 'g2',
          name: 'Priya Das',
          gender: 'Female',
          phone: '+919800022222',
          planTitle: 'Monthly Plan',
          feePaid: 1500,
          joinedDate: '24 Nov 2026',
          expiryDate: '24 Dec 2026',
          daysLeft: 30,
          isPtClient: false,
          addedByTrainer: 'Owner',
        ),
        GymMember(
          id: 'g3',
          name: 'Sam Nair',
          gender: 'Transgender',
          phone: '+919800033333',
          planTitle: 'Monthly Plan',
          feePaid: 1500,
          joinedDate: '24 Nov 2026',
          expiryDate: '24 Dec 2026',
          daysLeft: 30,
          isPtClient: false,
          addedByTrainer: 'Owner',
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
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mr. Arjun Rao'), findsOneWidget);
    expect(find.text('Ms. Priya Das'), findsOneWidget);
    expect(find.text('Mx. Sam Nair'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Transgender'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('audit_log_search_input')),
      'Transgender',
    );
    await tester.pump();
    expect(find.text('Mx. Sam Nair'), findsOneWidget);
    expect(find.text('Mr. Arjun Rao'), findsNothing);
    expect(find.text('Ms. Priya Das'), findsNothing);
  });
}
