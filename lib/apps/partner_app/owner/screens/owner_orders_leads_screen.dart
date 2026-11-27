import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../domain/models/gym_tenant.dart';
import '../../../../domain/models/trainer_profile.dart';
import '../../../../domain/models/walk_in_enquiry.dart';
import '../../../../domain/services/pt_split_calculator.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import 'owner_trainer_attendance_screen.dart';

class OwnerOrdersLeadsScreen extends StatelessWidget {
  const OwnerOrdersLeadsScreen({super.key});

  void _openAttendanceHistory(
    BuildContext context, {
    TrainerProfile? trainer,
  }) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SmartGymBloc>(),
          child: OwnerTrainerAttendanceScreen(
            initialTrainerId: trainer?.id,
            initialTrainerName: trainer?.name,
          ),
        ),
      ),
    );
  }

  void _showEditTrainerSheet(BuildContext context, TrainerProfile trainer) {
    HapticFeedback.selectionClick();
    final p = AppPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(minWidth: double.infinity),
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => AppTheme.ensureOwnerLight(
        context,
        child: BlocProvider.value(
          value: context.read<SmartGymBloc>(),
          child: _EditTrainerSheet(trainer: trainer),
        ),
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
    final p = AppPalette.of(context);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final plans = state.currentGym.effectiveFeePlans
        .map((plan) => '${plan.name} (₹${plan.price})')
        .toList();
    String selectedPlan =
        plans.isNotEmpty ? plans.first : 'Monthly (₹${state.currentGym.monthlyFee})';
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => AppTheme.ensureOwnerLight(
        context,
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final mp = AppPalette.of(ctx);
            return Padding(
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
                    Text(
                      'Log Walk-in Enquiry',
                      style: TextStyle(
                        color: mp.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Save visitors who asked about fees so you never lose a conversion.',
                      style: TextStyle(color: mp.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: mp.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Visitor Name',
                        hintText: 'e.g. Karthik',
                        labelStyle: TextStyle(color: mp.textSecondary),
                        hintStyle: TextStyle(color: mp.textMuted),
                        filled: true,
                        fillColor: mp.cardSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: mp.textPrimary),
                      decoration: InputDecoration(
                        counterText: '',
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(
                          color: mp.gold,
                          fontWeight: FontWeight.w800,
                        ),
                        labelText: 'Mobile Number',
                        hintText: '9876543210',
                        labelStyle: TextStyle(color: mp.textSecondary),
                        hintStyle: TextStyle(color: mp.textMuted),
                        filled: true,
                        fillColor: mp.cardSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
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
                              color: active ? mp.onAccent : mp.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          selected: active,
                          selectedColor: mp.goldButton,
                          backgroundColor: mp.cardSubtle,
                          side: BorderSide(
                            color: active ? mp.gold : mp.border,
                          ),
                          onSelected: (_) =>
                              setModalState(() => selectedPlan = plan),
                        );
                      }).toList(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(color: mp.danger, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: mp.goldButton,
                          foregroundColor: mp.onAccent,
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
            );
          },
        ),
      ),
    );
  }

  Future<void> _togglePtBaseFeeExclusion(
    BuildContext context,
    GymTenant gym,
    bool nextVal,
  ) async {
    HapticFeedback.selectionClick();
    final bloc = context.read<SmartGymBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final fs = bloc.firestoreService;
    if (fs != null && gym.id.isNotEmpty) {
      bloc.add(
        SyncGymTenantEvent(
          gym.copyWith(ptSplitExcludesBaseFee: nextVal),
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
        final diag = await fs.diagnoseGymWriteAccess(gym.id);
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 6),
            content: Text(
              'Failed to save PT base-fee setting: $e ($diag)',
              style: const TextStyle(color: Colors.white),
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
        checkInRadiusMeters: gym.checkInRadiusMeters,
        requireGpsCheckIn: gym.requireGpsCheckIn,
      ),
    );
  }

  Future<void> _confirmRemoveTrainer(
    BuildContext context,
    TrainerProfile trainer,
  ) async {
    final p = AppPalette.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppTheme.ensureOwnerLight(
        context,
        child: AlertDialog(
          backgroundColor: p.card,
          title: Text(
            'Remove ${trainer.name}?',
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This will remove the trainer from your gym and revoke their Trainer Portal access.',
            style: TextStyle(color: p.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: p.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
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
          backgroundColor: p.snackBg,
          content: Text(
            '${trainer.name} removed from gym.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.ensureOwnerLight(
      context,
      child: BlocBuilder<SmartGymBloc, SmartGymState>(
        builder: (context, state) {
          final p = AppPalette.of(context);
          final gym = state.currentGym;
          final onDutyCount =
              state.trainers.where((t) => t.isOnDutyToday).length;
          final onDutyBadgeColor = onDutyCount > 0 ? p.accent : p.amber;
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
          final totalOwnerNet = state.totalMonthlyRevenue - totalCoachPayout;

          return RefreshIndicator(
            color: p.gold,
            backgroundColor: p.card,
            onRefresh: () async {
              context.read<SmartGymBloc>().add(const RefreshGymDataEvent());
              await Future<void>.delayed(const Duration(milliseconds: 450));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TRAINER TEAM & PAYOUTS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                    if (state.trainers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: onDutyBadgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: onDutyBadgeColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '$onDutyCount/${state.trainers.length} ON DUTY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: onDutyBadgeColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.trainers.isNotEmpty) ...[
                  CredMetalCard(
                    glowColor: p.gold,
                    padding: const EdgeInsets.all(16),
                    borderRadius: 18,
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
                                    Text(
                                      'COACH PAYOUTS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: p.isDark ? p.cyan : p.purple,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '₹$totalCoachPayout',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: p.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 34,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                color: p.divider,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OWNER NET REVENUE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: p.gold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '₹$totalOwnerNet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: p.textPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 24, color: p.divider),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Keep Base Fee (₹${gym.monthlyFee}) 100% Owner',
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    gym.ptSplitExcludesBaseFee
                                        ? 'Trainer % applies only above base gym fee.'
                                        : 'Trainer % applies to whole PT package fee.',
                                    style: TextStyle(
                                      color: p.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch.adaptive(
                              key: const ValueKey(
                                'trainers_exclude_base_switch',
                              ),
                              value: gym.ptSplitExcludesBaseFee,
                              activeThumbColor: p.gold,
                              onChanged: (nextVal) => _togglePtBaseFeeExclusion(
                                context,
                                gym,
                                nextVal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (state.trainerRequests.isNotEmpty) ...[
                  Text(
                    'PENDING TRAINER APPROVALS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: p.gold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...state.trainerRequests.map((req) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CredMetalCard(
                        glowColor: p.gold,
                        padding: const EdgeInsets.all(14),
                        borderRadius: 18,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req.name,
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${req.phone} • Scanned Invite QR',
                                    style: TextStyle(
                                      color: p.textSecondary,
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
                              child: Text(
                                'Reject',
                                style: TextStyle(
                                  color: p.danger,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: p.accent,
                                foregroundColor: p.onAccent,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
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
                    glowColor: p.gold,
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No trainers have joined yet.\nTap the QR icon at the top right to invite trainers via Staff Invite QR or + Add Trainer.',
                      style: TextStyle(
                        fontSize: 13,
                        color: p.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ...List.generate(state.trainers.length, (i) {
                  final trainer = state.trainers[i];
                  final assignedPtClients = state.members
                      .where(
                        (m) =>
                            m.isPtClient &&
                            (m.assignedTrainer ?? '').trim().toLowerCase() ==
                                trainer.name.trim().toLowerCase(),
                      )
                      .toList();
                  return CredStaggeredItem(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TrainerRosterCard(
                        trainer: trainer,
                        trainers: state.trainers,
                        gym: gym,
                        assignedPtClients: assignedPtClients,
                        onViewHistory: () =>
                            _openAttendanceHistory(context, trainer: trainer),
                        onEdit: () => _showEditTrainerSheet(context, trainer),
                        onRemove: () => _confirmRemoveTrainer(context, trainer),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'WALK-IN ENQUIRY CRM (${state.enquiries.length})',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddEnquirySheet(context, state),
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 16,
                        color: p.gold,
                      ),
                      label: Text(
                        'Add Enquiry',
                        style: TextStyle(
                          color: p.gold,
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
                    glowColor: p.gold,
                    padding: const EdgeInsets.all(16),
                    borderRadius: 18,
                    child: Text(
                      'No walk-in enquiries yet.\nTap "+ Add Enquiry" whenever someone visits to ask fees.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: p.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ...List.generate(state.enquiries.length, (i) {
                  final enq = state.enquiries[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WalkInEnquiryCard(
                      enquiry: enq,
                      onWhatsApp: () => _sendEnquiryWhatsApp(
                        context,
                        state.currentGym.name,
                        enq.name,
                        enq.phone,
                        enq.interestedPlan,
                      ),
                      onConvertPaid: () {
                        HapticFeedback.mediumImpact();
                        context
                            .read<SmartGymBloc>()
                            .add(ConvertEnquiryToMemberEvent(i));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: p.snackBg,
                            content: Text(
                              '${enq.name} converted to active member!',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrainerRosterCard extends StatelessWidget {
  final TrainerProfile trainer;
  final List<TrainerProfile> trainers;
  final GymTenant gym;
  final List<GymMember> assignedPtClients;
  final VoidCallback onViewHistory;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _TrainerRosterCard({
    required this.trainer,
    required this.trainers,
    required this.gym,
    required this.assignedPtClients,
    required this.onViewHistory,
    required this.onEdit,
    required this.onRemove,
  });

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    var trainerShare = 0;
    var ownerShare = 0;
    var totalBaseKeep = 0;
    var totalPtPortion = 0;
    for (final client in assignedPtClients) {
      final split = PtSplitCalculator.computeMemberSplit(
        member: client,
        trainers: trainers,
        gym: gym,
      );
      trainerShare += split.trainerShare;
      ownerShare += split.ownerShare;
      totalBaseKeep += split.baseOwnerKeep;
      totalPtPortion += split.ptPortion;
    }

    final p = AppPalette.of(context);
    final onDuty = trainer.isOnDutyToday;
    final statusColor = onDuty ? p.accent : p.amber;
    final subtitle = [
      trainer.specialty.trim(),
      trainer.shiftSlot.trim(),
    ].where((part) => part.isNotEmpty).join(' • ');

    return CredMetalCard(
      glowColor: p.isDark ? statusColor : p.textMuted,
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(trainer.name),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('trainer_menu_${trainer.id}'),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: p.textMuted,
                  size: 20,
                ),
                color: p.card,
                onSelected: (val) {
                  if (val == 'history') {
                    onViewHistory();
                  } else if (val == 'edit') {
                    onEdit();
                  } else if (val == 'remove') {
                    onRemove();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'history',
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: p.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'View Login History',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.gold,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: p.cyan,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Edit Commission & Shift',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.cyan,
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
                          color: p.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Remove Trainer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.danger,
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
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  onDuty ? 'ON DUTY' : 'OFF DUTY',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                onDuty
                    ? Icons.access_time_filled_rounded
                    : Icons.schedule_rounded,
                size: 13,
                color: statusColor,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  trainer.radarDutySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: onDuty ? p.textSecondary : p.textMuted,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 22, color: p.divider),
          if (assignedPtClients.isEmpty)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'No PT clients assigned • ${trainer.commissionPercent}% Split',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    'Edit Split',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: p.isDark ? p.cyan : p.purple,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Assigned PT (${assignedPtClients.length}) • ${trainer.commissionPercent}% Split',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: p.textSecondary,
                  ),
                ),
                Text(
                  'Owner: ₹$ownerShare  |  Trainer: ₹$trainerShare',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: p.gold,
                  ),
                ),
              ],
            ),
            if (gym.ptSplitExcludesBaseFee) ...[
              const SizedBox(height: 4),
              Text(
                'Base ₹$totalBaseKeep kept 100% by Owner • Split on ₹$totalPtPortion PT add-on',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: p.gold,
                ),
              ),
            ],
            const SizedBox(height: 6),
            ...assignedPtClients.map((c) {
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: p.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: c.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: '  •  ${c.daysLeft}d left',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: c.daysLeft <= 5 ? p.amber : p.textMuted,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Paid ₹${c.feePaid}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.accent,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _WalkInEnquiryCard extends StatelessWidget {
  final WalkInEnquiry enquiry;
  final VoidCallback onWhatsApp;
  final VoidCallback onConvertPaid;

  const _WalkInEnquiryCard({
    required this.enquiry,
    required this.onWhatsApp,
    required this.onConvertPaid,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = enquiry.converted ? p.accent : p.gold;
    return CredMetalCard(
      glowColor: color,
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
                      enquiry.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${enquiry.phone} • ${enquiry.interestedPlan}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Logged by ${enquiry.loggedByTrainer} • ${enquiry.timeLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: p.textMuted,
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
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  enquiry.converted ? 'JOINED' : 'FOLLOW UP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (!enquiry.converted) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(
                        color: p.accent.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onWhatsApp,
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
                      backgroundColor: p.accent,
                      foregroundColor: p.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onConvertPaid,
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
    final p = AppPalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: p.snackBg,
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
    final p = AppPalette.of(context);
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
                    color: p.border,
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
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure trainer specialty, duty shift slot & PT split.',
                        style: TextStyle(color: p.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _specCtrl,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          labelText: 'Specialty / Category',
                          labelStyle: TextStyle(
                            color: p.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: 'e.g. Strength & Fat Loss Coach',
                          hintStyle: TextStyle(
                            color: p.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: p.cardSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: p.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: p.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _presets.map((preset) {
                          return ActionChip(
                            backgroundColor: p.cardSubtle,
                            side: BorderSide(
                              color: p.cyan.withValues(alpha: 0.35),
                            ),
                            label: Text(
                              preset,
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() => _specCtrl.text = preset);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'DUTY SHIFT SLOT',
                        style: TextStyle(
                          color: p.textMuted,
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
                                color: sel ? p.onAccent : p.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            selected: sel,
                            selectedColor: p.goldButton,
                            backgroundColor: p.cardSubtle,
                            side: BorderSide(
                              color: sel ? p.gold : p.border,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedSlot = slot),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'TRAINER PT COMMISSION (%)',
                        style: TextStyle(
                          color: p.textMuted,
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
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                              onChanged: (_) => setState(() => _error = null),
                              decoration: InputDecoration(
                                suffixText: '%',
                                suffixStyle: TextStyle(color: p.textSecondary),
                                filled: true,
                                fillColor: p.cardSubtle,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: p.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: p.border),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _commPresets.map((pctPreset) {
                                final sel = pct == pctPreset;
                                return ChoiceChip(
                                  key: ValueKey(
                                    'edit_trainer_comm_$pctPreset',
                                  ),
                                  label: Text('$pctPreset%'),
                                  selected: sel,
                                  selectedColor: p.cyan,
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: sel ? p.onAccent : p.textSecondary,
                                  ),
                                  backgroundColor: p.cardSubtle,
                                  side: BorderSide(
                                    color: sel ? p.cyan : p.border,
                                  ),
                                  onSelected: (_) => setState(() {
                                    _commCtrl.text = '$pctPreset';
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
                        style: TextStyle(
                          color: p.gold,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: p.danger,
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
                    backgroundColor: p.cyan,
                    foregroundColor: p.onAccent,
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
