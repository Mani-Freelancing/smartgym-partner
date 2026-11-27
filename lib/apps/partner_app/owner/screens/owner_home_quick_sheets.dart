import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/services/member_whatsapp_service.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import 'owner_audit_log_screen.dart';

/// Opens a focused bottom sheet on Home listing currently active paid members
/// without jumping away from Home unless the Owner taps "View All →".
Future<void> showActiveMembersSheet(
  BuildContext context, {
  VoidCallback? onViewFullMembers,
}) {
  final bloc = context.read<SmartGymBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.lightCardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => AppTheme.ensureOwnerLight(
      sheetCtx,
      child: BlocProvider.value(
        value: bloc,
        child: _ActiveMembersSheetBody(
          onViewFullMembers: onViewFullMembers,
        ),
      ),
    ),
  );
}

class _ActiveMembersSheetBody extends StatelessWidget {
  final VoidCallback? onViewFullMembers;

  const _ActiveMembersSheetBody({this.onViewFullMembers});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final activeList = state.activeMembers;
        final activePtCount = activeList.where((m) => m.isPtClient).length;
        final maxHeight = MediaQuery.of(context).size.height * 0.74;

        return ConstrainedBox(
          key: const ValueKey('active_members_sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.cardSubtle,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: p.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Members (${activeList.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              activePtCount > 0
                                  ? '$activePtCount PT VIP • ${activeList.length - activePtCount} Regular active'
                                  : 'Currently active paid memberships',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onViewFullMembers != null)
                        TextButton(
                          key: const ValueKey('active_sheet_view_all_btn'),
                          onPressed: () {
                            Navigator.pop(context);
                            onViewFullMembers!();
                          },
                          child: Text(
                            'View All →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: p.gold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (activeList.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        'No active members right now.\nTap "Enroll Member" on Home to add a paid membership.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: activeList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final m = activeList[i];
                          final inFloor = m.isInFloorToday();
                          return Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: p.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
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
                                              m.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: p.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (m.isPtClient) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: p.cardSubtle,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: p.gold.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                'PT VIP',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: p.gold,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (inFloor) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: p.accent.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'IN FLOOR',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: p.accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${m.planTitle} • ${m.daysLeft}d left (${m.expiryDate})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: m.isExpiringSoon
                                              ? p.amber
                                              : p.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'WhatsApp Message',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    MemberWhatsAppService.launchMessage(
                                      context: context,
                                      phone: m.phone,
                                      message:
                                          'Hi ${m.respectfulName}! Checking in from ${gym.name} — hope your workouts are going strong!',
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.chat_rounded,
                                    color: MemberWhatsAppService.whatsappGreen,
                                    size: 19,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens a live gym-floor occupancy bottom sheet showing all checked-in members
/// and on-duty coaches currently inside the gym floor.
Future<void> showLiveFloorSheet(BuildContext context) {
  final bloc = context.read<SmartGymBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.lightCardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => AppTheme.ensureOwnerLight(
      sheetCtx,
      child: BlocProvider.value(
        value: bloc,
        child: const _LiveFloorSheetBody(),
      ),
    ),
  );
}

class _LiveFloorSheetBody extends StatelessWidget {
  const _LiveFloorSheetBody();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final maxCap = gym.maxCapacity > 0 ? gym.maxCapacity : 60;
        final crowd = state.liveCrowd;
        final inFloorMembers = state.membersInFloor;
        final onFloorTrainers = state.trainersOnFloor;
        final untrackedScans = (crowd - inFloorMembers.length).clamp(0, maxCap);
        final occupancyRatio = (crowd / maxCap).clamp(0.0, 1.0);
        final maxHeight = MediaQuery.of(context).size.height * 0.76;

        return ConstrainedBox(
          key: const ValueKey('live_floor_sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.sensors_rounded,
                          color: p.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live In Floor ($crowd/$maxCap)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              'Members & coaches currently inside ${gym.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (crowd > 0 || inFloorMembers.isNotEmpty)
                        TextButton(
                          key: const ValueKey('live_floor_reset_btn'),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            context.read<SmartGymBloc>().add(
                                  const ResetGymFloorCrowdEvent(),
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: p.snackBg,
                                content: const Text(
                                  'Live floor count reset to 0',
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'Clear Floor',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: p.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Occupancy progress bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: p.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Floor Occupancy',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${(occupancyRatio * 100).round()}% • ${maxCap - crowd} free',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: occupancyRatio >= 0.8
                                      ? p.danger
                                      : p.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: occupancyRatio,
                            minHeight: 6,
                            backgroundColor: p.border.withValues(alpha: 0.55),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              occupancyRatio >= 0.8 ? p.danger : p.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (onFloorTrainers.isNotEmpty) ...[
                          Text(
                            'COACHES ON DUTY (${onFloorTrainers.length})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: p.gold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...onFloorTrainers.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: p.cardSubtle.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: p.gold.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: p.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: p.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${t.radarDutySubtitle} • ${t.specialty}',
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
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'ON DUTY',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: p.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          'MEMBERS IN FLOOR (${inFloorMembers.length})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (inFloorMembers.isEmpty && untrackedScans == 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: p.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Text(
                              'No members are checked in on the floor right now.\nMembers appear here live when they scan the Reception Door QR.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: p.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ...inFloorMembers.map((m) {
                          final timeStr = m.displayFloorCheckInTime;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: p.bg,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: p.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: p.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                m.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: p.textPrimary,
                                                ),
                                              ),
                                            ),
                                            if (m.isPtClient) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: p.cardSubtle,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'PT VIP',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: p.gold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${timeStr.isNotEmpty ? "In since $timeStr" : "Checked in today"} • ${m.planTitle}',
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
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    key: ValueKey('floor_checkout_${m.id}'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: p.gold,
                                      side: BorderSide(
                                        color: p.gold.withValues(alpha: 0.45),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      context.read<SmartGymBloc>().add(
                                            CheckOutMemberFromFloorEvent(m.id),
                                          );
                                    },
                                    child: const Text(
                                      'Check Out',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (untrackedScans > 0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: p.bg,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 18,
                                  color: p.gold,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '+$untrackedScans Door QR check-in(s) on floor',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens a focused bottom sheet on Home listing only expiring/expired members
/// with 1-tap WhatsApp renewal reminders (avoids redundant tab jumping).
Future<void> showExpiringMembersSheet(
  BuildContext context, {
  VoidCallback? onViewFullMembers,
}) {
  final bloc = context.read<SmartGymBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.lightCardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => AppTheme.ensureOwnerLight(
      sheetCtx,
      child: BlocProvider.value(
        value: bloc,
        child: _ExpiringMembersSheetBody(
          onViewFullMembers: onViewFullMembers,
        ),
      ),
    ),
  );
}

class _ExpiringMembersSheetBody extends StatelessWidget {
  final VoidCallback? onViewFullMembers;

  const _ExpiringMembersSheetBody({this.onViewFullMembers});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final expiring = state.expiringOrExpiredMembers;
        final maxHeight = MediaQuery.of(context).size.height * 0.72;

        return ConstrainedBox(
          key: const ValueKey('expiring_members_sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.cardSubtle,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.event_note_rounded,
                          color: p.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiring Soon (${expiring.length})',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              'Members expiring within 5 days or already due',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onViewFullMembers != null)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onViewFullMembers!();
                          },
                          child: Text(
                            'Renew / All →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: p.gold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (expiring.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        'All active memberships have more than 5 days remaining.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: expiring.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final m = expiring[i];
                          final expired = m.daysLeft <= 0;
                          return Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: p.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${m.planTitle} • ${expired ? 'Expired' : '${m.daysLeft}d left'} (${m.expiryDate})',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: expired
                                              ? p.danger
                                              : p.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: p.gold,
                                    side: BorderSide(
                                      color: p.gold.withValues(alpha: 0.45),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    MemberWhatsAppService.sendExpiryReminder(
                                      context: context,
                                      gymName: gym.name,
                                      member: m,
                                    );
                                  },
                                  icon: const Icon(Icons.chat_rounded, size: 14),
                                  label: const Text(
                                    'Remind',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens a focused bottom sheet on Home listing members with pending fee balances
/// so the Owner can collect dues in 1 tap without switching tabs.
Future<void> showPendingDuesSheet(BuildContext context) {
  final bloc = context.read<SmartGymBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.lightCardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => AppTheme.ensureOwnerLight(
      sheetCtx,
      child: BlocProvider.value(
        value: bloc,
        child: const _PendingDuesSheetBody(),
      ),
    ),
  );
}

class _PendingDuesSheetBody extends StatelessWidget {
  const _PendingDuesSheetBody();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final dueList = state.dueMembers;
        final maxHeight = MediaQuery.of(context).size.height * 0.72;

        return ConstrainedBox(
          key: const ValueKey('pending_dues_sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: dueList.isEmpty
                              ? p.cardSubtle
                              : p.danger.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.payments_outlined,
                          color: dueList.isEmpty ? p.gold : p.danger,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Balance Dues',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              dueList.isEmpty
                                  ? 'All balances clear'
                                  : '${dueList.length} member(s) owe ${formatInr(state.totalPendingDues)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: dueList.isEmpty
                                    ? p.textSecondary
                                    : p.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (dueList.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        'All member balances are clear — ₹0 pending dues!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: dueList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final m = dueList[i];
                          return Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: p.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '₹${m.dueAmount} due • ${m.planTitle}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: p.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'WhatsApp Reminder',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    MemberWhatsAppService.sendDueReminder(
                                      context: context,
                                      gymName: gym.name,
                                      member: m,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.chat_rounded,
                                    color: MemberWhatsAppService.whatsappGreen,
                                    size: 19,
                                  ),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: p.goldButton,
                                    foregroundColor: p.onAccent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    final collected = m.dueAmount;
                                    context.read<SmartGymBloc>().add(
                                          CollectMemberDueEvent(
                                            memberId: m.id,
                                            duePaid: collected,
                                          ),
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: p.snackBg,
                                        content: Text(
                                          'Collected ₹$collected from ${m.respectfulName}',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Mark Paid',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens a focused Walk-In Leads bottom sheet right on Home to convert or add leads.
Future<void> showWalkInLeadsSheet(BuildContext context) {
  final bloc = context.read<SmartGymBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.lightCardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => AppTheme.ensureOwnerLight(
      sheetCtx,
      child: BlocProvider.value(
        value: bloc,
        child: const _WalkInLeadsSheetBody(),
      ),
    ),
  );
}

class _WalkInLeadsSheetBody extends StatelessWidget {
  const _WalkInLeadsSheetBody();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final pendingEntries = <MapEntry<int, dynamic>>[];
        for (var i = 0; i < state.enquiries.length; i++) {
          final e = state.enquiries[i];
          if (!e.converted) {
            pendingEntries.add(MapEntry(i, e));
          }
        }
        final maxHeight = MediaQuery.of(context).size.height * 0.72;

        return ConstrainedBox(
          key: const ValueKey('walkin_leads_sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.cardSubtle,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.person_search_rounded,
                          color: p.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Walk-In Leads (${pendingEntries.length})',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              'Follow up or convert visitors to paid members',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: p.goldButton,
                          foregroundColor: p.onAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          showQuickLogWalkInSheet(context);
                        },
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text(
                          'Log Lead',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (pendingEntries.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        'No pending walk-in leads right now.\nTap "Log Lead" whenever a visitor enquiries about fees.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pendingEntries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final entry = pendingEntries[idx];
                          final origIdx = entry.key;
                          final enq = entry.value;
                          return Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: p.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        enq.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: p.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${enq.phone} • ${enq.interestedPlan}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: p.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'WhatsApp Follow-up',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    MemberWhatsAppService.launchMessage(
                                      context: context,
                                      phone: enq.phone,
                                      message:
                                          'Hi ${enq.name}! Thanks for visiting ${gym.name}. Your ${enq.interestedPlan} spot & trial pass are ready this week—reply here if you want us to reserve it!',
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.chat_rounded,
                                    color: MemberWhatsAppService.whatsappGreen,
                                    size: 19,
                                  ),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: p.goldButton,
                                    foregroundColor: p.onAccent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    context
                                        .read<SmartGymBloc>()
                                        .add(ConvertEnquiryToMemberEvent(origIdx));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: p.snackBg,
                                        content: Text(
                                          '${enq.name} converted to active member!',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Convert',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens a quick bottom sheet from Home Quick Actions to log a new walk-in visitor.
Future<void> showQuickLogWalkInSheet(BuildContext context) {
  final bloc = context.read<SmartGymBloc>();
  final state = bloc.state;
  final messenger = ScaffoldMessenger.of(context);
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final plans = state.currentGym.effectiveFeePlans
      .map((plan) => '${plan.name} (₹${plan.price})')
      .toList();
  String selectedPlan = plans.isNotEmpty
      ? plans.first
      : 'Monthly (₹${state.currentGym.monthlyFee})';
  String? error;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.lightCardSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => AppTheme.ensureOwnerLight(
      ctx,
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final mp = AppPalette.of(ctx);
          return Padding(
            key: const ValueKey('quick_log_walkin_sheet'),
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
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: mp.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    'Log Walk-In Visitor',
                    style: TextStyle(
                      color: mp.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Save visitors who enquired about fees for easy WhatsApp follow-up.',
                    style: TextStyle(color: mp.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(
                      color: mp.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Visitor Name',
                      hintText: 'e.g. Karthik',
                      filled: true,
                      fillColor: mp.bg,
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
                    style: TextStyle(
                      color: mp.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(
                        color: mp.gold,
                        fontWeight: FontWeight.w800,
                      ),
                      labelText: 'Mobile Number',
                      hintText: '98490 00000',
                      filled: true,
                      fillColor: mp.bg,
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
                            fontSize: 11.5,
                          ),
                        ),
                        selected: active,
                        selectedColor: mp.goldButton,
                        backgroundColor: mp.bg,
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
                      style: TextStyle(
                        color: mp.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
                            backgroundColor: mp.snackBg,
                            content: Text('Walk-in enquiry saved for $name'),
                          ),
                        );
                      },
                      child: const Text(
                        'SAVE WALK-IN LEAD',
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
