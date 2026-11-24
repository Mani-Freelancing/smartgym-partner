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
