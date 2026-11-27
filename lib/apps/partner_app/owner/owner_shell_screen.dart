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
                bottomNavigationBar: Container(
                  decoration: BoxDecoration(
                    color: p.navBar,
                    border: Border(
                      top: BorderSide(color: p.border, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8C6218)
                            .withValues(alpha: p.isDark ? 0.45 : 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 66,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            _buildNavItem(
                              p: p,
                              navKey: const ValueKey('owner_nav_home'),
                              index: 0,
                              activeIcon: Icons.home_rounded,
                              inactiveIcon: Icons.home_outlined,
                              label: 'Home',
                              badgeCount: 0,
                            ),
                            const SizedBox(width: 8),
                            _buildNavItem(
                              p: p,
                              navKey: const ValueKey('owner_nav_audit'),
                              index: 1,
                              activeIcon: Icons.people_alt_rounded,
                              inactiveIcon: Icons.people_outline_rounded,
                              label: 'Members',
                              badgeCount: 0,
                            ),
                            const SizedBox(width: 8),
                            _buildNavItem(
                              p: p,
                              navKey: const ValueKey('owner_nav_trainers'),
                              index: 2,
                              activeIcon: Icons.bar_chart_rounded,
                              inactiveIcon: Icons.bar_chart_outlined,
                              label: 'Trainers',
                              badgeCount: pendingCount,
                            ),
                          ],
                        ),
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
    required IconData activeIcon,
    required IconData inactiveIcon,
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            // Soft Warm Golden-Cream Glow like the screenshot (NO heavy black pill!)
            gradient: selected && !p.isDark
                ? const RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      Color(0xFFFFEAB8),
                      Color(0xFFFFF7E4),
                      Colors.white,
                    ],
                  )
                : null,
            color: selected && p.isDark
                ? p.gold.withValues(alpha: 0.16)
                : null,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? activeIcon : inactiveIcon,
                    size: 22,
                    color: selected ? p.textPrimary : p.textMuted,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -9,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: p.gold,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: TextStyle(
                            color: p.onAccent,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? p.gold : p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
