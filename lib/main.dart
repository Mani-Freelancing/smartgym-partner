import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'apps/partner_app/partner_app_root.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/gym_repository.dart';
import 'data/services/firestore_service.dart';
import 'domain/models/partner_role.dart';
import 'shared_bloc/smart_gym_bloc.dart';
import 'shared_bloc/smart_gym_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await Firebase.initializeApp(
    options: AppConfig.firebaseOptionsForInit(),
  );
  AppConfig.syncFromFirebaseProjectId(app.options.projectId);
  final user = FirebaseAuth.instance.currentUser;
  AppConfig.logBootInfo(
    entrypoint: 'main.dart',
    firebaseProjectId: app.options.projectId,
    firebaseAppId: app.options.appId,
    uid: user?.uid,
    phone: user?.phoneNumber,
  );
  runApp(SmartGymOSApp(firestoreService: FirestoreService()));
}

class SmartGymOSApp extends StatelessWidget {
  final FirestoreService? firestoreService;

  const SmartGymOSApp({super.key, this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => GymRepository(),
      child: BlocProvider(
        create: (context) => SmartGymBloc(
          repository: context.read<GymRepository>(),
          firestoreService: firestoreService,
        ),
        child: BlocBuilder<SmartGymBloc, SmartGymState>(
          buildWhen: (prev, curr) =>
              prev.isPartnerLoggedIn != curr.isPartnerLoggedIn ||
              prev.partnerRole != curr.partnerRole,
          builder: (context, state) {
            final useLightTheme = state.isPartnerLoggedIn &&
                state.partnerRole == PartnerRole.owner;
            return MaterialApp(
              title: AppConfig.partnerAppTitle(),
              debugShowCheckedModeBanner: false,
              theme: useLightTheme ? AppTheme.lightTheme : AppTheme.darkTheme,
              builder: (context, child) => StagingBannerOverlay(
                child: child ?? const SizedBox.shrink(),
              ),
              home: const PartnerAppRoot(),
            );
          },
        ),
      ),
    );
  }
}
