import '../models/gym_member.dart';
import '../models/gym_tenant.dart';

enum ChurnRiskLevel { critical, high, moderate }

class MemberChurnRisk {
  final GymMember member;
  final int score;
  final ChurnRiskLevel level;
  final String reason;
  final String suggestedWhatsAppMessage;

  const MemberChurnRisk({
    required this.member,
    required this.score,
    required this.level,
    required this.reason,
    required this.suggestedWhatsAppMessage,
  });
}

class GymRushForecast {
  final String peakHoursLabel;
  final String quietestWindowLabel;
  final String currentStatusLabel;
  final String ownerRecommendation;
  final bool isCurrentHourBusy;
  final bool isUsingLiveHistory;

  const GymRushForecast({
    required this.peakHoursLabel,
    required this.quietestWindowLabel,
    required this.currentStatusLabel,
    required this.ownerRecommendation,
    required this.isCurrentHourBusy,
    required this.isUsingLiveHistory,
  });
}

/// Zero-cost deterministic intelligence engine for member churn prevention
/// and hourly gym rush-hour forecasting.
class MemberIntelligenceService {
  /// Scores active/expiring/overdue members for drop-off risk and prepares
  /// respectful WhatsApp recovery messages.
  static List<MemberChurnRisk> evaluateChurnRisks({
    required List<GymMember> members,
    required String gymName,
  }) {
    final risks = <MemberChurnRisk>[];
    for (final m in members) {
      int score = 0;
      final reasons = <String>[];

      if (m.daysLeft < 0) {
        score += 60;
        reasons.add('Expired ${m.daysLeft.abs()}d ago');
      } else if (m.daysLeft == 0) {
        score += 55;
        reasons.add('Expires today');
      } else if (m.daysLeft <= 5) {
        score += 40;
        reasons.add('Expires in ${m.daysLeft}d');
      } else if (m.daysLeft <= 10) {
        score += 20;
        reasons.add('Renews in ${m.daysLeft}d');
      }

      if (m.hasDue) {
        score += 25;
        reasons.add('₹${m.dueAmount} due');
      }

      if (!m.isPtClient && (m.daysLeft <= 7 || m.hasDue)) {
        score += 10;
      }

      if (score < 30) continue;
      final clamped = score.clamp(0, 100);
      final level = clamped >= 70
          ? ChurnRiskLevel.critical
          : clamped >= 45
              ? ChurnRiskLevel.high
              : ChurnRiskLevel.moderate;

      final label = m.respectfulName.isEmpty ? 'Member' : m.respectfulName;
      final msg = m.daysLeft <= 0
          ? 'Hi $label, we missed seeing you at *$gymName*! Your ${m.planTitle} pass has ended — visit the front desk or reply here for a quick renewal & free 20-min trainer reset session.'
          : m.hasDue
              ? 'Hi $label, friendly reminder from *$gymName* that your ${m.planTitle} renews in ${m.daysLeft}d (pending balance ₹${m.dueAmount}). Drop by today and our coach will update your workout split!'
              : 'Hi $label, your ${m.planTitle} at *$gymName* expires in ${m.daysLeft} day(s) (${m.expiryDate}). Renew early at the desk to keep your streak unbroken!';

      risks.add(
        MemberChurnRisk(
          member: m,
          score: clamped,
          level: level,
          reason: reasons.join(' • '),
          suggestedWhatsAppMessage: msg,
        ),
      );
    }

    risks.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;
      return a.member.daysLeft.compareTo(b.member.daysLeft);
    });
    return risks;
  }

  /// Forecasts peak and quietest workout windows from [gym.hourlyCheckIns]
  /// (or standard Indian gym rush curve until enough live check-ins accrue).
  static GymRushForecast forecastRushHours(
    GymTenant gym, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final hour = clock.hour;
    final counts = gym.hourlyCheckIns;
    final totalRecorded =
        counts.length == 24 ? counts.fold<int>(0, (s, c) => s + c) : 0;

    if (totalRecorded >= 5 && counts.length == 24) {
      int bestPeakStart = 6;
      int bestPeakSum = -1;
      for (int h = 5; h <= 20; h++) {
        final windowSum = counts[h] + counts[h + 1] + counts[h + 2];
        if (windowSum > bestPeakSum) {
          bestPeakSum = windowSum;
          bestPeakStart = h;
        }
      }

      int bestQuietStart = 13;
      int bestQuietSum = 1 << 30;
      for (int h = 9; h <= 19; h++) {
        final windowSum = counts[h] + counts[h + 1] + counts[h + 2];
        if (windowSum < bestQuietSum) {
          bestQuietSum = windowSum;
          bestQuietStart = h;
        }
      }

      final peakLabel = _formatWindow(bestPeakStart, bestPeakStart + 3);
      final quietLabel = _formatWindow(bestQuietStart, bestQuietStart + 3);
      final currentIsBusy =
          (hour >= bestPeakStart && hour < bestPeakStart + 3) ||
              (gym.maxCapacity > 0 &&
                  gym.activeCrowd / gym.maxCapacity >= 0.7);
      return GymRushForecast(
        peakHoursLabel: peakLabel,
        quietestWindowLabel: quietLabel,
        currentStatusLabel: currentIsBusy
            ? 'Peak window now • Expect busy floor'
            : 'Low-rush window • Ideal workout slot',
        ownerRecommendation:
            'Live Peak: $peakLabel • Promote $quietLabel Off-Peak Passes',
        isCurrentHourBusy: currentIsBusy,
        isUsingLiveHistory: true,
      );
    }

    final isTypicalPeak =
        (hour >= 6 && hour < 9) || (hour >= 18 && hour < 21);
    final isLiveBusy =
        gym.maxCapacity > 0 && gym.activeCrowd / gym.maxCapacity >= 0.7;
    final busyNow = isTypicalPeak || isLiveBusy;

    return GymRushForecast(
      peakHoursLabel: '6–9 AM & 6–9 PM',
      quietestWindowLabel: '1–4 PM',
      currentStatusLabel: busyNow
          ? 'Peak rush hours • Expect busier racks'
          : 'Quiet slot • Racks & benches open',
      ownerRecommendation:
          'Typical Peak: 6–9 AM & 6–9 PM • Promote 1–4 PM Off-Peak Passes',
      isCurrentHourBusy: busyNow,
      isUsingLiveHistory: false,
    );
  }

  static String _formatWindow(int startHour, int endHour) {
    return '${_shortHour(startHour)}–${_shortHour(endHour)}';
  }

  static String _shortHour(int h) {
    final normalized = h % 24;
    final period = normalized >= 12 ? 'PM' : 'AM';
    final h12 = normalized % 12 == 0 ? 12 : normalized % 12;
    return '$h12 $period';
  }
}
