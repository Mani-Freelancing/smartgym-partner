import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../domain/models/trainer_profile.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

class OwnerOrdersLeadsScreen extends StatelessWidget {
  const OwnerOrdersLeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        return RefreshIndicator(
          color: AppTheme.ownerGold,
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
              'TRAINER DUTY, PT CLIENTS & COMMISSION SPLIT',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'See which trainer checked in on time, which PT customers are assigned to them, and the automatic 50/50 PT split.',
              style: TextStyle(fontSize: 12.5, color: Colors.white60),
            ),
            const SizedBox(height: 14),
            if (state.trainerRequests.isNotEmpty) ...[
              const Text(
                'PENDING TRAINER APPROVALS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppTheme.ownerGold,
                ),
              ),
              const SizedBox(height: 10),
              ...state.trainerRequests.map((req) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CredMetalCard(
                    glowColor: AppTheme.ownerGold,
                    padding: const EdgeInsets.all(16),
                    borderRadius: 18,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${req.phone} • Scanned Invite QR',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context
                                .read<SmartGymBloc>()
                                .add(RejectTrainerRequestEvent(req.id));
                          },
                          child: const Text(
                            'Reject',
                            style: TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () {
                            context
                                .read<SmartGymBloc>()
                                .add(ApproveTrainerRequestEvent(req));
                          },
                          child: const Text(
                            'Approve',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],
            if (state.trainers.isEmpty)
              CredMetalCard(
                glowColor: AppTheme.ownerGold,
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'No trainers have joined yet.\nTap the QR icon at the top right to invite trainers via Staff Invite QR or + Add Phone.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
              ),
            ...List.generate(state.trainers.length, (i) {
              final TrainerProfile trainer = state.trainers[i];
              final List<GymMember> assignedPtClients = state.members
                  .where(
                    (m) => m.isPtClient && m.assignedTrainer == trainer.name,
                  )
                  .toList();
              final totalPtCollected = assignedPtClients.fold<int>(
                0,
                (sum, m) => sum + m.feePaid,
              );
              final trainerShare =
                  (totalPtCollected * trainer.commissionPercent) ~/ 100;
              final ownerShare = totalPtCollected - trainerShare;

              return CredStaggeredItem(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: CredMetalCard(
                    glowColor:
                        trainer.isOnDuty ? AppTheme.accent : AppTheme.amber,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trainer.name,
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${trainer.specialty} • ${trainer.shiftSlot}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: (trainer.isOnDuty
                                        ? AppTheme.accent
                                        : AppTheme.amber)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(99),
                              ),
                                child: Text(
                                  trainer.isOnDuty
                                      ? 'ON DUTY • ${trainer.morningCheckInTime}'
                                      : 'OFF DUTY',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: trainer.isOnDuty
                                        ? AppTheme.accent
                                        : AppTheme.amber,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                              color: const Color(0xFF1A1E29),
                              onSelected: (val) async {
                                if (val != 'remove') return;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1E29),
                                    title: Text(
                                      'Remove ${trainer.name}?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    content: const Text(
                                      'This will remove the trainer from your gym and revoke their Trainer Portal access.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.danger,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  context.read<SmartGymBloc>().add(
                                        RemoveTrainerFromGymEvent(
                                          trainerId: trainer.id,
                                          phone: trainer.phone,
                                          trainerName: trainer.name,
                                          details: trainer.specialty,
                                        ),
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF1A1E29),
                                      content: Text(
                                        '${trainer.name} removed from gym.',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_remove_rounded,
                                        color: AppTheme.danger,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Remove Trainer',
                                        style: TextStyle(
                                          color: AppTheme.danger,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Assigned PT Clients (${assignedPtClients.length})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Text(
                              'Owner: ₹$ownerShare  |  Trainer: ₹$trainerShare',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.champagne,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (assignedPtClients.isEmpty)
                          const Text(
                            'No active Personal Training clients assigned yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          )
                        else
                          ...assignedPtClients.map((c) {
                            return Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '👤 ${c.name} (${c.daysLeft}d left)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Paid ₹${c.feePaid}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
            const Text(
              'WALK-IN ENQUIRIES LOGGED BY TRAINERS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...state.enquiries.map((enq) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor:
                      enq.converted ? AppTheme.accent : AppTheme.champagne,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enq.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${enq.interestedPlan} • Logged by ${enq.loggedByTrainer}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (enq.converted
                                  ? AppTheme.accent
                                  : AppTheme.champagne)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          enq.converted ? 'JOINED' : 'FOLLOW UP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: enq.converted
                                ? AppTheme.accent
                                : AppTheme.champagne,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (state.removedRecords.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'REMOVED STAFF & MEMBERS (${state.removedRecords.length})',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 8),
              ...state.removedRecords.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CredMetalCard(
                    glowColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    borderRadius: 14,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_remove_rounded,
                          color: AppTheme.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.phone.isNotEmpty ? '${entry.phone} • ' : ''}${entry.details}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.type.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.danger,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ],
          ),
        );
      },
    );
  }
}
