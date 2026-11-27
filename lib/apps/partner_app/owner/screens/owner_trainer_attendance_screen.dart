import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../domain/models/trainer_attendance_log.dart';
import '../../../../domain/models/trainer_profile.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import '../analytics/custom_range_bottom_sheet.dart';

class OwnerTrainerAttendanceScreen extends StatefulWidget {
  final String? initialTrainerId;
  final String? initialTrainerName;

  const OwnerTrainerAttendanceScreen({
    super.key,
    this.initialTrainerId,
    this.initialTrainerName,
  });

  @override
  State<OwnerTrainerAttendanceScreen> createState() =>
      _OwnerTrainerAttendanceScreenState();
}

enum _DateRangeFilter { all, today, last7Days, custom }

class _OwnerTrainerAttendanceScreenState
    extends State<OwnerTrainerAttendanceScreen> {
  static const List<String> _shortMonths = [
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

  String? _selectedTrainerId;
  String? _selectedTrainerName;
  _DateRangeFilter _range = _DateRangeFilter.all;
  DateTimeRange? _pickedRange;

  @override
  void initState() {
    super.initState();
    _selectedTrainerId = widget.initialTrainerId;
    _selectedTrainerName = widget.initialTrainerName;
  }

  String _formatPickedLabel(DateTimeRange r) {
    final s = r.start;
    final e = r.end;
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return '${s.day} ${_shortMonths[s.month - 1]} ${s.year}';
    }
    return '${s.day} ${_shortMonths[s.month - 1]} – ${e.day} ${_shortMonths[e.month - 1]}';
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showCustomRangeBottomSheet(
      context,
      initialRange: _pickedRange ?? DateTimeRange(start: today, end: today),
      firstDate: DateTime(2024),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedRange = picked;
        _range = _DateRangeFilter.custom;
      });
    }
  }

  List<TrainerAttendanceLog> _combinedLogs(SmartGymState state) {
    final now = DateTime.now();
    final todayKey = TrainerAttendanceLog.dateKeyFor(now);
    final logs = List<TrainerAttendanceLog>.from(state.trainerAttendanceLogs);

    for (final t in state.trainers) {
      if (!t.isOnDutyToday) continue;
      final alreadyLoggedToday = logs.any(
        (l) =>
            l.dateKey == todayKey &&
            l.isDutyCheckIn &&
            ((l.trainerId.isNotEmpty && l.trainerId == t.id) ||
                l.trainerName.trim().toLowerCase() ==
                    t.name.trim().toLowerCase()),
      );
      if (!alreadyLoggedToday) {
        final label = t.hasValidCheckInTime ? t.displayCheckInTime : 'Today';
        logs.add(
          TrainerAttendanceLog(
            id: 'live_${todayKey}_${t.id}',
            trainerId: t.id,
            trainerName: t.name,
            trainerPhone: t.phone,
            dateKey: todayKey,
            timeLabel: label,
            eventType: 'duty_checkin',
            timestampMs: now.millisecondsSinceEpoch,
          ),
        );
      }
    }

    logs.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return logs;
  }

  bool _matchesTrainer(TrainerAttendanceLog log) {
    final selId = _selectedTrainerId;
    final selName = _selectedTrainerName;
    if (selId == null && selName == null) return true;
    if (selId != null && log.trainerId == selId) return true;
    if (selName != null &&
        log.trainerName.trim().toLowerCase() == selName.trim().toLowerCase()) {
      return true;
    }
    return false;
  }

  bool _matchesDate(TrainerAttendanceLog log, DateTime now) {
    switch (_range) {
      case _DateRangeFilter.all:
        return true;
      case _DateRangeFilter.today:
        return log.dateKey == TrainerAttendanceLog.dateKeyFor(now);
      case _DateRangeFilter.last7Days:
        final cutoff = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        final cutoffKey = TrainerAttendanceLog.dateKeyFor(cutoff);
        return log.dateKey.compareTo(cutoffKey) >= 0;
      case _DateRangeFilter.custom:
        if (_pickedRange == null) return true;
        final startKey = TrainerAttendanceLog.dateKeyFor(_pickedRange!.start);
        final endKey = TrainerAttendanceLog.dateKeyFor(_pickedRange!.end);
        return log.dateKey.compareTo(startKey) >= 0 &&
            log.dateKey.compareTo(endKey) <= 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.ensureOwnerLight(
      context,
      child: Builder(
        builder: (context) {
          final p = AppPalette.of(context);
          return Scaffold(
            backgroundColor: p.bg,
            appBar: AppBar(
              backgroundColor: p.bg,
              foregroundColor: p.textPrimary,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Trainer Login History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: p.textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  key: const ValueKey('attendance_date_picker_btn'),
                  tooltip: 'Filter by date',
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    color: p.gold,
                  ),
                  onPressed: _pickDate,
                ),
              ],
            ),
            body: BlocBuilder<SmartGymBloc, SmartGymState>(
              builder: (context, state) {
                final now = DateTime.now();
                final allLogs = _combinedLogs(state);
                final filtered = allLogs
                    .where((l) => _matchesTrainer(l) && _matchesDate(l, now))
                    .toList();

                final grouped = <String, List<TrainerAttendanceLog>>{};
                for (final log in filtered) {
                  grouped.putIfAbsent(log.dateKey, () => []).add(log);
                }
                final sortedDates = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                  children: [
                    Text(
                      'NEWEST TO OLDEST CHECK-IN & LOGIN LOGS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 1. Date Range Selector — Warm Golden-Amber Segmented Track
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: p.gold,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'DATE FILTER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: p.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: p.cardSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _DateSegmentPill(
                              label: 'All Dates',
                              selected: _range == _DateRangeFilter.all,
                              onTap: () => setState(() {
                                _range = _DateRangeFilter.all;
                                _pickedRange = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _DateSegmentPill(
                              label: 'Today',
                              selected: _range == _DateRangeFilter.today,
                              onTap: () => setState(() {
                                _range = _DateRangeFilter.today;
                              }),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _DateSegmentPill(
                              label: 'Last 7 Days',
                              selected: _range == _DateRangeFilter.last7Days,
                              onTap: () => setState(() {
                                _range = _DateRangeFilter.last7Days;
                              }),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _DateSegmentPill(
                              key: const ValueKey('attendance_pick_date_pill'),
                              label: _range == _DateRangeFilter.custom &&
                                      _pickedRange != null
                                  ? _formatPickedLabel(_pickedRange!)
                                  : 'Pick Date',
                              icon: Icons.event_rounded,
                              selected: _range == _DateRangeFilter.custom,
                              onTap: _pickDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.trainers.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      // 2. Trainer Filter — Distinct Deep Teal-Emerald Coach Pills
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 13,
                            color: p.isDark
                                ? p.cyan
                                : const Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            'TRAINER FILTER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: p.isDark
                                  ? p.cyan
                                  : const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _TrainerFilterPill(
                              label: 'All Trainers',
                              isAllOption: true,
                              selected: _selectedTrainerId == null &&
                                  _selectedTrainerName == null,
                              onTap: () => setState(() {
                                _selectedTrainerId = null;
                                _selectedTrainerName = null;
                              }),
                            ),
                            ...state.trainers.map((TrainerProfile t) {
                              final selected = (_selectedTrainerId != null &&
                                      _selectedTrainerId == t.id) ||
                                  (_selectedTrainerName != null &&
                                      _selectedTrainerName!
                                              .trim()
                                              .toLowerCase() ==
                                          t.name.trim().toLowerCase());
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _TrainerFilterPill(
                                  label: t.name,
                                  selected: selected,
                                  onTap: () => setState(() {
                                    _selectedTrainerId = t.id;
                                    _selectedTrainerName = t.name;
                                  }),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (sortedDates.isEmpty)
                      CredMetalCard(
                        glowColor: p.gold,
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No trainer login or check-in records for this filter yet.\nWhenever trainers log in or scan Duty QR, each date and time is saved here.',
                          style: TextStyle(
                            fontSize: 13,
                            color: p.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      )
                    else
                      ...sortedDates.map((dateKey) {
                        final dayEntries = grouped[dateKey]!;
                        final headerLabel = dayEntries.first
                            .formattedDateLabelFor(now)
                            .toUpperCase();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      headerLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.3,
                                        color: p.gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${dayEntries.length} ${dayEntries.length == 1 ? 'entry' : 'entries'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              CredMetalCard(
                                glowColor: p.cyan,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                borderRadius: 18,
                                child: Column(
                                  children:
                                      List.generate(dayEntries.length, (i) {
                                    final entry = dayEntries[i];
                                    final color =
                                        entry.isDutyCheckIn ? p.accent : p.cyan;
                                    return Column(
                                      children: [
                                        if (i > 0)
                                          Divider(
                                            height: 18,
                                            color: p.divider,
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                entry.isDutyCheckIn
                                                    ? Icons
                                                        .qr_code_scanner_rounded
                                                    : Icons.login_rounded,
                                                size: 18,
                                                color: color,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      entry.trainerName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: p.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      entry.eventLabel,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: color,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                entry.timeLabel,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: p.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DateSegmentPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _DateSegmentPill({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: selected ? p.goldButton : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: p.goldButton.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                      size: 13,
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
      ),
    );
  }
}

class _TrainerFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAllOption;
  final VoidCallback onTap;

  const _TrainerFilterPill({
    required this.label,
    required this.selected,
    this.isAllOption = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final coachTeal = p.isDark ? p.cyan : const Color(0xFF0F766E);
    final unselectedBg = p.isDark ? p.card : const Color(0xFFF2FAF8);
    final unselectedBorder = p.isDark ? p.border : const Color(0xFFCBE6E1);

    return Material(
      color: selected ? coachTeal : unselectedBg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? coachTeal : unselectedBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: coachTeal.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAllOption ? Icons.groups_rounded : Icons.person_rounded,
                size: 13.5,
                color: selected
                    ? (p.isDark ? Colors.black : Colors.white)
                    : coachTeal,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? (p.isDark ? Colors.black : Colors.white)
                      : (p.isDark ? p.textSecondary : const Color(0xFF134E4A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
