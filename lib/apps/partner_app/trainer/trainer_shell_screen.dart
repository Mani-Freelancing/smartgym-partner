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
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: _screens[_tabIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _buildNavItem(
                  0,
                  Icons.person_add_alt_1_rounded,
                  'Admissions',
                ),
                _buildNavItem(
                  1,
                  Icons.restaurant_rounded,
                  'PT & Meals',
                ),
                _buildNavItem(
                  2,
                  Icons.qr_code_2_rounded,
                  'Radar & QR',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.trainerCyan.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: AppTheme.trainerCyan.withValues(alpha: 0.45))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? AppTheme.trainerCyan : Colors.white38,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? Colors.white : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
