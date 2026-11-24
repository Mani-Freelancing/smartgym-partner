import '../models/gym_member.dart';
import '../models/gym_tenant.dart';
import '../models/trainer_profile.dart';

typedef MemberPtSplit = ({
  int baseOwnerKeep,
  int ptPortion,
  int trainerShare,
  int ownerShare,
});

/// Single source of truth for Owner vs. Trainer PT commission splits, supporting
/// full-package splits (`0–100%`) as well as base-membership exclusion where the
/// gym's base fee stays 100% with the owner and trainer % applies only above it.
class PtSplitCalculator {
  const PtSplitCalculator._();

  static TrainerProfile? findTrainerForMember(
    GymMember member,
    List<TrainerProfile> trainers,
  ) {
    final assigned = (member.assignedTrainer ?? '').trim().toLowerCase();
    if (assigned.isEmpty) return null;
    for (final t in trainers) {
      if (t.name.trim().toLowerCase() == assigned) return t;
    }
    return null;
  }

  static MemberPtSplit computeMemberSplit({
    required GymMember member,
    required List<TrainerProfile> trainers,
    required GymTenant gym,
  }) {
    final total = member.feePaid < 0 ? 0 : member.feePaid;
    if (!member.isPtClient || total == 0) {
      return (
        baseOwnerKeep: total,
        ptPortion: 0,
        trainerShare: 0,
        ownerShare: total,
      );
    }

    final trainer = findTrainerForMember(member, trainers);
    if (trainer == null) {
      return (
        baseOwnerKeep: total,
        ptPortion: 0,
        trainerShare: 0,
        ownerShare: total,
      );
    }

    final baseKeep = gym.ptSplitExcludesBaseFee
        ? total.clamp(0, gym.monthlyFee < 0 ? 0 : gym.monthlyFee)
        : 0;
    final ptPortion = total - baseKeep;
    final pct = trainer.commissionPercent.clamp(0, 100);
    final trainerShare = (ptPortion * pct) ~/ 100;
    final ownerShare = total - trainerShare;

    return (
      baseOwnerKeep: baseKeep,
      ptPortion: ptPortion,
      trainerShare: trainerShare,
      ownerShare: ownerShare,
    );
  }
}
