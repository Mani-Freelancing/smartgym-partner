import 'package:equatable/equatable.dart';

class MissingMember extends Equatable {
  final String id;
  final String name;
  final int daysMissing;
  final String planName;
  final String lastMuscleTrained;
  final bool contacted;

  const MissingMember({
    required this.id,
    required this.name,
    required this.daysMissing,
    required this.planName,
    required this.lastMuscleTrained,
    this.contacted = false,
  });

  MissingMember copyWith({bool? contacted}) {
    return MissingMember(
      id: id,
      name: name,
      daysMissing: daysMissing,
      planName: planName,
      lastMuscleTrained: lastMuscleTrained,
      contacted: contacted ?? this.contacted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        daysMissing,
        planName,
        lastMuscleTrained,
        contacted,
      ];
}
