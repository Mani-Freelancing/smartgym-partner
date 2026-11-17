import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/gym_member.dart';
import '../../domain/models/gym_tenant.dart';
import '../../domain/models/machine_guide.dart';
import '../../domain/models/meal_review_item.dart';
import '../../domain/models/missing_member.dart';
import '../../domain/models/trainer_profile.dart';
import '../../domain/models/walk_in_enquiry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

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
        'phone': m.phone,
        'planTitle': m.planTitle,
        'feePaid': m.feePaid,
        'joinedDate': m.joinedDate,
        'expiryDate': m.expiryDate,
        'daysLeft': m.daysLeft,
        'assignedTrainer': m.assignedTrainer,
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

  Future<void> addMember(String gymId, GymMember member) async {
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(member.id)
        .set({
      'id': member.id,
      'name': member.name,
      'phone': member.phone,
      'planTitle': member.planTitle,
      'feePaid': member.feePaid,
      'joinedDate': member.joinedDate,
      'expiryDate': member.expiryDate,
      'daysLeft': member.daysLeft,
      'assignedTrainer': member.assignedTrainer,
      'isPtClient': member.isPtClient,
      'addedByTrainer': member.addedByTrainer,
      'currentWeightKg': member.currentWeightKg,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
    await _db.collection('phone_index').doc(phone).set({
      'phone': phone,
      'role': role,
      'gymId': gymId,
      'uid': _auth.currentUser?.uid ?? '',
      'name': name ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
