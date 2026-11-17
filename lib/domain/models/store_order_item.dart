import 'package:equatable/equatable.dart';

class StoreOrderItem extends Equatable {
  final String id;
  final String memberName;
  final String itemTitle;
  final String amountLabel;
  final String timeLabel;
  final bool fulfilled;

  const StoreOrderItem({
    required this.id,
    required this.memberName,
    required this.itemTitle,
    required this.amountLabel,
    required this.timeLabel,
    this.fulfilled = false,
  });

  StoreOrderItem copyWith({bool? fulfilled}) {
    return StoreOrderItem(
      id: id,
      memberName: memberName,
      itemTitle: itemTitle,
      amountLabel: amountLabel,
      timeLabel: timeLabel,
      fulfilled: fulfilled ?? this.fulfilled,
    );
  }

  @override
  List<Object?> get props => [
        id,
        memberName,
        itemTitle,
        amountLabel,
        timeLabel,
        fulfilled,
      ];
}
