import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import '../screens/owner_audit_log_screen.dart';
import 'custom_range_bottom_sheet.dart';
import 'owner_analytics_engine.dart';

String _compactRupee(int amount) {
  if (amount >= 100000) {
    final lakhs = amount / 100000.0;
    return '₹${lakhs.toStringAsFixed(lakhs >= 10 ? 1 : 2)}L';
  }
  if (amount >= 1000) {
    final k = amount / 1000.0;
    return '₹${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  return '₹$amount';
}

double _niceAxisMax(int maxRev) {
  if (maxRev <= 0) return 15000.0; // Clean 0 / 5k / 10k / 15k ticks
  const steps = <double>[
    3000,
    6000,
    9000,
    15000,
    30000,
    60000,
    90000,
    150000,
    300000,
    600000,
    900000,
    1500000,
    3000000,
  ];
  for (final s in steps) {
    if (maxRev <= s) return s;
  }
  return ((maxRev / 300000.0).ceil() * 300000).toDouble();
}

String _compactAxisValue(double value) {
  if (value <= 0) return '0';
  if (value >= 100000) {
    final l = value / 100000.0;
    return '${l == l.roundToDouble() ? l.toInt() : l.toStringAsFixed(1)}L';
  }
  if (value >= 1000) {
    final k = value / 1000.0;
    return '${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)}k';
  }
  return '${value.round()}';
}

/// Compact Dark-Gold "Total Collections" banner at top of CEO Dashboard
/// (matches reference: ~150px sleek dark-gold summary with rising golden bar/line skyline).
class OwnerCompactCollectionsBanner extends StatelessWidget {
  final SmartGymState state;
  final OwnerAnalyticsReport report;
  final AnalyticsBucket? selectedBucket;
  final VoidCallback onPickCustomRange;
  final bool embedded;

  const OwnerCompactCollectionsBanner({
    super.key,
    required this.state,
    required this.report,
    required this.selectedBucket,
    required this.onPickCustomRange,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final gym = state.currentGym;
    const warmBronze = Color(0xFFB4690E);
    const darkInk = Color(0xFF1C1917);
    final displayRevenue =
        selectedBucket?.revenue ?? report.totalPeriodRevenue;
    final coachCut = selectedBucket?.coachPayout ?? report.coachPayout;
    final ownerNet =
        selectedBucket?.ownerNetRevenue ?? report.ownerNetRevenue;

    final innerStack = Stack(
      children: [
        // Subtle Gold-Leaf Olympic Plate & Pro Dumbbell Watermark
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: const _GoldenGymStrengthCrestPainter(
                goldColor: Color(0xFFC88214),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${gym.name.toUpperCase()} • CEO OVERVIEW',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: warmBronze,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedBucket != null
                              ? selectedBucket!.detailLabel
                              : '${report.rangeTitle} Collection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5C5243),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onPickCustomRange,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE8D3A7),
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        size: 17,
                        color: warmBronze,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      formatInr(displayRevenue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: darkInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (report.growthPercent != null && selectedBucket == null)
                    Text(
                      '${report.growthPercent! >= 0 ? '▲ +' : '▼ '}${report.growthPercent}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: report.growthPercent! >= 0
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFEBD7B0)),
                      ),
                      child: Text(
                        '${selectedBucket?.joins ?? report.periodJoins} join(s)',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: warmBronze,
                        ),
                      ),
                    ),
                ],
              ),
              if (selectedBucket == null &&
                  state.totalMonthlyRevenue != report.totalPeriodRevenue) ...[
                const SizedBox(height: 2),
                Text(
                  report.totalCoachPayout > 0
                      ? 'Total Enrolled: ${formatInr(state.totalMonthlyRevenue)} • Net: ${formatInr(report.totalOwnerNetRevenue)}'
                      : 'Total Enrolled: ${formatInr(state.totalMonthlyRevenue)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: warmBronze,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Compact inline Cash / Online UPI summary chips
              Row(
                children: [
                  Expanded(
                    child: _BannerMiniSplit(
                      label: 'Cash',
                      amount: formatInr(report.cashRevenue),
                      valueColor: darkInk,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BannerMiniSplit(
                      label: 'Online / UPI',
                      amount: formatInr(report.onlineRevenue),
                      valueColor: warmBronze,
                    ),
                  ),
                ],
              ),
              if (coachCut > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _BannerMiniSplit(
                        key: const ValueKey('hero_net_owner_chip'),
                        label: 'Net Owner',
                        amount: formatInr(ownerNet),
                        valueColor: warmBronze,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BannerMiniSplit(
                        key: const ValueKey('hero_coach_payout_chip'),
                        label: 'Coach Payout',
                        amount: formatInr(coachCut),
                        valueColor: darkInk,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );

    const bannerGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFECC2),
        Color(0xFFFFF8E8),
      ],
    );

    if (embedded) {
      return innerStack;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: bannerGradient,
        border: Border.all(
          color: const Color(0xFFE8D3A7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B2111).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: innerStack,
      ),
    );
  }
}

class _BannerMiniSplit extends StatelessWidget {
  final String label;
  final String amount;
  final Color valueColor;

  const _BannerMiniSplit({
    super.key,
    required this.label,
    required this.amount,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAD7B3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B5E4C),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldenGymStrengthCrestPainter extends CustomPainter {
  final Color goldColor;

  const _GoldenGymStrengthCrestPainter({required this.goldColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Faint engraved Olympic Weight Plate watermark on far right (no uneven radial glow)
    final plateCenter = Offset(size.width - 24, size.height * 0.56);
    const outerR = 58.0;
    const midR = 41.0;
    const hubR = 14.0;

    canvas.drawCircle(
      plateCenter,
      outerR,
      Paint()
        ..color = goldColor.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      plateCenter,
      midR,
      Paint()
        ..color = goldColor.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 6 faint radial Olympic plate spokes
    final spokePaint = Paint()
      ..color = goldColor.withValues(alpha: 0.06)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) + 0.25;
      final p1 = Offset(
        plateCenter.dx + math.cos(angle) * (hubR + 4),
        plateCenter.dy + math.sin(angle) * (hubR + 4),
      );
      final p2 = Offset(
        plateCenter.dx + math.cos(angle) * (midR - 3),
        plateCenter.dy + math.sin(angle) * (midR - 3),
      );
      canvas.drawLine(p1, p2, spokePaint);
    }

    // Center Olympic 50mm collar hub
    canvas.drawCircle(
      plateCenter,
      hubR,
      Paint()
        ..color = goldColor.withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Faint etched Pro Dumbbell watermark (-24 deg)
    final dbCenter = Offset(size.width - 78, size.height * 0.52);
    canvas.save();
    canvas.translate(dbCenter.dx, dbCenter.dy);
    canvas.rotate(-0.42);

    final fillPaint = Paint()..color = goldColor.withValues(alpha: 0.06);
    final strokePaint = Paint()
      ..color = goldColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    void drawPlateRect(Rect r, double radius) {
      final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
      canvas.drawRRect(rr, fillPaint);
      canvas.drawRRect(rr, strokePaint);
    }

    // Knurled center handle bar
    drawPlateRect(const Rect.fromLTWH(-20, -4.5, 40, 9), 3);

    final knurlPaint = Paint()
      ..color = const Color(0xFF1F1C18).withValues(alpha: 0.14)
      ..strokeWidth = 0.9;
    for (double kx = -12; kx <= 12; kx += 4.5) {
      canvas.drawLine(Offset(kx, -3.5), Offset(kx - 2, 3.5), knurlPaint);
    }

    // Left stepped weight stack
    drawPlateRect(const Rect.fromLTWH(-31, -20, 10, 40), 3.5);
    drawPlateRect(const Rect.fromLTWH(-42, -15, 9, 30), 3.0);
    drawPlateRect(const Rect.fromLTWH(-47, -5, 4, 10), 2.0);

    // Right stepped weight stack
    drawPlateRect(const Rect.fromLTWH(21, -20, 10, 40), 3.5);
    drawPlateRect(const Rect.fromLTWH(33, -15, 9, 30), 3.0);
    drawPlateRect(const Rect.fromLTWH(43, -5, 4, 10), 2.0);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoldenGymStrengthCrestPainter oldDelegate) =>
      oldDelegate.goldColor != goldColor;
}

/// Pure WHITE "Revenue Trend" interactive chart card (matches reference image).
class OwnerWhiteRevenueTrendCard extends StatelessWidget {
  final OwnerAnalyticsReport report;
  final AnalyticsRange range;
  final AnalyticsChartType chartType;
  final int? selectedBucketIndex;
  final ValueChanged<AnalyticsRange> onSelectRange;
  final ValueChanged<AnalyticsChartType> onSelectChartType;
  final ValueChanged<int?> onSelectBucket;
  final bool embedded;

  const OwnerWhiteRevenueTrendCard({
    super.key,
    required this.report,
    required this.range,
    required this.chartType,
    required this.selectedBucketIndex,
    required this.onSelectRange,
    required this.onSelectChartType,
    required this.onSelectBucket,
    this.embedded = false,
  });

  void _scrubAt(Offset localPos, double width, int bucketCount) {
    if (bucketCount <= 0 || width <= 0) return;
    const leftAxisW = 34.0;
    final adjX = (localPos.dx - leftAxisW).clamp(0.0, width - leftAxisW);
    final usableW = (width - leftAxisW).clamp(1.0, width);
    final ratio = (adjX / usableW).clamp(0.0, 0.9999);
    final idx = (ratio * bucketCount).floor().clamp(0, bucketCount - 1);
    if (selectedBucketIndex != idx) {
      onSelectBucket(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final buckets = report.buckets;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: embedded
          ? null
          : BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.border),
              boxShadow: p.cardShadow,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Revenue Trend" + Chart Type Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Revenue Trend',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LightChartTypeChip(
                      key: const ValueKey('chart_type_area'),
                      icon: Icons.show_chart_rounded,
                      label: 'Area',
                      selected: chartType == AnalyticsChartType.area,
                      onTap: () => onSelectChartType(AnalyticsChartType.area),
                    ),
                    _LightChartTypeChip(
                      key: const ValueKey('chart_type_bar'),
                      icon: Icons.bar_chart_rounded,
                      label: 'Bar',
                      selected: chartType == AnalyticsChartType.bar,
                      onTap: () => onSelectChartType(AnalyticsChartType.bar),
                    ),
                    _LightChartTypeChip(
                      key: const ValueKey('chart_type_mix'),
                      icon: Icons.donut_large_rounded,
                      label: 'Mix',
                      selected: chartType == AnalyticsChartType.mix,
                      onTap: () => onSelectChartType(AnalyticsChartType.mix),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Timeframe Range Pills (1W / Monthly / 2M / Custom)
          Row(
            children: [
              Expanded(
                child: _LightRangePill(
                  key: const ValueKey('range_chip_1w'),
                  label: '1 Week',
                  selected: range == AnalyticsRange.week1,
                  onTap: () => onSelectRange(AnalyticsRange.week1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LightRangePill(
                  key: const ValueKey('range_chip_1m'),
                  label: 'Monthly',
                  selected: range == AnalyticsRange.month1,
                  onTap: () => onSelectRange(AnalyticsRange.month1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LightRangePill(
                  key: const ValueKey('range_chip_2m'),
                  label: '2 Months',
                  selected: range == AnalyticsRange.months2,
                  onTap: () => onSelectRange(AnalyticsRange.months2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LightRangePill(
                  key: const ValueKey('range_chip_custom'),
                  label: 'Custom',
                  icon: Icons.keyboard_arrow_down_rounded,
                  selected: range == AnalyticsRange.custom,
                  onTap: () => onSelectRange(AnalyticsRange.custom),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Interactive White Chart Viewport
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (chartType) {
              AnalyticsChartType.area => _buildWhiteCartesian(
                  key: ValueKey('area_${range.name}_${buckets.length}'),
                  buckets: buckets,
                  isBar: false,
                  p: p,
                ),
              AnalyticsChartType.bar => _buildWhiteCartesian(
                  key: ValueKey('bar_${range.name}_${buckets.length}'),
                  buckets: buckets,
                  isBar: true,
                  p: p,
                ),
              AnalyticsChartType.mix => _WhiteMixBreakdownView(
                  key: ValueKey('mix_${range.name}'),
                  report: report,
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteCartesian({
    required Key key,
    required List<AnalyticsBucket> buckets,
    required bool isBar,
    required AppPalette p,
  }) {
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
                height: 122,
                child: CustomPaint(
                  painter: isBar
                      ? _WhiteGoldBarPainter(
                          buckets: buckets,
                          selectedIndex: selectedBucketIndex,
                          palette: p,
                        )
                      : _WhiteGoldLinePainter(
                          buckets: buckets,
                          selectedIndex: selectedBucketIndex,
                          palette: p,
                        ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Row(
            children: List.generate(buckets.length, (i) {
              final b = buckets[i];
              final active = selectedBucketIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelectBucket(i),
                  child: Text(
                    b.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                      color: active ? p.gold : p.textMuted,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _WhiteGoldLinePainter extends CustomPainter {
  final List<AnalyticsBucket> buckets;
  final int? selectedIndex;
  final AppPalette palette;

  const _WhiteGoldLinePainter({
    required this.buckets,
    required this.selectedIndex,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisW = 32.0;
    const topPad = 26.0;
    const bottomPad = 10.0;
    const rightPad = 10.0;
    final chartH = size.height - topPad - bottomPad;
    final chartW = (size.width - leftAxisW - rightPad).clamp(1.0, size.width);

    final maxRev = buckets
        .map((b) => b.revenue)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final niceMax = _niceAxisMax(maxRev);

    final gridPaint = Paint()
      ..color = const Color(0xFFF0EAE0)
      ..strokeWidth = 1;

    // 4 horizontal gridlines + Y-axis labels (like 0L / 1L / 2L / 3L in reference)
    for (var g = 0; g <= 3; g++) {
      final frac = g / 3.0;
      final y = topPad + chartH * (1 - frac);
      canvas.drawLine(
        Offset(leftAxisW, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      final label = _compactAxisValue(niceMax * frac);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: palette.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftAxisW - 4);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (buckets.isEmpty) return;

    final points = <Offset>[];
    for (var i = 0; i < buckets.length; i++) {
      final x = buckets.length == 1
          ? leftAxisW + chartW / 2
          : leftAxisW + (i / (buckets.length - 1)) * chartW;
      final norm = maxRev == 0 ? 0.0 : (buckets[i].revenue / niceMax);
      final y = topPad + chartH * (1 - norm);
      points.add(Offset(x, y));

      // Subtle vertical gridline
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + chartH),
        Paint()
          ..color = const Color(0xFFF5F0E6)
          ..strokeWidth = 0.8,
      );
    }

    const goldLine = Color(0xFFE59A23);

    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      final areaPath = Path.from(linePath)
        ..lineTo(points.last.dx, topPad + chartH)
        ..lineTo(points.first.dx, topPad + chartH)
        ..close();

      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              goldLine.withValues(alpha: 0.24),
              goldLine.withValues(alpha: 0.04),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(leftAxisW, topPad, chartW, chartH)),
      );

      canvas.drawPath(
        linePath,
        Paint()
          ..color = goldLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    // Determine callout target (selected index, or highest/latest non-zero point)
    int badgeIdx = selectedIndex ?? (points.length - 1);
    if (selectedIndex == null && maxRev > 0) {
      for (var i = buckets.length - 1; i >= 0; i--) {
        if (buckets[i].revenue == maxRev) {
          badgeIdx = i;
          break;
        }
      }
    }

    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      final isHighlighted = i == badgeIdx;
      canvas.drawCircle(
        pt,
        isHighlighted ? 5.2 : 3.8,
        Paint()..color = goldLine,
      );
      canvas.drawCircle(
        pt,
        isHighlighted ? 2.2 : 1.6,
        Paint()..color = Colors.white,
      );
    }

    // Floating Golden Callout Pill (shown only when > 0 or user actively tapped a point)
    if (badgeIdx >= 0 &&
        badgeIdx < points.length &&
        (buckets[badgeIdx].revenue > 0 || selectedIndex != null)) {
      final pt = points[badgeIdx];
      final badgeText = _compactRupee(buckets[badgeIdx].revenue);
      final tp = TextPainter(
        text: TextSpan(
          text: badgeText,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F1A12),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final pillW = tp.width + 14;
      final pillH = tp.height + 6;
      final clampedLeft =
          (pt.dx - pillW / 2).clamp(leftAxisW, size.width - pillW);
      final pillTop = math.max(0.0, pt.dy - pillH - 8);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(clampedLeft, pillTop, pillW, pillH),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = const Color(0xFFF4B63F),
      );
      tp.paint(canvas, Offset(clampedLeft + 7, pillTop + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteGoldLinePainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _WhiteGoldBarPainter extends CustomPainter {
  final List<AnalyticsBucket> buckets;
  final int? selectedIndex;
  final AppPalette palette;

  const _WhiteGoldBarPainter({
    required this.buckets,
    required this.selectedIndex,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxisW = 32.0;
    const topPad = 16.0;
    const bottomPad = 10.0;
    final chartH = size.height - topPad - bottomPad;
    final chartW = (size.width - leftAxisW).clamp(1.0, size.width);

    final maxRev = buckets
        .map((b) => b.revenue)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final niceMax = _niceAxisMax(maxRev);

    for (var g = 0; g <= 3; g++) {
      final frac = g / 3.0;
      final y = topPad + chartH * (1 - frac);
      canvas.drawLine(
        Offset(leftAxisW, y),
        Offset(size.width, y),
        Paint()..color = const Color(0xFFF0EAE0),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _compactAxisValue(niceMax * frac),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: palette.textMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftAxisW - 4);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    if (buckets.isEmpty) return;
    final slotW = chartW / buckets.length;
    final barW = (slotW * 0.50).clamp(8.0, 26.0);

    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final norm = maxRev == 0 ? 0.0 : (b.revenue / niceMax);
      final h = (chartH * norm).clamp(b.revenue > 0 ? 8.0 : 4.0, chartH);
      final left = leftAxisW + i * slotW + (slotW - barW) / 2;
      final top = topPad + chartH - h;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, top, barW, h),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      final isSelected = selectedIndex == i;
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isSelected
                ? [const Color(0xFFB87314), const Color(0xFFE59A23)]
                : [
                    const Color(0xFFE59A23),
                    const Color(0xFFF6D089),
                  ],
          ).createShader(rect.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteGoldBarPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.selectedIndex != selectedIndex;
}

class _WhiteMixBreakdownView extends StatelessWidget {
  final OwnerAnalyticsReport report;

  const _WhiteMixBreakdownView({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final totalChannel = report.cashRevenue + report.onlineRevenue;
    final onlineShare =
        totalChannel == 0 ? 0.0 : report.onlineRevenue / totalChannel;
    final cashShare =
        totalChannel == 0 ? 0.0 : report.cashRevenue / totalChannel;
    final totalPlan = report.ptRevenue + report.regularRevenue;
    final ptShare = totalPlan == 0 ? 0.0 : report.ptRevenue / totalPlan;
    final regShare = totalPlan == 0 ? 0.0 : report.regularRevenue / totalPlan;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: CustomPaint(
              painter: _WhiteDonutPainter(
                onlineFraction: onlineShare,
                cashFraction: cashShare,
                goldColor: p.gold,
                cashColor: p.accent,
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
              children: [
                _LightMixBarRow(
                  label: 'Online / UPI',
                  amount: formatInr(report.onlineRevenue),
                  fraction: onlineShare,
                  color: p.gold,
                ),
                const SizedBox(height: 8),
                _LightMixBarRow(
                  label: 'Cash Floor',
                  amount: formatInr(report.cashRevenue),
                  fraction: cashShare,
                  color: p.accent,
                ),
                const SizedBox(height: 8),
                _LightMixBarRow(
                  label: 'PT VIP Plans',
                  amount: formatInr(report.ptRevenue),
                  fraction: ptShare,
                  color: p.cyan,
                ),
                const SizedBox(height: 8),
                _LightMixBarRow(
                  label: 'Regular Plans',
                  amount: formatInr(report.regularRevenue),
                  fraction: regShare,
                  color: p.amber,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteDonutPainter extends CustomPainter {
  final double onlineFraction;
  final double cashFraction;
  final Color goldColor;
  final Color cashColor;

  const _WhiteDonutPainter({
    required this.onlineFraction,
    required this.cashFraction,
    required this.goldColor,
    required this.cashColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFF3ECE0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11,
    );

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
          ..color = goldColor
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
          ..color = cashColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteDonutPainter oldDelegate) =>
      oldDelegate.onlineFraction != onlineFraction ||
      oldDelegate.cashFraction != cashFraction;
}

class _LightMixBarRow extends StatelessWidget {
  final String label;
  final String amount;
  final double fraction;
  final Color color;

  const _LightMixBarRow({
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
                  fontWeight: FontWeight.w700,
                  color: p.textSecondary,
                ),
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 4.5,
            value: fraction.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF3ECE0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _LightChartTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LightChartTypeChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected ? p.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? p.cardShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12.5,
              color: selected ? p.gold : p.textMuted,
            ),
            const SizedBox(width: 3.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
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

class _LightRangePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _LightRangePill({
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6.5),
        decoration: BoxDecoration(
          color: selected ? p.cardSubtle : p.bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? p.gold : p.border,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: selected ? p.gold : p.textSecondary,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    icon,
                    size: 13,
                    color: selected ? p.gold : p.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standalone backwards-compatible wrapper if rendered outside OwnerRevenueScreen.
class OwnerCeoHeroCard extends StatefulWidget {
  final SmartGymState state;

  const OwnerCeoHeroCard({super.key, required this.state});

  @override
  State<OwnerCeoHeroCard> createState() => _OwnerCeoHeroCardState();
}

class _OwnerCeoHeroCardState extends State<OwnerCeoHeroCard> {
  AnalyticsRange _range = AnalyticsRange.month1;
  AnalyticsChartType _chartType = AnalyticsChartType.area;
  DateTimeRange? _customRange;
  int? _selectedBucketIndex;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showCustomRangeBottomSheet(
      context,
      initialRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 13)),
            end: now,
          ),
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

  @override
  Widget build(BuildContext context) {
    final report = OwnerAnalyticsEngine.buildReport(
      state: widget.state,
      range: _range,
      customRange: _customRange,
    );
    final selectedBucket = (_selectedBucketIndex != null &&
            _selectedBucketIndex! < report.buckets.length)
        ? report.buckets[_selectedBucketIndex!]
        : null;

    final p = AppPalette.of(context);

    // Clean warm sunlit gold -> soft cream -> pure white gradient (zero muddy dark shade)
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFECC2),
            Color(0xFFFFF6E0),
            Color(0xFFFFFDF7),
            Color(0xFFFFFFFF),
          ],
          stops: [0.0, 0.28, 0.54, 1.0],
        ),
        border: Border.all(color: const Color(0xFFEBD7B0)),
        boxShadow: p.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OwnerCompactCollectionsBanner(
              state: widget.state,
              report: report,
              selectedBucket: selectedBucket,
              onPickCustomRange: _pickCustomRange,
              embedded: true,
            ),
            OwnerWhiteRevenueTrendCard(
              report: report,
              range: _range,
              chartType: _chartType,
              selectedBucketIndex: _selectedBucketIndex,
              embedded: true,
              onSelectRange: (next) {
                if (next == AnalyticsRange.custom) {
                  _pickCustomRange();
                } else {
                  setState(() {
                    _range = next;
                    _selectedBucketIndex = null;
                  });
                }
              },
              onSelectChartType: (t) => setState(() {
                _chartType = t;
                _selectedBucketIndex = null;
              }),
              onSelectBucket: (idx) =>
                  setState(() => _selectedBucketIndex = idx),
            ),
          ],
        ),
      ),
    );
  }
}
