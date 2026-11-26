import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo_application/apps/customer_app/auth/customer_login_screen.dart';
import 'package:flutter_demo_application/apps/customer_app/screens/customer_pass_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/auth/partner_login_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_drawer.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/owner_shell_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_audit_log_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_orders_leads_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/owner/screens/owner_revenue_screen.dart';
import 'package:flutter_demo_application/apps/partner_app/trainer/trainer_shell_screen.dart';
import 'package:flutter_demo_application/core/theme/app_theme.dart';
import 'package:flutter_demo_application/core/widgets/cred_neopop_widgets.dart';
import 'package:flutter_demo_application/data/repositories/gym_repository.dart';
import 'package:flutter_demo_application/domain/models/partner_role.dart';
import 'package:flutter_demo_application/main_partner.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_bloc.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_event.dart';
import 'package:flutter_demo_application/shared_bloc/smart_gym_state.dart';

void main() {
  testWidgets(
    'SmartGymPartnerApp switches MaterialApp theme: light for Partner Login & Owner, dark for Trainer',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SmartGymPartnerApp());
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Unauthenticated Partner Login uses Light Sapphire Theme
      final loginFinder = find.byType(PartnerLoginScreen);
      expect(loginFinder, findsOneWidget);
      final loginCtx = tester.element(loginFinder);
      expect(Theme.of(loginCtx).brightness, Brightness.light);
      expect(AppPalette.of(loginCtx), AppPalette.light);
      expect(AppPalette.of(loginCtx).isDark, isFalse);

      final appLogin = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(appLogin.theme?.brightness, Brightness.light);

      // 2. Logging in as Owner keeps MaterialApp and shell in Light Theme
      final bloc = BlocProvider.of<SmartGymBloc>(loginCtx);
      bloc.add(
        const LoginPartnerEvent(
          role: PartnerRole.owner,
          phone: '+919849012345',
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final appOwner = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(appOwner.theme?.brightness, Brightness.light);
      expect(
        appOwner.theme?.scaffoldBackgroundColor,
        AppTheme.lightScaffoldBg,
      );

      final ownerShell = find.byType(OwnerShellScreen);
      expect(ownerShell, findsOneWidget);
      final ownerCtx = tester.element(ownerShell);
      expect(Theme.of(ownerCtx).brightness, Brightness.light);
      expect(AppPalette.of(ownerCtx), AppPalette.light);
      expect(AppPalette.of(ownerCtx).isDark, isFalse);

      // 3. Logging out restores Light Login; signing in as Trainer switches to Dark Theme
      bloc.add(const LogoutPartnerEvent());
      await tester.pump(const Duration(milliseconds: 300));
      bloc.add(
        const LoginPartnerEvent(
          role: PartnerRole.trainer,
          phone: '+919111111111',
          trainerName: 'Coach Karthik',
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final appTrainer = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(appTrainer.theme?.brightness, Brightness.dark);

      final trainerShell = find.byType(TrainerShellScreen);
      expect(trainerShell, findsOneWidget);
      final trainerCtx = tester.element(trainerShell);
      expect(Theme.of(trainerCtx).brightness, Brightness.dark);
      expect(AppPalette.of(trainerCtx).isDark, isTrue);
    },
  );

  testWidgets(
    'Standalone Owner screens enforce Light Theme & AppPalette.light inside bare MaterialApp',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bloc = SmartGymBloc(repository: GymRepository());
      addTearDown(bloc.close);

      for (final screen in const <Widget>[
        OwnerRevenueScreen(),
        OwnerAuditLogScreen(),
        OwnerOrdersLeadsScreen(),
        OwnerDrawer(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: bloc,
              child: Scaffold(body: screen),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Descendant inside screen's subtree must see Light Theme & AppPalette.light
        final inner = find.descendant(
          of: find.byWidget(screen),
          matching: find.byType(BlocBuilder<SmartGymBloc, SmartGymState>),
        );
        expect(inner, findsWidgets);
        final ctx = tester.element(inner.first);
        expect(Theme.of(ctx).brightness, Brightness.light);
        expect(AppPalette.of(ctx), AppPalette.light);
      }
    },
  );

  testWidgets(
    'CredMetalCard uses crisp white surface in Light Theme and CRED gradient in Dark Theme',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: CredMetalCard(
              child: Text('Light Card'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(CredMetalCard),
          matching: find.byType(Container),
        ),
      ).toList();
      final lightOuterBox = lightContainers.first.decoration! as BoxDecoration;
      final lightInnerBox = lightContainers[1].decoration! as BoxDecoration;
      expect(lightOuterBox.gradient, isNull);
      expect(lightOuterBox.border, isNotNull);
      expect(lightInnerBox.color, AppTheme.lightCardSurface);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: CredMetalCard(
              child: Text('Dark Card'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final darkContainers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(CredMetalCard),
          matching: find.byType(Container),
        ),
      ).toList();
      final darkOuterBox = darkContainers.first.decoration! as BoxDecoration;
      final darkInnerBox = darkContainers[1].decoration! as BoxDecoration;
      expect(darkOuterBox.gradient, isA<LinearGradient>());
      expect(darkInnerBox.color, isNull);
      expect(darkInnerBox.gradient, isA<RadialGradient>());
    },
  );

  testWidgets(
    'CustomerLoginScreen & CustomerPassScreen stay in existing CRED Dark Theme',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bloc = SmartGymBloc(repository: GymRepository());
      addTearDown(bloc.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: BlocProvider.value(
            value: bloc,
            child: const CustomerLoginScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      final custLoginCtx = tester.element(find.byType(CustomerLoginScreen));
      expect(Theme.of(custLoginCtx).brightness, Brightness.dark);
      expect(AppPalette.of(custLoginCtx), AppPalette.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(
              backgroundColor: AppTheme.scaffoldBg,
              body: CustomerPassScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      final passCtx = tester.element(find.byType(CustomerPassScreen));
      expect(Theme.of(passCtx).brightness, Brightness.dark);
      expect(AppPalette.of(passCtx), AppPalette.dark);
      expect(AppPalette.of(passCtx).isDark, isTrue);

      final customerCardFinder = find.descendant(
        of: find.byType(CustomerPassScreen),
        matching: find.byType(CredMetalCard),
      );
      expect(customerCardFinder, findsWidgets);
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: customerCardFinder.first,
          matching: find.byType(Container),
        ),
      ).toList();
      final outerBox = containers.first.decoration! as BoxDecoration;
      final innerBox = containers[1].decoration! as BoxDecoration;
      expect(outerBox.gradient, isA<LinearGradient>());
      expect(innerBox.color, isNull);
      expect(innerBox.gradient, isA<RadialGradient>());
    },
  );
}
