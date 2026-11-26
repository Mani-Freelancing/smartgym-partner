import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import '../screens/owner_audit_log_screen.dart';
import 'custom_range_bottom_sheet.dart';
import 'owner_analytics_engine.dart';

/// Unified starting CEO Overview hero card fusing live revenue metrics,
/// floor occupancy, timeframe switcher (`1W`, `1M`, `2M`, `Custom`),
/// and multi-type interactive analytics (`Area`, `Bar`, `Mix`).
class OwnerCeoHeroCard extends StatefulWidget {
  final SmartGymState state;

  const OwnerCeoHeroCard({
    super.key,
    required this.state,
  });

  @override
  State<OwnerCeoHeroCard> createState() => _OwnerCeoHeroCardState();
}

class _OwnerCeoHeroCardState extends State<OwnerCeoHeroCard> {
  AnalyticsRange _range = AnalyticsRange.month1;
  AnalyticsChartType _chartType = AnalyticsChartType.area;
  DateTimeRange? _customRange;
  int? _selectedBucketIndex;

  Future<void> _pickCustomRange() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 13)),
          end: now,
        );
    final picked = await showCustomRangeBottomSheet(
      context,
      initialRange: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _customRange = picked;
      _range = AnalyticsRange.custom;
      _selectedBucketIndex = null;
    });
  }

  void _selectRange(AnalyticsRange next) {
    HapticFeedback.selectionClick();
    if (next == AnalyticsRange.custom) {
      _pickCustomRange();
      return;
    }
    setState(() {
      _range = next;
      _selectedBucketIndex = null;
    });
  }

  void _selectChartType(AnalyticsChartType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _chartType = type;
      _selectedBucketIndex = null;
    });
  }

  void _scrubAt(Offset localPos, double width, int bucketCount) {
    if (bucketCount <= 0 || width <= 0) return;
    final ratio = (localPos.dx / width).clamp(0.0, 0.9999);
    final idx = (ratio * bucketCount).floor().clamp(0, bucketCount - 1);
    if (_selectedBucketIndex != idx) {
      setState(() => _selectedBucketIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final gym = widget.state.currentGym;
    final report = OwnerAnalyticsEngine.buildReport(
      state: widget.state,
      range: _range,
      customRange: _customRange,
    );

    final selectedBucket = (_selectedBucketIndex != null &&
            _selectedBucketIndex! < report.buckets.length)
        ? report.buckets[_selectedBucketIndex!]
        : null;

    return CredMetalCard(
      glowColor: p.gold,
      enableShimmer: p.isDark,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Gym CEO Header + Live Floor Occupancy Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${gym.name.toUpperCase()} • CEO OVERVIEW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: p.gold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${widget.state.liveCrowd}/${gym.maxCapacity} IN FLOOR',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: p.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Hero Revenue Headline + Join / Pace Pills
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatInr(
                        selectedBucket?.revenue ?? report.totalPeriodRevenue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedBucket != null
                          ? selectedBucket.detailLabel
                          : '${report.rangeTitle} Collection',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: p.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (selectedBucket == null &&
                        widget.state.totalMonthlyRevenue !=
                            report.totalPeriodRevenue) ...[
                      const SizedBox(height: 2),
                      Text(
                        report.totalCoachPayout > 0
                            ? 'Total Enrolled: ${formatInr(widget.state.totalMonthlyRevenue)} • Net: ${formatInr(report.totalOwnerNetRevenue)}'
                            : 'Total Enrolled: ${formatInr(widget.state.totalMonthlyRevenue)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: p.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MiniStatPill(
                    text:
                        '${selectedBucket?.joins ?? report.periodJoins} join(s)',
                    color: p.cyan,
                  ),
                  if (report.growthPercent != null && selectedBucket == null)
                    _MiniStatPill(
                      text:
                          '${report.growthPercent! >= 0 ? '+' : ''}${report.growthPercent}% pace',
                      color: report.growthPercent! >= 0 ? p.accent : p.danger,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Chart Type Switcher + Range Date Caption
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: p.cardSubtle,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChartTypeChip(
                      key: const ValueKey('chart_type_area'),
                      icon: Icons.show_chart_rounded,
                      label: 'Area',
                      selected: _chartType == AnalyticsChartType.area,
                      onTap: () => _selectChartType(AnalyticsChartType.area),
                    ),
                    _ChartTypeChip(
                      key: const ValueKey('chart_type_bar'),
                      icon: Icons.bar_chart_rounded,
                      label: 'Bar',
                      selected: _chartType == AnalyticsChartType.bar,
                      onTap: () => _selectChartType(AnalyticsChartType.bar),
                    ),
                    _ChartTypeChip(
                      key: const ValueKey('chart_type_mix'),
                      icon: Icons.donut_large_rounded,
                      label: 'Mix',
                      selected: _chartType == AnalyticsChartType.mix,
                      onTap: () => _selectChartType(AnalyticsChartType.mix),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  report.rangeSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: p.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Timeframe Pills (1W / Monthly / 2M / Custom)
          Row(
            children: [
              Expanded(
                child: _RangePill(
                  key: const ValueKey('range_chip_1w'),
                  label: '1 Week',
                  selected: _range == AnalyticsRange.week1,
                  onTap: () => _selectRange(AnalyticsRange.week1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RangePill(
                  key: const ValueKey('range_chip_1m'),
                  label: 'Monthly',
                  selected: _range == AnalyticsRange.month1,
                  onTap: () => _selectRange(AnalyticsRange.month1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RangePill(
                  key: const ValueKey('range_chip_2m'),
                  label: '2 Months',
                  selected: _range == AnalyticsRange.months2,
                  onTap: () => _selectRange(AnalyticsRange.months2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RangePill(
                  key: const ValueKey('range_chip_custom'),
                  label: 'Custom',
                  icon: Icons.date_range_rounded,
                  selected: _range == AnalyticsRange.custom,
                  onTap: () => _selectRange(AnalyticsRange.custom),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Interactive Chart Viewport (Area / Bar / Mix)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_chartType) {
              AnalyticsChartType.area => _buildInteractiveCartesianChart(
                  key: ValueKey('area_${_range.name}_${report.buckets.length}'),
                  report: report,
                  isBar: false,
                  p: p,
                ),
              AnalyticsChartType.bar => _buildInteractiveCartesianChart(
                  key: ValueKey('bar_${_range.name}_${report.buckets.length}'),
                  report: report,
                  isBar: true,
                  p: p,
                ),
              AnalyticsChartType.mix => _MixBreakdownView(
                  key: ValueKey('mix_${_range.name}'),
                  report: report,
                ),
            },
          ),

          // 6. Cash vs Online Split (shown in Area/Bar; Mix already displays it)
          if (_chartType != AnalyticsChartType.mix) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeroSplitChip(
                    label: 'Cash',
                    amount: formatInr(report.cashRevenue),
                    accent: p.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroSplitChip(
                    label: 'Online / UPI',
                    amount: formatInr(report.onlineRevenue),
                    accent: p.gold,
                  ),
                ),
              ],
            ),
          ],

          // 7. Net Owner vs Coach Payout Summary (visible whenever trainers take PT cut)
          if ((selectedBucket?.coachPayout ?? report.coachPayout) > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HeroSplitChip(
                    key: const ValueKey('hero_net_owner_chip'),
                    label: 'Net Owner',
                    amount: formatInr(
                      selectedBucket?.ownerNetRevenue ?? report.ownerNetRevenue,
                    ),
                    accent: p.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroSplitChip(
                    key: const ValueKey('hero_coach_payout_chip'),
                    label: 'Coach Payout',
                    amount: formatInr(
                      selectedBucket?.coachPayout ?? report.coachPayout,
                    ),
                    accent: p.cyan,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractiveCartesianChart({
    required Key key,
    required OwnerAnalyticsReport report,
    required bool isBar,
    required AppPalette p,
  }) {
    final buckets = report.buckets;
    return Column(
      key: key,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) =>
                  _scrubAt(d.localPosition, width, buckets.length),
              onHorizontalDragUpdate: (d) =>
                  _scrubAt(d.localPosition, width, buckets.length),
              child: SizedBox(
                width: double.infinity,
                height: 148,
                child: CustomPaint(
                  painter: isBar
                      ? _GlowingBarChartPainter(
                          buckets: buckets,
                          selectedIndex: _selectedBucketIndex,
                          palette: p,
                        )
                      : _GlowingSplineChartPainter(
                          buckets: buckets,
                          selectedIndex: _selectedBucketIndex,
                          palette: p,
                        ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(buckets.length, (i) {
            final b = buckets[i];
            final active = _selectedBucketIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedBucketIndex = i),
                child: Text(
                  b.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                    color: active ? p.gold : p.textMuted,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _GlowingSplineChartPainter extends CustomPainter {
  final List<AnalyticsBucket> buckets;
  final int? selectedIndex;
  final AppPalette palette;

  const _GlowingSplineChartPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = palette.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFF0F172A).withValues(alpha: 0.07)
      ..strokeWidth = 1;

    const topPad = 14.0;
    const bottomPad = 12.0;
    const horizPad = 14.0;
    final chartH = size.height - topPad - bottomPad;
    final chartW = (size.width - horizPad * 2).clamp(1.0, size.width);

    for (var g = 0; g < 3; g++) {
      final y = topPad + (chartH * (g / 2));
      canvas.drawLine(
        Offset(horizPad, y),
        Offset(size.width - horizPad, y),
        gridPaint,
      );
    }

    if (buckets.isEmpty) return;

    final maxRev = buckets
        .map((b) => b.revenue)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxRev > 0 ? maxRev.toDouble() : 1.0;

    final points = <Offset>[];
    for (var i = 0; i < buckets.length; i++) {
      final x = buckets.length == 1
          ? size.width / 2
          : horizPad + (i / (buckets.length - 1)) * chartW;
      final norm = buckets[i].revenue / safeMax;
      final y = topPad + chartH * (1 - (maxRev == 0 ? 0.0 : norm));
      points.add(Offset(x, y));
    }

    final lineColor = palette.gold;
    final endColor = palette.cyan;

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      final areaPath = Path.from(path)
        ..lineTo(points.last.dx, topPad + chartH)
        ..lineTo(points.first.dx, topPad + chartH)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: palette.isDark ? 0.34 : 0.22),
            endColor.withValues(alpha: palette.isDark ? 0.08 : 0.05),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, topPad, size.width, chartH));
      canvas.drawPath(areaPath, fillPaint);

      final glowPaint = Paint()
        ..color = lineColor.withValues(alpha: palette.isDark ? 0.35 : 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [lineColor, palette.isDark ? AppTheme.champagne : lineColor],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    } else if (points.length == 1) {
      canvas.drawLine(
        Offset(horizPad, points.first.dy),
        Offset(size.width - horizPad, points.first.dy),
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.4,
      );
    }

    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      final isSelected = selectedIndex == i;

      if (isSelected) {
        canvas.drawLine(
          Offset(pt.dx, topPad - 4),
          Offset(pt.dx, topPad + chartH),
          Paint()
            ..color = lineColor.withValues(alpha: 0.45)
            ..strokeWidth = 1.4,
        );
        canvas.drawCircle(
          pt,
          7,
          Paint()..color = lineColor.withValues(alpha: 0.22),
        );
      }

      canvas.drawCircle(
        pt,
        isSelected ? 4.2 : 3.0,
        Paint()..color = lineColor,
      );
      canvas.drawCircle(
        pt,
        1.5,
        Paint()..color = palette.card,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowingSplineChartPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.palette.isDark != palette.isDark;
}

class _GlowingBarChartPainter extends CustomPainter {
  final List<AnalyticsBucket> buckets;
  final int? selectedIndex;
  final AppPalette palette;

  const _GlowingBarChartPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = palette.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFF0F172A).withValues(alpha: 0.07)
      ..strokeWidth = 1;

    const topPad = 14.0;
    const bottomPad = 10.0;
    final chartH = size.height - topPad - bottomPad;

    for (var g = 0; g < 3; g++) {
      final y = topPad + (chartH * (g / 2));
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), gridPaint);
    }

    if (buckets.isEmpty) return;
    final maxRev = buckets
        .map((b) => b.revenue)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxRev > 0 ? maxRev.toDouble() : 1.0;

    final slotW = size.width / buckets.length;
    final barW = (slotW * 0.48).clamp(8.0, 28.0);

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final norm = maxRev == 0 ? 0.0 : (b.revenue / safeMax);
      final h = (chartH * norm).clamp(b.revenue > 0 ? 10.0 : 4.0, chartH);
      final left = i * slotW + (slotW - barW) / 2;
      final top = topPad + chartH - h;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barW, h),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );

      final isSelected = selectedIndex == i;
      final topColor = isSelected ? palette.textPrimary : palette.gold;
      final bottomColor =
          palette.gold.withValues(alpha: isSelected ? 0.55 : 0.30);

      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [topColor, bottomColor],
          ).createShader(rect.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowingBarChartPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.palette.isDark != palette.isDark;
}

class _MixBreakdownView extends StatelessWidget {
  final OwnerAnalyticsReport report;

  const _MixBreakdownView({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final totalChannel = report.cashRevenue + report.onlineRevenue;
    final onlineShare =
        totalChannel == 0 ? 0.0 : report.onlineRevenue / totalChannel;
    final cashShare = totalChannel == 0 ? 0.0 : report.cashRevenue / totalChannel;

    final totalPlan = report.ptRevenue + report.regularRevenue;
    final ptShare = totalPlan == 0 ? 0.0 : report.ptRevenue / totalPlan;
    final regShare = totalPlan == 0 ? 0.0 : report.regularRevenue / totalPlan;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: CustomPaint(
              painter: _GlowingDonutPainter(
                onlineFraction: onlineShare,
                cashFraction: cashShare,
                palette: p,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalChannel == 0
                          ? '0%'
                          : '${(onlineShare * 100).round()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      'UPI / Online',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: p.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BreakdownBarRow(
                  label: 'Online / UPI',
                  amount: formatInr(report.onlineRevenue),
                  fraction: onlineShare,
                  color: p.gold,
                ),
                const SizedBox(height: 8),
                _BreakdownBarRow(
                  label: 'Cash Floor',
                  amount: formatInr(report.cashRevenue),
                  fraction: cashShare,
                  color: p.accent,
                ),
                const SizedBox(height: 8),
                _BreakdownBarRow(
                  label: 'PT VIP Plans',
                  amount: formatInr(report.ptRevenue),
                  fraction: ptShare,
                  color: p.cyan,
                ),
                const SizedBox(height: 8),
                _BreakdownBarRow(
                  label: 'Regular Plans',
                  amount: formatInr(report.regularRevenue),
                  fraction: regShare,
                  color: p.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingDonutPainter extends CustomPainter {
  final double onlineFraction;
  final double cashFraction;
  final AppPalette palette;

  const _GlowingDonutPainter({
    required this.onlineFraction,
    required this.cashFraction,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = palette.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    canvas.drawCircle(center, radius, trackPaint);

    if (onlineFraction <= 0 && cashFraction <= 0) return;

    const startAngle = -math.pi / 2;
    final onlineSweep = (onlineFraction.clamp(0.0, 1.0)) * 2 * math.pi;
    final cashSweep = (cashFraction.clamp(0.0, 1.0)) * 2 * math.pi;

    if (onlineSweep > 0.02) {
      canvas.drawArc(
        rect,
        startAngle,
        onlineSweep,
        false,
        Paint()
          ..color = palette.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
    }

    if (cashSweep > 0.02) {
      canvas.drawArc(
        rect,
        startAngle + onlineSweep,
        cashSweep,
        false,
        Paint()
          ..color = palette.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowingDonutPainter oldDelegate) =>
      oldDelegate.onlineFraction != onlineFraction ||
      oldDelegate.cashFraction != cashFraction ||
      oldDelegate.palette.isDark != palette.isDark;
}

class _BreakdownBarRow extends StatelessWidget {
  final String label;
  final String amount;
  final double fraction;
  final Color color;

  const _BreakdownBarRow({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: p.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              amount,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: fraction.clamp(0.0, 1.0),
            backgroundColor: p.isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ChartTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChartTypeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (p.isDark
                  ? p.gold.withValues(alpha: 0.22)
                  : p.card)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected && !p.isDark ? p.cardShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? p.gold : p.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? p.textPrimary : p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _RangePill({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? p.goldButton : p.cardSubtle,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? p.goldButton : p.border,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 12,
                    color: selected ? p.onAccent : p.gold,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? p.onAccent : p.textSecondary,
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

class _MiniStatPill extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniStatPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _HeroSplitChip extends StatelessWidget {
  final String label;
  final String amount;
  final Color accent;

  const _HeroSplitChip({
    super.key,
    required this.label,
    required this.amount,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: p.isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
