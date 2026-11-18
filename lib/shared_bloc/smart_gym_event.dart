import 'package:equatable/equatable.dart';
import '../domain/models/gym_member.dart';
import '../domain/models/gym_tenant.dart';
import '../domain/models/machine_guide.dart';
import '../domain/models/meal_review_item.dart';
import '../domain/models/missing_member.dart';
import '../domain/models/partner_role.dart';
import '../domain/models/trainer_join_request.dart';
import '../domain/models/trainer_profile.dart';
import '../domain/models/walk_in_enquiry.dart';

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

// --- LIVE FIRESTORE AUTH, ONBOARDING & STREAM SYNC EVENTS ---

class CheckAuthSessionEvent extends SmartGymEvent {
  const CheckAuthSessionEvent();
}

class RefreshGymDataEvent extends SmartGymEvent {
  const RefreshGymDataEvent();
}

class CreateNewGymOnboardingEvent extends SmartGymEvent {
  final String gymName;
  final String area;
  final String ownerName;
  final int monthlyFee;
  final int ptFee;

  const CreateNewGymOnboardingEvent({
    required this.gymName,
    required this.area,
    required this.ownerName,
    this.monthlyFee = 1500,
    this.ptFee = 6000,
  });

  @override
  List<Object?> get props => [gymName, area, ownerName, monthlyFee, ptFee];
}

class AddTrainerToGymEvent extends SmartGymEvent {
  final String name;
  final String phone;
  final String specialty;

  const AddTrainerToGymEvent({
    required this.name,
    required this.phone,
    this.specialty = 'Floor & Transformation Coach',
  });

  @override
  List<Object?> get props => [name, phone, specialty];
}

class JoinGymWithInviteQrEvent extends SmartGymEvent {
  final String gymId;
  final String inviteCode;
  final String trainerName;

  const JoinGymWithInviteQrEvent({
    required this.gymId,
    required this.inviteCode,
    required this.trainerName,
  });

  @override
  List<Object?> get props => [gymId, inviteCode, trainerName];
}

class RemoveTrainerFromGymEvent extends SmartGymEvent {
  final String trainerId;
  final String phone;
  final String trainerName;

  const RemoveTrainerFromGymEvent({
    required this.trainerId,
    required this.phone,
    required this.trainerName,
  });

  @override
  List<Object?> get props => [trainerId, phone, trainerName];
}

class RemoveMemberFromGymEvent extends SmartGymEvent {
  final String memberId;
  final String phone;
  final String memberName;

  const RemoveMemberFromGymEvent({
    required this.memberId,
    required this.phone,
    required this.memberName,
  });

  @override
  List<Object?> get props => [memberId, phone, memberName];
}

class SyncGymTenantEvent extends SmartGymEvent {
  final GymTenant gym;
  const SyncGymTenantEvent(this.gym);

  @override
  List<Object?> get props => [gym];
}

class SyncMembersEvent extends SmartGymEvent {
  final List<GymMember> members;
  const SyncMembersEvent(this.members);

  @override
  List<Object?> get props => [members];
}

class SyncTrainersEvent extends SmartGymEvent {
  final List<TrainerProfile> trainers;
  const SyncTrainersEvent(this.trainers);

  @override
  List<Object?> get props => [trainers];
}

class SyncEnquiriesEvent extends SmartGymEvent {
  final List<WalkInEnquiry> enquiries;
  const SyncEnquiriesEvent(this.enquiries);

  @override
  List<Object?> get props => [enquiries];
}

class SyncMachinesEvent extends SmartGymEvent {
  final List<MachineGuide> machines;
  const SyncMachinesEvent(this.machines);

  @override
  List<Object?> get props => [machines];
}

class SyncMealsEvent extends SmartGymEvent {
  final List<MealReviewItem> meals;
  const SyncMealsEvent(this.meals);

  @override
  List<Object?> get props => [meals];
}

class SyncMissingMembersEvent extends SmartGymEvent {
  final List<MissingMember> missingMembers;
  const SyncMissingMembersEvent(this.missingMembers);

  @override
  List<Object?> get props => [missingMembers];
}

class SyncTrainerRequestsEvent extends SmartGymEvent {
  final List<TrainerJoinRequest> requests;
  const SyncTrainerRequestsEvent(this.requests);

  @override
  List<Object?> get props => [requests];
}

class ApproveTrainerRequestEvent extends SmartGymEvent {
  final TrainerJoinRequest request;
  const ApproveTrainerRequestEvent(this.request);

  @override
  List<Object?> get props => [request];
}

class RejectTrainerRequestEvent extends SmartGymEvent {
  final String requestId;
  const RejectTrainerRequestEvent(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class CancelPendingRequestEvent extends SmartGymEvent {
  const CancelPendingRequestEvent();
}
