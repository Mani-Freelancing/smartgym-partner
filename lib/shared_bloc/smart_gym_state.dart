import 'package:equatable/equatable.dart';
import '../domain/models/gym_member.dart';
import '../domain/models/gym_tenant.dart';
import '../domain/models/machine_guide.dart';
import '../domain/models/meal_review_item.dart';
import '../domain/models/missing_member.dart';
import '../domain/models/partner_role.dart';
import '../domain/models/trainer_profile.dart';
import '../domain/models/walk_in_enquiry.dart';

class SmartGymState extends Equatable {
  final List<GymTenant> gyms;
  final int selectedGymIndex;
  final bool isPartnerLoggedIn;
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

  const SmartGymState({
    required this.gyms,
    this.selectedGymIndex = 0,
    this.isPartnerLoggedIn = false,
    this.partnerRole = PartnerRole.owner,
    this.loggedInTrainerName = 'Coach Karthik Reddy',
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
  });

  GymTenant get currentGym => gyms[selectedGymIndex];

  int get liveCrowd =>
      (currentGym.activeCrowd + crowdDelta).clamp(4, currentGym.maxCapacity);

  // Computed Owner CEO metrics
  int get totalMonthlyRevenue =>
      457000 + members.fold<int>(0, (sum, m) => sum + m.feePaid);

  int get activeMembersCount => members.where((m) => !m.isExpired).length;

  List<GymMember> get expiringOrExpiredMembers =>
      members.where((m) => m.daysLeft <= 5).toList();

  List<GymMember> get ptMembers =>
      members.where((m) => m.isPtClient).toList();

  SmartGymState copyWith({
    List<GymTenant>? gyms,
    int? selectedGymIndex,
    bool? isPartnerLoggedIn,
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
  }) {
    return SmartGymState(
      gyms: gyms ?? this.gyms,
      selectedGymIndex: selectedGymIndex ?? this.selectedGymIndex,
      isPartnerLoggedIn: isPartnerLoggedIn ?? this.isPartnerLoggedIn,
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
    );
  }

  @override
  List<Object?> get props => [
        gyms,
        selectedGymIndex,
        isPartnerLoggedIn,
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
      ];
}
