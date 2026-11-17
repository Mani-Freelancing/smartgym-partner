import 'package:equatable/equatable.dart';

class MachineGuide extends Equatable {
  final String code;
  final String name;
  final String muscle;
  final String mistakeTip;

  const MachineGuide({
    required this.code,
    required this.name,
    required this.muscle,
    required this.mistakeTip,
  });

  @override
  List<Object?> get props => [code, name, muscle, mistakeTip];
}
