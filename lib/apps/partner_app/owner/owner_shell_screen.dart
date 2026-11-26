import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import 'screens/owner_audit_log_screen.dart';
import 'screens/owner_orders_leads_screen.dart';
import 'screens/owner_revenue_screen.dart';

class OwnerShellScreen extends StatefulWidget {
  const OwnerShellScreen({super.key});

  @override
  State<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends State<OwnerShellScreen> {
  int _tabIndex = 0;
  String _auditFilter = 'All';

  void _openAuditTab(String filter) {
    setState(() {
      _auditFilter = filter;
      _tabIndex = 1;
    });
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
              final pendingCount = state.trainerRequests.length;
              return Scaffold(
                backgroundColor: p.bg,
                body: IndexedStack(
                  index: _tabIndex,
                  children: [
                    OwnerRevenueScreen(
                      onOpenWalkInLeads: () => setState(() => _tabIndex = 2),
                      onOpenAuditLog: _openAuditTab,
                    ),
                    OwnerAuditLogScreen(
                      embedded: true,
                      activeFilter: _auditFilter,
                      onFilterChanged: (f) => setState(() => _auditFilter = f),
                    ),
                    const OwnerOrdersLeadsScreen(),
                  ],
                ),
                bottomNavigationBar: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: Container(
                      height: 66,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: p.navBar,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: p.border,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: p.isDark ? 0.55 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildNavItem(
                            p: p,
                            navKey: const ValueKey('owner_nav_home'),
                            index: 0,
                            icon: Icons.dashboard_rounded,
                            label: 'Home',
                            badgeCount: 0,
                          ),
                          const SizedBox(width: 6),
                          _buildNavItem(
                            p: p,
                            navKey: const ValueKey('owner_nav_audit'),
                            index: 1,
                            icon: Icons.fact_check_rounded,
                            label: 'Audit Log',
                            badgeCount: 0,
                          ),
                          const SizedBox(width: 6),
                          _buildNavItem(
                            p: p,
                            navKey: const ValueKey('owner_nav_trainers'),
                            index: 2,
                            icon: Icons.groups_2_rounded,
                            label: 'Trainers',
                            badgeCount: pendingCount,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNavItem({
    required AppPalette p,
    required Key navKey,
    required int index,
    required IconData icon,
    required String label,
    required int badgeCount,
  }) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        key: navKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_tabIndex == index) return;
          HapticFeedback.selectionClick();
          setState(() => _tabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? p.gold.withValues(alpha: p.isDark ? 0.16 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(
                    color: p.gold.withValues(alpha: p.isDark ? 0.55 : 0.38),
                    width: 1.1,
                  )
                : Border.all(color: Colors.transparent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 20 : 0,
                height: 2.5,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: p.gold,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? p.gold : p.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        letterSpacing: 0.1,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w600,
                        color: selected ? p.textPrimary : p.textSecondary,
                      ),
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: p.gold,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          color: p.onAccent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
