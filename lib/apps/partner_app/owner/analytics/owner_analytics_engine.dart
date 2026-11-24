import 'package:flutter/material.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../domain/models/gym_tenant.dart';
import '../../../../domain/models/trainer_profile.dart';
import '../../../../domain/services/pt_split_calculator.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

enum AnalyticsRange { week1, month1, months2, custom }

enum AnalyticsChartType { area, bar, mix }

class AnalyticsBucket {
  final String label;
  final String detailLabel;
  final int revenue;
  final int coachPayout;
  final int dues;
  final int joins;

  int get ownerNetRevenue => revenue - coachPayout;

  const AnalyticsBucket({
    required this.label,
    required this.detailLabel,
    required this.revenue,
    this.coachPayout = 0,
    required this.dues,
    required this.joins,
  });
}

class OwnerAnalyticsReport {
  final AnalyticsRange range;
  final String rangeTitle;
  final String rangeSubtitle;
  final int totalPeriodRevenue;
  final int coachPayout;
  final int ownerNetRevenue;
  final int totalCoachPayout;
  final int totalOwnerNetRevenue;
  final int previousPeriodRevenue;
  final int? growthPercent;
  final int periodJoins;
  final int cashRevenue;
  final int onlineRevenue;
  final int ptRevenue;
  final int regularRevenue;
  final int totalDues;
  final List<AnalyticsBucket> buckets;

  const OwnerAnalyticsReport({
    required this.range,
    required this.rangeTitle,
    required this.rangeSubtitle,
    required this.totalPeriodRevenue,
    this.coachPayout = 0,
    int? ownerNetRevenue,
    this.totalCoachPayout = 0,
    int? totalOwnerNetRevenue,
    required this.previousPeriodRevenue,
    required this.growthPercent,
    required this.periodJoins,
    required this.cashRevenue,
    required this.onlineRevenue,
    required this.ptRevenue,
    required this.regularRevenue,
    required this.totalDues,
    required this.buckets,
  })  : ownerNetRevenue = ownerNetRevenue ?? (totalPeriodRevenue - coachPayout),
        totalOwnerNetRevenue = totalOwnerNetRevenue ?? 0;
}

class OwnerAnalyticsEngine {
  static const _months = [
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

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String formatShortDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}';

  /// Parses member date labels (`Today...`, `Just Now`, `dd MMM yyyy`, `dd MMM`, ISO, `dd/MM/yyyy`).
  static DateTime? parseDate(String raw, {required DateTime now}) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    final today = _dayOnly(now);

    if (lower.startsWith('today') ||
        lower.contains('just now') ||
        lower.contains('converted today') ||
        lower.contains('register import')) {
      return today;
    }

    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }

    final slashMatch =
        RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (slashMatch != null) {
      final d = int.parse(slashMatch.group(1)!);
      final m = int.parse(slashMatch.group(2)!);
      final y = int.parse(slashMatch.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }

    final namedMatch =
        RegExp(r'^(\d{1,2})\s+([A-Za-z]{3,})(?:\s+(\d{4}))?$').firstMatch(s);
    if (namedMatch != null) {
      final d = int.parse(namedMatch.group(1)!);
      final monToken = namedMatch.group(2)!.substring(0, 3).toLowerCase();
      final mIdx = _months.indexWhere((m) => m.toLowerCase() == monToken);
      if (mIdx != -1 && d >= 1 && d <= 31) {
        final yearGroup = namedMatch.group(3);
        int year = yearGroup != null ? int.parse(yearGroup) : today.year;
        var parsed = DateTime(year, mIdx + 1, d);
        if (yearGroup == null &&
            parsed.isAfter(today.add(const Duration(days: 14)))) {
          parsed = DateTime(year - 1, mIdx + 1, d);
        }
        return parsed;
      }
    }

    return null;
  }

  static OwnerAnalyticsReport buildReport({
    required SmartGymState state,
    required AnalyticsRange range,
    DateTimeRange? customRange,
    DateTime? now,
  }) {
    final clock = _dayOnly(now ?? DateTime.now());
    final (start, end, rangeTitle, rangeSubtitle) = switch (range) {
      AnalyticsRange.week1 => (
          clock.subtract(const Duration(days: 6)),
          clock,
          'Last 7 Days',
          '${formatShortDate(clock.subtract(const Duration(days: 6)))} – ${formatShortDate(clock)}',
        ),
      AnalyticsRange.month1 => (
          clock.subtract(const Duration(days: 29)),
          clock,
          'Last 30 Days',
          '${formatShortDate(clock.subtract(const Duration(days: 29)))} – ${formatShortDate(clock)}',
        ),
      AnalyticsRange.months2 => (
          clock.subtract(const Duration(days: 59)),
          clock,
          'Last 2 Months',
          '${formatShortDate(clock.subtract(const Duration(days: 59)))} – ${formatShortDate(clock)}',
        ),
      AnalyticsRange.custom => () {
          final s = _dayOnly(
            customRange?.start ?? clock.subtract(const Duration(days: 13)),
          );
          final e = _dayOnly(customRange?.end ?? clock);
          final orderedStart = s.isAfter(e) ? e : s;
          final orderedEnd = s.isAfter(e) ? s : e;
          final days = orderedEnd.difference(orderedStart).inDays + 1;
          return (
            orderedStart,
            orderedEnd,
            'Custom ($days d)',
            '${formatShortDate(orderedStart)} – ${formatShortDate(orderedEnd)}',
          );
        }(),
    };

    final totalDays = end.difference(start).inDays + 1;
    final prevEnd = start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: totalDays - 1));

    final datedMembers = <(GymMember, DateTime)>[];
    for (final m in state.members) {
      final dt = parseDate(m.joinedDate, now: clock) ?? clock;
      datedMembers.add((m, dt));
    }

    final inRange = datedMembers
        .where((entry) => !entry.$2.isBefore(start) && !entry.$2.isAfter(end))
        .toList();
    final inPrev = datedMembers
        .where(
          (entry) =>
              !entry.$2.isBefore(prevStart) && !entry.$2.isAfter(prevEnd),
        )
        .toList();

    final totalPeriodRevenue =
        inRange.fold<int>(0, (sum, e) => sum + e.$1.feePaid);
    final previousPeriodRevenue =
        inPrev.fold<int>(0, (sum, e) => sum + e.$1.feePaid);

    int? growthPercent;
    if (previousPeriodRevenue > 0) {
      growthPercent = (((totalPeriodRevenue - previousPeriodRevenue) /
                  previousPeriodRevenue) *
              100)
          .round();
    } else if (totalPeriodRevenue > 0) {
      growthPercent = 100;
    }

    final cashRevenue = inRange
        .where((e) => e.$1.paymentMode != 'Online')
        .fold<int>(0, (sum, e) => sum + e.$1.feePaid);
    final onlineRevenue = inRange
        .where((e) => e.$1.paymentMode == 'Online')
        .fold<int>(0, (sum, e) => sum + e.$1.feePaid);
    final ptRevenue = inRange
        .where((e) => e.$1.isPtClient)
        .fold<int>(0, (sum, e) => sum + e.$1.feePaid);
    final regularRevenue = inRange
        .where((e) => !e.$1.isPtClient)
        .fold<int>(0, (sum, e) => sum + e.$1.feePaid);

    final periodCoachPayout = inRange.fold<int>(
      0,
      (sum, e) =>
          sum +
          PtSplitCalculator.computeMemberSplit(
            member: e.$1,
            trainers: state.trainers,
            gym: state.currentGym,
          ).trainerShare,
    );
    final periodOwnerNetRevenue = totalPeriodRevenue - periodCoachPayout;

    final totalCoachPayout = state.members.fold<int>(
      0,
      (sum, m) =>
          sum +
          PtSplitCalculator.computeMemberSplit(
            member: m,
            trainers: state.trainers,
            gym: state.currentGym,
          ).trainerShare,
    );
    final totalOwnerNetRevenue = state.totalMonthlyRevenue - totalCoachPayout;

    final buckets = _buildBuckets(
      start: start,
      end: end,
      range: range,
      entries: inRange,
      trainers: state.trainers,
      gym: state.currentGym,
    );

    return OwnerAnalyticsReport(
      range: range,
      rangeTitle: rangeTitle,
      rangeSubtitle: rangeSubtitle,
      totalPeriodRevenue: totalPeriodRevenue,
      coachPayout: periodCoachPayout,
      ownerNetRevenue: periodOwnerNetRevenue,
      totalCoachPayout: totalCoachPayout,
      totalOwnerNetRevenue: totalOwnerNetRevenue,
      previousPeriodRevenue: previousPeriodRevenue,
      growthPercent: growthPercent,
      periodJoins: inRange.length,
      cashRevenue: cashRevenue,
      onlineRevenue: onlineRevenue,
      ptRevenue: ptRevenue,
      regularRevenue: regularRevenue,
      totalDues: state.totalPendingDues,
      buckets: buckets,
    );
  }

  static List<AnalyticsBucket> _buildBuckets({
    required DateTime start,
    required DateTime end,
    required AnalyticsRange range,
    required List<(GymMember, DateTime)> entries,
    required List<TrainerProfile> trainers,
    required GymTenant gym,
  }) {
    final totalDays = end.difference(start).inDays + 1;
    final bucketCount = switch (range) {
      AnalyticsRange.week1 => 7,
      AnalyticsRange.month1 => 5,
      AnalyticsRange.months2 => 6,
      AnalyticsRange.custom => totalDays <= 10
          ? totalDays
          : (totalDays <= 35 ? 5 : 6),
    };

    final stepDays = (totalDays / bucketCount).ceil().clamp(1, 365);
    final result = <AnalyticsBucket>[];

    for (var i = 0; i < bucketCount; i++) {
      final bStart = start.add(Duration(days: i * stepDays));
      if (bStart.isAfter(end)) break;
      final rawEnd = bStart.add(Duration(days: stepDays - 1));
      final bEnd = rawEnd.isAfter(end) ? end : rawEnd;

      final matching = entries.where(
        (e) => !e.$2.isBefore(bStart) && !e.$2.isAfter(bEnd),
      );
      final rev = matching.fold<int>(0, (s, e) => s + e.$1.feePaid);
      final payout = matching.fold<int>(
        0,
        (s, e) =>
            s +
            PtSplitCalculator.computeMemberSplit(
              member: e.$1,
              trainers: trainers,
              gym: gym,
            ).trainerShare,
      );
      final due = matching.fold<int>(0, (s, e) => s + e.$1.dueAmount);

      final label = totalDays <= 10
          ? (range == AnalyticsRange.week1
              ? _weekdays[bStart.weekday - 1]
              : '${bStart.day}/${bStart.month}')
          : '${bStart.day} ${_months[bStart.month - 1]}';
      final detailLabel = bStart == bEnd
          ? formatShortDate(bStart)
          : '${formatShortDate(bStart)} – ${formatShortDate(bEnd)}';

      result.add(
        AnalyticsBucket(
          label: label,
          detailLabel: detailLabel,
          revenue: rev,
          coachPayout: payout,
          dues: due,
          joins: matching.length,
        ),
      );
    }

    return result;
  }
}
