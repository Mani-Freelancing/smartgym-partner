import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'apps/customer_app/customer_app_root.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/gym_repository.dart';
import 'data/services/firestore_service.dart';
import 'shared_bloc/smart_gym_bloc.dart';

/// Production/Staging Entrypoint for APP 1: SmartGym Club (Customer App APK)
/// Build command:
///   flutter build appbundle --flavor prod --dart-define=ENV=prod -t lib/main_customer.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp(
    options: AppConfig.firebaseOptionsForInit(),
  );
  AppConfig.syncFromFirebaseProjectId(app.options.projectId);
  runApp(SmartGymCustomerApp(firestoreService: FirestoreService()));
}

class SmartGymCustomerApp extends StatelessWidget {
  final FirestoreService? firestoreService;

  const SmartGymCustomerApp({super.key, this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => GymRepository(),
      child: BlocProvider(
        create: (context) => SmartGymBloc(
          repository: context.read<GymRepository>(),
          firestoreService: firestoreService,
        ),
        child: MaterialApp(
          title: AppConfig.customerAppTitle(),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          builder: (context, child) => StagingBannerOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const CustomerAppRoot(),
        ),
      ),
    );
  }
}
