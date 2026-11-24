import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_demo_application/core/config/app_config.dart';

void main() {
  test('AppConfig defaults to prod and switches cleanly on Firebase staging project ID', () {
    AppConfig.resetForTesting();
    addTearDown(AppConfig.resetForTesting);

    expect(AppConfig.environment, AppEnvironment.prod);
    expect(AppConfig.isProd, isTrue);
    expect(AppConfig.isStaging, isFalse);
    expect(AppConfig.firebaseProjectId, 'smartgym-os');
    expect(AppConfig.packageId, 'com.smartgym.partner');
    expect(AppConfig.partnerAppTitle(), 'SmartGym Partner');
    expect(AppConfig.customerAppTitle(), 'SmartGym Club');

    expect(AppConfig.parseEnvironment('staging'), AppEnvironment.staging);
    expect(AppConfig.parseEnvironment(' STAGE '), AppEnvironment.staging);
    expect(AppConfig.parseEnvironment('prod'), AppEnvironment.prod);

    AppConfig.syncFromFirebaseProjectId('smartgym-os-staging');
    expect(AppConfig.environment, AppEnvironment.staging);
    expect(AppConfig.isStaging, isTrue);
    expect(AppConfig.firebaseProjectId, 'smartgym-os-staging');
    expect(AppConfig.packageId, 'com.smartgym.partner.staging');
    expect(AppConfig.partnerAppTitle(), 'SmartGym Partner (Staging)');
    expect(AppConfig.customerAppTitle(), 'SmartGym Club (Staging)');

    AppConfig.syncFromFirebaseProjectId('smartgym-os');
    expect(AppConfig.isProd, isTrue);

    expect(
      AppConfig.iosStagingFirebaseOptions.projectId,
      'smartgym-os-staging',
    );
    expect(
      AppConfig.iosStagingFirebaseOptions.iosBundleId,
      'com.smartgym.partner.staging',
    );
  });

  testWidgets('StagingBannerOverlay displays non-blocking STAGING badge only when active', (
    WidgetTester tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StagingBannerOverlay(
          forceShow: true,
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => tapped++,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('STAGING'), findsOneWidget);
    await tester.tap(find.text('Tap Me'));
    await tester.pump();
    expect(tapped, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: StagingBannerOverlay(
          forceShow: false,
          child: Scaffold(body: Text('Prod Screen')),
        ),
      ),
    );
    expect(find.text('STAGING'), findsNothing);
    expect(find.text('Prod Screen'), findsOneWidget);
  });
}
