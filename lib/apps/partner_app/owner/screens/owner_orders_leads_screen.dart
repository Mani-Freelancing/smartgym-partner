import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../domain/models/trainer_profile.dart';
import '../../../../domain/services/pt_split_calculator.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

class OwnerOrdersLeadsScreen extends StatelessWidget {
  const OwnerOrdersLeadsScreen({super.key});

  void _showEditTrainerSheet(BuildContext context, TrainerProfile trainer) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(minWidth: double.infinity),
      backgroundColor: const Color(0xFF1A1E29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<SmartGymBloc>(),
        child: _EditTrainerSheet(trainer: trainer),
      ),
    );
  }

  Future<void> _sendEnquiryWhatsApp(
    BuildContext context,
    String gymName,
    String memberName,
    String phone,
    String plan,
  ) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final waNumber = digits.length == 10 ? '91$digits' : digits;
    if (waNumber.isEmpty) return;

    final message = Uri.encodeComponent(
      'Hi $memberName! Thanks for visiting $gymName. Your $plan spot & trial pass are ready this week—reply here if you want us to reserve it!',
    );
    final uri = Uri.parse('https://wa.me/$waNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp on this device')),
      );
    }
  }

  void _showAddEnquirySheet(BuildContext context, SmartGymState state) {
    final bloc = context.read<SmartGymBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final plans = state.currentGym.effectiveFeePlans
        .map((p) => '${p.name} (₹${p.price})')
        .toList();
    String selectedPlan =
        plans.isNotEmpty ? plans.first : 'Monthly (₹${state.currentGym.monthlyFee})';
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1E29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Log Walk-in Enquiry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Save visitors who asked about fees so you never lose a conversion.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Visitor Name',
                    hintText: 'e.g. Karthik',
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
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(
                      color: AppTheme.champagne,
                      fontWeight: FontWeight.w800,
                    ),
                    labelText: 'Mobile Number',
                    hintText: '9876543210',
                    filled: true,
                    fillColor: const Color(0xFF12151C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: plans.map((plan) {
                    final active = selectedPlan == plan;
                    return ChoiceChip(
                      label: Text(
                        plan,
                        style: TextStyle(
                          color: active ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      selected: active,
                      selectedColor: AppTheme.champagne,
                      backgroundColor: const Color(0xFF12151C),
                      onSelected: (_) =>
                          setModalState(() => selectedPlan = plan),
                    );
                  }).toList(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.champagne,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      if (name.isEmpty || phone.length != 10) {
                        setModalState(
                          () => error = 'Enter visitor name & 10-digit mobile.',
                        );
                        return;
                      }
                      bloc.add(
                        AddWalkInEnquiryEvent(
                          name: name,
                          phone: '+91$phone',
                          interestedPlan: selectedPlan,
                          loggedByTrainer: state.loggedInTrainerName.isEmpty
                              ? 'Owner'
                              : state.loggedInTrainerName,
                        ),
                      );
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Walk-in enquiry saved for $name'),
                        ),
                      );
                    },
                    child: const Text(
                      'SAVE ENQUIRY',
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
              'See trainer check-ins, assigned PT clients, and configurable PT commission splits.',
              style: TextStyle(fontSize: 12.5, color: Colors.white60),
            ),
            const SizedBox(height: 12),
            if (state.trainers.isNotEmpty) ...[
              Builder(
                builder: (ctx) {
                  final gym = state.currentGym;
                  final totalCoachPayout = state.members.fold<int>(
                    0,
                    (sum, m) =>
                        sum +
                        PtSplitCalculator.computeMemberSplit(
                          member: m,
                          trainers: state.trainers,
                          gym: gym,
                        ).trainerShare,
                  );
                  final totalOwnerNet =
                      state.totalMonthlyRevenue - totalCoachPayout;
                  return CredMetalCard(
                    glowColor: AppTheme.ownerGold,
                    padding: const EdgeInsets.all(14),
                    borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.members.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'COACH PAYOUTS',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: AppTheme.trainerCyan,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹$totalCoachPayout',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.trainerCyan,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'OWNER NET REVENUE',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: AppTheme.ownerGold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹$totalOwnerNet',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.ownerGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18, color: Colors.white12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Keep Base Fee (₹${gym.monthlyFee}) 100% Owner',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    gym.ptSplitExcludesBaseFee
                                        ? 'Trainer % applies only above base gym fee.'
                                        : 'Trainer % applies to whole PT package fee.',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              key: const ValueKey('trainers_exclude_base_switch'),
                              value: gym.ptSplitExcludesBaseFee,
                              activeThumbColor: AppTheme.ownerGold,
                              onChanged: (nextVal) async {
                                HapticFeedback.selectionClick();
                                final bloc = context.read<SmartGymBloc>();
                                final messenger = ScaffoldMessenger.of(context);
                                final fs = bloc.firestoreService;
                                if (fs != null && gym.id.isNotEmpty) {
                                  bloc.add(
                                    SyncGymTenantEvent(
                                      gym.copyWith(
                                        ptSplitExcludesBaseFee: nextVal,
                                      ),
                                    ),
                                  );
                                  try {
                                    await fs
                                        .setPtSplitExcludesBaseFee(
                                          gymId: gym.id,
                                          excludesBaseFee: nextVal,
                                        )
                                        .timeout(const Duration(seconds: 10));
                                  } on TimeoutException {
                                    bloc.add(SyncGymTenantEvent(gym));
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AppTheme.danger,
                                        content: Text(
                                          'Could not reach database — turn on internet and try again.',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    bloc.add(SyncGymTenantEvent(gym));
                                    final diag = await fs
                                        .diagnoseGymWriteAccess(gym.id);
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.danger,
                                        duration: const Duration(seconds: 6),
                                        content: Text(
                                          'Failed to save PT base-fee setting: $e ($diag)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                bloc.add(
                                  UpdateGymSettingsEvent(
                                    name: gym.name,
                                    area: gym.area,
                                    monthlyFee: gym.monthlyFee,
                                    ptFee: gym.ptFee,
                                    ptSplitExcludesBaseFee: nextVal,
                                    maxCapacity: gym.maxCapacity,
                                    feePlans: gym.feePlans,
                                    latitude: gym.latitude,
                                    longitude: gym.longitude,
                                    checkInRadiusMeters:
                                        gym.checkInRadiusMeters,
                                    requireGpsCheckIn: gym.requireGpsCheckIn,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
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
                    (m) =>
                        m.isPtClient &&
                        (m.assignedTrainer ?? '').trim().toLowerCase() ==
                            trainer.name.trim().toLowerCase(),
                  )
                  .toList();
              var trainerShare = 0;
              var ownerShare = 0;
              var totalBaseKeep = 0;
              var totalPtPortion = 0;
              for (final client in assignedPtClients) {
                final split = PtSplitCalculator.computeMemberSplit(
                  member: client,
                  trainers: state.trainers,
                  gym: state.currentGym,
                );
                trainerShare += split.trainerShare;
                ownerShare += split.ownerShare;
                totalBaseKeep += split.baseOwnerKeep;
                totalPtPortion += split.ptPortion;
              }

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
                              key: ValueKey('trainer_menu_${trainer.id}'),
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                              color: const Color(0xFF1A1E29),
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  _showEditTrainerSheet(context, trainer);
                                  return;
                                }
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
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        color: AppTheme.trainerCyan,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Edit Commission & Shift',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.trainerCyan,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                                      Flexible(
                                        child: Text(
                                          'Remove Trainer',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.danger,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 4,
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Assigned PT (${assignedPtClients.length}) • ${trainer.commissionPercent}% Split',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
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
                        if (state.currentGym.ptSplitExcludesBaseFee &&
                            assignedPtClients.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Base ₹$totalBaseKeep kept 100% by Owner • Split on ₹$totalPtPortion PT add-on',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ownerGold,
                            ),
                          ),
                        ],
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'WALK-IN ENQUIRY CRM',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white38,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEnquirySheet(context, state),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 16,
                    color: AppTheme.champagne,
                  ),
                  label: const Text(
                    'Add Enquiry',
                    style: TextStyle(
                      color: AppTheme.champagne,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (state.enquiries.isEmpty)
              CredMetalCard(
                glowColor: AppTheme.champagne,
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: const Text(
                  'No walk-in enquiries yet.\nTap "+ Add Enquiry" whenever someone visits to ask fees.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ),
            ...List.generate(state.enquiries.length, (i) {
              final enq = state.enquiries[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor:
                      enq.converted ? AppTheme.accent : AppTheme.champagne,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                  '${enq.phone} • ${enq.interestedPlan}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Logged by ${enq.loggedByTrainer} • ${enq.timeLabel}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
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
                      if (!enq.converted) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accent,
                                  side: BorderSide(
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.45),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _sendEnquiryWhatsApp(
                                  context,
                                  state.currentGym.name,
                                  enq.name,
                                  enq.phone,
                                  enq.interestedPlan,
                                ),
                                icon: const Icon(Icons.chat_rounded, size: 16),
                                label: const Text(
                                  'WhatsApp',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  context
                                      .read<SmartGymBloc>()
                                      .add(ConvertEnquiryToMemberEvent(i));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${enq.name} converted to active member!',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Convert Paid',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _EditTrainerSheet extends StatefulWidget {
  final TrainerProfile trainer;

  const _EditTrainerSheet({required this.trainer});

  @override
  State<_EditTrainerSheet> createState() => _EditTrainerSheetState();
}

class _EditTrainerSheetState extends State<_EditTrainerSheet> {
  static const _presets = [
    'Floor & Transformation Coach',
    'Strength & Hypertrophy',
    'Fat Loss & Conditioning',
    'CrossFit & Mobility',
  ];
  static const _slots = [
    'Morning (6–10 AM)',
    'Afternoon (12–4 PM)',
    'Evening (5–9:30 PM)',
    'Full Day',
  ];
  static const _commPresets = [30, 40, 50, 60, 100];

  late TextEditingController _specCtrl;
  late TextEditingController _commCtrl;
  late String _selectedSlot;
  String? _error;

  @override
  void initState() {
    super.initState();
    _specCtrl = TextEditingController(text: widget.trainer.specialty);
    _commCtrl =
        TextEditingController(text: '${widget.trainer.commissionPercent}');
    _selectedSlot = _slots.contains(widget.trainer.shiftSlot)
        ? widget.trainer.shiftSlot
        : _slots.first;
  }

  @override
  void dispose() {
    _specCtrl.dispose();
    _commCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final pct = int.tryParse(_commCtrl.text.trim());
    if (pct == null || pct < 0 || pct > 100) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Enter a commission between 0% and 100%.');
      return;
    }
    HapticFeedback.mediumImpact();
    context.read<SmartGymBloc>().add(
          UpdateTrainerDetailsEvent(
            trainerId: widget.trainer.id,
            specialty: _specCtrl.text.trim(),
            shiftSlot: _selectedSlot,
            commissionPercent: pct,
          ),
        );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1E29),
        content: Text(
          '✅ Updated ${widget.trainer.name} ($pct% PT split • $_selectedSlot)',
          style: const TextStyle(
            color: AppTheme.trainerCyan,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = (int.tryParse(_commCtrl.text.trim()) ??
            widget.trainer.commissionPercent)
        .clamp(0, 100);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              Text(
                'Edit ${widget.trainer.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Configure trainer specialty, duty shift slot & PT split.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _specCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Specialty',
                  filled: true,
                  fillColor: const Color(0xFF12151C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presets.map((p) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF12151C),
                    side: BorderSide(
                      color: AppTheme.trainerCyan.withValues(alpha: 0.35),
                    ),
                    label: Text(
                      p,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _specCtrl.text = p);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text(
                'DUTY SHIFT SLOT',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slots.map((slot) {
                  final sel = _selectedSlot == slot;
                  return ChoiceChip(
                    label: Text(
                      slot,
                      style: TextStyle(
                        color: sel ? Colors.black : Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: sel,
                    selectedColor: AppTheme.ownerGold,
                    backgroundColor: const Color(0xFF12151C),
                    side: BorderSide(
                      color: sel ? AppTheme.ownerGold : Colors.white12,
                    ),
                    onSelected: (_) => setState(() => _selectedSlot = slot),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text(
                'TRAINER PT COMMISSION (%)',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      key: const ValueKey('edit_trainer_comm_input'),
                      controller: _commCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        suffixText: '%',
                        filled: true,
                        fillColor: const Color(0xFF12151C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _commPresets.map((p) {
                        final sel = pct == p;
                        return ChoiceChip(
                          key: ValueKey('edit_trainer_comm_$p'),
                          label: Text('$p%'),
                          selected: sel,
                          selectedColor: AppTheme.trainerCyan,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: sel ? Colors.black : Colors.white70,
                          ),
                          backgroundColor: const Color(0xFF12151C),
                          onSelected: (_) => setState(() {
                            _commCtrl.text = '$p';
                            _error = null;
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                pct == 100
                    ? 'PT Split Preview: Coach gets 100% (Freelance PT) • Owner gets 0%'
                    : 'PT Split Preview: Coach gets $pct% • Owner gets ${100 - pct}%',
                style: const TextStyle(
                  color: AppTheme.champagne,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.softRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              ),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  key: const ValueKey('edit_trainer_save_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.trainerCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_rounded, size: 19),
                  label: const Text(
                    'SAVE TRAINER SETTINGS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
