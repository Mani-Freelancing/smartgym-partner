import 'package:equatable/equatable.dart';

class TrainerProfile extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String specialty;
  final String shiftSlot;
  final String? morningCheckInTime;
  final bool isOnDuty;
  final int commissionPercent;

  const TrainerProfile({
    required this.id,
    required this.name,
    this.phone = '',
    required this.specialty,
    this.shiftSlot = 'Morning (6–10 AM)',
    this.morningCheckInTime,
    required this.isOnDuty,
    this.commissionPercent = 50,
  });

  static String _dateKeyFor(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formats [dt] (defaults to `DateTime.now()`) as `04:25 PM`.
  static String formatCheckInTime([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final hour24 = now.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final hh = hour12.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $period';
  }

  /// Formats a persisted Firestore `morningCheckInTime` entry as
  /// `YYYY-MM-DD • 04:25 PM` (21 chars, within Firestore's 30-char limit)
  /// so duty attendance automatically resets on a new calendar day.
  static String formatCheckInRecord([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    return '${_dateKeyFor(now)} • ${formatCheckInTime(now)}';
  }

  static final RegExp _datedPrefix = RegExp(r'^(\d{4}-\d{2}-\d{2})\s*•\s*(.+)$');

  /// Extracts just the human-readable clock time (e.g. `04:25 PM`) without the
  /// internal `YYYY-MM-DD • ` prefix, or `''` for placeholder values.
  String get displayCheckInTime {
    final raw = morningCheckInTime?.trim() ?? '';
    if (raw.isEmpty) return '';
    final match = _datedPrefix.firstMatch(raw);
    final timePart = match != null ? match.group(2)!.trim() : raw;
    final lower = timePart.toLowerCase();
    if (lower == 'not checked in' || lower == 'checked in now') return '';
    return timePart;
  }

  bool get hasValidCheckInTime => displayCheckInTime.isNotEmpty;

  /// True when an active trainer doc still carries a legacy `'Checked In Now'`
  /// placeholder instead of a real clock timestamp.
  bool get needsCheckInTimestampUpgrade =>
      isOnDuty &&
      (morningCheckInTime?.trim().toLowerCase() ?? '') == 'checked in now';

  /// Whether this trainer is checked in for [now]'s calendar day.
  /// Entries with an older `YYYY-MM-DD • ` date automatically reset to off duty.
  bool isCheckedInToday([DateTime? now]) {
    if (!isOnDuty) return false;
    final raw = morningCheckInTime?.trim() ?? '';
    final match = _datedPrefix.firstMatch(raw);
    if (match != null) {
      return match.group(1) == _dateKeyFor(now ?? DateTime.now());
    }
    return true;
  }

  bool get isOnDutyToday => isCheckedInToday();

  /// Clean English duty status shown on both Trainer and Owner cards.
  String radarDutySubtitleFor([DateTime? now]) {
    if (!isCheckedInToday(now)) return 'Not Checked In Today';
    final t = displayCheckInTime;
    return t.isNotEmpty ? 'Checked in at $t' : 'Checked in today';
  }

  String get radarDutySubtitle => radarDutySubtitleFor();

  /// Badge text shown on the Owner Trainers roster card.
  String ownerDutyBadgeTextFor([DateTime? now]) {
    if (!isCheckedInToday(now)) return 'OFF DUTY';
    final t = displayCheckInTime;
    return t.isNotEmpty ? 'ON DUTY • $t' : 'ON DUTY • TODAY';
  }

  String get ownerDutyBadgeText => ownerDutyBadgeTextFor();

  TrainerProfile copyWith({
    String? specialty,
    String? shiftSlot,
    String? morningCheckInTime,
    bool? isOnDuty,
    int? commissionPercent,
  }) {
    return TrainerProfile(
      id: id,
      name: name,
      phone: phone,
      specialty: specialty ?? this.specialty,
      shiftSlot: shiftSlot ?? this.shiftSlot,
      morningCheckInTime: morningCheckInTime ?? this.morningCheckInTime,
      isOnDuty: isOnDuty ?? this.isOnDuty,
      commissionPercent: commissionPercent ?? this.commissionPercent,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        specialty,
        shiftSlot,
        morningCheckInTime,
        isOnDuty,
        commissionPercent,
      ];
}
