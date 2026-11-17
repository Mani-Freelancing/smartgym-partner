import 'package:equatable/equatable.dart';

class WalkInEnquiry extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String interestedPlan;
  final String loggedByTrainer;
  final String timeLabel;
  final bool converted;

  const WalkInEnquiry({
    required this.id,
    required this.name,
    required this.phone,
    required this.interestedPlan,
    required this.loggedByTrainer,
    required this.timeLabel,
    this.converted = false,
  });

  WalkInEnquiry copyWith({bool? converted}) {
    return WalkInEnquiry(
      id: id,
      name: name,
      phone: phone,
      interestedPlan: interestedPlan,
      loggedByTrainer: loggedByTrainer,
      timeLabel: timeLabel,
      converted: converted ?? this.converted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        interestedPlan,
        loggedByTrainer,
        timeLabel,
        converted,
      ];
}
