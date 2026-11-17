import 'package:flutter/material.dart';
import '../../domain/models/gym_member.dart';
import '../../domain/models/gym_tenant.dart';
import '../../domain/models/machine_guide.dart';
import '../../domain/models/meal_review_item.dart';
import '../../domain/models/missing_member.dart';
import '../../domain/models/trainer_profile.dart';
import '../../domain/models/walk_in_enquiry.dart';

class GymRepository {
  List<GymTenant> getInitialGyms() {
    return const [
      GymTenant(
        id: 'imfit_hitech',
        name: 'IMFIT Gym',
        area: 'HITEC City Main Rd, Madhapur',
        headTrainer: 'Coach Karthik Reddy',
        brandColor: Color(0xFF00E676),
        activeCrowd: 18,
        maxCapacity: 60,
        monthlyFee: 2000,
        ptFee: 5000,
      ),
      GymTenant(
        id: 'gympoint_madhapur',
        name: 'GymPoint Fitness Studio',
        area: 'Siddhi Vinayak Nagar, Madhapur',
        headTrainer: 'Coach Vikram Singh',
        brandColor: Color(0xFF3B82F6),
        activeCrowd: 42,
        maxCapacity: 55,
        monthlyFee: 1800,
        ptFee: 4500,
      ),
      GymTenant(
        id: 'primezone_ayyappa',
        name: 'Primezone Fitness',
        area: 'Ayyappa Society, Madhapur',
        headTrainer: 'Coach Naveen Kumar',
        brandColor: Color(0xFFF59E0B),
        activeCrowd: 24,
        maxCapacity: 50,
        monthlyFee: 1500,
        ptFee: 4000,
      ),
    ];
  }

  List<TrainerProfile> getInitialTrainers() {
    return const [
      TrainerProfile(
        id: 'tr_1',
        name: 'Coach Karthik Reddy',
        specialty: 'Strength & Fat Loss Head Coach',
        morningCheckInTime: '05:48 AM',
        isOnDuty: true,
        commissionPercent: 50,
      ),
      TrainerProfile(
        id: 'tr_2',
        name: 'Coach Arjun Varma',
        specialty: 'Hypertrophy & Mobility',
        morningCheckInTime: '06:05 AM',
        isOnDuty: true,
        commissionPercent: 50,
      ),
      TrainerProfile(
        id: 'tr_3',
        name: 'Coach Sameer Khan',
        specialty: 'Evening Transformation Coach',
        morningCheckInTime: null,
        isOnDuty: false,
        commissionPercent: 50,
      ),
    ];
  }

  List<GymMember> getInitialMembers() {
    return const [
      GymMember(
        id: 'mem_1',
        name: 'Arjun Nair',
        phone: '+91 98401 22310',
        planTitle: 'Personal Training VIP',
        feePaid: 5000,
        joinedDate: 'Today, 09:30 AM',
        expiryDate: '16 Dec 2026',
        daysLeft: 30,
        assignedTrainer: 'Coach Karthik Reddy',
        isPtClient: true,
        addedByTrainer: 'Coach Karthik Reddy',
        currentWeightKg: 78.4,
      ),
      GymMember(
        id: 'mem_2',
        name: 'Sneha Reddy',
        phone: '+91 90004 51289',
        planTitle: 'Personal Training VIP',
        feePaid: 5000,
        joinedDate: '12 Nov 2026',
        expiryDate: '12 Dec 2026',
        daysLeft: 26,
        assignedTrainer: 'Coach Karthik Reddy',
        isPtClient: true,
        addedByTrainer: 'Coach Karthik Reddy',
        currentWeightKg: 62.1,
      ),
      GymMember(
        id: 'mem_3',
        name: 'Rohan Verma',
        phone: '+91 97012 88341',
        planTitle: 'Personal Training VIP',
        feePaid: 5000,
        joinedDate: '10 Nov 2026',
        expiryDate: '10 Dec 2026',
        daysLeft: 24,
        assignedTrainer: 'Coach Arjun Varma',
        isPtClient: true,
        addedByTrainer: 'Coach Arjun Varma',
        currentWeightKg: 84.0,
      ),
      GymMember(
        id: 'mem_4',
        name: 'Deepak Varma',
        phone: '+91 91234 55678',
        planTitle: '6-Month Pro Plan',
        feePaid: 9000,
        joinedDate: 'Today, 11:15 AM',
        expiryDate: '16 May 2027',
        daysLeft: 180,
        assignedTrainer: null,
        isPtClient: false,
        addedByTrainer: 'Coach Karthik Reddy',
        currentWeightKg: 71.5,
      ),
      GymMember(
        id: 'mem_5',
        name: 'Vikram Aditya',
        phone: '+91 99887 66554',
        planTitle: '1-Month Regular',
        feePaid: 2000,
        joinedDate: '18 Oct 2026',
        expiryDate: '18 Nov 2026',
        daysLeft: 2,
        assignedTrainer: null,
        isPtClient: false,
        addedByTrainer: 'Coach Arjun Varma',
        currentWeightKg: 76.0,
      ),
      GymMember(
        id: 'mem_6',
        name: 'Prashanth Rao',
        phone: '+91 94401 33992',
        planTitle: '1-Month Regular',
        feePaid: 2000,
        joinedDate: '15 Oct 2026',
        expiryDate: '15 Nov 2026',
        daysLeft: 0,
        assignedTrainer: null,
        isPtClient: false,
        addedByTrainer: 'Coach Karthik Reddy',
        currentWeightKg: 81.2,
      ),
    ];
  }

  List<WalkInEnquiry> getInitialEnquiries() {
    return const [
      WalkInEnquiry(
        id: 'enq_1',
        name: 'Sandeep Chowdary (Mindspace IT)',
        phone: '+91 98490 11223',
        interestedPlan: '6-Month Plan + PT Trial',
        loggedByTrainer: 'Coach Karthik Reddy',
        timeLabel: 'Today, 10:40 AM',
      ),
      WalkInEnquiry(
        id: 'enq_2',
        name: 'Meghana Rao',
        phone: '+91 91772 44556',
        interestedPlan: '1-Month Fat Loss Batch',
        loggedByTrainer: 'Coach Arjun Varma',
        timeLabel: 'Yesterday, 07:15 PM',
      ),
    ];
  }

  List<MachineGuide> getMachineGuides() {
    return const [
      MachineGuide(
        code: 'QR #04',
        name: 'Lat Pulldown Pro',
        muscle: 'Back • Lats',
        mistakeTip: 'Avoid leaning back 45° or swinging your lower back.',
      ),
      MachineGuide(
        code: 'QR #09',
        name: 'Pec Deck Chest Fly',
        muscle: 'Chest • Inner Pec',
        mistakeTip: 'Keep a slight elbow bend; do not shrug your shoulders.',
      ),
      MachineGuide(
        code: 'QR #14',
        name: 'Hack Squat Machine',
        muscle: 'Quads • Glutes',
        mistakeTip: 'Place feet shoulder-width; never lock knees at the top.',
      ),
    ];
  }

  List<MealReviewItem> getInitialMealQueue() {
    return const [
      MealReviewItem(
        id: 'meal_1',
        memberName: 'Arjun Nair (PT VIP)',
        timeLabel: '1:15 PM • Lunch Plate',
        mealDescription: '150g Grilled Chicken + 1 Cup Rice + Dal + Curd',
        macros: '520 kcal • 44g Protein',
      ),
      MealReviewItem(
        id: 'meal_2',
        memberName: 'Sneha Reddy (PT VIP)',
        timeLabel: '8:45 AM • Breakfast Plate',
        mealDescription: '3 Idli + Sambar + 1 Boiled Egg',
        macros: '340 kcal • 12g Protein',
      ),
      MealReviewItem(
        id: 'meal_3',
        memberName: 'Rohan Verma (PT VIP)',
        timeLabel: '9:10 PM • Dinner Plate',
        mealDescription: '2 Chapati + Paneer Bhurji (120g) + Salad',
        macros: '460 kcal • 28g Protein',
      ),
    ];
  }

  List<MissingMember> getInitialMissingMembers() {
    return const [
      MissingMember(
        id: 'missing_1',
        name: 'Rahul Sharma',
        daysMissing: 5,
        planName: '6-Month Gold (Expires in 42d)',
        lastMuscleTrained: 'Chest & Triceps',
      ),
      MissingMember(
        id: 'missing_2',
        name: 'Kiran Kumar',
        daysMissing: 6,
        planName: 'Monthly Plan (Expires in 4d)',
        lastMuscleTrained: 'Back & Biceps',
      ),
      MissingMember(
        id: 'missing_3',
        name: 'Divya Krishnan',
        daysMissing: 5,
        planName: 'Personal Training VIP',
        lastMuscleTrained: 'Legs & Core',
      ),
    ];
  }
}
