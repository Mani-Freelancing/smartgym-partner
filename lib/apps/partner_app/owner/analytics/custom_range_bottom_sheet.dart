import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Opens a dark-gold animated bottom-sheet calendar range picker with
/// smooth month transitions, quick presets, and a bottom Apply button.
Future<DateTimeRange?> showCustomRangeBottomSheet(
  BuildContext context, {
  DateTimeRange? initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      reverseDuration: Duration(milliseconds: 260),
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (ctx) => AppTheme.ensureOwnerLight(
      ctx,
      child: _CustomRangeCalendarSheet(
        initialRange: initialRange,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    ),
  );
}

class _CustomRangeCalendarSheet extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const _CustomRangeCalendarSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_CustomRangeCalendarSheet> createState() =>
      _CustomRangeCalendarSheetState();
}

class _CustomRangeCalendarSheetState extends State<_CustomRangeCalendarSheet> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _weekHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late DateTime _firstDay;
  late DateTime _lastDay;
  DateTime? _startDate;
  DateTime? _endDate;
  late DateTime _visibleMonth;
  int _monthSlideDirection = 1; // 1 = forward, -1 = backward

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _firstDay = _dayOnly(widget.firstDate);
    _lastDay = _dayOnly(widget.lastDate);
    final initEnd = _dayOnly(widget.initialRange?.end ?? _lastDay);
    final initStart = _dayOnly(
      widget.initialRange?.start ?? _lastDay.subtract(const Duration(days: 13)),
    );
    _startDate = initStart.isBefore(_firstDay) ? _firstDay : initStart;
    _endDate = initEnd.isAfter(_lastDay) ? _lastDay : initEnd;
    _visibleMonth = DateTime(_endDate!.year, _endDate!.month, 1);
  }

  String _formatBadgeDate(DateTime d) =>
      '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

  bool get _canGoPrev {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    final firstMonth = DateTime(_firstDay.year, _firstDay.month, 1);
    return !prev.isBefore(firstMonth);
  }

  bool get _canGoNext {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    final lastMonth = DateTime(_lastDay.year, _lastDay.month, 1);
    return !next.isAfter(lastMonth);
  }

  void _shiftMonth(int delta) {
    if (delta < 0 && !_canGoPrev) return;
    if (delta > 0 && !_canGoNext) return;
    HapticFeedback.selectionClick();
    setState(() {
      _monthSlideDirection = delta >= 0 ? 1 : -1;
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  void _applyPresetDays(int days) {
    HapticFeedback.selectionClick();
    final end = _lastDay;
    var start = end.subtract(Duration(days: days - 1));
    if (start.isBefore(_firstDay)) start = _firstDay;
    setState(() {
      _monthSlideDirection = 1;
      _startDate = start;
      _endDate = end;
      _visibleMonth = DateTime(end.year, end.month, 1);
    });
  }

  void _applyThisMonth() {
    HapticFeedback.selectionClick();
    final end = _lastDay;
    var start = DateTime(end.year, end.month, 1);
    if (start.isBefore(_firstDay)) start = _firstDay;
    setState(() {
      _monthSlideDirection = 1;
      _startDate = start;
      _endDate = end;
      _visibleMonth = DateTime(end.year, end.month, 1);
    });
  }

  void _applyLastMonth() {
    HapticFeedback.selectionClick();
    final prevEnd = DateTime(_lastDay.year, _lastDay.month, 0);
    var prevStart = DateTime(prevEnd.year, prevEnd.month, 1);
    if (prevEnd.isBefore(_firstDay)) return;
    if (prevStart.isBefore(_firstDay)) prevStart = _firstDay;
    setState(() {
      _monthSlideDirection = -1;
      _startDate = prevStart;
      _endDate = prevEnd;
      _visibleMonth = DateTime(prevStart.year, prevStart.month, 1);
    });
  }

  void _onDayTap(DateTime d) {
    if (d.isBefore(_firstDay) || d.isAfter(_lastDay)) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_startDate == null || _endDate != null) {
        _startDate = d;
        _endDate = null;
      } else {
        if (d.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = d;
        } else {
          _endDate = d;
        }
      }
    });
  }

  int get _selectedDayCount {
    final s = _startDate ?? _lastDay;
    final e = _endDate ?? s;
    return e.difference(s).inDays + 1;
  }

  void _submitRange() {
    HapticFeedback.mediumImpact();
    final s = _startDate ?? _lastDay;
    final e = _endDate ?? s;
    Navigator.of(context).pop(DateTimeRange(start: s, end: e));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final maxH = MediaQuery.of(context).size.height * 0.88;
    final effStart = _startDate;
    final effEnd = _endDate ?? _startDate;
    final waitingForEnd = _startDate != null && _endDate == null;

    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('custom_range_sheet'),
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: p.gold.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A)
                  .withValues(alpha: p.isDark ? 0.35 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pinned Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: p.gold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: p.gold,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CUSTOM DATE STUDIO',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: p.gold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Select Start & End Date',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: p.textMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Middle: Readout + Presets + Animated Calendar Grid
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Selected Range Dual-Box Readout
                    Row(
                      children: [
                        Expanded(
                          child: _DateEndpointBox(
                            label: 'FROM',
                            value: effStart != null
                                ? _formatBadgeDate(effStart)
                                : 'Pick date',
                            highlighted: !waitingForEnd,
                            accent: p.gold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: p.gold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Text(
                                '${_selectedDayCount}d',
                                key: ValueKey(_selectedDayCount),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: p.gold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _DateEndpointBox(
                            label: 'TO',
                            value: waitingForEnd
                                ? 'Tap end date'
                                : (effEnd != null
                                    ? _formatBadgeDate(effEnd)
                                    : 'Pick date'),
                            highlighted: waitingForEnd,
                            accent: p.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Smart Presets Row
                    Row(
                      children: [
                        Expanded(
                          child: _PresetChip(
                            key: const ValueKey('custom_range_preset_14d'),
                            label: '14 Days',
                            onTap: () => _applyPresetDays(14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PresetChip(
                            key: const ValueKey('custom_range_preset_this_mo'),
                            label: 'This Month',
                            onTap: _applyThisMonth,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PresetChip(
                            key: const ValueKey('custom_range_preset_last_mo'),
                            label: 'Last Month',
                            onTap: _applyLastMonth,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PresetChip(
                            key: const ValueKey('custom_range_preset_90d'),
                            label: '90 Days',
                            onTap: () => _applyPresetDays(90),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Calendar Surface with subtle spring reveal
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeOutBack,
                      builder: (_, t, calChild) => Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.94 + (0.06 * t),
                          child: calChild,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        decoration: BoxDecoration(
                          color: p.cardSubtle,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: p.border),
                        ),
                        child: Column(
                          children: [
                            // Month Navigation Bar
                            Row(
                              children: [
                                _MonthNavButton(
                                  key: const ValueKey('custom_range_prev_month'),
                                  icon: Icons.chevron_left_rounded,
                                  enabled: _canGoPrev,
                                  onTap: () => _shiftMonth(-1),
                                ),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 260),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    transitionBuilder: (child, anim) {
                                      final offsetTween = Tween<Offset>(
                                        begin: Offset(
                                          0.28 * _monthSlideDirection,
                                          0,
                                        ),
                                        end: Offset.zero,
                                      );
                                      return SlideTransition(
                                        position: anim.drive(offsetTween),
                                        child: FadeTransition(
                                          opacity: anim,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                                      key: ValueKey(
                                        '${_visibleMonth.year}-${_visibleMonth.month}',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: p.textPrimary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                _MonthNavButton(
                                  key: const ValueKey('custom_range_next_month'),
                                  icon: Icons.chevron_right_rounded,
                                  enabled: _canGoNext,
                                  onTap: () => _shiftMonth(1),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Weekday Headers
                            Row(
                              children: _weekHeaders
                                  .map(
                                    (w) => Expanded(
                                      child: Text(
                                        w,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: p.textMuted,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 6),

                            // Animated Month Grid
                            AnimatedSize(
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) {
                                  final offsetTween = Tween<Offset>(
                                    begin: Offset(
                                      0.18 * _monthSlideDirection,
                                      0,
                                    ),
                                    end: Offset.zero,
                                  );
                                  return SlideTransition(
                                    position: anim.drive(offsetTween),
                                    child: FadeTransition(
                                      opacity: anim,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildMonthGrid(
                                  key: ValueKey(
                                    'grid_${_visibleMonth.year}_${_visibleMonth.month}',
                                  ),
                                  effStart: effStart,
                                  effEnd: effEnd,
                                  p: p,
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

            // Pinned Bottom Action Bar with Apply Button
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: p.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        key: const ValueKey('custom_range_apply_btn'),
                        onPressed: _submitRange,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.goldButton,
                          foregroundColor: p.onAccent,
                          elevation: 4,
                          shadowColor: p.goldButton.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 19),
                        label: Text(
                          'Apply ($_selectedDayCount ${_selectedDayCount == 1 ? 'Day' : 'Days'})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
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

  Widget _buildMonthGrid({
    required Key key,
    required DateTime? effStart,
    required DateTime? effEnd,
    required AppPalette p,
  }) {
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = _visibleMonth.weekday - 1;
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;
    final rowCount = totalCells ~/ 7;

    return Column(
      key: key,
      children: List.generate(rowCount, (rowIdx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: List.generate(7, (colIdx) {
              final cellIndex = rowIdx * 7 + colIdx;
              final dayNum = cellIndex - leadingBlanks + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 38));
              }

              final d = DateTime(
                _visibleMonth.year,
                _visibleMonth.month,
                dayNum,
              );
              final disabled = d.isBefore(_firstDay) || d.isAfter(_lastDay);
              final isToday = _sameDay(d, _lastDay);
              final isStart = effStart != null && _sameDay(d, effStart);
              final isEnd = effEnd != null && _sameDay(d, effEnd);
              final inRange = effStart != null &&
                  effEnd != null &&
                  !d.isBefore(effStart) &&
                  !d.isAfter(effEnd);
              final showTrack = inRange && !(isStart && isEnd);

              BorderRadius? trackRadius;
              if (showTrack) {
                final roundLeft = isStart || colIdx == 0;
                final roundRight = isEnd || colIdx == 6;
                trackRadius = BorderRadius.horizontal(
                  left: Radius.circular(roundLeft ? 19 : 0),
                  right: Radius.circular(roundRight ? 19 : 0),
                );
              }

              return Expanded(
                child: GestureDetector(
                  key: ValueKey(
                    'cal_day_${d.year}_${d.month}_${d.day}',
                  ),
                  onTap: disabled ? null : () => _onDayTap(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: 38,
                    decoration: showTrack
                        ? BoxDecoration(
                            color: p.gold.withValues(alpha: p.isDark ? 0.18 : 0.14),
                            borderRadius: trackRadius,
                          )
                        : null,
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        scale: (isStart || isEnd) ? 1.06 : 1.0,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isStart || isEnd) ? p.goldButton : null,
                            border: isToday && !(isStart || isEnd)
                                ? Border.all(
                                    color: p.gold.withValues(alpha: 0.7),
                                    width: 1.2,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: (isStart || isEnd)
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: disabled
                                      ? p.textMuted.withValues(alpha: 0.4)
                                      : ((isStart || isEnd)
                                          ? p.onAccent
                                          : (inRange
                                              ? p.textPrimary
                                              : p.textSecondary)),
                                ),
                              ),
                              if (isToday && !(isStart || isEnd))
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: p.gold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _DateEndpointBox extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;
  final Color accent;

  const _DateEndpointBox({
    required this.label,
    required this.value,
    required this.highlighted,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted ? accent.withValues(alpha: 0.1) : p.cardSubtle,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: highlighted ? accent.withValues(alpha: 0.55) : p.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: highlighted ? accent : p.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: highlighted ? p.textPrimary : p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.cardSubtle,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: p.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MonthNavButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? p.gold : p.textMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
