import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/gym_repository.dart';
import '../data/services/firestore_service.dart';
import '../domain/models/gym_member.dart';
import '../domain/models/gym_tenant.dart';
import '../domain/models/machine_guide.dart';
import '../domain/models/meal_review_item.dart';
import '../domain/models/missing_member.dart';
import '../domain/models/partner_role.dart';
import '../domain/models/removed_record.dart';
import '../domain/models/trainer_join_request.dart';
import '../domain/models/trainer_profile.dart';
import '../domain/models/walk_in_enquiry.dart';
import 'smart_gym_event.dart';
import 'smart_gym_state.dart';

class SmartGymBloc extends Bloc<SmartGymEvent, SmartGymState> {
  final GymRepository repository;
  final FirestoreService? firestoreService;

  StreamSubscription<GymTenant?>? _gymSub;
  StreamSubscription<List<GymMember>>? _membersSub;
  StreamSubscription<List<TrainerProfile>>? _trainersSub;
  StreamSubscription<List<WalkInEnquiry>>? _enquiriesSub;
  StreamSubscription<List<MachineGuide>>? _machinesSub;
  StreamSubscription<List<MealReviewItem>>? _mealsSub;
  StreamSubscription<List<MissingMember>>? _missingSub;
  StreamSubscription<List<TrainerJoinRequest>>? _requestsSub;
  StreamSubscription<PhoneLookupResult?>? _phoneSub;
  StreamSubscription<PhoneLookupResult?>? _onboardingPhoneSub;
  StreamSubscription<List<RemovedRecord>>? _removedSub;

  SmartGymBloc({
    required this.repository,
    this.firestoreService,
  }) : super(
          firestoreService == null
              ? SmartGymState(
                  gyms: repository.getInitialGyms(),
                  members: repository.getInitialMembers(),
                  trainers: repository.getInitialTrainers(),
                  enquiries: repository.getInitialEnquiries(),
                  machineGuides: repository.getMachineGuides(),
                  mealQueue: repository.getInitialMealQueue(),
                  missingMembers: repository.getInitialMissingMembers(),
                )
              : const SmartGymState(
                  isAuthChecking: true,
                  gyms: [],
                  members: [],
                  trainers: [],
                  enquiries: [],
                  machineGuides: [],
                  mealQueue: [],
                  missingMembers: [],
                ),
        ) {
    on<CheckAuthSessionEvent>(_onCheckAuthSession);
    on<RefreshGymDataEvent>(_onRefreshGymData);
    on<CreateNewGymOnboardingEvent>(_onCreateNewGymOnboarding);
    on<AddTrainerToGymEvent>(_onAddTrainerToGym);
    on<JoinGymWithInviteQrEvent>(_onJoinGymWithInviteQr);
    on<RemoveTrainerFromGymEvent>(_onRemoveTrainerFromGym);
    on<RemoveMemberFromGymEvent>(_onRemoveMemberFromGym);
    on<SyncGymTenantEvent>(_onSyncGymTenant);
    on<SyncMembersEvent>((e, emit) => emit(state.copyWith(members: e.members)));
    on<SyncTrainersEvent>(
        (e, emit) => emit(state.copyWith(trainers: e.trainers)));
    on<SyncEnquiriesEvent>(
        (e, emit) => emit(state.copyWith(enquiries: e.enquiries)));
    on<SyncMachinesEvent>(
        (e, emit) => emit(state.copyWith(machineGuides: e.machines)));
    on<SyncMealsEvent>((e, emit) => emit(state.copyWith(mealQueue: e.meals)));
    on<SyncMissingMembersEvent>(
        (e, emit) => emit(state.copyWith(missingMembers: e.missingMembers)));
    on<SyncTrainerRequestsEvent>(
        (e, emit) => emit(state.copyWith(trainerRequests: e.requests)));
    on<ApproveTrainerRequestEvent>(_onApproveTrainerRequest);
    on<RejectTrainerRequestEvent>(_onRejectTrainerRequest);
    on<CancelPendingRequestEvent>(_onCancelPendingRequest);
    on<SyncRemovedRecordsEvent>(
        (e, emit) => emit(state.copyWith(removedRecords: e.records)));
    on<UpdateGymSettingsEvent>(_onUpdateGymSettings);
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

    if (firestoreService != null) {
      add(const CheckAuthSessionEvent());
    }
  }

  Future<void> _cancelSubscriptions() async {
    final oldSubs = [
      _gymSub,
      _membersSub,
      _trainersSub,
      _enquiriesSub,
      _machinesSub,
      _mealsSub,
      _missingSub,
      _requestsSub,
      _phoneSub,
      _onboardingPhoneSub,
      _removedSub,
    ];
    _gymSub = null;
    _membersSub = null;
    _trainersSub = null;
    _enquiriesSub = null;
    _machinesSub = null;
    _mealsSub = null;
    _missingSub = null;
    _requestsSub = null;
    _phoneSub = null;
    _onboardingPhoneSub = null;
    _removedSub = null;
    await Future.wait(
      oldSubs.whereType<StreamSubscription<dynamic>>().map((s) => s.cancel()),
    );
  }

  void _subscribeToGym(String gymId) {
    final fs = firestoreService;
    if (fs == null || gymId.isEmpty) return;
    _cancelSubscriptions();
    _gymSub = fs.watchGym(gymId).listen((gym) {
      if (gym != null) add(SyncGymTenantEvent(gym));
    });
    _membersSub =
        fs.watchMembers(gymId).listen((list) => add(SyncMembersEvent(list)));
    _trainersSub =
        fs.watchTrainers(gymId).listen((list) => add(SyncTrainersEvent(list)));
    _enquiriesSub = fs
        .watchEnquiries(gymId)
        .listen((list) => add(SyncEnquiriesEvent(list)));
    _machinesSub =
        fs.watchMachines(gymId).listen((list) => add(SyncMachinesEvent(list)));
    _mealsSub =
        fs.watchMeals(gymId).listen((list) => add(SyncMealsEvent(list)));
    _missingSub = fs
        .watchMissingMembers(gymId)
        .listen((list) => add(SyncMissingMembersEvent(list)));
    _requestsSub = fs.watchTrainerRequests(gymId).listen(
          (list) => add(SyncTrainerRequestsEvent(list)),
          onError: (_) {},
        );
    _removedSub = fs.watchRemovedLogs(gymId).listen(
          (list) => add(SyncRemovedRecordsEvent(list)),
          onError: (_) {},
        );
    final phone = fs.currentUser?.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      _phoneSub = fs.watchPhoneLookup(phone).listen(
        (lookup) {
          if (lookup == null) {
            add(const LogoutPartnerEvent());
          }
        },
        onError: (_) {},
      );
    }
  }

  @override
  Future<void> close() async {
    await _cancelSubscriptions();
    return super.close();
  }

  Future<void> _onRefreshGymData(
    RefreshGymDataEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null) return;
    final phone = fs.currentUser?.phoneNumber ?? '';
    if (phone.isNotEmpty) {
      try {
        final lookup = await fs.lookupPhone(phone);
        if (lookup == null || lookup.gymId.isEmpty) {
          add(const LogoutPartnerEvent());
          return;
        }
      } catch (_) {}
    }
    final gymId = state.currentGym.id;
    if (gymId.isNotEmpty) {
      _subscribeToGym(gymId);
    }
  }

  void _onSyncGymTenant(
    SyncGymTenantEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final existingIndex = state.gyms.indexWhere((g) => g.id == event.gym.id);
    if (existingIndex == -1) {
      emit(state.copyWith(gyms: [event.gym], selectedGymIndex: 0));
    } else {
      final updated = List<GymTenant>.from(state.gyms);
      updated[existingIndex] = event.gym;
      emit(state.copyWith(gyms: updated));
    }
  }

  void _watchOnboardingApproval(String phone) {
    final fs = firestoreService;
    if (fs == null || phone.isEmpty) return;
    _onboardingPhoneSub?.cancel();
    _onboardingPhoneSub = fs.watchPhoneLookup(phone).listen(
      (lookup) {
        if (lookup != null && lookup.gymId.isNotEmpty) {
          _onboardingPhoneSub?.cancel();
          _onboardingPhoneSub = null;
          add(const CheckAuthSessionEvent());
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _onCheckAuthSession(
    CheckAuthSessionEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null) {
      emit(state.copyWith(isAuthChecking: false));
      return;
    }
    final user = fs.currentUser;
    final phone = user?.phoneNumber ?? '';
    if (user == null || phone.isEmpty) {
      emit(state.copyWith(
        isAuthChecking: false,
        isPartnerLoggedIn: false,
        needsOnboarding: false,
      ));
      return;
    }
    try {
      final lookup = await fs.lookupPhone(phone);
      if (lookup == null || lookup.gymId.isEmpty) {
        final pendingGymName = await fs.lookupPendingGymName(phone);
        _watchOnboardingApproval(phone);
        emit(state.copyWith(
          isAuthChecking: false,
          isPartnerLoggedIn: false,
          needsOnboarding: true,
          authenticatedPhone: phone,
          pendingApprovalGymName: pendingGymName,
          clearPendingApproval: pendingGymName == null,
        ));
        return;
      }
      _subscribeToGym(lookup.gymId);
      emit(state.copyWith(
        isAuthChecking: false,
        isPartnerLoggedIn: true,
        needsOnboarding: false,
        authenticatedPhone: phone,
        partnerRole: lookup.role == 'trainer'
            ? PartnerRole.trainer
            : PartnerRole.owner,
        loggedInTrainerName: lookup.name.isEmpty ? 'Partner' : lookup.name,
      ));
    } catch (_) {
      emit(state.copyWith(
        isAuthChecking: false,
        isPartnerLoggedIn: false,
      ));
    }
  }

  Future<void> _onCreateNewGymOnboarding(
    CreateNewGymOnboardingEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null) return;
    emit(state.copyWith(isOnboardingBusy: true, clearAuthError: true));
    try {
      final phone =
          state.authenticatedPhone.isNotEmpty ? state.authenticatedPhone : (fs.currentUser?.phoneNumber ?? '');
      final gymId = await fs.createNewGym(
        gymName: event.gymName,
        area: event.area,
        ownerName: event.ownerName,
        ownerPhone: phone,
        monthlyFee: event.monthlyFee,
        ptFee: event.ptFee,
      );
      _subscribeToGym(gymId);
      emit(state.copyWith(
        isOnboardingBusy: false,
        needsOnboarding: false,
        isPartnerLoggedIn: true,
        partnerRole: PartnerRole.owner,
        loggedInTrainerName: event.ownerName.trim(),
      ));
    } catch (e) {
      emit(state.copyWith(
        isOnboardingBusy: false,
        authError: 'Could not register gym: $e',
      ));
    }
  }

  Future<void> _onAddTrainerToGym(
    AddTrainerToGymEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null || state.currentGym.id.isEmpty) return;
    await fs.addTrainerToGym(
      gymId: state.currentGym.id,
      name: event.name,
      phone: event.phone,
      specialty: event.specialty,
      shiftSlot: event.shiftSlot,
    );
  }

  Future<void> _onJoinGymWithInviteQr(
    JoinGymWithInviteQrEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null) return;
    emit(state.copyWith(isOnboardingBusy: true, clearAuthError: true));
    try {
      final phone = state.authenticatedPhone.isNotEmpty
          ? state.authenticatedPhone
          : (fs.currentUser?.phoneNumber ?? '');
      final gymName = await fs.submitTrainerJoinRequest(
        gymId: event.gymId,
        inviteCode: event.inviteCode,
        trainerName: event.trainerName,
        trainerPhone: phone,
      );
      emit(state.copyWith(
        isOnboardingBusy: false,
        needsOnboarding: true,
        isPartnerLoggedIn: false,
        pendingApprovalGymName: gymName,
      ));
    } catch (e) {
      emit(state.copyWith(
        isOnboardingBusy: false,
        authError: 'Could not send join request: $e',
      ));
    }
  }

  Future<void> _onApproveTrainerRequest(
    ApproveTrainerRequestEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null || state.currentGym.id.isEmpty) return;
    await fs.approveTrainerRequest(
      gymId: state.currentGym.id,
      request: event.request,
    );
  }

  Future<void> _onRejectTrainerRequest(
    RejectTrainerRequestEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null || state.currentGym.id.isEmpty) return;
    await fs.rejectTrainerRequest(
      gymId: state.currentGym.id,
      requestId: event.requestId,
    );
  }

  Future<void> _onCancelPendingRequest(
    CancelPendingRequestEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    final phone = state.authenticatedPhone.isNotEmpty
        ? state.authenticatedPhone
        : (fs?.currentUser?.phoneNumber ?? '');
    if (fs != null && phone.isNotEmpty) {
      await fs.clearPendingRequest(phone);
    }
    emit(state.copyWith(clearPendingApproval: true));
  }

  Future<void> _onRemoveTrainerFromGym(
    RemoveTrainerFromGymEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final updated =
        state.trainers.where((t) => t.id != event.trainerId).toList();
    final record = RemovedRecord(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      type: 'trainer',
      name: event.trainerName,
      phone: event.phone,
      details: event.details,
    );
    emit(state.copyWith(
      trainers: updated,
      removedRecords: [record, ...state.removedRecords],
    ));
    _syncAsync(
      () => firestoreService!.removeTrainerFromGym(
        gymId: state.currentGym.id,
        trainerId: event.trainerId,
        phone: event.phone,
        name: event.trainerName,
        details: event.details,
      ),
    );
  }

  Future<void> _onRemoveMemberFromGym(
    RemoveMemberFromGymEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final updated =
        state.members.where((m) => m.id != event.memberId).toList();
    final record = RemovedRecord(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      type: 'member',
      name: event.memberName,
      phone: event.phone,
      details: event.details,
    );
    emit(state.copyWith(
      members: updated,
      removedRecords: [record, ...state.removedRecords],
    ));
    _syncAsync(
      () => firestoreService!.removeMemberFromGym(
        gymId: state.currentGym.id,
        memberId: event.memberId,
        phone: event.phone,
        name: event.memberName,
        details: event.details,
      ),
    );
  }

  Future<void> _onUpdateGymSettings(
    UpdateGymSettingsEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    if (state.gyms.isEmpty) return;
    final current = state.currentGym;
    final updatedGyms = List<GymTenant>.from(state.gyms);
    updatedGyms[state.selectedGymIndex] = current.copyWith(
      name: event.name.trim().isEmpty ? current.name : event.name.trim(),
      area: event.area.trim().isEmpty ? current.area : event.area.trim(),
      monthlyFee: event.monthlyFee,
      ptFee: event.ptFee,
      maxCapacity: event.maxCapacity,
    );
    emit(state.copyWith(gyms: updatedGyms));
    _syncAsync(
      () => firestoreService!.updateGymSettings(
        gymId: current.id,
        name: event.name,
        area: event.area,
        monthlyFee: event.monthlyFee,
        ptFee: event.ptFee,
        maxCapacity: event.maxCapacity,
      ),
    );
  }

  void _syncAsync(Future<void> Function() task) {
    if (firestoreService == null) return;
    task().catchError((_) {});
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

  Future<void> _onLoginPartner(
    LoginPartnerEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    final fs = firestoreService;
    if (fs == null) {
      // Offline / widget-test mode
      emit(
        state.copyWith(
          isPartnerLoggedIn: true,
          partnerRole: event.role,
          loggedInTrainerName: event.trainerName ?? state.currentGym.headTrainer,
        ),
      );
      return;
    }

    emit(state.copyWith(isAuthChecking: true, clearAuthError: true));
    try {
      final lookup = await fs.lookupPhone(event.phone);
      if (lookup == null || lookup.gymId.isEmpty) {
        final pendingGymName = await fs.lookupPendingGymName(event.phone);
        _watchOnboardingApproval(event.phone);
        emit(state.copyWith(
          isAuthChecking: false,
          isPartnerLoggedIn: false,
          needsOnboarding: true,
          authenticatedPhone: event.phone,
          pendingApprovalGymName: pendingGymName,
          clearPendingApproval: pendingGymName == null,
        ));
        return;
      }
      _subscribeToGym(lookup.gymId);
      emit(
        state.copyWith(
          isAuthChecking: false,
          isPartnerLoggedIn: true,
          needsOnboarding: false,
          authenticatedPhone: event.phone,
          partnerRole: lookup.role == 'trainer'
              ? PartnerRole.trainer
              : PartnerRole.owner,
          loggedInTrainerName: lookup.name.isEmpty ? 'Partner' : lookup.name,
        ),
      );
    } catch (e) {
      emit(state.copyWith(
        isAuthChecking: false,
        authError: 'Could not verify account: $e',
      ));
    }
  }

  Future<void> _onLogoutPartner(
    LogoutPartnerEvent event,
    Emitter<SmartGymState> emit,
  ) async {
    await _cancelSubscriptions();
    if (firestoreService != null) {
      try {
        await firestoreService!.signOut();
      } catch (_) {}
      emit(
        state.copyWith(
          isPartnerLoggedIn: false,
          needsOnboarding: false,
          authenticatedPhone: '',
          gyms: const [],
          members: const [],
          trainers: const [],
          enquiries: const [],
          machineGuides: const [],
          mealQueue: const [],
          missingMembers: const [],
          trainerRequests: const [],
          removedRecords: const [],
        ),
      );
    } else {
      emit(state.copyWith(isPartnerLoggedIn: false));
    }
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
      joinedDate: event.joinedDate ?? 'Just Now',
      expiryDate: event.expiryDate ?? '${event.daysValid}d from today',
      daysLeft: event.daysValid,
      assignedTrainer: event.assignedTrainer,
      isPtClient: event.isPtClient,
      addedByTrainer: event.addedByTrainer,
      currentWeightKg: event.currentWeightKg,
      paymentMode: event.paymentMode,
      paymentReference: event.paymentReference,
      paymentProofBase64: event.paymentProofBase64,
    );
    final updated = [newMember, ...state.members];
    emit(state.copyWith(members: updated));
    _syncAsync(() => firestoreService!.addMember(state.currentGym.id, newMember));
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
    _syncAsync(() => firestoreService!.addEnquiry(state.currentGym.id, newEnq));
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
    _syncAsync(() async {
      await firestoreService!.markEnquiryConverted(state.currentGym.id, enq.id);
      await firestoreService!.addMember(state.currentGym.id, convertedMember);
    });
  }

  void _onMarkTrainerDutyCheckIn(
    MarkTrainerDutyCheckInEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final updated = List<TrainerProfile>.from(state.trainers);
    final trainer = updated[event.trainerIndex];
    updated[event.trainerIndex] = trainer.copyWith(
      isOnDuty: true,
      morningCheckInTime: 'Checked In Now',
    );
    emit(state.copyWith(trainers: updated));
    _syncAsync(
      () => firestoreService!.markTrainerDuty(
        state.currentGym.id,
        trainer.id,
        'Checked In Now',
      ),
    );
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
    _syncAsync(
      () => firestoreService!.updateMemberWeight(
        state.currentGym.id,
        event.memberId,
        event.newWeightKg,
      ),
    );
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
    _syncAsync(
      () => firestoreService!.addMachineGuide(state.currentGym.id, nextGuide),
    );
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
    final meal = updatedMeals[event.mealIndex];
    updatedMeals[event.mealIndex] = meal.copyWith(
      trainerFeedback: event.feedback,
    );
    emit(state.copyWith(mealQueue: updatedMeals));
    _syncAsync(
      () => firestoreService!.updateMealFeedback(
        state.currentGym.id,
        meal.id,
        event.feedback,
      ),
    );
  }

  void _onRescueMissingMember(
    RescueMissingMemberEvent event,
    Emitter<SmartGymState> emit,
  ) {
    final updatedMembers = List<MissingMember>.from(state.missingMembers);
    final missing = updatedMembers[event.memberIndex];
    updatedMembers[event.memberIndex] = missing.copyWith(contacted: true);
    emit(state.copyWith(missingMembers: updatedMembers));
    _syncAsync(
      () => firestoreService!.markMissingMemberContacted(
        state.currentGym.id,
        missing.id,
      ),
    );
  }
}
