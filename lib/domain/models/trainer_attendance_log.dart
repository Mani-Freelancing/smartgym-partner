import 'package:equatable/equatable.dart';
import 'trainer_profile.dart';

class TrainerAttendanceLog extends Equatable {
  final String id;
  final String trainerId;
  final String trainerName;
  final String trainerPhone;
  final String dateKey;
  final String timeLabel;
  final String eventType;
  final int timestampMs;

  const TrainerAttendanceLog({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    this.trainerPhone = '',
    required this.dateKey,
    required this.timeLabel,
    required this.eventType,
    required this.timestampMs,
  });

  static const List<String> _months = [
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

  static String dateKeyFor([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static TrainerAttendanceLog fromDateTime({
    required String trainerId,
    required String trainerName,
    String trainerPhone = '',
    required String eventType,
    DateTime? at,
    String? idOverride,
  }) {
    final dt = at ?? DateTime.now();
    return TrainerAttendanceLog(
      id: idOverride ?? 'att_${dt.millisecondsSinceEpoch}_${trainerId.isNotEmpty ? trainerId : 'tr'}',
      trainerId: trainerId,
      trainerName: trainerName,
      trainerPhone: trainerPhone,
      dateKey: dateKeyFor(dt),
      timeLabel: TrainerProfile.formatCheckInTime(dt),
      eventType: eventType,
      timestampMs: dt.millisecondsSinceEpoch,
    );
  }

  bool get isDutyCheckIn => eventType == 'duty_checkin';

  String get eventLabel => isDutyCheckIn ? 'Duty Check-In' : 'App Login';

  String formattedDateLabelFor([DateTime? now]) {
    final today = now ?? DateTime.now();
    final todayKey = dateKeyFor(today);
    final yesterdayKey = dateKeyFor(
      DateTime(today.year, today.month, today.day).subtract(
        const Duration(days: 1),
      ),
    );
    final parts = dateKey.split('-');
    var shortDate = dateKey;
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null &&
          month != null &&
          day != null &&
          month >= 1 &&
          month <= 12) {
        shortDate = '$day ${_months[month - 1]} $year';
      }
    }
    if (dateKey == todayKey) return 'Today • $shortDate';
    if (dateKey == yesterdayKey) return 'Yesterday • $shortDate';
    return shortDate;
  }

  String get formattedDateLabel => formattedDateLabelFor();

  @override
  List<Object?> get props => [
        id,
        trainerId,
        trainerName,
        trainerPhone,
        dateKey,
        timeLabel,
        eventType,
        timestampMs,
      ];
}
