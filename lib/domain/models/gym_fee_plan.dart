import 'package:equatable/equatable.dart';

/// Represents a configurable gym membership or personal training package
/// (e.g., 1 Month, 3 Months, 6 Months, 1 Year, PT VIP, Couple/Student plans).
class GymFeePlan extends Equatable {
  final String id;
  final String name;
  final int price;
  final int durationDays;
  final int? durationMonths;
  final bool includesPt;
  final bool isCustom;

  const GymFeePlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    this.durationMonths,
    this.includesPt = false,
    this.isCustom = false,
  });

  String get durationLabel {
    if (durationMonths != null && durationMonths! > 0) {
      return '$durationMonths ${durationMonths == 1 ? 'Month' : 'Months'}';
    }
    return '$durationDays ${durationDays == 1 ? 'Day' : 'Days'}';
  }

  GymFeePlan copyWith({
    String? id,
    String? name,
    int? price,
    int? durationDays,
    int? durationMonths,
    bool clearDurationMonths = false,
    bool? includesPt,
    bool? isCustom,
  }) {
    return GymFeePlan(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      durationDays: durationDays ?? this.durationDays,
      durationMonths:
          clearDurationMonths ? null : (durationMonths ?? this.durationMonths),
      includesPt: includesPt ?? this.includesPt,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'durationDays': durationDays,
        if (durationMonths != null) 'durationMonths': durationMonths,
        'includesPt': includesPt,
        'isCustom': isCustom,
      };

  factory GymFeePlan.fromJson(Map<String, dynamic> map) {
    final months = (map['durationMonths'] as num?)?.toInt();
    final rawDays = (map['durationDays'] as num?)?.toInt();
    final days = rawDays ?? ((months ?? 1) * 30);
    return GymFeePlan(
      id: (map['id'] ?? 'plan_${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      name: (map['name'] ?? 'Membership Plan').toString(),
      price: (map['price'] as num?)?.toInt() ?? 0,
      durationDays: days < 1 ? 30 : days,
      durationMonths: months,
      includesPt: map['includesPt'] is bool ? map['includesPt'] as bool : false,
      isCustom: map['isCustom'] is bool ? map['isCustom'] as bool : false,
    );
  }

  static List<GymFeePlan> decodeList(dynamic raw) {
    if (raw is! List) return const [];
    final plans = <GymFeePlan>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        plans.add(GymFeePlan.fromJson(item));
      } else if (item is Map) {
        plans.add(GymFeePlan.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return plans;
  }

  static List<GymFeePlan> defaultPlans({
    int monthlyFee = 1500,
    int ptFee = 6000,
  }) {
    final baseMonthly = monthlyFee > 0 ? monthlyFee : 1500;
    final basePt = ptFee > 0 ? ptFee : 6000;
    final qPrice = baseMonthly == 1500
        ? 4000
        : ((baseMonthly * 2.65 / 100).round() * 100).clamp(1, 1000000);
    final hPrice = baseMonthly == 1500
        ? 7500
        : ((baseMonthly * 5.0 / 100).round() * 100).clamp(1, 1000000);
    final aPrice = baseMonthly == 1500
        ? 12000
        : ((baseMonthly * 8.0 / 100).round() * 100).clamp(1, 1000000);
    return [
      GymFeePlan(
        id: 'plan_1m',
        name: '1 Month Regular',
        price: baseMonthly,
        durationDays: 30,
        durationMonths: 1,
      ),
      GymFeePlan(
        id: 'plan_3m',
        name: '3 Months Quarterly',
        price: qPrice,
        durationDays: 90,
        durationMonths: 3,
      ),
      GymFeePlan(
        id: 'plan_6m',
        name: '6 Months Half-Yearly',
        price: hPrice,
        durationDays: 180,
        durationMonths: 6,
      ),
      GymFeePlan(
        id: 'plan_12m',
        name: '1 Year Annual',
        price: aPrice,
        durationDays: 365,
        durationMonths: 12,
      ),
      GymFeePlan(
        id: 'plan_pt_1m',
        name: 'Personal Training VIP',
        price: basePt,
        durationDays: 30,
        durationMonths: 1,
        includesPt: true,
      ),
    ];
  }

  static int resolveMonthlyFee(
    List<GymFeePlan> plans, {
    int fallback = 1500,
  }) {
    final nonPt = plans.where((p) => !p.includesPt && p.price > 0).toList();
    if (nonPt.isEmpty) return fallback;
    final oneMo = nonPt.where((p) => p.durationMonths == 1).toList();
    if (oneMo.isNotEmpty) return oneMo.first.price;
    return nonPt.first.price;
  }

  static int resolvePtFee(
    List<GymFeePlan> plans, {
    int fallback = 6000,
  }) {
    final pt = plans.where((p) => p.includesPt && p.price > 0).toList();
    if (pt.isEmpty) return fallback;
    return pt.first.price;
  }

  static GymFeePlan? matchPlanForDuration(
    List<GymFeePlan> plans, {
    required int months,
    required bool isPt,
  }) {
    for (final p in plans) {
      if (p.includesPt == isPt && p.durationMonths == months && p.price > 0) {
        return p;
      }
    }
    return null;
  }

  /// Returns the default 1-month regular plan (or first non-PT/available plan).
  static GymFeePlan? resolveDefaultRegularPlan(List<GymFeePlan> plans) {
    final oneMonthRegular = matchPlanForDuration(
      plans,
      months: 1,
      isPt: false,
    );
    if (oneMonthRegular != null) return oneMonthRegular;
    for (final p in plans) {
      if (!p.includesPt && p.price > 0) return p;
    }
    return plans.isNotEmpty ? plans.first : null;
  }

  static int? matchPriceForDuration(
    List<GymFeePlan> plans, {
    required int months,
    required bool isPt,
  }) {
    return matchPlanForDuration(plans, months: months, isPt: isPt)?.price;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        price,
        durationDays,
        durationMonths,
        includesPt,
        isCustom,
      ];
}
