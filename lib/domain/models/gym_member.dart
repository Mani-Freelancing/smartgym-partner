import 'package:equatable/equatable.dart';

/// Canonical gender categories with respectful labels and salutations.
enum MemberGender {
  male(
    value: 'Male',
    label: 'Male',
    honorific: 'Mr.',
    respectfulAddress: 'Sir',
  ),
  female(
    value: 'Female',
    label: 'Female',
    honorific: 'Ms.',
    respectfulAddress: "Ma'am",
  ),
  transgender(
    value: 'Transgender',
    label: 'Transgender',
    honorific: 'Mx.',
    respectfulAddress: 'Mx.',
  );

  final String value;
  final String label;
  final String honorific;
  final String respectfulAddress;

  const MemberGender({
    required this.value,
    required this.label,
    required this.honorific,
    required this.respectfulAddress,
  });

  /// Normalizes stored or user-entered gender strings into [MemberGender].
  static MemberGender? fromString(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    if (normalized == 'male' ||
        normalized == 'm' ||
        normalized == 'mr' ||
        normalized == 'mr.') {
      return MemberGender.male;
    }
    if (normalized == 'female' ||
        normalized == 'f' ||
        normalized == 'ms' ||
        normalized == 'ms.' ||
        normalized == 'mrs' ||
        normalized == 'mrs.') {
      return MemberGender.female;
    }
    if (normalized == 'transgender' ||
        normalized == 'trans' ||
        normalized == 'tg' ||
        normalized == 'mx' ||
        normalized == 'mx.') {
      return MemberGender.transgender;
    }
    return null;
  }
}

class GymMember extends Equatable {
  static final _existingHonorificPattern = RegExp(
    r'^(mr|mrs|ms|miss|mx|dr)\.?\s+',
    caseSensitive: false,
  );

  final String id;
  final String name;
  final String gender;
  final String phone;
  final String planTitle;
  final int feePaid;
  final int dueAmount;
  final String joinedDate;
  final String expiryDate;
  final int daysLeft;
  final String? assignedTrainer;
  final bool isPtClient;
  final String addedByTrainer;
  final double currentWeightKg;
  final String paymentMode;
  final String paymentReference;
  final String paymentProofBase64;

  const GymMember({
    required this.id,
    required this.name,
    this.gender = '',
    required this.phone,
    required this.planTitle,
    required this.feePaid,
    this.dueAmount = 0,
    required this.joinedDate,
    required this.expiryDate,
    required this.daysLeft,
    this.assignedTrainer,
    required this.isPtClient,
    required this.addedByTrainer,
    this.currentWeightKg = 74.0,
    this.paymentMode = 'Cash',
    this.paymentReference = '',
    this.paymentProofBase64 = '',
  });

  bool get isExpired => daysLeft <= 0;
  bool get isExpiringSoon => daysLeft > 0 && daysLeft <= 5;
  bool get hasDue => dueAmount > 0;

  MemberGender? get memberGender => MemberGender.fromString(gender);
  String get genderLabel => memberGender?.label ?? '';
  String get honorific => memberGender?.honorific ?? '';

  /// Returns the member's name prefixed with a respectful honorific when known.
  String get respectfulName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    if (honorific.isEmpty || _existingHonorificPattern.hasMatch(trimmed)) {
      return trimmed;
    }
    return '$honorific $trimmed';
  }

  GymMember copyWith({
    String? gender,
    String? planTitle,
    int? feePaid,
    int? dueAmount,
    String? expiryDate,
    int? daysLeft,
    String? assignedTrainer,
    bool? isPtClient,
    double? currentWeightKg,
  }) {
    return GymMember(
      id: id,
      name: name,
      gender: gender ?? this.gender,
      phone: phone,
      planTitle: planTitle ?? this.planTitle,
      feePaid: feePaid ?? this.feePaid,
      dueAmount: dueAmount ?? this.dueAmount,
      joinedDate: joinedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      daysLeft: daysLeft ?? this.daysLeft,
      assignedTrainer: assignedTrainer ?? this.assignedTrainer,
      isPtClient: isPtClient ?? this.isPtClient,
      addedByTrainer: addedByTrainer,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      paymentMode: paymentMode,
      paymentReference: paymentReference,
      paymentProofBase64: paymentProofBase64,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        gender,
        phone,
        planTitle,
        feePaid,
        dueAmount,
        joinedDate,
        expiryDate,
        daysLeft,
        assignedTrainer,
        isPtClient,
        addedByTrainer,
        currentWeightKg,
        paymentMode,
        paymentReference,
        paymentProofBase64,
      ];
}
