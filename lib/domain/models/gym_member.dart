import 'package:equatable/equatable.dart';

class GymMember extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String planTitle;
  final int feePaid;
  final String joinedDate;
  final String expiryDate;
  final int daysLeft;
  final String? assignedTrainer;
  final bool isPtClient;
  final String addedByTrainer;
  final double currentWeightKg;

  const GymMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.planTitle,
    required this.feePaid,
    required this.joinedDate,
    required this.expiryDate,
    required this.daysLeft,
    this.assignedTrainer,
    required this.isPtClient,
    required this.addedByTrainer,
    this.currentWeightKg = 74.0,
  });

  bool get isExpired => daysLeft <= 0;
  bool get isExpiringSoon => daysLeft > 0 && daysLeft <= 5;

  GymMember copyWith({
    String? planTitle,
    int? feePaid,
    String? expiryDate,
    int? daysLeft,
    String? assignedTrainer,
    bool? isPtClient,
    double? currentWeightKg,
  }) {
    return GymMember(
      id: id,
      name: name,
      phone: phone,
      planTitle: planTitle ?? this.planTitle,
      feePaid: feePaid ?? this.feePaid,
      joinedDate: joinedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      daysLeft: daysLeft ?? this.daysLeft,
      assignedTrainer: assignedTrainer ?? this.assignedTrainer,
      isPtClient: isPtClient ?? this.isPtClient,
      addedByTrainer: addedByTrainer,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        planTitle,
        feePaid,
        joinedDate,
        expiryDate,
        daysLeft,
        assignedTrainer,
        isPtClient,
        addedByTrainer,
        currentWeightKg,
      ];
}
