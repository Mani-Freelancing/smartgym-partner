import 'package:equatable/equatable.dart';

class RemovedRecord extends Equatable {
  final String id;
  final String type; // 'trainer' | 'member'
  final String name;
  final String phone;
  final String details;
  final String removedAtLabel;

  const RemovedRecord({
    required this.id,
    required this.type,
    required this.name,
    required this.phone,
    required this.details,
    this.removedAtLabel = '',
  });

  @override
  List<Object?> get props => [id, type, name, phone, details, removedAtLabel];
}
