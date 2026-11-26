import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logout_confirm_dialog.dart';
import '../../data/services/hero_avatar_service.dart';
import '../../shared_bloc/smart_gym_bloc.dart';
import '../../shared_bloc/smart_gym_event.dart';
import '../../shared_bloc/smart_gym_state.dart';
import 'auth/customer_cinematic_intro.dart';
import 'auth/customer_login_screen.dart';
import 'auth/customer_welcome_screen.dart';
import 'customer_drawer.dart';
import 'screens/customer_machines_screen.dart';
import 'screens/customer_pass_screen.dart';
import 'screens/customer_pt_diet_screen.dart';
import 'screens/customer_store_screen.dart';

class CustomerAppRoot extends StatefulWidget {
  const CustomerAppRoot({super.key});

  @override
  State<CustomerAppRoot> createState() => _CustomerAppRootState();
}

class _CustomerAppRootState extends State<CustomerAppRoot> {
  static const _seenIntroKey = 'customer_seen_intro_v1';
  int _tabIndex = 0;
  bool _checkingIntro = true;
  bool _showIntro = false;
  bool _cinematicLaunched = false;
  bool _homeVisible = false;

  static String _titleCase(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _loadIntroFlag();
  }

  Future<void> _loadIntroFlag() async {
    try {
      await HeroAvatarService.loadSavedPose();
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_seenIntroKey) ?? false;
      if (mounted) {
        setState(() {
          _showIntro = !seen;
          _checkingIntro = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _showIntro = false;
          _checkingIntro = false;
        });
      }
    }
  }

  void _launchPowerCinematicOnce(
    BuildContext context, {
    required String gymName,
    required String memberName,
    required String planTitle,
  }) {
    if (_cinematicLaunched) return;
    _cinematicLaunched = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _tabIndex = 0);
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: const Duration(milliseconds: 900),
          pageBuilder: (ctx, animation, secondaryAnimation) =>
              CustomerCinematicIntro(
            gymName: gymName,
            memberName: memberName,
            planTitle: planTitle,
            onFinished: () {
              if (Navigator.of(ctx).canPop()) {
                Navigator.of(ctx).pop();
              }
            },
          ),
          transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ),
              child: child,
            );
          },
        ),
      );
      // Reveal Home underneath only after the intro route is already on top
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _homeVisible = true);
      });
    });
  }

  Future<void> _markIntroSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenIntroKey, true);
    } catch (_) {}
    if (mounted) {
      setState(() => _showIntro = false);
    }
  }

  static const _screens = [
    CustomerPassScreen(),
    CustomerMachinesScreen(),
    CustomerPtDietScreen(),
    CustomerStoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        if (state.isAuthChecking || _checkingIntro) {
          return const Scaffold(
            backgroundColor: Color(0xFF07090D),
            body: SizedBox.expand(),
          );
        }

        if (!state.isPartnerLoggedIn && !state.needsOnboarding && _showIntro) {
          return CustomerWelcomeScreen(onFinished: _markIntroSeen);
        }

        if (state.needsOnboarding) {
          return Scaffold(
            backgroundColor: AppTheme.scaffoldBg,
            body: SafeArea(
              child: RefreshIndicator(
                color: AppTheme.trainerCyan,
                backgroundColor: const Color(0xFF1A1E29),
                onRefresh: () async {
                  context
                      .read<SmartGymBloc>()
                      .add(const CheckAuthSessionEvent());
                  await Future<void>.delayed(const Duration(milliseconds: 450));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E29),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.trainerCyan.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.card_membership_rounded,
                            color: AppTheme.trainerCyan,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Membership Not Found',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask your Gym Owner or Trainer to enroll your number (${state.authenticatedPhone}) as a Paid Member.\n\nOnce enrolled, this screen will unlock automatically!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => confirmAndLogout(
                              context,
                              title: 'Switch Mobile Number?',
                              message:
                                  'Are you sure you want to log out and try another mobile number?',
                              confirmLabel: 'Switch',
                            ),
                            child: const Text(
                              'Switch Mobile Number',
                              style: TextStyle(
                                color: AppTheme.trainerCyan,
                                fontWeight: FontWeight.w800,
                              ),
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
        }

        if (!state.isPartnerLoggedIn) {
          return const CustomerLoginScreen();
        }

        if (state.gyms.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF07090D),
            body: SizedBox.expand(),
          );
        }

        final gym = state.currentGym;
        _launchPowerCinematicOnce(
          context,
          gymName: gym.name,
          memberName: state.currentMember?.respectfulName.isNotEmpty == true
              ? state.currentMember!.respectfulName
              : 'Club Athlete',
          planTitle: state.currentMember?.planTitle ?? '1-Month Regular',
        );

        return ColoredBox(
          color: const Color(0xFF07090D),
          child: Opacity(
            opacity: _homeVisible ? 1.0 : 0.0,
            child: Scaffold(
              key: const ValueKey('customer_home'),
          backgroundColor: AppTheme.scaffoldBg,
          drawer: const CustomerDrawer(),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          tooltip: 'Profile & Settings',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.trainerCyan.withValues(alpha: 0.14),
                            foregroundColor: AppTheme.trainerCyan,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Scaffold.of(ctx).openDrawer();
                          },
                          icon: const Icon(Icons.menu_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SMARTGYM CLUB • LIVE PASS',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: AppTheme.trainerCyan,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_titleCase(gym.name)}${gym.area.isNotEmpty ? ' (${_titleCase(gym.area)})' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
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
                          color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '🔥 ${state.streakDays}d',
                          style: const TextStyle(
                            color: AppTheme.trainerCyan,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildDockItem(
                      0,
                      Icons.qr_code_scanner_rounded,
                      'Club Pass',
                    ),
                    _buildDockItem(
                      1,
                      Icons.play_circle_outline_rounded,
                      'Floor QR',
                    ),
                    _buildDockItem(
                      2,
                      Icons.restaurant_menu_rounded,
                      'PT & Diet',
                    ),
                    _buildDockItem(
                      3,
                      Icons.local_fire_department_rounded,
                      'Fuel & PR',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ),
        );
      },
    );
  }

  Widget _buildDockItem(int index, IconData icon, String label) {
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
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.trainerCyan.withValues(alpha: 0.22),
                      AppTheme.trainerCyan.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            border: selected
                ? Border.all(
                    color: AppTheme.trainerCyan.withValues(alpha: 0.5),
                    width: 1.1,
                  )
                : Border.all(color: Colors.transparent),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 16 : 0,
                height: 2.5,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppTheme.trainerCyan,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Icon(
                icon,
                size: 18,
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
