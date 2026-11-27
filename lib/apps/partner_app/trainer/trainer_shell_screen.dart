import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import 'screens/trainer_absent_radar_screen.dart';
import 'screens/trainer_meal_queue_screen.dart';
import 'screens/trainer_members_onboarding_screen.dart';

class TrainerShellScreen extends StatefulWidget {
  const TrainerShellScreen({super.key});

  @override
  State<TrainerShellScreen> createState() => _TrainerShellScreenState();
}

class _TrainerShellScreenState extends State<TrainerShellScreen> {
  int _tabIndex = 0;

  static const _screens = [
    TrainerMembersOnboardingScreen(),
    TrainerMealQueueScreen(),
    TrainerAbsentRadarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppTheme.ensureOwnerLight(
      context,
      child: Builder(
        builder: (context) {
          final p = AppPalette.of(context);
          return Scaffold(
            backgroundColor: p.bg,
            body: IndexedStack(
              index: _tabIndex,
              children: _screens,
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
                          navKey: const ValueKey('trainer_nav_admissions'),
                          index: 0,
                          activeIcon: Icons.person_add_alt_1_rounded,
                          inactiveIcon: Icons.person_add_alt_1_outlined,
                          label: 'Admissions',
                        ),
                        const SizedBox(width: 8),
                        _buildNavItem(
                          p: p,
                          navKey: const ValueKey('trainer_nav_meals'),
                          index: 1,
                          activeIcon: Icons.restaurant_rounded,
                          inactiveIcon: Icons.restaurant_outlined,
                          label: 'PT & Meals',
                        ),
                        const SizedBox(width: 8),
                        _buildNavItem(
                          p: p,
                          navKey: const ValueKey('trainer_nav_radar'),
                          index: 2,
                          activeIcon: Icons.qr_code_2_rounded,
                          inactiveIcon: Icons.qr_code_2_outlined,
                          label: 'Radar & QR',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
              Icon(
                selected ? activeIcon : inactiveIcon,
                size: 22,
                color: selected ? p.textPrimary : p.textMuted,
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
