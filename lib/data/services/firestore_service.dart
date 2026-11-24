import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../domain/models/gym_fee_plan.dart';
import '../../domain/models/gym_member.dart';
import '../../domain/models/gym_tenant.dart';
import '../../domain/models/machine_guide.dart';
import '../../domain/models/meal_review_item.dart';
import '../../domain/models/missing_member.dart';
import '../../domain/models/removed_record.dart';
import '../../domain/models/trainer_join_request.dart';
import '../../domain/models/trainer_profile.dart';
import '../../domain/models/walk_in_enquiry.dart';

class PhoneLookupResult {
  final String phone;
  final String role;
  final String gymId;
  final String name;

  const PhoneLookupResult({
    required this.phone,
    required this.role,
    required this.gymId,
    required this.name,
  });
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() => _auth.signOut();

  Future<PhoneLookupResult?> lookupPhone(String phone) async {
    final doc = await _db.collection('phone_index').doc(phone).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    return PhoneLookupResult(
      phone: phone,
      role: (data['role'] ?? 'owner') as String,
      gymId: (data['gymId'] ?? '') as String,
      name: (data['name'] ?? '') as String,
    );
  }

  Stream<PhoneLookupResult?> watchPhoneLookup(String phone) {
    return _db.collection('phone_index').doc(phone).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      return PhoneLookupResult(
        phone: phone,
        role: (data['role'] ?? 'owner') as String,
        gymId: (data['gymId'] ?? '') as String,
        name: (data['name'] ?? '') as String,
      );
    });
  }

  /// Creates a brand-new gym tenant and binds the owner's phone in `phone_index`
  /// in a single atomic batch.
  Future<String> createNewGym({
    required String gymName,
    required String area,
    required String ownerName,
    required String ownerPhone,
    int monthlyFee = 1500,
    int ptFee = 6000,
    int maxCapacity = 60,
    List<GymFeePlan> feePlans = const [],
    double? latitude,
    double? longitude,
    int checkInRadiusMeters = 100,
    bool requireGpsCheckIn = true,
    bool ptSplitExcludesBaseFee = true,
  }) async {
    final slug = gymName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final shortTs =
        (DateTime.now().millisecondsSinceEpoch % 100000).toString();
    final gymId = '${slug.isEmpty ? 'gym' : slug}_$shortTs';
    final uid = _auth.currentUser?.uid ?? '';
    final effectivePlans = feePlans.isNotEmpty
        ? feePlans
        : GymFeePlan.defaultPlans(monthlyFee: monthlyFee, ptFee: ptFee);

    final gymPayload = <String, dynamic>{
      'id': gymId,
      'name': gymName.trim(),
      'area': area.trim(),
      'headTrainer': ownerName.trim(),
      'monthlyFee': monthlyFee,
      'ptFee': ptFee,
      'feePlans': effectivePlans.map((p) => p.toJson()).toList(),
      'activeCrowd': 0,
      'crowdDate': GymTenant.dateKeyFor(),
      'maxCapacity': maxCapacity,
      'checkInRadiusMeters': checkInRadiusMeters,
      'requireGpsCheckIn': requireGpsCheckIn,
      'ptSplitExcludesBaseFee': ptSplitExcludesBaseFee,
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (latitude != null && longitude != null) {
      gymPayload['latitude'] = latitude;
      gymPayload['longitude'] = longitude;
    }

    final batch = _db.batch();
    final gymRef = _db.collection('gyms').doc(gymId);
    batch.set(gymRef, gymPayload);

    final phoneRef = _db.collection('phone_index').doc(ownerPhone);
    batch.set(phoneRef, {
      'phone': ownerPhone,
      'role': 'owner',
      'gymId': gymId,
      'uid': uid,
      'name': ownerName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return gymId;
  }

  Future<void> updateGymSettings({
    required String gymId,
    required String name,
    required String area,
    required int monthlyFee,
    required int ptFee,
    required int maxCapacity,
    List<GymFeePlan>? feePlans,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    int? checkInRadiusMeters,
    bool? requireGpsCheckIn,
    bool? ptSplitExcludesBaseFee,
  }) async {
    final updates = <String, dynamic>{
      'name': name.trim(),
      'area': area.trim(),
      'monthlyFee': monthlyFee,
      'ptFee': ptFee,
      'maxCapacity': maxCapacity,
    };
    if (feePlans != null) {
      updates['feePlans'] = feePlans.map((p) => p.toJson()).toList();
    }
    if (clearLocation) {
      updates['latitude'] = FieldValue.delete();
      updates['longitude'] = FieldValue.delete();
    } else if (latitude != null && longitude != null) {
      updates['latitude'] = latitude;
      updates['longitude'] = longitude;
    }
    if (checkInRadiusMeters != null) {
      updates['checkInRadiusMeters'] = checkInRadiusMeters;
    }
    if (requireGpsCheckIn != null) {
      updates['requireGpsCheckIn'] = requireGpsCheckIn;
    }
    if (ptSplitExcludesBaseFee != null) {
      updates['ptSplitExcludesBaseFee'] = ptSplitExcludesBaseFee;
    }
    await _db.collection('gyms').doc(gymId).update(updates);
  }

  Future<void> setPtSplitExcludesBaseFee({
    required String gymId,
    required bool excludesBaseFee,
  }) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .update({'ptSplitExcludesBaseFee': excludesBaseFee});
  }

  /// Builds a concise diagnostic summary when a gym settings write is denied.
  Future<String> diagnoseGymWriteAccess(String gymId) async {
    try {
      final user = _auth.currentUser;
      final phone = user?.phoneNumber ?? '';
      final uid = user?.uid ?? '';
      final phoneSnap = phone.isNotEmpty
          ? await _db.collection('phone_index').doc(phone).get()
          : null;
      final gymSnap = await _db.collection('gyms').doc(gymId).get();
      final d = gymSnap.data();
      final phoneRole = phoneSnap?.data()?['role'] ?? 'missing';
      final phoneGym = phoneSnap?.data()?['gymId'] ?? 'missing';
      final ownerUid = d?['ownerUid'] ?? 'missing';
      final crowd = d?['activeCrowd'];
      final cap = d?['maxCapacity'];
      final headLen = (d?['headTrainer']?.toString() ?? '').length;
      final keys = d?.keys.join(',') ?? 'none';
      final summary =
          'uidMatch=${ownerUid == uid}, ownerEmpty=${ownerUid == ''}, '
          'phoneRole=$phoneRole, phoneGym=$phoneGym, '
          'crowd=$crowd/$cap (${crowd.runtimeType}/${cap.runtimeType}), '
          'headLen=$headLen, docKeys=[$keys]';
      debugPrint('GYM_SAVE_DIAG: $summary');
      return summary;
    } catch (diagErr) {
      debugPrint('GYM_SAVE_DIAG error: $diagErr');
      return 'diagError=$diagErr';
    }
  }

  /// Owner adds a trainer to their gym and registers their phone in `phone_index`.
  Future<void> addTrainerToGym({
    required String gymId,
    required String name,
    required String phone,
    String specialty = 'Floor & Transformation Coach',
    String shiftSlot = 'Morning (6–10 AM)',
    int commissionPercent = 50,
  }) async {
    final trainerId = 'tr_${DateTime.now().millisecondsSinceEpoch}';
    final batch = _db.batch();
    batch.set(
      _db.collection('gyms').doc(gymId).collection('trainers').doc(trainerId),
      {
        'id': trainerId,
        'name': name.trim(),
        'phone': phone.trim(),
        'specialty': specialty.trim(),
        'shiftSlot': shiftSlot.trim(),
        'morningCheckInTime': 'Not Checked In',
        'isOnDuty': false,
        'commissionPercent': commissionPercent.clamp(0, 100),
      },
    );
    batch.set(
      _db.collection('phone_index').doc(phone.trim()),
      {
        'phone': phone.trim(),
        'role': 'trainer',
        'gymId': gymId,
        'uid': '',
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  /// Returns an active staff invite code for `gymId`, creating one if needed.
  Future<String> ensureActiveInviteCode(String gymId, String gymName) async {
    final invitesRef = _db.collection('gyms').doc(gymId).collection('invites');
    final existing =
        await invitesRef.where('active', isEqualTo: true).limit(1).get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }
    final code = 'INV${(DateTime.now().millisecondsSinceEpoch % 1000000)}';
    await invitesRef.doc(code).set({
      'code': code,
      'gymId': gymId,
      'gymName': gymName,
      'active': true,
      'createdByUid': _auth.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Trainer submits a join request after scanning the Owner's Staff Invite QR.
  /// Owner must approve this request before the trainer gains access.
  Future<String> submitTrainerJoinRequest({
    required String gymId,
    required String inviteCode,
    required String trainerName,
    required String trainerPhone,
  }) async {
    final inviteDoc = await _db
        .collection('gyms')
        .doc(gymId)
        .collection('invites')
        .doc(inviteCode)
        .get();
    if (!inviteDoc.exists || (inviteDoc.data()?['active'] != true)) {
      throw Exception('Invalid or expired gym invite QR.');
    }

    final gymName = (inviteDoc.data()?['gymName'] ?? 'this gym') as String;
    final uid = _auth.currentUser?.uid ?? '';
    final requestId = uid.isNotEmpty
        ? uid
        : 'req_${DateTime.now().millisecondsSinceEpoch}';

    final batch = _db.batch();
    batch.set(
      _db
          .collection('gyms')
          .doc(gymId)
          .collection('trainer_requests')
          .doc(requestId),
      {
        'id': requestId,
        'name': trainerName.trim(),
        'phone': trainerPhone,
        'uid': uid,
        'inviteCode': inviteCode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _db.collection('pending_requests').doc(trainerPhone),
      {
        'phone': trainerPhone,
        'gymId': gymId,
        'gymName': gymName,
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
    return gymName;
  }

  /// Checks if the current trainer phone has a pending approval request.
  Future<String?> lookupPendingGymName(String phone) async {
    try {
      final doc = await _db.collection('pending_requests').doc(phone).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      final gymId = (data['gymId'] ?? '') as String;
      final gymName = (data['gymName'] ?? '') as String;
      if (gymId.isEmpty) return null;
      // Also verify the request doc in trainer_requests still exists (wasn't rejected)
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        final reqDoc = await _db
            .collection('gyms')
            .doc(gymId)
            .collection('trainer_requests')
            .doc(uid)
            .get();
        if (!reqDoc.exists) {
          await _db.collection('pending_requests').doc(phone).delete();
          return null;
        }
      }
      return gymName.isEmpty ? 'this gym' : gymName;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingRequest(String phone) async {
    try {
      final pendingDoc =
          await _db.collection('pending_requests').doc(phone).get();
      final gymId = (pendingDoc.data()?['gymId'] ?? '') as String;
      final uid = _auth.currentUser?.uid ?? '';
      if (gymId.isNotEmpty && uid.isNotEmpty) {
        await _db
            .collection('gyms')
            .doc(gymId)
            .collection('trainer_requests')
            .doc(uid)
            .delete();
      }
      await _db.collection('pending_requests').doc(phone).delete();
    } catch (_) {}
  }

  Stream<List<TrainerJoinRequest>> watchTrainerRequests(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('trainer_requests')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final d = doc.data();
            return TrainerJoinRequest(
              id: doc.id,
              name: (d['name'] ?? '') as String,
              phone: (d['phone'] ?? '') as String,
              uid: (d['uid'] ?? '') as String,
              inviteCode: (d['inviteCode'] ?? '') as String,
              status: (d['status'] ?? 'pending') as String,
            );
          }).toList(),
        );
  }

  /// Owner approves a pending trainer request: creates trainer + phone_index and deletes request.
  Future<void> approveTrainerRequest({
    required String gymId,
    required TrainerJoinRequest request,
  }) async {
    final trainerId = request.uid.isNotEmpty
        ? request.uid
        : 'tr_${DateTime.now().millisecondsSinceEpoch}';
    final batch = _db.batch();
    batch.set(
      _db.collection('phone_index').doc(request.phone),
      {
        'phone': request.phone,
        'role': 'trainer',
        'gymId': gymId,
        'uid': request.uid,
        'name': request.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _db.collection('gyms').doc(gymId).collection('trainers').doc(trainerId),
      {
        'id': trainerId,
        'name': request.name,
        'phone': request.phone,
        'specialty': 'Floor & Transformation Coach',
        'morningCheckInTime': 'Not Checked In',
        'isOnDuty': false,
        'commissionPercent': 50,
      },
    );
    batch.delete(
      _db
          .collection('gyms')
          .doc(gymId)
          .collection('trainer_requests')
          .doc(request.id),
    );
    await batch.commit();
  }

  Future<void> rejectTrainerRequest({
    required String gymId,
    required String requestId,
  }) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('trainer_requests')
        .doc(requestId)
        .delete();
  }

  Stream<GymTenant?> watchGym(String gymId) {
    return _db.collection('gyms').doc(gymId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final d = doc.data()!;
      final rawCrowd = (d['activeCrowd'] as num?)?.toInt() ?? 0;
      var resolvedCrowdDate = (d['crowdDate'] ?? '') as String;
      if (resolvedCrowdDate.isEmpty && rawCrowd > 0) {
        final fallbackTs = d['updatedAt'] ?? d['createdAt'];
        resolvedCrowdDate = fallbackTs is Timestamp
            ? GymTenant.dateKeyFor(fallbackTs.toDate())
            : '1970-01-01';
      }
      return GymTenant(
        id: doc.id,
        name: (d['name'] ?? '') as String,
        area: (d['area'] ?? '') as String,
        headTrainer: (d['headTrainer'] ?? '') as String,
        brandColor: const Color(0xFFE5C158),
        activeCrowd: rawCrowd,
        crowdDate: resolvedCrowdDate,
        maxCapacity: (d['maxCapacity'] as num?)?.toInt() ?? 60,
        monthlyFee: (d['monthlyFee'] as num?)?.toInt() ?? 1500,
        ptFee: (d['ptFee'] as num?)?.toInt() ?? 6000,
        ptSplitExcludesBaseFee:
            (d['ptSplitExcludesBaseFee'] as bool?) ?? true,
        feePlans: GymFeePlan.decodeList(d['feePlans']),
        latitude: (d['latitude'] as num?)?.toDouble(),
        longitude: (d['longitude'] as num?)?.toDouble(),
        checkInRadiusMeters:
            (d['checkInRadiusMeters'] as num?)?.toInt() ?? 100,
        requireGpsCheckIn: (d['requireGpsCheckIn'] as bool?) ?? true,
        hourlyCheckIns: GymTenant.decodeHourlyCheckIns(d['hourlyCheckIns']),
      );
    });
  }

  Stream<GymMember?> watchMemberByPhone(String gymId, String phone) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final d = doc.data();
      return GymMember(
        id: doc.id,
        name: (d['name'] ?? '') as String,
        gender: (d['gender'] ?? '') as String,
        phone: (d['phone'] ?? '') as String,
        planTitle: (d['planTitle'] ?? '') as String,
        feePaid: (d['feePaid'] as num?)?.toInt() ?? 0,
        dueAmount: (d['dueAmount'] as num?)?.toInt() ?? 0,
        joinedDate: (d['joinedDate'] ?? '') as String,
        expiryDate: (d['expiryDate'] ?? '') as String,
        daysLeft: (d['daysLeft'] as num?)?.toInt() ?? 0,
        assignedTrainer: (d['assignedTrainer'] as String?)?.isEmpty ?? true
            ? null
            : d['assignedTrainer'] as String,
        isPtClient: (d['isPtClient'] ?? false) as bool,
        addedByTrainer: (d['addedByTrainer'] ?? '') as String,
        currentWeightKg: (d['currentWeightKg'] as num?)?.toDouble() ?? 70.0,
        paymentMode: (d['paymentMode'] ?? 'Cash') as String,
        paymentReference: (d['paymentReference'] ?? '') as String,
        paymentProofBase64: (d['paymentProofBase64'] ?? '') as String,
      );
    });
  }

  Future<void> submitMealSnap({
    required String gymId,
    required MealReviewItem meal,
    required String memberPhone,
  }) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('meals')
        .doc(meal.id)
        .set({
      'id': meal.id,
      'memberName': meal.memberName,
      'timeLabel': meal.timeLabel,
      'mealDescription': meal.mealDescription,
      'macros': meal.macros,
      'trainerFeedback': meal.trainerFeedback,
      'memberPhone': memberPhone,
    });
  }

  Future<void> incrementGymCrowd(
    String gymId,
    int nextCrowd, {
    List<int>? hourlyCheckIns,
    String? crowdDate,
  }) async {
    await _db.collection('gyms').doc(gymId).update({
      'activeCrowd': nextCrowd,
      'crowdDate': crowdDate ?? GymTenant.dateKeyFor(),
      if (hourlyCheckIns != null && hourlyCheckIns.length == 24)
        'hourlyCheckIns': hourlyCheckIns,
    });
  }

  Stream<List<GymMember>> watchMembers(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final d = doc.data();
            return GymMember(
              id: doc.id,
              name: (d['name'] ?? '') as String,
              gender: (d['gender'] ?? '') as String,
              phone: (d['phone'] ?? '') as String,
              planTitle: (d['planTitle'] ?? '') as String,
              feePaid: (d['feePaid'] as num?)?.toInt() ?? 0,
              dueAmount: (d['dueAmount'] as num?)?.toInt() ?? 0,
              joinedDate: (d['joinedDate'] ?? '') as String,
              expiryDate: (d['expiryDate'] ?? '') as String,
              daysLeft: (d['daysLeft'] as num?)?.toInt() ?? 0,
              assignedTrainer: (d['assignedTrainer'] as String?)?.isEmpty ?? true
                  ? null
                  : d['assignedTrainer'] as String,
              isPtClient: (d['isPtClient'] ?? false) as bool,
              addedByTrainer: (d['addedByTrainer'] ?? '') as String,
              currentWeightKg:
                  (d['currentWeightKg'] as num?)?.toDouble() ?? 70.0,
              paymentMode: (d['paymentMode'] ?? 'Cash') as String,
              paymentReference: (d['paymentReference'] ?? '') as String,
              paymentProofBase64: (d['paymentProofBase64'] ?? '') as String,
            );
          }).toList(),
        );
  }

  Stream<List<TrainerProfile>> watchTrainers(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('trainers')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final d = doc.data();
            return TrainerProfile(
              id: doc.id,
              name: (d['name'] ?? '') as String,
              phone: (d['phone'] ?? '') as String,
              specialty: (d['specialty'] ?? '') as String,
              shiftSlot: (d['shiftSlot'] ?? 'Morning (6–10 AM)') as String,
              morningCheckInTime: (d['morningCheckInTime'] ?? '') as String,
              isOnDuty: (d['isOnDuty'] ?? false) as bool,
              commissionPercent:
                  (d['commissionPercent'] as num?)?.toInt() ?? 50,
            );
          }).toList(),
        );
  }

  Stream<List<WalkInEnquiry>> watchEnquiries(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('enquiries')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final d = doc.data();
            return WalkInEnquiry(
              id: doc.id,
              name: (d['name'] ?? '') as String,
              phone: (d['phone'] ?? '') as String,
              interestedPlan: (d['interestedPlan'] ?? '') as String,
              loggedByTrainer: (d['loggedByTrainer'] ?? '') as String,
              timeLabel: (d['timeLabel'] ?? '') as String,
              converted: (d['converted'] ?? false) as bool,
            );
          }).toList(),
        );
  }

  Stream<List<MachineGuide>> watchMachines(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('machines')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final d = doc.data();
            return MachineGuide(
              code: (d['code'] ?? doc.id) as String,
              name: (d['name'] ?? '') as String,
              muscle: (d['muscle'] ?? '') as String,
              mistakeTip: (d['mistakeTip'] ?? '') as String,
            );
          }).toList(),
        );
  }

  Stream<List<MealReviewItem>> watchMeals(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('meals')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final d = doc.data();
            return MealReviewItem(
              id: doc.id,
              memberName: (d['memberName'] ?? '') as String,
              timeLabel: (d['timeLabel'] ?? '') as String,
              mealDescription: (d['mealDescription'] ?? '') as String,
              macros: (d['macros'] ?? '') as String,
              trainerFeedback: (d['trainerFeedback'] ?? '') as String,
            );
          }).toList(),
        );
  }

  Stream<List<MissingMember>> watchMissingMembers(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('missing')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            return MissingMember(
              id: d.id,
              name: (data['name'] ?? '') as String,
              daysMissing: (data['daysMissing'] as num?)?.toInt() ?? 5,
              planName: (data['planName'] ?? '') as String,
              lastMuscleTrained: (data['lastMuscleTrained'] ?? '') as String,
              contacted: (data['contacted'] ?? false) as bool,
            );
          }).toList(),
        );
  }

  Future<void> markMissingMemberContacted(
    String gymId,
    String missingId,
  ) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('missing')
        .doc(missingId)
        .update({'contacted': true});
  }

  /// Ensures default gym data exists in Firestore under `gyms/{gym.id}`
  /// so first-time logins have live cloud records ready to read and update.
  Future<void> seedGymIfEmpty({
    required GymTenant gym,
    required List<TrainerProfile> trainers,
    required List<GymMember> members,
    required List<WalkInEnquiry> enquiries,
    required List<MachineGuide> machines,
    required List<MealReviewItem> meals,
  }) async {
    final gymRef = _db.collection('gyms').doc(gym.id);
    final doc = await gymRef.get();
    if (doc.exists) return;

    final batch = _db.batch();
    batch.set(gymRef, {
      'id': gym.id,
      'name': gym.name,
      'area': gym.area,
      'headTrainer': gym.headTrainer,
      'activeCrowd': gym.activeCrowd,
      'crowdDate': gym.crowdDate.isNotEmpty
          ? gym.crowdDate
          : GymTenant.dateKeyFor(),
      'maxCapacity': gym.maxCapacity,
      'monthlyFee': gym.monthlyFee,
      'ptFee': gym.ptFee,
      'ownerUid': _auth.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final t in trainers) {
      batch.set(gymRef.collection('trainers').doc(t.id), {
        'id': t.id,
        'name': t.name,
        'specialty': t.specialty,
        'morningCheckInTime': t.morningCheckInTime,
        'isOnDuty': t.isOnDuty,
        'commissionPercent': t.commissionPercent,
      });
    }

    for (final m in members) {
      batch.set(gymRef.collection('members').doc(m.id), {
        'id': m.id,
        'name': m.name,
        'gender': m.gender,
        'phone': m.phone,
        'planTitle': m.planTitle,
        'feePaid': m.feePaid,
        'joinedDate': m.joinedDate,
        'expiryDate': m.expiryDate,
        'daysLeft': m.daysLeft,
        'assignedTrainer': m.assignedTrainer ?? '',
        'isPtClient': m.isPtClient,
        'addedByTrainer': m.addedByTrainer,
        'currentWeightKg': m.currentWeightKg,
      });
    }

    for (final e in enquiries) {
      batch.set(gymRef.collection('enquiries').doc(e.id), {
        'id': e.id,
        'name': e.name,
        'phone': e.phone,
        'interestedPlan': e.interestedPlan,
        'loggedByTrainer': e.loggedByTrainer,
        'timeLabel': e.timeLabel,
        'converted': e.converted,
      });
    }

    for (final g in machines) {
      batch.set(gymRef.collection('machines').doc(g.code), {
        'code': g.code,
        'name': g.name,
        'muscle': g.muscle,
        'mistakeTip': g.mistakeTip,
      });
    }

    for (final meal in meals) {
      batch.set(gymRef.collection('meals').doc(meal.id), {
        'id': meal.id,
        'memberName': meal.memberName,
        'timeLabel': meal.timeLabel,
        'mealDescription': meal.mealDescription,
        'macros': meal.macros,
        'trainerFeedback': meal.trainerFeedback,
      });
    }

    await batch.commit();
  }

  Stream<List<RemovedRecord>> watchRemovedLogs(String gymId) {
    return _db
        .collection('gyms')
        .doc(gymId)
        .collection('removed_logs')
        .orderBy('removedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final d = doc.data();
            return RemovedRecord(
              id: doc.id,
              type: (d['type'] ?? 'member') as String,
              name: (d['name'] ?? '') as String,
              phone: (d['phone'] ?? '') as String,
              details: (d['details'] ?? '') as String,
            );
          }).toList(),
        );
  }

  Future<void> removeTrainerFromGym({
    required String gymId,
    required String trainerId,
    required String phone,
    required String name,
    String details = 'Floor Trainer',
  }) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('trainers')
        .doc(trainerId)
        .delete();
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isNotEmpty) {
      final phoneRef = _db.collection('phone_index').doc(trimmedPhone);
      final snap = await phoneRef.get();
      if (snap.exists && snap.data()?['role'] == 'trainer') {
        await phoneRef.delete();
      }
    }
    final logId = 'rem_${DateTime.now().millisecondsSinceEpoch}';
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('removed_logs')
        .doc(logId)
        .set({
      'id': logId,
      'type': 'trainer',
      'name': name,
      'phone': trimmedPhone,
      'details': details,
      'removedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeMemberFromGym({
    required String gymId,
    required String memberId,
    required String phone,
    required String name,
    String details = 'Gym Member',
  }) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .delete();
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isNotEmpty) {
      final phoneRef = _db.collection('phone_index').doc(trimmedPhone);
      final snap = await phoneRef.get();
      if (snap.exists && snap.data()?['role'] == 'member') {
        await phoneRef.delete();
      }
    }
    final logId = 'rem_${DateTime.now().millisecondsSinceEpoch}';
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('removed_logs')
        .doc(logId)
        .set({
      'id': logId,
      'type': 'member',
      'name': name,
      'phone': trimmedPhone,
      'details': details,
      'removedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addMember(String gymId, GymMember member) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(member.id)
        .set({
      'id': member.id,
      'name': member.name,
      'gender': member.gender,
      'phone': member.phone,
      'planTitle': member.planTitle,
      'feePaid': member.feePaid,
      'dueAmount': member.dueAmount,
      'joinedDate': member.joinedDate,
      'expiryDate': member.expiryDate,
      'daysLeft': member.daysLeft,
      'assignedTrainer': member.assignedTrainer ?? '',
      'isPtClient': member.isPtClient,
      'addedByTrainer': member.addedByTrainer,
      'currentWeightKg': member.currentWeightKg,
      'paymentMode': member.paymentMode,
      'paymentReference': member.paymentReference,
      'paymentProofBase64': member.paymentProofBase64,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (member.phone.trim().isNotEmpty) {
      await registerPhoneLookup(
        phone: member.phone.trim(),
        role: 'member',
        gymId: gymId,
        name: member.name,
      );
    }
  }

  Future<void> addEnquiry(String gymId, WalkInEnquiry enquiry) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('enquiries')
        .doc(enquiry.id)
        .set({
      'id': enquiry.id,
      'name': enquiry.name,
      'phone': enquiry.phone,
      'interestedPlan': enquiry.interestedPlan,
      'loggedByTrainer': enquiry.loggedByTrainer,
      'timeLabel': enquiry.timeLabel,
      'converted': enquiry.converted,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markEnquiryConverted(String gymId, String enquiryId) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('enquiries')
        .doc(enquiryId)
        .update({'converted': true});
  }

  Future<void> markTrainerDuty(
    String gymId,
    String trainerId,
    String checkInTime,
  ) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('trainers')
        .doc(trainerId)
        .update({
      'isOnDuty': true,
      'morningCheckInTime': checkInTime,
    });
  }

  Future<void> updateMemberWeight(
    String gymId,
    String memberId,
    double newWeightKg,
  ) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .update({'currentWeightKg': newWeightKg});
  }

  Future<void> collectMemberDue(
    String gymId,
    String memberId,
    int newFeePaid,
  ) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .update({
      'feePaid': newFeePaid,
      'dueAmount': 0,
    });
  }

  /// Renews an existing member's plan cycle and payment proof without duplicating the doc.
  Future<void> renewMember(String gymId, GymMember member) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(member.id)
        .update({
      'planTitle': member.planTitle,
      'feePaid': member.feePaid,
      'dueAmount': member.dueAmount,
      'joinedDate': member.joinedDate,
      'expiryDate': member.expiryDate,
      'daysLeft': member.daysLeft,
      'assignedTrainer': member.assignedTrainer ?? '',
      'isPtClient': member.isPtClient,
      'paymentMode': member.paymentMode,
      'paymentReference': member.paymentReference,
      'paymentProofBase64': member.paymentProofBase64,
    });
  }

  /// Updates trainer specialty, duty shift slot, and PT commission split.
  Future<void> updateTrainerDetails({
    required String gymId,
    required String trainerId,
    required String specialty,
    required String shiftSlot,
    required int commissionPercent,
  }) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('trainers')
        .doc(trainerId)
        .update({
      'specialty': specialty.trim(),
      'shiftSlot': shiftSlot.trim(),
      'commissionPercent': commissionPercent.clamp(0, 100),
    });
  }

  Future<void> addMachineGuide(String gymId, MachineGuide guide) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('machines')
        .doc(guide.code)
        .set({
      'code': guide.code,
      'name': guide.name,
      'muscle': guide.muscle,
      'mistakeTip': guide.mistakeTip,
    });
  }

  Future<void> updateMealFeedback(
    String gymId,
    String mealId,
    String feedback,
  ) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('meals')
        .doc(mealId)
        .update({'trainerFeedback': feedback});
  }

  Future<void> registerPhoneLookup({
    required String phone,
    required String role,
    required String gymId,
    String? name,
  }) async {
    final docRef = _db.collection('phone_index').doc(phone);
    try {
      final existing = await docRef.get();
      if (existing.exists) return;
    } catch (_) {
      // Non-existent phone_index doc may fail read rule; proceed to create.
    }
    await docRef.set({
      'phone': phone,
      'role': role,
      'gymId': gymId,
      'uid': _auth.currentUser?.uid ?? '',
      'name': name ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<MissingMember>> fetchMissingMembers(String gymId) async {
    final snap =
        await _db.collection('gyms').doc(gymId).collection('missing').get();
    return snap.docs.map((d) {
      final data = d.data();
      return MissingMember(
        id: d.id,
        name: (data['name'] ?? '') as String,
        daysMissing: (data['daysMissing'] ?? 5) as int,
        planName: (data['planName'] ?? '') as String,
        lastMuscleTrained: (data['lastMuscleTrained'] ?? '') as String,
        contacted: (data['contacted'] ?? false) as bool,
      );
    }).toList();
  }
}
