import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// CRED-style Matte Metal Card with specular top-left border highlight,
/// subtle radial spotlight, and tactile spring-scale press animation.
class CredMetalCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color glowColor;
  final bool enableShimmer;
  final double borderRadius;

  const CredMetalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.onTap,
    this.glowColor = const Color(0xFF00E676),
    this.enableShimmer = false,
    this.borderRadius = 24,
  });

  @override
  State<CredMetalCard> createState() => _CredMetalCardState();
}

class _CredMetalCardState extends State<CredMetalCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.enableShimmer) {
      _shimmerCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CredMetalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableShimmer && !_shimmerCtrl.isAnimating) {
      _shimmerCtrl.repeat();
    } else if (!widget.enableShimmer && _shimmerCtrl.isAnimating) {
      _shimmerCtrl.stop();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isLight = !p.isDark;
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            // Specular rim in dark mode; crisp clean border in daylight Owner mode
            gradient: isLight
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.glowColor.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.03),
                      widget.glowColor.withValues(alpha: 0.18),
                    ],
                    stops: const [0.0, 0.25, 0.7, 1.0],
                  ),
            border: isLight
                ? Border.all(
                    color: Color.lerp(
                      const Color(0xFFE2E8F0),
                      widget.glowColor,
                      0.22,
                    )!,
                    width: 1,
                  )
                : null,
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.08),
                      blurRadius: 28,
                      spreadRadius: -4,
                    ),
                  ],
          ),
          padding: EdgeInsets.all(isLight ? 0 : 1.2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              isLight ? widget.borderRadius - 1 : widget.borderRadius - 1.2,
            ),
            child: Stack(
              children: [
                Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: isLight ? Colors.white : null,
                    gradient: isLight
                        ? RadialGradient(
                            center: const Alignment(-0.9, -0.9),
                            radius: 1.5,
                            colors: [
                              Color.lerp(
                                Colors.white,
                                widget.glowColor,
                                0.045,
                              )!,
                              Colors.white,
                            ],
                          )
                        : RadialGradient(
                            center: const Alignment(-0.85, -0.9),
                            radius: 1.4,
                            colors: [
                              Color.lerp(
                                const Color(0xFF212633),
                                widget.glowColor,
                                0.11,
                              )!,
                              const Color(0xFF1A1E29),
                              const Color(0xFF151922),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                  ),
                  child: widget.child,
                ),
                if (widget.enableShimmer)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shimmerCtrl,
                        builder: (context, _) {
                          final slide = (_shimmerCtrl.value * 3.0) - 1.0;
                          return FractionalTranslation(
                            translation: Offset(slide, 0),
                            child: Transform.rotate(
                              angle: -0.35,
                              child: Container(
                                width: 90,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.045),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CRED NeoPOP 3D Tactile Button that physically depresses by 4px on tap.
class CredNeoPopButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const CredNeoPopButton({
    super.key,
    required this.label,
    this.icon,
    this.color = const Color(0xFF00E676),
    this.textColor = const Color(0xFF06080B),
    required this.onTap,
  });

  @override
  State<CredNeoPopButton> createState() => _CredNeoPopButtonState();
}

class _CredNeoPopButtonState extends State<CredNeoPopButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    final shadowColor = HSLColor.fromColor(widget.color)
        .withLightness(
          (HSLColor.fromColor(widget.color).lightness - 0.22).clamp(0.05, 1.0),
        )
        .toColor();

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isDown = true);
      },
      onTapUp: (_) {
        setState(() => _isDown = false);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isDown = false),
      child: SizedBox(
        height: 54,
        child: Stack(
          children: [
            // 3D Bottom Bevel Lip
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: shadowColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            // Top Tactile Surface
            AnimatedPositioned(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOutQuad,
              left: 0,
              right: 0,
              top: _isDown ? 4 : 0,
              bottom: _isDown ? 1 : 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: widget.textColor, size: 19),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
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
    );
  }
}

/// CRED Garage-style Segmented Glowing Arc Gauge with smooth tween animation.
class CredArcGauge extends StatelessWidget {
  final int current;
  final int max;
  final Color activeColor;

  const CredArcGauge({
    super.key,
    required this.current,
    required this.max,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final targetRatio = (current / max).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetRatio),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, animRatio, _) {
        final animCount = (animRatio * max).round();
        return SizedBox(
          width: 84,
          height: 84,
          child: CustomPaint(
            painter: _CredArcPainter(
              ratio: animRatio,
              activeColor: activeColor,
              trackColor: p.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$animCount',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: p.textPrimary,
                      letterSpacing: -0.8,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'OF $max',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CredArcPainter extends CustomPainter {
  final double ratio;
  final Color activeColor;
  final Color trackColor;

  _CredArcPainter({
    required this.ratio,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    const startAngle = math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    if (ratio > 0) {
      final glowPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * ratio,
        false,
        glowPaint,
      );

      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * ratio,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CredArcPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Smooth CRED Staggered Slide + Fade Entrance wrapper.
class CredStaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;

  const CredStaggeredItem({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<CredStaggeredItem> createState() => _CredStaggeredItemState();
}

class _CredStaggeredItemState extends State<CredStaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 320 + (widget.index * 70)),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
