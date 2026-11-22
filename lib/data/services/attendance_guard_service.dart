import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyCheckInRecord {
  final bool checkedInToday;
  final String timeLabel;
  final bool checkedOutToday;
  final String checkOutTimeLabel;
  final String dateKey;

  const DailyCheckInRecord({
    required this.checkedInToday,
    required this.timeLabel,
    this.checkedOutToday = false,
    this.checkOutTimeLabel = '',
    required this.dateKey,
  });
}

/// Enforces real-time gym attendance rules (once-per-day per member+gym,
/// persistent across app restarts, check-out decrement, plus gym hours).
class AttendanceGuardService {
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _formatTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$min $ampm';
  }

  static String _storageKey(String gymId, String memberKey) {
    final safeGym = gymId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final safeMember = memberKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return 'smartgym_checkin_${safeGym}_${safeMember}_${_todayKey()}';
  }

  static String _checkoutKey(String gymId, String memberKey) {
    final safeGym = gymId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final safeMember = memberKey.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return 'smartgym_checkout_${safeGym}_${safeMember}_${_todayKey()}';
  }

  /// Gym floor check-in hours: 5:00 AM to 11:00 PM.
  static bool isWithinGymHours() {
    final hour = DateTime.now().hour;
    return hour >= 5 && hour < 23;
  }

  static Future<DailyCheckInRecord> getTodayStatus({
    required String gymId,
    required String memberKey,
  }) async {
    final today = _todayKey();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTime = prefs.getString(_storageKey(gymId, memberKey));
      final savedOut = prefs.getString(_checkoutKey(gymId, memberKey));
      if (savedTime != null && savedTime.isNotEmpty) {
        return DailyCheckInRecord(
          checkedInToday: true,
          timeLabel: savedTime,
          checkedOutToday: savedOut != null && savedOut.isNotEmpty,
          checkOutTimeLabel: savedOut ?? '',
          dateKey: today,
        );
      }
    } catch (_) {}
    return DailyCheckInRecord(
      checkedInToday: false,
      timeLabel: '',
      dateKey: today,
    );
  }

  static Future<DailyCheckInRecord> recordCheckInToday({
    required String gymId,
    required String memberKey,
  }) async {
    final now = DateTime.now();
    final today = _todayKey();
    final timeLabel = _formatTime(now);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey(gymId, memberKey), timeLabel);
    } catch (_) {}
    return DailyCheckInRecord(
      checkedInToday: true,
      timeLabel: timeLabel,
      dateKey: today,
    );
  }

  static Future<DailyCheckInRecord> recordCheckOutToday({
    required String gymId,
    required String memberKey,
  }) async {
    final now = DateTime.now();
    final today = _todayKey();
    final outTime = _formatTime(now);
    String inTime = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      inTime = prefs.getString(_storageKey(gymId, memberKey)) ?? '';
      await prefs.setString(_checkoutKey(gymId, memberKey), outTime);
    } catch (_) {}
    return DailyCheckInRecord(
      checkedInToday: true,
      timeLabel: inTime,
      checkedOutToday: true,
      checkOutTimeLabel: outTime,
      dateKey: today,
    );
  }

  /// Clears today's check-in & check-out state so a member/tester can re-scan freshly.
  static Future<void> clearTodayStatus({
    required String gymId,
    required String memberKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey(gymId, memberKey));
      await prefs.remove(_checkoutKey(gymId, memberKey));
    } catch (_) {}
    version.value++;
  }
}
