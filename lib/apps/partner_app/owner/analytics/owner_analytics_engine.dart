import 'package:flutter/material.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

enum AnalyticsRange { week1, month1, months2, custom }

enum AnalyticsChartType { area, bar, mix }

enum AiInsightTone { positive, warning, alert, info }

class AnalyticsBucket {
  final String label;
  final String detailLabel;
  final int revenue;
  final int dues;
  final int joins;
  final bool isForecast;

  const AnalyticsBucket({
    required this.label,
    required this.detailLabel,
    required this.revenue,
    required this.dues,
    required this.joins,
    this.isForecast = false,
  });
}

class AiInsight {
  final String id;
  final String tag;
  final String title;
  final String detail;
  final AiInsightTone tone;
  final String? actionLabel;
  final String? auditFilter;
  final bool openLeads;

  const AiInsight({
    required this.id,
    required this.tag,
    required this.title,
    required this.detail,
    required this.tone,
    this.actionLabel,
    this.auditFilter,
    this.openLeads = false,
  });
}

class OwnerAnalyticsReport {
  final AnalyticsRange range;
  final String rangeTitle;
  final String rangeSubtitle;
  final int totalPeriodRevenue;
  final int previousPeriodRevenue;
  final int? growthPercent;
  final int periodJoins;
  final int projectedNext30dRevenue;
  final int pipelinePotential;
  final int cashRevenue;
  final int onlineRevenue;
  final int ptRevenue;
  final int regularRevenue;
  final int totalDues;
  final int atRiskRevenue;
  final int healthScore;
  final int retentionScore;
  final int collectionScore;
  final int ptMixScore;
  final int pipelineScore;
  final List<AnalyticsBucket> buckets;
  final List<AiInsight> insights;

  const OwnerAnalyticsReport({
    required this.range,
    required this.rangeTitle,
    required this.rangeSubtitle,
    required this.totalPeriodRevenue,
    required this.previousPeriodRevenue,
    required this.growthPercent,
    required this.periodJoins,
    required this.projectedNext30dRevenue,
    required this.pipelinePotential,
    required this.cashRevenue,
    required this.onlineRevenue,
    required this.ptRevenue,
    required this.regularRevenue,
    required this.totalDues,
    required this.atRiskRevenue,
    required this.healthScore,
    required this.retentionScore,
    required this.collectionScore,
    required this.ptMixScore,
    required this.pipelineScore,
    required this.buckets,
    required this.insights,
  });
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

    final buckets = _buildBuckets(
      start: start,
      end: end,
      range: range,
      entries: inRange,
      growthPercent: growthPercent,
    );

    // Overall gym intelligence & 30d forward forecast
    final expiringMembers = state.expiringOrExpiredMembers;
    final atRiskRevenue =
        expiringMembers.fold<int>(0, (sum, m) => sum + m.feePaid);
    final pendingLeads = state.enquiries.where((e) => !e.converted).toList();
    final pipelinePotential =
        pendingLeads.length * state.currentGym.monthlyFee;

    final last30Start = clock.subtract(const Duration(days: 29));
    final last30Rev = datedMembers
        .where((e) => !e.$2.isBefore(last30Start) && !e.$2.isAfter(clock))
        .fold<int>(0, (sum, e) => sum + e.$1.feePaid);
    final dailyVelocity =
        totalPeriodRevenue > 0 ? totalPeriodRevenue / totalDays : 0.0;
    final base30d = last30Rev > 0
        ? last30Rev
        : (dailyVelocity * 30).round();
    final renewalExpected =
        ((state.totalMonthlyRevenue - atRiskRevenue) * 0.85)
            .clamp(0, 10000000)
            .round();
    final leadConversionBoost = (pipelinePotential * 0.4).round();
    final projectedNext30dRevenue = base30d > 0
        ? ((base30d * 0.65) + (renewalExpected * 0.35) + leadConversionBoost)
            .round()
        : leadConversionBoost;

    // 4-pillar Health Score (0..100)
    final totalMembers = state.members.length;
    final retentionScore = totalMembers == 0
        ? 50
        : ((1 - (expiringMembers.length / totalMembers)) * 100)
            .clamp(15, 100)
            .round();

    final grossBilled = state.totalMonthlyRevenue + state.totalPendingDues;
    final collectionScore = grossBilled == 0
        ? 70
        : ((state.totalMonthlyRevenue / grossBilled) * 100)
            .clamp(20, 100)
            .round();

    final ptShare =
        totalMembers == 0 ? 0.0 : state.ptMembers.length / totalMembers;
    final ptMixScore =
        totalMembers == 0 ? 50 : ((ptShare / 0.35) * 100).clamp(25, 100).round();

    final pipelineScore = pendingLeads.isEmpty
        ? (totalMembers > 0 ? 65 : 40)
        : (65 + (pendingLeads.length * 7)).clamp(40, 100);

    final healthScore = ((retentionScore * 0.32) +
            (collectionScore * 0.32) +
            (ptMixScore * 0.18) +
            (pipelineScore * 0.18))
        .round()
        .clamp(0, 100);

    final insights = _buildAiInsights(
      state: state,
      atRiskRevenue: atRiskRevenue,
      expiringCount: expiringMembers.length,
      pendingLeadCount: pendingLeads.length,
      pipelinePotential: pipelinePotential,
      projectedNext30dRevenue: projectedNext30dRevenue,
      growthPercent: growthPercent,
      cashRevenue: cashRevenue,
      onlineRevenue: onlineRevenue,
    );

    return OwnerAnalyticsReport(
      range: range,
      rangeTitle: rangeTitle,
      rangeSubtitle: rangeSubtitle,
      totalPeriodRevenue: totalPeriodRevenue,
      previousPeriodRevenue: previousPeriodRevenue,
      growthPercent: growthPercent,
      periodJoins: inRange.length,
      projectedNext30dRevenue: projectedNext30dRevenue,
      pipelinePotential: pipelinePotential,
      cashRevenue: cashRevenue,
      onlineRevenue: onlineRevenue,
      ptRevenue: ptRevenue,
      regularRevenue: regularRevenue,
      totalDues: state.totalPendingDues,
      atRiskRevenue: atRiskRevenue,
      healthScore: healthScore,
      retentionScore: retentionScore,
      collectionScore: collectionScore,
      ptMixScore: ptMixScore,
      pipelineScore: pipelineScore,
      buckets: buckets,
      insights: insights,
    );
  }

  static List<AnalyticsBucket> _buildBuckets({
    required DateTime start,
    required DateTime end,
    required AnalyticsRange range,
    required List<(GymMember, DateTime)> entries,
    required int? growthPercent,
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
          dues: due,
          joins: matching.length,
        ),
      );
    }

    // Append a subtle AI forward-forecast point based on trailing bucket pace.
    if (result.isNotEmpty) {
      final nonZero = result.where((b) => b.revenue > 0).toList();
      final trailingAvg = nonZero.isEmpty
          ? 0
          : (nonZero.fold<int>(0, (s, b) => s + b.revenue) / nonZero.length)
              .round();
      final factor = (growthPercent != null && growthPercent > 0) ? 1.1 : 1.02;
      final forecastRev = (trailingAvg * factor).round();
      if (forecastRev > 0) {
        result.add(
          AnalyticsBucket(
            label: 'AI+',
            detailLabel: 'AI Forecast Next',
            revenue: forecastRev,
            dues: 0,
            joins: nonZero.isEmpty ? 0 : (nonZero.length / result.length).ceil(),
            isForecast: true,
          ),
        );
      }
    }

    return result;
  }

  static List<AiInsight> _buildAiInsights({
    required SmartGymState state,
    required int atRiskRevenue,
    required int expiringCount,
    required int pendingLeadCount,
    required int pipelinePotential,
    required int projectedNext30dRevenue,
    required int? growthPercent,
    required int cashRevenue,
    required int onlineRevenue,
  }) {
    final insights = <AiInsight>[];

    if (state.totalPendingDues > 0) {
      insights.add(
        AiInsight(
          id: 'collect_dues',
          tag: 'CASH RECOVERY',
          title: 'Collect ₹${state.totalPendingDues} Pending Dues',
          detail:
              '${state.dueMembers.length} member(s) have unpaid balances. 1-tap WhatsApp reminders recover most balances within 48h.',
          tone: AiInsightTone.alert,
          actionLabel: 'Open Dues',
          auditFilter: 'Dues',
        ),
      );
    }

    if (expiringCount > 0) {
      insights.add(
        AiInsight(
          id: 'renewal_risk',
          tag: 'RENEWAL SHIELD',
          title: '₹$atRiskRevenue Revenue Expiring ($expiringCount)',
          detail:
              'Renewals within 5 days or overdue need early outreach before members drop off.',
          tone: AiInsightTone.warning,
          actionLabel: 'Review Expiring',
          auditFilter: 'Expiring',
        ),
      );
    }

    if (pendingLeadCount > 0) {
      insights.add(
        AiInsight(
          id: 'lead_pipeline',
          tag: 'AI FORECAST',
          title: '+₹$pipelinePotential Pipeline Ready',
          detail:
              '$pendingLeadCount unconverted walk-in lead(s) waiting. Next 30d forecast sits near ₹$projectedNext30dRevenue.',
          tone: AiInsightTone.positive,
          actionLabel: 'Follow Up Leads',
          openLeads: true,
        ),
      );
    }

    final activeNonPt =
        state.members.where((m) => !m.isExpired && !m.isPtClient).length;
    if (activeNonPt >= 2) {
      final upsellAdd = state.currentGym.ptFee * 2;
      insights.add(
        AiInsight(
          id: 'pt_upsell',
          tag: 'PT UPSELL AI',
          title: 'Add +₹$upsellAdd/mo via PT Upgrades',
          detail:
              '$activeNonPt active member(s) are on regular plans. Upgrading even 2 to PT boosts trainer & CEO profit.',
          tone: AiInsightTone.info,
          actionLabel: 'View Active',
          auditFilter: 'All',
        ),
      );
    }

    final occRatio = state.currentGym.maxCapacity > 0
        ? state.liveCrowd / state.currentGym.maxCapacity
        : 0.0;
    if (occRatio >= 0.75) {
      final occPct = (occRatio * 100).round();
      insights.add(
        AiInsight(
          id: 'crowd_peak',
          tag: 'FLOOR LOAD',
          title: 'Floor Running at $occPct% Capacity',
          detail:
              'Promote afternoon off-peak passes to avoid evening bottlenecks while keeping daily footfall growing.',
          tone: AiInsightTone.info,
        ),
      );
    }

    if (cashRevenue > onlineRevenue && cashRevenue > 0) {
      insights.add(
        AiInsight(
          id: 'upi_shift',
          tag: 'DIGITAL AUDIT',
          title: 'Encourage UPI Screenshot Proofs',
          detail:
              'Most recent period collections arrived in Cash. Enabling UPI proof upload tightens owner audit accuracy.',
          tone: AiInsightTone.info,
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        AiInsight(
          id: 'baseline_growth',
          tag: 'AI COPILOT READY',
          title: state.members.isEmpty
              ? 'Enroll First Members to Unlock Forecasts'
              : 'All Metrics Healthy${growthPercent != null ? ' ($growthPercent% trend)' : ''}',
          detail: state.members.isEmpty
              ? 'Once paid plans & walk-in enquiries flow in, AI Copilot automatically tracks renewal risks, dues recovery & 30d run-rate.'
              : 'Next 30d run-rate projects near ₹$projectedNext30dRevenue with zero dues or expiring drops.',
          tone: AiInsightTone.positive,
        ),
      );
    }

    return insights;
  }
}
