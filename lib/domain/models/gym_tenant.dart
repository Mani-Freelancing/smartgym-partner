import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'gym_fee_plan.dart';

class GymTenant extends Equatable {
  final String id;
  final String name;
  final String area;
  final String headTrainer;
  final Color brandColor;
  final int activeCrowd;
  final String crowdDate;
  final int maxCapacity;
  final int monthlyFee;
  final int ptFee;
  final bool ptSplitExcludesBaseFee;
  final List<GymFeePlan> feePlans;
  final double? latitude;
  final double? longitude;
  final int checkInRadiusMeters;
  final bool requireGpsCheckIn;
  final List<int> hourlyCheckIns;

  const GymTenant({
    required this.id,
    required this.name,
    required this.area,
    required this.headTrainer,
    required this.brandColor,
    required this.activeCrowd,
    this.crowdDate = '',
    required this.maxCapacity,
    required this.monthlyFee,
    required this.ptFee,
    this.ptSplitExcludesBaseFee = true,
    this.feePlans = const [],
    this.latitude,
    this.longitude,
    this.checkInRadiusMeters = 100,
    this.requireGpsCheckIn = true,
    this.hourlyCheckIns = const [],
  });

  static List<int> decodeHourlyCheckIns(dynamic raw) {
    if (raw is! List) return const [];
    final list = <int>[];
    for (int i = 0; i < 24; i++) {
      final v = i < raw.length ? (raw[i] as num?)?.toInt() ?? 0 : 0;
      list.add(v < 0 ? 0 : v);
    }
    return list;
  }

  /// Returns `YYYY-MM-DD` for [now] (defaults to `DateTime.now()`).
  static String dateKeyFor([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Effective floor count for [now], auto-resetting to `0` whenever
  /// [crowdDate] belongs to a previous calendar day.
  int activeCrowdForDate([DateTime? now]) {
    if (crowdDate.isEmpty) return activeCrowd;
    return crowdDate == dateKeyFor(now) ? activeCrowd : 0;
  }

  /// Whether persisted [activeCrowd] belongs to an older calendar day and
  /// should be cleared back to `0` for [now].
  bool isCrowdStaleForDate([DateTime? now]) =>
      activeCrowd > 0 &&
      crowdDate.isNotEmpty &&
      crowdDate != dateKeyFor(now);

  bool get hasLocation => latitude != null && longitude != null;

  List<GymFeePlan> get effectiveFeePlans => feePlans.isNotEmpty
      ? feePlans
      : GymFeePlan.defaultPlans(monthlyFee: monthlyFee, ptFee: ptFee);

  GymTenant copyWith({
    String? name,
    String? area,
    String? headTrainer,
    int? activeCrowd,
    String? crowdDate,
    int? maxCapacity,
    int? monthlyFee,
    int? ptFee,
    bool? ptSplitExcludesBaseFee,
    List<GymFeePlan>? feePlans,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    int? checkInRadiusMeters,
    bool? requireGpsCheckIn,
    List<int>? hourlyCheckIns,
  }) {
    return GymTenant(
      id: id,
      name: name ?? this.name,
      area: area ?? this.area,
      headTrainer: headTrainer ?? this.headTrainer,
      brandColor: brandColor,
      activeCrowd: activeCrowd ?? this.activeCrowd,
      crowdDate: crowdDate ?? this.crowdDate,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      ptFee: ptFee ?? this.ptFee,
      ptSplitExcludesBaseFee:
          ptSplitExcludesBaseFee ?? this.ptSplitExcludesBaseFee,
      feePlans: feePlans ?? this.feePlans,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      checkInRadiusMeters: checkInRadiusMeters ?? this.checkInRadiusMeters,
      requireGpsCheckIn: requireGpsCheckIn ?? this.requireGpsCheckIn,
      hourlyCheckIns: hourlyCheckIns ?? this.hourlyCheckIns,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        area,
        headTrainer,
        brandColor,
        activeCrowd,
        crowdDate,
        maxCapacity,
        monthlyFee,
        ptFee,
        ptSplitExcludesBaseFee,
        feePlans,
        latitude,
        longitude,
        checkInRadiusMeters,
        requireGpsCheckIn,
        hourlyCheckIns,
      ];
}
