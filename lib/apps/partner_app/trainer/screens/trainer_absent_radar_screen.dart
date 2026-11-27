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
    final bloc = context.read<SmartGymBloc>();
    final codeCtrl = TextEditingController(text: 'QR #18');
    final nameCtrl = TextEditingController();
    final muscleCtrl = TextEditingController(text: 'Shoulders • Side Delt');
    final tipCtrl = TextEditingController(
      text: 'Lead with elbows; keep traps relaxed.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AppTheme.ensureOwnerLight(
        ctx,
        child: Builder(
          builder: (ctx) {
            final dp = AppPalette.of(ctx);
            InputDecoration dec(String label, {String? hint}) =>
                InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: dp.textSecondary,
                  ),
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: dp.textMuted,
                  ),
                  filled: true,
                  fillColor: dp.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: dp.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: dp.border),
                  ),
                  isDense: true,
                );
            return AlertDialog(
              backgroundColor: dp.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: dp.border),
              ),
              title: Text(
                'Add Machine QR Video Guide',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: dp.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: dp.textPrimary,
                      ),
                      decoration: dec('Sticker Code (e.g. QR #18)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: dp.textPrimary,
                      ),
                      decoration: dec(
                        'Machine Name',
                        hint: 'e.g. Cable Lateral Raise',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: muscleCtrl,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: dp.textPrimary,
                      ),
                      decoration: dec('Target Muscle'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tipCtrl,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: dp.textPrimary,
                      ),
                      decoration: dec('Trainer Posture Tip'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: dp.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: dp.goldButton,
                    foregroundColor: dp.onAccent,
                  ),
                  onPressed: () {
                    bloc.add(
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
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.ensureOwnerLight(
      context,
      child: Builder(
        builder: (context) {
          final p = AppPalette.of(context);
          return BlocBuilder<SmartGymBloc, SmartGymState>(
            builder: (context, state) {
              return RefreshIndicator(
                color: p.gold,
                backgroundColor: p.card,
                onRefresh: () async {
                  context
                      .read<SmartGymBloc>()
                      .add(const RefreshGymDataEvent());
                  await Future<void>.delayed(
                    const Duration(milliseconds: 450),
                  );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
                  children: [
                    // 1. Trainer Morning Duty Check-In
                    Text(
                      'TRAINER DUTY ATTENDANCE (VISIBLE TO OWNER)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(state.trainers.length, (i) {
                      final t = state.trainers[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CredMetalCard(
                          glowColor: t.isOnDutyToday ? p.accent : p.amber,
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      t.radarDutySubtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: t.isOnDutyToday
                                            ? p.accent
                                            : p.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!t.isOnDutyToday)
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: p.goldButton,
                                    foregroundColor: p.onAccent,
                                  ),
                                  onPressed: () async {
                                    HapticFeedback.mediumImpact();
                                    final bloc = context.read<SmartGymBloc>();
                                    if (bloc.firestoreService == null) {
                                      bloc.add(MarkTrainerDutyCheckInEvent(i));
                                      return;
                                    }
                                    final raw =
                                        await Navigator.of(context).push<String>(
                                      MaterialPageRoute(
                                        builder: (_) => QrScannerScreen(
                                          title: 'Duty QR Check-In',
                                          subtitle:
                                              'Scan the Reception Duty QR at your gym desk.',
                                          accentColor: p.gold,
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor: p.danger,
                                          content: const Text(
                                            'Wrong QR! Please scan your gym\'s Reception Duty QR.',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Scan Duty QR',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: p.onAccent,
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
                        final churnRisks =
                            MemberIntelligenceService.evaluateChurnRisks(
                          members: state.members,
                          gymName: state.currentGym.name,
                        );
                        if (churnRisks.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHURN SHIELD • LIVE AT-RISK MEMBERS (${churnRisks.length})',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: p.textMuted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...churnRisks.take(5).map((risk) {
                              final riskColor = switch (risk.level) {
                                ChurnRiskLevel.critical => p.danger,
                                ChurnRiskLevel.high => p.amber,
                                ChurnRiskLevel.moderate => p.gold,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    risk.member.respectfulName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 14.5,
                                                      color: p.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: riskColor.withValues(
                                                      alpha: 0.14,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'RISK ${risk.score}%',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: riskColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${risk.member.planTitle} • ${risk.reason}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: p.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: p.accent
                                              .withValues(alpha: 0.12),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.mediumImpact();
                                          MemberWhatsAppService.launchMessage(
                                            context: context,
                                            phone: risk.member.phone,
                                            message:
                                                risk.suggestedWhatsAppMessage,
                                          );
                                        },
                                        child: Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: p.accent,
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
                    Text(
                      '5-DAY ABSENT MEMBER RADAR',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(state.missingMembers.length, (i) {
                      final m = state.missingMembers[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CredMetalCard(
                          glowColor: p.danger,
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${m.planName} • Last: ${m.lastMuscleTrained}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: m.contacted
                                      ? p.bg
                                      : p.accent.withValues(alpha: 0.12),
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
                                    color: m.contacted ? p.textMuted : p.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 18),

                    // 4. Machine QR Video Guides Management
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'SMART MACHINE QR VIDEOS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              color: p.textMuted,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAddMachineModal(context),
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            size: 16,
                            color: p.gold,
                          ),
                          label: Text(
                            'Add Machine QR',
                            style: TextStyle(
                              color: p.gold,
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
                          glowColor: p.gold,
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
                                  color: p.cardSubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: p.gold.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  guide.code,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: p.gold,
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${guide.muscle} • ${guide.mistakeTip}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: p.textSecondary,
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
        },
      ),
    );
  }
}
