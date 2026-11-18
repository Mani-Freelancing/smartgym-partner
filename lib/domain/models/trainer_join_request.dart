import 'package:equatable/equatable.dart';

class TrainerJoinRequest extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String uid;
  final String inviteCode;
  final String status;

  const TrainerJoinRequest({
    required this.id,
    required this.name,
    required this.phone,
    required this.uid,
    required this.inviteCode,
    this.status = 'pending',
  });

  @override
  List<Object?> get props => [id, name, phone, uid, inviteCode, status];
}
