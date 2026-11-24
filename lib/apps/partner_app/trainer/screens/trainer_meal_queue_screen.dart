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
    final weightCtrl = TextEditingController(
      text: (member.currentWeightKg - 0.8).toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '15-Day Body Check • ${member.respectfulName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Previous Weight: ${member.currentWeightKg} kg',
              style: const TextStyle(fontSize: 12.5, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'New Weight (kg)',
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
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final w = double.tryParse(weightCtrl.text.trim()) ??
                  member.currentWeightKg;
              context.read<SmartGymBloc>().add(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final ptClients = state.ptMembers;
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
            const Text(
              '1-TAP VIP MEAL PLATE REVIEW QUEUE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(state.mealQueue.length, (i) {
              final item = state.mealQueue[i];
              final status = item.trainerFeedback;
              return CredStaggeredItem(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CredMetalCard(
                    glowColor: AppTheme.champagne,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.5,
                                  color: Colors.white,
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.mealDescription,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.macros,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.champagne,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (status != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Reviewed: "$status"',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              _buildQuickReplyChip(context, i, 'Great Protein'),
                              const SizedBox(width: 8),
                              _buildQuickReplyChip(context, i, '+2 Eggs'),
                              const SizedBox(width: 8),
                              _buildQuickReplyChip(context, i, 'Less Rice'),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text(
              '15-DAY PT CLIENT BODY WEIGHT LOG',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...ptClients.map((GymMember m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor: AppTheme.accent,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Current Weight: ${m.currentWeightKg} kg  •  ${m.assignedTrainer}',
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
                          backgroundColor:
                              AppTheme.accent.withValues(alpha: 0.14),
                        ),
                        onPressed: () => _showWeightLogDialog(context, m),
                        child: const Text(
                          'Log Weight',
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
          ],
          ),
        );
      },
    );
  }

  Widget _buildQuickReplyChip(BuildContext context, int index, String reply) {
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text(
              reply,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
