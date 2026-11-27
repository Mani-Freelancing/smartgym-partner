import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

class TrainerMealQueueScreen extends StatelessWidget {
  const TrainerMealQueueScreen({super.key});

  void _showWeightLogDialog(BuildContext context, GymMember member) {
    final bloc = context.read<SmartGymBloc>();
    final weightCtrl = TextEditingController(
      text: (member.currentWeightKg - 0.8).toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (ctx) => AppTheme.ensureOwnerLight(
        ctx,
        child: Builder(
          builder: (ctx) {
            final dp = AppPalette.of(ctx);
            return AlertDialog(
              backgroundColor: dp.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: dp.border),
              ),
              title: Text(
                '15-Day Body Check • ${member.respectfulName}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: dp.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Previous Weight: ${member.currentWeightKg} kg',
                    style: TextStyle(fontSize: 12.5, color: dp.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: dp.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'New Weight (kg)',
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: dp.textSecondary,
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
                    ),
                  ),
                ],
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
                    final w = double.tryParse(weightCtrl.text.trim()) ??
                        member.currentWeightKg;
                    bloc.add(
                      UpdateMemberWeightEvent(
                        memberId: member.id,
                        newWeightKg: w,
                      ),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Save Weight',
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
              final ptClients = state.ptMembers;
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
                    Text(
                      '1-TAP VIP MEAL PLATE REVIEW QUEUE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(state.mealQueue.length, (i) {
                      final item = state.mealQueue[i];
                      final status = item.trainerFeedback;
                      final hasReply =
                          status != null && status.trim().isNotEmpty;
                      return CredStaggeredItem(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CredMetalCard(
                            glowColor: p.gold,
                            padding: const EdgeInsets.all(18),
                            borderRadius: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        item.memberName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.5,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      flex: 4,
                                      child: Text(
                                        item.timeLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: p.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.mealDescription,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: p.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.macros,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: p.gold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (hasReply)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Reviewed: "$status"',
                                      style: TextStyle(
                                        color: p.accent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      _buildQuickReplyChip(
                                        context,
                                        p,
                                        i,
                                        'Great Protein',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildQuickReplyChip(
                                        context,
                                        p,
                                        i,
                                        '+2 Eggs',
                                      ),
                                      const SizedBox(width: 8),
                                      _buildQuickReplyChip(
                                        context,
                                        p,
                                        i,
                                        'Less Rice',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      '15-DAY PT CLIENT BODY WEIGHT LOG',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...ptClients.map((GymMember m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CredMetalCard(
                          glowColor: p.accent,
                          padding: const EdgeInsets.all(16),
                          borderRadius: 18,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.respectfulName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Current Weight: ${m.currentWeightKg} kg  •  ${m.assignedTrainer}',
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
                                  backgroundColor: p.cardSubtle,
                                  side: BorderSide(
                                    color: p.gold.withValues(alpha: 0.4),
                                  ),
                                ),
                                onPressed: () =>
                                    _showWeightLogDialog(context, m),
                                child: Text(
                                  'Log Weight',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: p.gold,
                                  ),
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

  Widget _buildQuickReplyChip(
    BuildContext context,
    AppPalette p,
    int index,
    String reply,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.read<SmartGymBloc>().add(
                ReviewClientMealEvent(mealIndex: index, feedback: reply),
              );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9.5, horizontal: 4),
          decoration: BoxDecoration(
            color: p.cardSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.gold.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                reply,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: p.gold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
