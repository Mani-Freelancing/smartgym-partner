import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class CustomerPtDietScreen extends StatefulWidget {
  const CustomerPtDietScreen({super.key});

  @override
  State<CustomerPtDietScreen> createState() => _CustomerPtDietScreenState();
}

class _CustomerPtDietScreenState extends State<CustomerPtDietScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _lastPhotoPath;

  void _openMealSnapSheet(BuildContext context) {
    final bloc = context.read<SmartGymBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final descCtrl = TextEditingController();
    final macrosCtrl = TextEditingController(text: '45g P • 40g C • 12g F');
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1E29),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        reverseDuration: Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Text(
                  'Snap & Send Meal to Trainer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 640,
                      imageQuality: 60,
                    );
                    if (picked != null) {
                      setModalState(() => _lastPhotoPath = picked.path);
                    }
                  },
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12151C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.trainerCyan.withValues(alpha: 0.4),
                      ),
                    ),
                    child: _lastPhotoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_lastPhotoPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                color: AppTheme.trainerCyan,
                                size: 30,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'TAP TO SNAP MEAL PLATE',
                                style: TextStyle(
                                  color: AppTheme.trainerCyan,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'What is on your plate?',
                    hintText: 'e.g. 200g Grilled Chicken + Brown Rice',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF12151C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: macrosCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Estimated Macros',
                    filled: true,
                    fillColor: const Color(0xFF12151C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.trainerCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (descCtrl.text.trim().isEmpty) {
                        setModalState(
                          () => errorText = 'Enter your meal description.',
                        );
                        return;
                      }
                      HapticFeedback.mediumImpact();
                      bloc.add(
                        SubmitCustomerMealEvent(
                          mealDescription: descCtrl.text,
                          macros: macrosCtrl.text,
                        ),
                      );
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: AppTheme.trainerCyan,
                          content: Text(
                            'Meal sent to your Trainer for 1-tap review!',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'SEND TO TRAINER',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final member = state.currentMember;
        final weight = member?.currentWeightKg ?? 74.0;
        final isPt = member?.isPtClient ?? state.isPtUnlocked;

        return RefreshIndicator(
          color: AppTheme.trainerCyan,
          backgroundColor: const Color(0xFF1A1E29),
          onRefresh: () async {
            context.read<SmartGymBloc>().add(const RefreshGymDataEvent());
            await Future<void>.delayed(const Duration(milliseconds: 450));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // 1. 15-Day Body Weight & PT Card
              CredStaggeredItem(
                index: 0,
                child: CredMetalCard(
                  glowColor: isPt ? AppTheme.champagne : AppTheme.trainerCyan,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPt
                                  ? 'VIP COACH • ${member?.assignedTrainer ?? state.currentGym.headTrainer}'
                                  : '15-DAY BODY CHECK',
                              style: TextStyle(
                                color: isPt
                                    ? AppTheme.champagne
                                    : AppTheme.trainerCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Synced live from Trainer body check-in',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.monitor_weight_rounded,
                          color: AppTheme.trainerCyan,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Snap Meal CTA
              CredStaggeredItem(
                index: 1,
                child: CredNeoPopButton(
                  label: 'SNAP MEAL PLATE FOR TRAINER REVIEW',
                  icon: Icons.camera_alt_rounded,
                  color: AppTheme.trainerCyan,
                  onTap: () => _openMealSnapSheet(context),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Meal Reviews Feed
              const Text(
                'YOUR MEAL REVIEWS',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              if (state.mealQueue.isEmpty)
                CredMetalCard(
                  glowColor: AppTheme.trainerCyan,
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'No meal snaps logged yet.\nTap above to snap your meal and get instant trainer feedback!',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ...List.generate(state.mealQueue.length, (i) {
                final meal = state.mealQueue[i];
                final reviewed = (meal.trainerFeedback ?? '').isNotEmpty;
                return CredStaggeredItem(
                  index: i + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CredMetalCard(
                      glowColor:
                          reviewed ? AppTheme.accent : AppTheme.champagne,
                      padding: const EdgeInsets.all(16),
                      borderRadius: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  meal.mealDescription,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                meal.timeLabel,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meal.macros,
                            style: const TextStyle(
                              color: AppTheme.trainerCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: (reviewed
                                      ? AppTheme.accent
                                      : AppTheme.champagne)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              reviewed
                                  ? 'Trainer: ${meal.trainerFeedback}'
                                  : 'Waiting for Trainer review...',
                              style: TextStyle(
                                color: reviewed
                                    ? AppTheme.accent
                                    : AppTheme.champagne,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
