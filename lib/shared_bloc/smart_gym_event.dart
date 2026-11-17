import 'package:equatable/equatable.dart';
import '../domain/models/partner_role.dart';

sealed class SmartGymEvent extends Equatable {
  const SmartGymEvent();

  @override
  List<Object?> get props => [];
}

class SelectGymTenantEvent extends SmartGymEvent {
  final int gymIndex;
  const SelectGymTenantEvent(this.gymIndex);

  @override
  List<Object?> get props => [gymIndex];
}

class CustomizeCurrentGymEvent extends SmartGymEvent {
  final String name;
  final String area;
  final String headTrainer;

  const CustomizeCurrentGymEvent({
    required this.name,
    required this.area,
    required this.headTrainer,
  });

  @override
  List<Object?> get props => [name, area, headTrainer];
}

class SwitchPartnerRoleEvent extends SmartGymEvent {
  final PartnerRole role;
  const SwitchPartnerRoleEvent(this.role);

  @override
  List<Object?> get props => [role];
}

class LoginPartnerEvent extends SmartGymEvent {
  final PartnerRole role;
  final String phone;
  final String? trainerName;

  const LoginPartnerEvent({
    required this.role,
    required this.phone,
    this.trainerName,
  });

  @override
  List<Object?> get props => [role, phone, trainerName];
}

class LogoutPartnerEvent extends SmartGymEvent {
  const LogoutPartnerEvent();
}

// --- TRAINER OPERATIONS EVENTS (Updates Owner Dashboard Live!) ---

class AddNewGymMemberEvent extends SmartGymEvent {
  final String name;
  final String phone;
  final String planTitle;
  final int feePaid;
  final int daysValid;
  final bool isPtClient;
  final String? assignedTrainer;
  final String addedByTrainer;

  const AddNewGymMemberEvent({
    required this.name,
    required this.phone,
    required this.planTitle,
    required this.feePaid,
    required this.daysValid,
    required this.isPtClient,
    this.assignedTrainer,
    required this.addedByTrainer,
  });

  @override
  List<Object?> get props => [
        name,
        phone,
        planTitle,
        feePaid,
        daysValid,
        isPtClient,
        assignedTrainer,
        addedByTrainer,
      ];
}

class AddWalkInEnquiryEvent extends SmartGymEvent {
  final String name;
  final String phone;
  final String interestedPlan;
  final String loggedByTrainer;

  const AddWalkInEnquiryEvent({
    required this.name,
    required this.phone,
    required this.interestedPlan,
    required this.loggedByTrainer,
  });

  @override
  List<Object?> get props => [name, phone, interestedPlan, loggedByTrainer];
}

class ConvertEnquiryToMemberEvent extends SmartGymEvent {
  final int enquiryIndex;
  const ConvertEnquiryToMemberEvent(this.enquiryIndex);

  @override
  List<Object?> get props => [enquiryIndex];
}

class MarkTrainerDutyCheckInEvent extends SmartGymEvent {
  final int trainerIndex;
  const MarkTrainerDutyCheckInEvent(this.trainerIndex);

  @override
  List<Object?> get props => [trainerIndex];
}

class UpdateMemberWeightEvent extends SmartGymEvent {
  final String memberId;
  final double newWeightKg;

  const UpdateMemberWeightEvent({
    required this.memberId,
    required this.newWeightKg,
  });

  @override
  List<Object?> get props => [memberId, newWeightKg];
}

class AddMachineGuideEvent extends SmartGymEvent {
  final String code;
  final String name;
  final String muscle;
  final String mistakeTip;

  const AddMachineGuideEvent({
    required this.code,
    required this.name,
    required this.muscle,
    required this.mistakeTip,
  });

  @override
  List<Object?> get props => [code, name, muscle, mistakeTip];
}

// --- CUSTOMER & SHARED EVENTS ---

class ToggleMembershipExpiryDemoEvent extends SmartGymEvent {
  const ToggleMembershipExpiryDemoEvent();
}

class SimulateQrCheckInEvent extends SmartGymEvent {
  const SimulateQrCheckInEvent();
}

class RenewMembershipViaUpiEvent extends SmartGymEvent {
  final bool unlockPt;
  const RenewMembershipViaUpiEvent({this.unlockPt = false});

  @override
  List<Object?> get props => [unlockPt];
}

class TogglePeakCrowdSimulationEvent extends SmartGymEvent {
  const TogglePeakCrowdSimulationEvent();
}

class TogglePtLockDemoEvent extends SmartGymEvent {
  final bool? forceUnlocked;
  const TogglePtLockDemoEvent({this.forceUnlocked});

  @override
  List<Object?> get props => [forceUnlocked];
}

class RefillWheyTubEvent extends SmartGymEvent {
  const RefillWheyTubEvent();
}

class ToggleVacationFreezeEvent extends SmartGymEvent {
  final bool isFrozen;
  const ToggleVacationFreezeEvent(this.isFrozen);

  @override
  List<Object?> get props => [isFrozen];
}

class ReviewClientMealEvent extends SmartGymEvent {
  final int mealIndex;
  final String feedback;

  const ReviewClientMealEvent({
    required this.mealIndex,
    required this.feedback,
  });

  @override
  List<Object?> get props => [mealIndex, feedback];
}

class RescueMissingMemberEvent extends SmartGymEvent {
  final int memberIndex;
  const RescueMissingMemberEvent(this.memberIndex);

  @override
  List<Object?> get props => [memberIndex];
}
