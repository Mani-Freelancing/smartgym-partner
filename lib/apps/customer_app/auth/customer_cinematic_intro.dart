import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

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
      duration: const Duration(milliseconds: 3500),
    );

    _mainCtrl.addListener(() {
      if (!_impactTriggered && _mainCtrl.value >= 0.40) {
        _impactTriggered = true;
        HapticFeedback.heavyImpact();
      }
    });

    _mainCtrl.addStatusListener((status) {
      // Hold on the intro screen for inspection until auto-navigation is re-enabled.
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
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 300,
                            height: 330,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 3D Perspective Hero Portrait (No circle/frame)
                                Transform(
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
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.white,
                                          Colors.white,
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.16, 0.82, 1.0],
                                      ).createShader(bounds),
                                      blendMode: BlendMode.dstIn,
                                      child: ShaderMask(
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.transparent,
                                            Colors.white,
                                            Colors.white,
                                            Colors.transparent,
                                          ],
                                          stops: [0.0, 0.16, 0.84, 1.0],
                                        ).createShader(bounds),
                                        blendMode: BlendMode.dstIn,
                                        child: Image.asset(
                                          'assets/images/power_hero_3d.jpg',
                                          width: 300,
                                          height: 330,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Opacity(
                            opacity: textT,
                            child: Transform.scale(
                              scale: 0.85 + (easedText * 0.15),
                              child: Column(
                                children: [
                                  Text(
                                    'WELCOME TO ${widget.gymName.toUpperCase()}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.ownerGold,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
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
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                        height: 1.08,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.trainerCyan
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: AppTheme.trainerCyan
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: Text(
                                      '${widget.memberName} • ${widget.planTitle}',
                                      style: const TextStyle(
                                        color: AppTheme.trainerCyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
