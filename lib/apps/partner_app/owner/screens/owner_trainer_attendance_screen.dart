import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../domain/models/trainer_attendance_log.dart';
import '../../../../domain/models/trainer_profile.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

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
  String? _selectedTrainerId;
  String? _selectedTrainerName;
  _DateRangeFilter _range = _DateRangeFilter.all;
  DateTime? _pickedDate;

  @override
  void initState() {
    super.initState();
    _selectedTrainerId = widget.initialTrainerId;
    _selectedTrainerName = widget.initialTrainerName;
  }

  Future<void> _pickDate() async {
    final p = AppPalette.of(context);
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year, now.month, now.day),
      builder: (ctx, child) => Theme(
        data: p.isDark
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppTheme.ownerGold,
                  onPrimary: Colors.black,
                  surface: Color(0xFF1A1E29),
                  onSurface: Colors.white,
                ),
              )
            : AppTheme.lightTheme.copyWith(
                colorScheme: ColorScheme.light(
                  primary: p.goldButton,
                  onPrimary: p.onAccent,
                  surface: p.card,
                  onSurface: p.textPrimary,
                ),
              ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedDate = picked;
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
        if (_pickedDate == null) return true;
        return log.dateKey == TrainerAttendanceLog.dateKeyFor(_pickedDate);
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
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All Dates',
                            selected: _range == _DateRangeFilter.all,
                            accent: p.goldButton,
                            onTap: () => setState(() {
                              _range = _DateRangeFilter.all;
                              _pickedDate = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Today',
                            selected: _range == _DateRangeFilter.today,
                            accent: p.goldButton,
                            onTap: () => setState(() {
                              _range = _DateRangeFilter.today;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Last 7 Days',
                            selected: _range == _DateRangeFilter.last7Days,
                            accent: p.goldButton,
                            onTap: () => setState(() {
                              _range = _DateRangeFilter.last7Days;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: _range == _DateRangeFilter.custom &&
                                    _pickedDate != null
                                ? TrainerAttendanceLog.dateKeyFor(_pickedDate)
                                : 'Pick Date',
                            selected: _range == _DateRangeFilter.custom,
                            accent: p.goldButton,
                            onTap: _pickDate,
                          ),
                        ],
                      ),
                    ),
                    if (state.trainers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All Trainers',
                              selected: _selectedTrainerId == null &&
                                  _selectedTrainerName == null,
                              accent: p.cyan,
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
                                child: _FilterChip(
                                  label: t.name,
                                  selected: selected,
                                  accent: p.cyan,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: selected ? p.onAccent : p.textSecondary,
        ),
      ),
      selected: selected,
      selectedColor: accent,
      backgroundColor: p.card,
      side: BorderSide(color: selected ? accent : p.border),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
