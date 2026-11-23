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
  final int maxCapacity;
  final int monthlyFee;
  final int ptFee;
  final List<GymFeePlan> feePlans;
  final double? latitude;
  final double? longitude;
  final int checkInRadiusMeters;
  final bool requireGpsCheckIn;

  const GymTenant({
    required this.id,
    required this.name,
    required this.area,
    required this.headTrainer,
    required this.brandColor,
    required this.activeCrowd,
    required this.maxCapacity,
    required this.monthlyFee,
    required this.ptFee,
    this.feePlans = const [],
    this.latitude,
    this.longitude,
    this.checkInRadiusMeters = 100,
    this.requireGpsCheckIn = true,
  });

  bool get hasLocation => latitude != null && longitude != null;

  List<GymFeePlan> get effectiveFeePlans => feePlans.isNotEmpty
      ? feePlans
      : GymFeePlan.defaultPlans(monthlyFee: monthlyFee, ptFee: ptFee);

  GymTenant copyWith({
    String? name,
    String? area,
    String? headTrainer,
    int? activeCrowd,
    int? maxCapacity,
    int? monthlyFee,
    int? ptFee,
    List<GymFeePlan>? feePlans,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    int? checkInRadiusMeters,
    bool? requireGpsCheckIn,
  }) {
    return GymTenant(
      id: id,
      name: name ?? this.name,
      area: area ?? this.area,
      headTrainer: headTrainer ?? this.headTrainer,
      brandColor: brandColor,
      activeCrowd: activeCrowd ?? this.activeCrowd,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      ptFee: ptFee ?? this.ptFee,
      feePlans: feePlans ?? this.feePlans,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      checkInRadiusMeters: checkInRadiusMeters ?? this.checkInRadiusMeters,
      requireGpsCheckIn: requireGpsCheckIn ?? this.requireGpsCheckIn,
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
        maxCapacity,
        monthlyFee,
        ptFee,
        feePlans,
        latitude,
        longitude,
        checkInRadiusMeters,
        requireGpsCheckIn,
      ];
}
