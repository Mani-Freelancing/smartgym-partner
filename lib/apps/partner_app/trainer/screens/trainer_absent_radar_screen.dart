import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

class TrainerAbsentRadarScreen extends StatelessWidget {
  const TrainerAbsentRadarScreen({super.key});

  void _showAddMachineModal(BuildContext context) {
    final codeCtrl = TextEditingController(text: 'QR #18');
    final nameCtrl = TextEditingController();
    final muscleCtrl = TextEditingController(text: 'Shoulders • Side Delt');
    final tipCtrl = TextEditingController(
      text: 'Lead with elbows; keep traps relaxed.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Machine QR Video Guide',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Sticker Code (e.g. QR #18)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Machine Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: muscleCtrl,
              decoration: const InputDecoration(
                labelText: 'Target Muscle',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tipCtrl,
              decoration: const InputDecoration(
                labelText: 'Trainer Posture Tip',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              context.read<SmartGymBloc>().add(
                    AddMachineGuideEvent(
                      code: codeCtrl.text,
                      name: nameCtrl.text.trim().isEmpty
                          ? 'Cable Lateral Raise'
                          : nameCtrl.text,
                      muscle: muscleCtrl.text,
                      mistakeTip: tipCtrl.text,
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save Machine QR',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            // 1. Trainer Morning Duty Check-In
            const Text(
              'TRAINER DUTY ATTENDANCE (VISIBLE TO OWNER)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(state.trainers.length, (i) {
              final t = state.trainers[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor: t.isOnDuty ? AppTheme.accent : AppTheme.amber,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              t.isOnDuty
                                  ? 'Checked in at ${t.morningCheckInTime}'
                                  : 'Not Checked In Today',
                              style: TextStyle(
                                fontSize: 12,
                                color: t.isOnDuty
                                    ? AppTheme.accent
                                    : AppTheme.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!t.isOnDuty)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                AppTheme.accent.withValues(alpha: 0.16),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            context
                                .read<SmartGymBloc>()
                                .add(MarkTrainerDutyCheckInEvent(i));
                          },
                          child: const Text(
                            'Scan Duty QR',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // 2. 5-Day Absent Member Radar
            const Text(
              '5-DAY ABSENT MEMBER RADAR',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(state.missingMembers.length, (i) {
              final m = state.missingMembers[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor: AppTheme.danger,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${m.name}  •  ${m.daysMissing}d Absent',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${m.planName} • Last: ${m.lastMuscleTrained}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: m.contacted
                              ? Colors.white10
                              : AppTheme.accent.withValues(alpha: 0.16),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context
                              .read<SmartGymBloc>()
                              .add(RescueMissingMemberEvent(i));
                        },
                        child: Text(
                          m.contacted ? 'Pinged' : 'WhatsApp',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: m.contacted
                                ? Colors.white38
                                : AppTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 18),

            // 3. Machine QR Video Guides Management
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'SMART MACHINE QR VIDEOS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white38,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddMachineModal(context),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 16,
                    color: AppTheme.champagne,
                  ),
                  label: const Text(
                    'Add Machine QR',
                    style: TextStyle(
                      color: AppTheme.champagne,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            ...state.machineGuides.map((guide) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor: AppTheme.champagne,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.champagne.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          guide.code,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.champagne,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guide.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${guide.muscle} • ${guide.mistakeTip}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
