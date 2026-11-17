import 'package:equatable/equatable.dart';

class MealReviewItem extends Equatable {
  final String id;
  final String memberName;
  final String timeLabel;
  final String mealDescription;
  final String macros;
  final String? trainerFeedback;

  const MealReviewItem({
    required this.id,
    required this.memberName,
    required this.timeLabel,
    required this.mealDescription,
    required this.macros,
    this.trainerFeedback,
  });

  MealReviewItem copyWith({String? trainerFeedback}) {
    return MealReviewItem(
      id: id,
      memberName: memberName,
      timeLabel: timeLabel,
      mealDescription: mealDescription,
      macros: macros,
      trainerFeedback: trainerFeedback ?? this.trainerFeedback,
    );
  }

  @override
  List<Object?> get props => [
        id,
        memberName,
        timeLabel,
        mealDescription,
        macros,
        trainerFeedback,
      ];
}
