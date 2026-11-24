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
import 'owner_audit_log_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final expiringList = state.expiringOrExpiredMembers;
        final pendingEnquiries =
            state.enquiries.where((e) => !e.converted).length;

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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              // 1. Unified CEO Overview Hero + Analytics Chart Card
              CredStaggeredItem(
                index: 0,
                child: OwnerCeoHeroCard(
                  state: state,
                ),
              ),
              const SizedBox(height: 18),

              // 2. Clear 2x2 Key Numbers Grid
              const Text(
                'KEY NUMBERS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetricCard(
                      key: const ValueKey('home_metric_active'),
                      icon: Icons.people_alt_rounded,
                      label: 'Active Members',
                      value: '${state.activeMembersCount}',
                      sub:
                          '${state.ptMembers.length} PT VIP • ${state.members.length} total',
                      accentColor: AppTheme.accent,
                      onTap: () => _openAudit(context, 'All'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMetricCard(
                      key: const ValueKey('home_metric_expiring'),
                      icon: Icons.timer_outlined,
                      label: 'Expiring Soon',
                      value: '${expiringList.length}',
                      sub: expiringList.isEmpty
                          ? 'All memberships ok'
                          : 'Within 5 days / due',
                      accentColor: expiringList.isEmpty
                          ? AppTheme.accent
                          : AppTheme.amber,
                      onTap: () => _openAudit(context, 'Expiring'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetricCard(
                      key: const ValueKey('home_metric_dues'),
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Pending Dues',
                      value: formatInr(state.totalPendingDues),
                      sub: state.dueMembers.isEmpty
                          ? 'All balances clear'
                          : '${state.dueMembers.length} member(s) owe',
                      accentColor: AppTheme.softRed,
                      surfaceTint: state.totalPendingDues > 0
                          ? const Color(0xFF2E191E)
                          : const Color(0xFF22161A),
                      onTap: () => _openAudit(context, 'Dues'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMetricCard(
                      key: const ValueKey('home_metric_walkins'),
                      icon: Icons.person_search_rounded,
                      label: 'Walk-In Leads',
                      value: '$pendingEnquiries',
                      sub: pendingEnquiries == 0
                          ? 'No pending leads'
                          : 'Pending follow-up',
                      accentColor: AppTheme.champagne,
                      onTap: onOpenWalkInLeads,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Primary Quick Action
              const Text(
                'QUICK ACTION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const ValueKey('home_enroll_member_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.ownerGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<SmartGymBloc>(),
                          child: const OwnerAddMemberScreen(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text(
                    'Enroll Member',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (state.members.isEmpty) ...[
                const SizedBox(height: 16),
                CredMetalCard(
                  glowColor: AppTheme.ownerGold,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: const Text(
                    'No gym members added yet.\nTap Enroll Member above to add your first paid member and start tracking collections live.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
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
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color accentColor;
  final Color? surfaceTint;
  final VoidCallback? onTap;

  const _SummaryMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.accentColor,
    this.surfaceTint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceTint ?? const Color(0xFF171B26),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
