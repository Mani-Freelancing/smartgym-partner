import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class CustomerWelcomeScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const CustomerWelcomeScreen({super.key, required this.onFinished});

  @override
  State<CustomerWelcomeScreen> createState() => _CustomerWelcomeScreenState();
}

class _CustomerWelcomeScreenState extends State<CustomerWelcomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  late final AnimationController _floatCtrl;
  int _page = 0;

  static const _slides = [
    _WelcomeSlideData(
      badge: 'SMART CHECK-IN',
      title: 'Digital Club Pass\n& Door QR',
      subtitle:
          'Scan in at the reception desk in 1 second, track your workout streak, and renew with ₹0 extra fee.',
      icon: Icons.qr_code_scanner_rounded,
      accent: AppTheme.trainerCyan,
    ),
    _WelcomeSlideData(
      badge: 'TRAIN SMARTER',
      title: 'Live Floor Crowd\n& Machine Guides',
      subtitle:
          'See how busy the gym is before leaving home, and scan any machine sticker for form & posture tips.',
      icon: Icons.sensors_rounded,
      accent: AppTheme.ownerGold,
    ),
    _WelcomeSlideData(
      badge: 'VIP COACHING',
      title: 'Diet Snap, Whey\n& PR Story Cards',
      subtitle:
          'Snap your meal for instant trainer feedback, track your whey tub scoops, and share PR cards to IG.',
      icon: Icons.emoji_events_rounded,
      accent: AppTheme.champagne,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _nextOrStart() {
    HapticFeedback.mediumImpact();
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _slides[_page];
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: current.accent, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'SMARTGYM CLUB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onFinished();
                    },
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = i);
                },
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _floatCtrl,
                          builder: (context, child) {
                            final dy = (_floatCtrl.value - 0.5) * 12;
                            return Transform.translate(
                              offset: Offset(0, dy),
                              child: child,
                            );
                          },
                          child: Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  s.accent.withValues(alpha: 0.28),
                                  s.accent.withValues(alpha: 0.04),
                                ],
                              ),
                              border: Border.all(
                                color: s.accent.withValues(alpha: 0.45),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: s.accent.withValues(alpha: 0.22),
                                  blurRadius: 36,
                                ),
                              ],
                            ),
                            child: Icon(s.icon, color: s.accent, size: 64),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: s.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            s.badge,
                            style: TextStyle(
                              color: s.accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? current.accent : Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: current.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _nextOrStart,
                      child: Text(
                        isLast ? 'GET STARTED' : 'NEXT',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSlideData {
  final String badge;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _WelcomeSlideData({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
}
