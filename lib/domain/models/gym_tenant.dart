import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

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
  });

  GymTenant copyWith({
    String? name,
    String? area,
    String? headTrainer,
    int? activeCrowd,
    int? maxCapacity,
    int? monthlyFee,
    int? ptFee,
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
      ];
}
