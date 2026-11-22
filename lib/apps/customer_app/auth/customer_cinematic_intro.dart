import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/hero_avatar_service.dart';

class CustomerCinematicIntro extends StatefulWidget {
  final String gymName;
  final String memberName;
  final String planTitle;
  final VoidCallback onFinished;

  const CustomerCinematicIntro({
    super.key,
    required this.gymName,
    required this.memberName,
    required this.planTitle,
    required this.onFinished,
  });

  @override
  State<CustomerCinematicIntro> createState() => _CustomerCinematicIntroState();
}

class _CustomerCinematicIntroState extends State<CustomerCinematicIntro>
    with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final AnimationController _embersCtrl;
  final List<_EmberParticle> _embers = [];
  bool _impactTriggered = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    for (int i = 0; i < 56; i++) {
      _embers.add(
        _EmberParticle(
          xNorm: rng.nextDouble(),
          yStart: 0.78 + rng.nextDouble() * 0.42,
          speed: 0.38 + rng.nextDouble() * 0.85,
          drift: (rng.nextDouble() - 0.5) * 0.18,
          radius: 1.5 + rng.nextDouble() * 3.4,
          phase: rng.nextDouble(),
          isGold: rng.nextBool(),
        ),
      );
    }

    _embersCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2900),
    );

    _mainCtrl.addListener(() {
      if (!_impactTriggered && _mainCtrl.value >= 0.40) {
        _impactTriggered = true;
        HapticFeedback.heavyImpact();
      }
    });

    _mainCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_finished) {
        _finished = true;
        widget.onFinished();
      }
    });

    _mainCtrl.forward();
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _embersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: Stack(
        children: [
          // 1. Rising Fire Embers + Radial Flame Aura
          AnimatedBuilder(
            animation: Listenable.merge([_embersCtrl, _mainCtrl]),
            builder: (context, _) {
              final t = _mainCtrl.value;
              return CustomPaint(
                size: size,
                painter: _FireEmbersPainter(
                  embers: _embers,
                  progress: _embersCtrl.value,
                  powerIntensity: (t * 1.7).clamp(0.25, 1.0),
                ),
              );
            },
          ),

          // 2. 3D Anime Gym Hero + Perspective Slam + Shockwave + Kinetic Text
          AnimatedBuilder(
            animation: Listenable.merge([_mainCtrl, _embersCtrl]),
            builder: (context, _) {
              final t = _mainCtrl.value;

              // Hero 3D slam entrance: 0.0 -> 0.42
              final heroRaw = (t / 0.42).clamp(0.0, 1.0);
              final easedHero = Curves.easeOutCubic.transform(heroRaw);
              final heroScale = 0.62 + (easedHero * 0.38);
              final idleBreath =
                  t > 0.42 ? math.sin((t - 0.42) * math.pi * 3) * 0.018 : 0.0;

              // 3D perspective tilt during entrance, settling into subtle 3D sway
              final rotY = (1.0 - easedHero) * 0.45 +
                  (t > 0.42
                      ? math.sin((_embersCtrl.value) * math.pi * 2) * 0.045
                      : 0.0);
              final rotX = (1.0 - easedHero) * -0.18;

              // Camera micro-shake right on impact (0.40 -> 0.52)
              double shakeX = 0;
              double shakeY = 0;
              if (t >= 0.40 && t <= 0.52) {
                final shakeDecay = 1.0 - ((t - 0.40) / 0.12);
                shakeX = math.sin(t * 210) * 6.5 * shakeDecay;
                shakeY = math.cos(t * 170) * 4.5 * shakeDecay;
              }

              // Text reveal phase: 0.44 -> 0.68
              final textT = ((t - 0.44) / 0.24).clamp(0.0, 1.0);
              final easedText = Curves.easeOutBack.transform(textT);

              // Hold at full visibility while inspecting
              const masterOpacity = 1.0;

              return Opacity(
                opacity: masterOpacity,
                child: Transform.translate(
                  offset: Offset(shakeX, shakeY),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),
                          SizedBox(
                            width: (size.width * 0.80).clamp(250.0, 330.0),
                            height: (size.height * 0.43).clamp(280.0, 380.0),
                            child: Center(
                              // 3D Perspective Hero Portrait (No circle/frame)
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0018)
                                  ..rotateY(rotY)
                                  ..rotateX(rotX)
                                  ..scaleByDouble(
                                    heroScale + idleBreath,
                                    heroScale + idleBreath,
                                    1.0,
                                    1.0,
                                  ),
                                child: Opacity(
                                  opacity: heroRaw,
                                  child: Hero(
                                    tag: 'power_hero_avatar',
                                    child: HeroAvatarImage(
                                      width: (size.width * 0.84)
                                          .clamp(260.0, 340.0),
                                      height: (size.height * 0.45)
                                          .clamp(290.0, 390.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Opacity(
                            opacity: textT,
                            child: Transform.scale(
                              scale: 0.88 + (easedText * 0.12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.ownerGold,
                                          Color(0xFFFF6B2B),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'WELCOME TO ${widget.gymName.toUpperCase()}',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.ownerGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.8,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        Colors.white,
                                        AppTheme.ownerGold,
                                        Color(0xFFFF6B2B),
                                      ],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'UNLEASH YOUR\nPOWER',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 33,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                        height: 1.16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. No top Skip button — transitions straight into Member Pass
        ],
      ),
    );
  }
}

class _EmberParticle {
  final double xNorm;
  final double yStart;
  final double speed;
  final double drift;
  final double radius;
  final double phase;
  final bool isGold;

  const _EmberParticle({
    required this.xNorm,
    required this.yStart,
    required this.speed,
    required this.drift,
    required this.radius,
    required this.phase,
    required this.isGold,
  });
}

class _FireEmbersPainter extends CustomPainter {
  final List<_EmberParticle> embers;
  final double progress;
  final double powerIntensity;

  _FireEmbersPainter({
    required this.embers,
    required this.progress,
    required this.powerIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final auraPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.1),
        radius: 0.85,
        colors: [
          const Color(0xFFFF5518).withValues(alpha: 0.28 * powerIntensity),
          const Color(0xFFE5C158).withValues(alpha: 0.10 * powerIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), auraPaint);

    for (final e in embers) {
      final t = (progress * e.speed + e.phase) % 1.0;
      final y = size.height * (e.yStart - t * 1.15);
      final x = size.width * (e.xNorm + math.sin(t * math.pi * 3) * e.drift);
      final alpha = (1.0 - t).clamp(0.0, 1.0) * 0.85;
      final color = e.isGold
          ? AppTheme.ownerGold.withValues(alpha: alpha)
          : const Color(0xFFFF6324).withValues(alpha: alpha);
      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(x, y), e.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireEmbersPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.powerIntensity != powerIntensity;
}
