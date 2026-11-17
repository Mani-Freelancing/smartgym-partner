import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'apps/partner_app/partner_app_root.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/gym_repository.dart';
import 'shared_bloc/smart_gym_bloc.dart';

/// Step 1 Active Entrypoint: Launches the Partner App (Owner & Trainer)
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartGymOSApp());
}

class SmartGymOSApp extends StatelessWidget {
  const SmartGymOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => GymRepository(),
      child: BlocProvider(
        create: (context) => SmartGymBloc(
          repository: context.read<GymRepository>(),
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
