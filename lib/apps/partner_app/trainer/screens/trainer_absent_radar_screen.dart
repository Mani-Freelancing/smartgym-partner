import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../data/services/member_whatsapp_service.dart';
import '../../../../domain/services/member_intelligence_service.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import '../../shared/qr_scanner_screen.dart';

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
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final bloc = context.read<SmartGymBloc>();
                            if (bloc.firestoreService == null) {
                              bloc.add(MarkTrainerDutyCheckInEvent(i));
                              return;
                            }
                            final raw = await Navigator.of(context).push<String>(
                              MaterialPageRoute(
                                builder: (_) => const QrScannerScreen(
                                  title: 'Duty QR Check-In',
                                  subtitle:
                                      'Scan the Reception Duty QR at your gym desk.',
                                  accentColor: AppTheme.accent,
                                ),
                              ),
                            );
                            if (raw == null || !context.mounted) return;
                            final uri = Uri.tryParse(raw);
                            final scannedGymId =
                                uri?.queryParameters['gymId'] ?? '';
                            if (uri?.scheme == 'smartgym' &&
                                uri?.host == 'duty' &&
                                scannedGymId == state.currentGym.id) {
                              bloc.add(MarkTrainerDutyCheckInEvent(i));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFFFF6B6B),
                                  content: Text(
                                    'Wrong QR! Please scan your gym\'s Reception Duty QR.',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              );
                            }
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

            // 2. Live Churn Risk & 5-Day Absent Member Radar
            Builder(
              builder: (context) {
                final churnRisks = MemberIntelligenceService.evaluateChurnRisks(
                  members: state.members,
                  gymName: state.currentGym.name,
                );
                if (churnRisks.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHURN SHIELD • LIVE AT-RISK MEMBERS (${churnRisks.length})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...churnRisks.take(5).map((risk) {
                      final riskColor = switch (risk.level) {
                        ChurnRiskLevel.critical => AppTheme.danger,
                        ChurnRiskLevel.high => AppTheme.amber,
                        ChurnRiskLevel.moderate => AppTheme.champagne,
                      };
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CredMetalCard(
                          glowColor: riskColor,
                          padding: const EdgeInsets.all(16),
                          borderRadius: 18,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            risk.member.respectfulName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: riskColor.withValues(
                                              alpha: 0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'RISK ${risk.score}%',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: riskColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${risk.member.planTitle} • ${risk.reason}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: MemberWhatsAppService
                                      .whatsappGreen
                                      .withValues(alpha: 0.16),
                                ),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  MemberWhatsAppService.launchMessage(
                                    context: context,
                                    phone: risk.member.phone,
                                    message: risk.suggestedWhatsAppMessage,
                                  );
                                },
                                child: const Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: MemberWhatsAppService.whatsappGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),

            // 3. 5-Day Absent Member Radar
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
                          final matched = state.members.where(
                            (gm) =>
                                gm.name.trim().toLowerCase() ==
                                m.name.trim().toLowerCase(),
                          );
                          if (matched.isNotEmpty) {
                            final gm = matched.first;
                            MemberWhatsAppService.launchMessage(
                              context: context,
                              phone: gm.phone,
                              message:
                                  'Hi ${gm.respectfulName}, we missed you at *${state.currentGym.name}* (${m.daysMissing} days since your ${m.lastMuscleTrained} session). Ready for a quick comeback workout today?',
                            );
                          }
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
          ),
        );
      },
    );
  }
}
