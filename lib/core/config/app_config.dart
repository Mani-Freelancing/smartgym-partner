import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Deployment target for SmartGym Partner and Customer apps.
enum AppEnvironment { staging, prod }

/// Centralized build-time & Firebase-backed environment configuration.
///
/// Separate Staging vs Production using both Gradle/Xcode flavors (`--flavor`)
/// and optional Dart defines (`--dart-define=ENV=staging|prod`). When `ENV` is
/// omitted at compile time, [syncFromFirebaseProjectId] also infers `staging`
/// automatically whenever native Firebase config targets `smartgym-os-staging`.
class AppConfig {
  AppConfig._();

  static const String prodFirebaseProjectId = 'smartgym-os';
  static const String stagingFirebaseProjectId = 'smartgym-os-staging';

  static const String prodPackageId = 'com.smartgym.partner';
  static const String stagingPackageId = 'com.smartgym.partner.staging';

  static const String _rawEnv = String.fromEnvironment('ENV');

  static const String _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _rawGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );

  // Optional per-environment custom REST API endpoints (empty until a custom
  // server/Cloud Functions backend is introduced alongside Firestore).
  static const String _stagingApiBaseUrl = String.fromEnvironment(
    'STAGING_API_BASE_URL',
  );
  static const String _prodApiBaseUrl = String.fromEnvironment(
    'PROD_API_BASE_URL',
  );

  static AppEnvironment? _runtimeDetectedEnv;

  /// True if `--dart-define=ENV=...` was explicitly set at compile time.
  static bool get hasExplicitEnvDefine => _rawEnv.trim().isNotEmpty;

  /// Parses an environment flag such as `'staging'` or `'prod'`.
  static AppEnvironment parseEnvironment(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'staging' || 'stage' || 'dev' => AppEnvironment.staging,
      _ => AppEnvironment.prod,
    };
  }

  /// Syncs runtime environment from `Firebase.app().options.projectId` when
  /// `--dart-define=ENV=...` wasn't passed explicitly (e.g. `flutter run --flavor staging`).
  static void syncFromFirebaseProjectId(String? projectId) {
    if (hasExplicitEnvDefine || projectId == null || projectId.trim().isEmpty) {
      return;
    }
    final trimmed = projectId.trim();
    if (trimmed == stagingFirebaseProjectId || trimmed.contains('staging')) {
      _runtimeDetectedEnv = AppEnvironment.staging;
    } else if (trimmed == prodFirebaseProjectId) {
      _runtimeDetectedEnv = AppEnvironment.prod;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _runtimeDetectedEnv = null;
  }

  static AppEnvironment get environment {
    if (hasExplicitEnvDefine) {
      return parseEnvironment(_rawEnv);
    }
    return _runtimeDetectedEnv ?? AppEnvironment.prod;
  }

  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProd => environment == AppEnvironment.prod;

  static String get environmentName => isStaging ? 'staging' : 'prod';

  static String get firebaseProjectId =>
      isStaging ? stagingFirebaseProjectId : prodFirebaseProjectId;

  static String get packageId => isStaging ? stagingPackageId : prodPackageId;

  static String get apiBaseUrl {
    if (_rawApiBaseUrl.trim().isNotEmpty) {
      return _rawApiBaseUrl.trim();
    }
    return isStaging ? _stagingApiBaseUrl.trim() : _prodApiBaseUrl.trim();
  }

  static String get geminiApiKey => _rawGeminiApiKey.trim();

  static String partnerAppTitle([String baseTitle = 'SmartGym Partner']) =>
      isStaging ? '$baseTitle (Staging)' : baseTitle;

  static String customerAppTitle([String baseTitle = 'SmartGym Club']) =>
      isStaging ? '$baseTitle (Staging)' : baseTitle;

  static const FirebaseOptions iosStagingFirebaseOptions = FirebaseOptions(
    apiKey: 'AIzaSyCsLK9zYvwA-aRe7J9VD-NdMnCmj30RxkM',
    appId: '1:1043626652907:ios:99a65e4fa7c7c35c407aae',
    messagingSenderId: '1043626652907',
    projectId: stagingFirebaseProjectId,
    storageBucket: 'smartgym-os-staging.firebasestorage.app',
    iosBundleId: stagingPackageId,
  );

  /// On Android, `google-services.json` per Gradle flavor (`staging`/`prod`)
  /// already selects the target Firebase project automatically even if
  /// `--dart-define=ENV=...` is omitted. On iOS, passing `--dart-define=ENV=staging`
  /// selects [iosStagingFirebaseOptions] without needing duplicate Xcode plists.
  static FirebaseOptions? firebaseOptionsForInit() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && isStaging) {
      return iosStagingFirebaseOptions;
    }
    return null;
  }

  static void logBootInfo({
    required String entrypoint,
    required String? firebaseProjectId,
    required String? firebaseAppId,
    String? uid,
    String? phone,
  }) {
    debugPrint(
      '[BOOT][$entrypoint] env=$environmentName '
      'firebaseProject=${firebaseProjectId ?? "null"} '
      'appId=${firebaseAppId ?? "null"} '
      'packageId=$packageId '
      'uid=${uid ?? "none"} phone=${phone ?? "none"}',
    );
  }
}

/// Non-interactive corner badge rendered on top of Staging builds so live
/// production and staging apps are visually unmistakable.
class StagingBannerOverlay extends StatelessWidget {
  final Widget child;
  final bool? forceShow;

  const StagingBannerOverlay({
    super.key,
    required this.child,
    this.forceShow,
  });

  @override
  Widget build(BuildContext context) {
    final show = forceShow ?? AppConfig.isStaging;
    if (!show) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5C158).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'STAGING',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
