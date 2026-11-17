import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/gym_repository.dart';
import '../domain/models/gym_member.dart';
import '../domain/models/gym_tenant.dart';
import '../domain/models/machine_guide.dart';
import '../domain/models/meal_review_item.dart';
import '../domain/models/missing_member.dart';
import '../domain/models/trainer_profile.dart';
import '../domain/models/walk_in_enquiry.dart';
import 'smart_gym_event.dart';
import 'smart_gym_state.dart';

class SmartGymBloc extends Bloc<SmartGymEvent, SmartGymState> {
  final GymRepository repository;

  SmartGymBloc({required this.repository})
      : super(
          SmartGymState(
            gyms: repository.getInitialGyms(),
            members: repository.getInitialMembers(),
            trainers: repository.getInitialTrainers(),
            enquiries: repository.getInitialEnquiries(),
            machineGuides: repository.getMachineGuides(),
            mealQueue: repository.getInitialMealQueue(),
            missingMembers: repository.getInitialMissingMembers(),
          ),
        ) {
    on<SelectGymTenantEvent>(_onSelectGymTenant);
    on<CustomizeCurrentGymEvent>(_onCustomizeCurrentGym);
    on<SwitchPartnerRoleEvent>(_onSwitchPartnerRole);
    on<LoginPartnerEvent>(_onLoginPartner);
    on<LogoutPartnerEvent>(_onLogoutPartner);
    on<AddNewGymMemberEvent>(_onAddNewGymMember);
    on<AddWalkInEnquiryEvent>(_onAddWalkInEnquiry);
    on<ConvertEnquiryToMemberEvent>(_onConvertEnquiryToMember);
    on<MarkTrainerDutyCheckInEvent>(_onMarkTrainerDutyCheckIn);
    on<UpdateMemberWeightEvent>(_onUpdateMemberWeight);
    on<AddMachineGuideEvent>(_onAddMachineGuide);
    on<ToggleMembershipExpiryDemoEvent>(_onToggleMembershipExpiryDemo);
    on<SimulateQrCheckInEvent>(_onSimulateQrCheckIn);
    on<RenewMembershipViaUpiEvent>(_onRenewMembershipViaUpi);
    on<TogglePeakCrowdSimulationEvent>(_onTogglePeakCrowdSimulation);
    on<TogglePtLockDemoEvent>(_onTogglePtLockDemo);
    on<RefillWheyTubEvent>(_onRefillWheyTub);
    on<ToggleVacationFreezeEvent>(_onToggleVacationFreeze);
    on<ReviewClientMealEvent>(_onReviewClientMeal);
    on<RescueMissingMemberEvent>(_onRescueMissingMember);
  }

  void _onSelectGymTenant(
    SelectGymTenantEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(state.copyWith(selectedGymIndex: event.gymIndex, crowdDelta: 0));
  }

  void _onCustomizeCurrentGym(
    CustomizeCurrentGymEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final updatedGyms = List<GymTenant>.from(state.gyms);
    final current = state.currentGym;
    updatedGyms[state.selectedGymIndex] = current.copyWith(
      name: event.name.trim().isEmpty ? current.name : event.name.trim(),
      area: event.area.trim().isEmpty ? current.area : event.area.trim(),
      headTrainer: event.headTrainer.trim().isEmpty
          ? current.headTrainer
          : event.headTrainer.trim(),
    );
    emit(state.copyWith(gyms: updatedGyms));
  }

  void _onSwitchPartnerRole(
    SwitchPartnerRoleEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(state.copyWith(partnerRole: event.role));
  }

  void _onLoginPartner(
    LoginPartnerEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(
      state.copyWith(
        isPartnerLoggedIn: true,
        partnerRole: event.role,
        loggedInTrainerName:
            event.trainerName ?? state.currentGym.headTrainer,
      ),
    );
  }

  void _onLogoutPartner(
    LogoutPartnerEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(state.copyWith(isPartnerLoggedIn: false));
  }

  void _onAddNewGymMember(
    AddNewGymMemberEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final newMember = GymMember(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      name: event.name.trim(),
      phone: event.phone.trim(),
      planTitle: event.planTitle,
      feePaid: event.feePaid,
      joinedDate: 'Just Now',
      expiryDate: '${event.daysValid}d from today',
      daysLeft: event.daysValid,
      assignedTrainer: event.assignedTrainer,
      isPtClient: event.isPtClient,
      addedByTrainer: event.addedByTrainer,
    );
    final updated = [newMember, ...state.members];
    emit(state.copyWith(members: updated));
  }

  void _onAddWalkInEnquiry(
    AddWalkInEnquiryEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final newEnq = WalkInEnquiry(
      id: 'enq_${DateTime.now().millisecondsSinceEpoch}',
      name: event.name.trim(),
      phone: event.phone.trim(),
      interestedPlan: event.interestedPlan,
      loggedByTrainer: event.loggedByTrainer,
      timeLabel: 'Just Now',
    );
    emit(state.copyWith(enquiries: [newEnq, ...state.enquiries]));
  }

  void _onConvertEnquiryToMember(
    ConvertEnquiryToMemberEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final enq = state.enquiries[event.enquiryIndex];
    final updatedEnquiries = List<WalkInEnquiry>.from(state.enquiries);
    updatedEnquiries[event.enquiryIndex] = enq.copyWith(converted: true);

    final convertedMember = GymMember(
      id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
      name: enq.name,
      phone: enq.phone,
      planTitle: enq.interestedPlan,
      feePaid: state.currentGym.monthlyFee,
      joinedDate: 'Converted Today',
      expiryDate: '30d from today',
      daysLeft: 30,
      assignedTrainer: enq.loggedByTrainer,
      isPtClient: enq.interestedPlan.toLowerCase().contains('pt'),
      addedByTrainer: enq.loggedByTrainer,
    );

    emit(
      state.copyWith(
        enquiries: updatedEnquiries,
        members: [convertedMember, ...state.members],
      ),
    );
  }

  void _onMarkTrainerDutyCheckIn(
    MarkTrainerDutyCheckInEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final updated = List<TrainerProfile>.from(state.trainers);
    updated[event.trainerIndex] = updated[event.trainerIndex].copyWith(
      isOnDuty: true,
      morningCheckInTime: 'Checked In Now',
    );
    emit(state.copyWith(trainers: updated));
  }

  void _onUpdateMemberWeight(
    UpdateMemberWeightEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final updated = state.members.map((m) {
      if (m.id == event.memberId) {
        return m.copyWith(currentWeightKg: event.newWeightKg);
      }
      return m;
    }).toList();
    emit(state.copyWith(members: updated));
  }

  void _onAddMachineGuide(
    AddMachineGuideEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final nextGuide = MachineGuide(
      code: event.code.trim().isEmpty ? 'QR #19' : event.code.trim(),
      name: event.name.trim(),
      muscle: event.muscle.trim(),
      mistakeTip: event.mistakeTip.trim(),
    );
    emit(state.copyWith(machineGuides: [nextGuide, ...state.machineGuides]));
  }

  void _onToggleMembershipExpiryDemo(
    ToggleMembershipExpiryDemoEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(state.copyWith(isMembershipExpired: !state.isMembershipExpired));
  }

  void _onSimulateQrCheckIn(
    SimulateQrCheckInEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final nextScoops = state.wheyScoopsLeft > 1
        ? state.wheyScoopsLeft - 1
        : state.wheyScoopsLeft;
    emit(
      state.copyWith(
        streakDays: state.streakDays + 1,
        crowdDelta: state.crowdDelta + 1,
        wheyScoopsLeft: nextScoops,
      ),
    );
  }

  void _onRenewMembershipViaUpi(
    RenewMembershipViaUpiEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(
      state.copyWith(
        isMembershipExpired: false,
        isPtUnlocked: event.unlockPt ? true : state.isPtUnlocked,
      ),
    );
  }

  void _onTogglePeakCrowdSimulation(
    TogglePeakCrowdSimulationEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(state.copyWith(crowdDelta: state.crowdDelta == 0 ? 25 : 0));
  }

  void _onTogglePtLockDemo(
    TogglePtLockDemoEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(
      state.copyWith(
        isPtUnlocked: event.forceUnlocked ?? !state.isPtUnlocked,
      ),
    );
  }

  void _onRefillWheyTub(
    RefillWheyTubEvent event,
    Emitter<SmartGymState> emit,
  ) {
    emit(state.copyWith(wheyScoopsLeft: 30));
  }

  void _onToggleVacationFreeze(
    ToggleVacationFreezeEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final nextFreezeDays = (event.isFrozen && state.freezeDaysLeft > 0)
        ? state.freezeDaysLeft - 1
        : state.freezeDaysLeft;
    emit(
      state.copyWith(
        isMembershipFrozen: event.isFrozen,
        freezeDaysLeft: nextFreezeDays,
      ),
    );
  }

  void _onReviewClientMeal(
    ReviewClientMealEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final updatedMeals = List<MealReviewItem>.from(state.mealQueue);
    updatedMeals[event.mealIndex] = updatedMeals[event.mealIndex].copyWith(
      trainerFeedback: event.feedback,
    );
    emit(state.copyWith(mealQueue: updatedMeals));
  }

  void _onRescueMissingMember(
    RescueMissingMemberEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final updatedMembers = List<MissingMember>.from(state.missingMembers);
    updatedMembers[event.memberIndex] =
        updatedMembers[event.memberIndex].copyWith(contacted: true);
    emit(state.copyWith(missingMembers: updatedMembers));
  }
}
