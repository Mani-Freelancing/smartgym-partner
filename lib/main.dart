import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'apps/partner_app/partner_app_root.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/gym_repository.dart';
import 'data/services/firestore_service.dart';
import 'shared_bloc/smart_gym_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        child: MaterialApp(
          title: 'SmartGym Partner',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const PartnerAppRoot(),
        ),
      ),
    );
  }
}
