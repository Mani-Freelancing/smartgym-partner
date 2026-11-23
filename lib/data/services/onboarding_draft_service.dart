import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/gym_fee_plan.dart';

/// Persists in-progress Partner Onboarding form fields & current horizontal step
/// across app restarts, scoped per authenticated phone number.
class OnboardingDraft {
  final int ownerStep;
  final bool isOwnerForm;
  final String gymName;
  final String area;
  final String ownerName;
  final String monthlyFee;
  final String ptFee;
  final String maxCapacity;
  final List<GymFeePlan> feePlans;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final bool requireGpsCheckIn;
  final String trainerName;
  final int updatedAtMs;

  const OnboardingDraft({
    this.ownerStep = 0,
    this.isOwnerForm = true,
    this.gymName = '',
    this.area = '',
    this.ownerName = '',
    this.monthlyFee = '1500',
    this.ptFee = '6000',
    this.maxCapacity = '60',
    this.feePlans = const [],
    this.latitude,
    this.longitude,
    this.radiusMeters = 100,
    this.requireGpsCheckIn = true,
    this.trainerName = '',
    this.updatedAtMs = 0,
  });

  bool get hasProgress {
    final defaults = GymFeePlan.defaultPlans();
    final plansChanged = feePlans.isNotEmpty && !listEquals(feePlans, defaults);
    return ownerStep > 0 ||
        !isOwnerForm ||
        gymName.trim().isNotEmpty ||
        area.trim().isNotEmpty ||
        ownerName.trim().isNotEmpty ||
        monthlyFee.trim() != '1500' ||
        ptFee.trim() != '6000' ||
        maxCapacity.trim() != '60' ||
        plansChanged ||
        latitude != null ||
        longitude != null ||
        trainerName.trim().isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
        'ownerStep': ownerStep.clamp(0, 2),
        'isOwnerForm': isOwnerForm,
        'gymName': gymName,
        'area': area,
        'ownerName': ownerName,
        'monthlyFee': monthlyFee,
        'ptFee': ptFee,
        'maxCapacity': maxCapacity,
        'feePlans': feePlans.map((p) => p.toJson()).toList(),
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'requireGpsCheckIn': requireGpsCheckIn,
        'trainerName': trainerName,
        'updatedAtMs': updatedAtMs,
      };

  factory OnboardingDraft.fromJson(Map<String, dynamic> map) {
    final rawStep = (map['ownerStep'] as num?)?.toInt() ?? 0;
    final rawRadius = (map['radiusMeters'] as num?)?.toInt() ?? 100;
    return OnboardingDraft(
      ownerStep: rawStep.clamp(0, 2),
      isOwnerForm:
          map['isOwnerForm'] is bool ? map['isOwnerForm'] as bool : true,
      gymName: (map['gymName'] ?? '').toString(),
      area: (map['area'] ?? '').toString(),
      ownerName: (map['ownerName'] ?? '').toString(),
      monthlyFee: (map['monthlyFee'] ?? '1500').toString(),
      ptFee: (map['ptFee'] ?? '6000').toString(),
      maxCapacity: (map['maxCapacity'] ?? '60').toString(),
      feePlans: GymFeePlan.decodeList(map['feePlans']),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      radiusMeters: rawRadius,
      requireGpsCheckIn: map['requireGpsCheckIn'] is bool
          ? map['requireGpsCheckIn'] as bool
          : true,
      trainerName: (map['trainerName'] ?? '').toString(),
      updatedAtMs: (map['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class OnboardingDraftService {
  static String _keyForPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final suffix = normalized.isEmpty ? 'default' : normalized;
    return 'onboarding_draft_v1_$suffix';
  }

  @visibleForTesting
  static String storageKeyForPhone(String phone) => _keyForPhone(phone);

  static Future<OnboardingDraft?> loadDraft(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyForPhone(phone));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final draft = OnboardingDraft.fromJson(decoded);
      return draft.hasProgress ? draft : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDraft(String phone, OnboardingDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPhone(phone);
      if (!draft.hasProgress) {
        await prefs.remove(key);
        return;
      }
      final enriched = OnboardingDraft(
        ownerStep: draft.ownerStep,
        isOwnerForm: draft.isOwnerForm,
        gymName: draft.gymName,
        area: draft.area,
        ownerName: draft.ownerName,
        monthlyFee: draft.monthlyFee,
        ptFee: draft.ptFee,
        maxCapacity: draft.maxCapacity,
        feePlans: draft.feePlans,
        latitude: draft.latitude,
        longitude: draft.longitude,
        radiusMeters: draft.radiusMeters,
        requireGpsCheckIn: draft.requireGpsCheckIn,
        trainerName: draft.trainerName,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString(key, jsonEncode(enriched.toJson()));
    } catch (_) {
      // Non-fatal in case SharedPreferences is unavailable.
    }
  }

  static Future<void> clearDraft(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyForPhone(phone));
    } catch (_) {
      // Ignore cleanup failures.
    }
  }
}
