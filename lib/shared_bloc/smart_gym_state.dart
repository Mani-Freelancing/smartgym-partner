import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
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

class SmartGymState extends Equatable {
  final List<GymTenant> gyms;
  final int selectedGymIndex;
  final bool isAuthChecking;
  final bool isPartnerLoggedIn;
  final bool needsOnboarding;
  final bool isOnboardingBusy;
  final String authenticatedPhone;
  final String? authError;
  final PartnerRole partnerRole;
  final String loggedInTrainerName;
  final List<GymMember> members;
  final List<TrainerProfile> trainers;
  final List<WalkInEnquiry> enquiries;
  final bool isMembershipExpired;
  final bool isPtUnlocked;
  final bool isMembershipFrozen;
  final int freezeDaysLeft;
  final int wheyScoopsLeft;
  final int streakDays;
  final int crowdDelta;
  final List<MachineGuide> machineGuides;
  final List<MealReviewItem> mealQueue;
  final List<MissingMember> missingMembers;
  final List<TrainerJoinRequest> trainerRequests;
  final String? pendingApprovalGymName;
  final List<RemovedRecord> removedRecords;

  const SmartGymState({
    required this.gyms,
    this.selectedGymIndex = 0,
    this.isAuthChecking = false,
    this.isPartnerLoggedIn = false,
    this.needsOnboarding = false,
    this.isOnboardingBusy = false,
    this.authenticatedPhone = '',
    this.authError,
    this.partnerRole = PartnerRole.owner,
    this.loggedInTrainerName = '',
    required this.members,
    required this.trainers,
    required this.enquiries,
    this.isMembershipExpired = false,
    this.isPtUnlocked = false,
    this.isMembershipFrozen = false,
    this.freezeDaysLeft = 15,
    this.wheyScoopsLeft = 5,
    this.streakDays = 21,
    this.crowdDelta = 0,
    required this.machineGuides,
    required this.mealQueue,
    required this.missingMembers,
    this.trainerRequests = const [],
    this.pendingApprovalGymName,
    this.removedRecords = const [],
  });

  static const GymTenant emptyGym = GymTenant(
    id: '',
    name: 'SmartGym Partner',
    area: '',
    headTrainer: '',
    brandColor: Color(0xFFE5C158),
    activeCrowd: 0,
    maxCapacity: 60,
    monthlyFee: 1500,
    ptFee: 6000,
  );

  GymTenant get currentGym =>
      (gyms.isNotEmpty && selectedGymIndex < gyms.length)
          ? gyms[selectedGymIndex]
          : emptyGym;

  int get liveCrowd =>
      (currentGym.activeCrowd + crowdDelta).clamp(0, currentGym.maxCapacity);

  // Computed Owner CEO metrics (100% live from real members)
  int get totalMonthlyRevenue =>
      members.fold<int>(0, (sum, m) => sum + m.feePaid);

  int get activeMembersCount => members.where((m) => !m.isExpired).length;

  List<GymMember> get expiringOrExpiredMembers =>
      members.where((m) => m.daysLeft <= 5).toList();

  List<GymMember> get ptMembers =>
      members.where((m) => m.isPtClient).toList();

  SmartGymState copyWith({
    List<GymTenant>? gyms,
    int? selectedGymIndex,
    bool? isAuthChecking,
    bool? isPartnerLoggedIn,
    bool? needsOnboarding,
    bool? isOnboardingBusy,
    String? authenticatedPhone,
    String? authError,
    bool clearAuthError = false,
    PartnerRole? partnerRole,
    String? loggedInTrainerName,
    List<GymMember>? members,
    List<TrainerProfile>? trainers,
    List<WalkInEnquiry>? enquiries,
    bool? isMembershipExpired,
    bool? isPtUnlocked,
    bool? isMembershipFrozen,
    int? freezeDaysLeft,
    int? wheyScoopsLeft,
    int? streakDays,
    int? crowdDelta,
    List<MachineGuide>? machineGuides,
    List<MealReviewItem>? mealQueue,
    List<MissingMember>? missingMembers,
    List<TrainerJoinRequest>? trainerRequests,
    String? pendingApprovalGymName,
    bool clearPendingApproval = false,
    List<RemovedRecord>? removedRecords,
  }) {
    return SmartGymState(
      gyms: gyms ?? this.gyms,
      selectedGymIndex: selectedGymIndex ?? this.selectedGymIndex,
      isAuthChecking: isAuthChecking ?? this.isAuthChecking,
      isPartnerLoggedIn: isPartnerLoggedIn ?? this.isPartnerLoggedIn,
      needsOnboarding: needsOnboarding ?? this.needsOnboarding,
      isOnboardingBusy: isOnboardingBusy ?? this.isOnboardingBusy,
      authenticatedPhone: authenticatedPhone ?? this.authenticatedPhone,
      authError: clearAuthError ? null : (authError ?? this.authError),
      partnerRole: partnerRole ?? this.partnerRole,
      loggedInTrainerName: loggedInTrainerName ?? this.loggedInTrainerName,
      members: members ?? this.members,
      trainers: trainers ?? this.trainers,
      enquiries: enquiries ?? this.enquiries,
      isMembershipExpired: isMembershipExpired ?? this.isMembershipExpired,
      isPtUnlocked: isPtUnlocked ?? this.isPtUnlocked,
      isMembershipFrozen: isMembershipFrozen ?? this.isMembershipFrozen,
      freezeDaysLeft: freezeDaysLeft ?? this.freezeDaysLeft,
      wheyScoopsLeft: wheyScoopsLeft ?? this.wheyScoopsLeft,
      streakDays: streakDays ?? this.streakDays,
      crowdDelta: crowdDelta ?? this.crowdDelta,
      machineGuides: machineGuides ?? this.machineGuides,
      mealQueue: mealQueue ?? this.mealQueue,
      missingMembers: missingMembers ?? this.missingMembers,
      trainerRequests: trainerRequests ?? this.trainerRequests,
      pendingApprovalGymName: clearPendingApproval
          ? null
          : (pendingApprovalGymName ?? this.pendingApprovalGymName),
      removedRecords: removedRecords ?? this.removedRecords,
    );
  }

  @override
  List<Object?> get props => [
        gyms,
        selectedGymIndex,
        isAuthChecking,
        isPartnerLoggedIn,
        needsOnboarding,
        isOnboardingBusy,
        authenticatedPhone,
        authError,
        partnerRole,
        loggedInTrainerName,
        members,
        trainers,
        enquiries,
        isMembershipExpired,
        isPtUnlocked,
        isMembershipFrozen,
        freezeDaysLeft,
        wheyScoopsLeft,
        streakDays,
        crowdDelta,
        machineGuides,
        mealQueue,
        missingMembers,
        trainerRequests,
        pendingApprovalGymName,
        removedRecords,
      ];
}
