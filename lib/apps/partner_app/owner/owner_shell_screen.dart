import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import 'screens/owner_orders_leads_screen.dart';
import 'screens/owner_revenue_screen.dart';

class OwnerShellScreen extends StatefulWidget {
  const OwnerShellScreen({super.key});

  @override
  State<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends State<OwnerShellScreen> {
  int _tabIndex = 0;

  static const _screens = [
    OwnerRevenueScreen(),
    OwnerOrdersLeadsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final pendingCount = state.trainerRequests.length;
        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: IndexedStack(
            index: _tabIndex,
            children: _screens,
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Container(
                height: 66,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1D2230), Color(0xFF141822)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppTheme.ownerGold.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Revenue',
                      badgeCount: 0,
                    ),
                    const SizedBox(width: 6),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.groups_2_rounded,
                      label: 'Trainers & PT',
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
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required int badgeCount,
  }) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_tabIndex == index) return;
          HapticFeedback.selectionClick();
          setState(() => _tabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.ownerGold.withValues(alpha: 0.22),
                      AppTheme.ownerGold.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(
                    color: AppTheme.ownerGold.withValues(alpha: 0.55),
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
                  color: AppTheme.ownerGold,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppTheme.ownerGold.withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? AppTheme.ownerGold : Colors.white38,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 0.2,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w600,
                        color: selected ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.ownerGold,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
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
