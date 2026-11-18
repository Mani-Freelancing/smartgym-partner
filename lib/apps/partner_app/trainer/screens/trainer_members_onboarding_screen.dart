import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

class TrainerMembersOnboardingScreen extends StatelessWidget {
  const TrainerMembersOnboardingScreen({super.key});

  void _showAddMemberSheet(BuildContext context, SmartGymState state) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    int selectedPlanIdx = 0;
    String selectedTrainer = state.loggedInTrainerName;

    final plans = [
      {
        'title': '1-Month Regular',
        'fee': state.currentGym.monthlyFee,
        'days': 30,
        'isPt': false,
      },
      {
        'title': '6-Month Pro Plan',
        'fee': state.currentGym.monthlyFee * 5,
        'days': 180,
        'isPt': false,
      },
      {
        'title': 'Personal Training VIP',
        'fee': state.currentGym.ptFee,
        'days': 30,
        'isPt': true,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentPlan = plans[selectedPlanIdx];
          final isPt = currentPlan['isPt'] as bool;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ONBOARD NEW GYM CUSTOMER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Instantly syncs to Owner Revenue & PT Commission Split',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Full Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'SELECT MEMBERSHIP PLAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(plans.length, (i) {
                    final p = plans[i];
                    final sel = i == selectedPlanIdx;
                    return ChoiceChip(
                      label: Text('${p['title']} (₹${p['fee']})'),
                      selected: sel,
                      selectedColor: AppTheme.accent,
                      labelStyle: TextStyle(
                        color: sel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      onSelected: (_) =>
                          setModalState(() => selectedPlanIdx = i),
                    );
                  }),
                ),
                if (isPt) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'ASSIGN PERSONAL TRAINER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppTheme.champagne,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.trainers.map((t) {
                      final sel = t.name == selectedTrainer;
                      return ChoiceChip(
                        label: Text(t.name),
                        selected: sel,
                        selectedColor: AppTheme.champagne,
                        labelStyle: TextStyle(
                          color: sel ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setModalState(() => selectedTrainer = t.name),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                CredNeoPopButton(
                  label:
                      'Add Customer & Collect ₹${currentPlan['fee']}',
                  icon: Icons.person_add_alt_1_rounded,
                  color: AppTheme.accent,
                  onTap: () {
                    final name = nameCtrl.text.trim().isEmpty
                        ? 'Karthikeya Rao'
                        : nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim().isEmpty
                        ? '+91 98480 32910'
                        : phoneCtrl.text.trim();

                    context.read<SmartGymBloc>().add(
                          AddNewGymMemberEvent(
                            name: name,
                            phone: phone,
                            planTitle: currentPlan['title'] as String,
                            feePaid: currentPlan['fee'] as int,
                            daysValid: currentPlan['days'] as int,
                            isPtClient: isPt,
                            assignedTrainer: isPt ? selectedTrainer : null,
                            addedByTrainer: state.loggedInTrainerName,
                          ),
                        );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF141822),
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          '✅ $name added! Owner Revenue increased by ₹${currentPlan['fee']}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddEnquiryDialog(BuildContext context, SmartGymState state) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final planCtrl = TextEditingController(text: '3-Month Weight Loss + PT');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Walk-In Enquiry',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Visitor Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: planCtrl,
              decoration: const InputDecoration(
                labelText: 'Interested Plan / Goal',
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
                    AddWalkInEnquiryEvent(
                      name: nameCtrl.text.trim().isEmpty
                          ? 'Harish Reddy (Walk-In)'
                          : nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim().isEmpty
                          ? '+91 90102 33445'
                          : phoneCtrl.text.trim(),
                      interestedPlan: planCtrl.text.trim(),
                      loggedByTrainer: state.loggedInTrainerName,
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save Enquiry',
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
            // Quick Onboarding Actions for Floor Trainer
            CredStaggeredItem(
              index: 0,
              child: CredMetalCard(
                glowColor: AppTheme.accent,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FLOOR ADMISSIONS & ENQUIRIES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Onboard Walk-In Customers & Assign PT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Every new customer added here automatically updates the Gym Owner\'s revenue and PT split.',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    CredNeoPopButton(
                      label: '+ Add New Paid Customer',
                      icon: Icons.person_add_alt_1_rounded,
                      color: AppTheme.accent,
                      onTap: () => _showAddMemberSheet(context, state),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.champagne),
                          foregroundColor: AppTheme.champagne,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showAddEnquiryDialog(context, state),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: const Text(
                          '+ Log Walk-In Enquiry (Not Paid Yet)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Pending Walk-In Enquiries (1-Tap Convert to Paid Member)
            const Text(
              'WALK-IN ENQUIRIES (1-TAP CONVERT TO MEMBER)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(state.enquiries.length, (i) {
              final enq = state.enquiries[i];
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
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${enq.interestedPlan} • ${enq.timeLabel}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: enq.converted
                              ? Colors.white10
                              : AppTheme.accent.withValues(alpha: 0.16),
                        ),
                        onPressed: enq.converted
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                context
                                    .read<SmartGymBloc>()
                                    .add(ConvertEnquiryToMemberEvent(i));
                              },
                        child: Text(
                          enq.converted ? 'Joined' : 'Convert Paid',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: enq.converted
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

            const SizedBox(height: 16),
            Text(
              'ALL GYM MEMBERS (${state.members.length})',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...state.members.map((GymMember m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor: m.isExpired
                      ? AppTheme.danger
                      : (m.isPtClient ? AppTheme.champagne : AppTheme.accent),
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              m.isPtClient
                                  ? '${m.planTitle} • Trainer: ${m.assignedTrainer}'
                                  : '${m.planTitle} • Expires: ${m.expiryDate}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m.isExpired ? 'EXPIRED' : '${m.daysLeft}d left',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: m.isExpired
                              ? AppTheme.danger
                              : AppTheme.accent,
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
