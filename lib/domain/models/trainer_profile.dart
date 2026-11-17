import 'package:equatable/equatable.dart';

class TrainerProfile extends Equatable {
  final String id;
  final String name;
  final String specialty;
  final String? morningCheckInTime;
  final bool isOnDuty;
  final int commissionPercent;

  const TrainerProfile({
    required this.id,
    required this.name,
    required this.specialty,
    this.morningCheckInTime,
    required this.isOnDuty,
    this.commissionPercent = 50,
  });

  TrainerProfile copyWith({
    String? morningCheckInTime,
    bool? isOnDuty,
  }) {
    return TrainerProfile(
      id: id,
      name: name,
      specialty: specialty,
      morningCheckInTime: morningCheckInTime ?? this.morningCheckInTime,
      isOnDuty: isOnDuty ?? this.isOnDuty,
      commissionPercent: commissionPercent,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        specialty,
        morningCheckInTime,
        isOnDuty,
        commissionPercent,
      ];
}
