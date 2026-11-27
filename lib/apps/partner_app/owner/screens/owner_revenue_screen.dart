import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import '../analytics/owner_analytics_widgets.dart';
import '../owner_add_member_screen.dart';
import '../owner_gym_settings_sheet.dart';
import '../owner_team_qr_sheet.dart';
import 'owner_audit_log_screen.dart';
import 'owner_home_quick_sheets.dart';

class OwnerRevenueScreen extends StatelessWidget {
  final VoidCallback? onOpenWalkInLeads;
  final ValueChanged<String>? onOpenAuditLog;

  const OwnerRevenueScreen({
    super.key,
    this.onOpenWalkInLeads,
    this.onOpenAuditLog,
  });

  void _openAudit(BuildContext context, String filter) {
    if (onOpenAuditLog != null) {
      onOpenAuditLog!(filter);
    } else {
      OwnerAuditLogScreen.open(context, initialFilter: filter);
    }
  }

  void _openEnrollMember(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SmartGymBloc>(),
          child: const OwnerAddMemberScreen(),
        ),
      ),
    );
  }

  void _openQrSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final p = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<SmartGymBloc>(),
        child: const OwnerTeamQrSheet(),
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
              final gym = state.currentGym;
              final expiringList = state.expiringOrExpiredMembers;
              final pendingEnquiries =
                  state.enquiries.where((e) => !e.converted).length;

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
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  children: [
                    // Editorial Greeting Header
                    // Text(
                    //   'CEO Dashboard',
                    //   style: TextStyle(
                    //     fontSize: 18,
                    //     fontWeight: FontWeight.w900,
                    //     letterSpacing: -0.6,
                    //     color: p.textPrimary,
                    //   ),
                    // ),
                
                    const SizedBox(height: 20),

                    // 1. Single Unified Container: Total Collections + Revenue Trend
                    CredStaggeredItem(
                      index: 0,
                      child: OwnerCeoHeroCard(state: state),
                    ),
                    const SizedBox(height: 11),

                    // 2. White KPI Cards (3-column primary row + 2-column dues/leads row)
                    Row(
                      children: [
                        Expanded(
                          child: _GoldenKpiTile(
                            key: const ValueKey('home_metric_active'),
                            icon: Icons.groups_rounded,
                            value: '${state.activeMembersCount}',
                            label: 'Active Members',
                            footerText: state.ptMembers.isNotEmpty
                                ? '▲ ${state.ptMembers.length} PT VIP'
                                : 'Quick View →',
                            footerColor: p.accent,
                            onTap: () => showActiveMembersSheet(
                              context,
                              onViewFullMembers: () =>
                                  _openAudit(context, 'All'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _GoldenKpiTile(
                            key: const ValueKey('home_metric_expiring'),
                            icon: Icons.event_note_rounded,
                            value: '${expiringList.length}',
                            label: 'Expiring Soon',
                            footerText: 'Quick View →',
                            footerColor: p.gold,
                            onTap: () {
                              showExpiringMembersSheet(
                                context,
                                onViewFullMembers: () =>
                                    _openAudit(context, 'Expiring'),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _GoldenKpiTile(
                            key: const ValueKey('home_metric_floor'),
                            icon: Icons.sensors_rounded,
                            value: '${state.liveCrowd}',
                            label:
                                '${state.liveCrowd}/${gym.maxCapacity} IN FLOOR',
                            footerText: '● Live →',
                            footerColor: p.accent,
                            onTap: () => showLiveFloorSheet(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: _GoldenCompactRowTile(
                            key: const ValueKey('home_metric_dues'),
                            icon: Icons.payments_outlined,
                            label: 'Pending Dues',
                            value: formatInr(state.totalPendingDues),
                            isAlert: state.totalPendingDues > 0,
                            onTap: () => showPendingDuesSheet(context),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _GoldenCompactRowTile(
                            key: const ValueKey('home_metric_walkins'),
                            icon: Icons.person_search_rounded,
                            label: 'Walk-In Leads',
                            value: '$pendingEnquiries',
                            isAlert: false,
                            onTap: () => showWalkInLeadsSheet(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. 4 Unique Quick Actions (Zero Duplicates with KPIs or Bottom Nav)
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _GoldenQuickActionTile(
                            key: const ValueKey('home_enroll_member_btn'),
                            icon: Icons.person_add_alt_1_rounded,
                            label: 'Enroll Member',
                            onTap: () => _openEnrollMember(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GoldenQuickActionTile(
                            key: const ValueKey('home_log_walkin_btn'),
                            icon: Icons.person_pin_circle_rounded,
                            label: 'Log Walk-In',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              showQuickLogWalkInSheet(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GoldenQuickActionTile(
                            key: const ValueKey('home_share_qr_btn'),
                            icon: Icons.qr_code_2_rounded,
                            label: 'Share QR',
                            onTap: () => _openQrSheet(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GoldenQuickActionTile(
                            key: const ValueKey('home_gym_settings_btn'),
                            icon: Icons.tune_rounded,
                            label: 'Gym Settings',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              showOwnerGymSettingsSheet(context, state);
                            },
                          ),
                        ),
                      ],
                    ),

                    if (state.members.isEmpty) ...[
                      const SizedBox(height: 14),
                      CredMetalCard(
                        glowColor: p.gold,
                        padding: const EdgeInsets.all(15),
                        borderRadius: 16,
                        child: Text(
                          'No gym members added yet.\nTap Enroll Member above to add your first paid member and start tracking collections live.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: p.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
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

class _GoldenKpiTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String footerText;
  final Color footerColor;
  final VoidCallback? onTap;

  const _GoldenKpiTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.footerText,
    required this.footerColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: p.cardShadow,
      ),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(11, 12, 11, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: p.cardSubtle,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: p.gold),
                ),
                const SizedBox(height: 9),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  footerText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: footerColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldenCompactRowTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isAlert;
  final VoidCallback? onTap;

  const _GoldenCompactRowTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.isAlert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: p.cardShadow,
      ),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAlert
                    ? Color.lerp(p.border, p.danger, 0.25)!
                    : p.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isAlert
                        ? p.danger.withValues(alpha: 0.08)
                        : p.cardSubtle,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isAlert ? p.danger : p.gold,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isAlert ? p.danger : p.textPrimary,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: p.gold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldenQuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GoldenQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: p.cardShadow,
      ),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFFEDC2),
                        Color(0xFFFFF8E8),
                      ],
                    ),
                    border: Border.all(
                      color: p.gold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon, size: 20, color: p.gold),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
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
}
