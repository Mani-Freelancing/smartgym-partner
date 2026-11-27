import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../data/services/member_whatsapp_service.dart';
import '../../../../data/services/upi_proof_ocr_service.dart';
import '../../../../domain/models/gym_fee_plan.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import '../../shared/upi_payment_proof_section.dart';

class TrainerMembersOnboardingScreen extends StatelessWidget {
  const TrainerMembersOnboardingScreen({super.key});

  void _showAddMemberSheet(BuildContext context, SmartGymState state) {
    final bloc = context.read<SmartGymBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final defaultPlan = GymFeePlan.resolveDefaultRegularPlan(
      state.currentGym.effectiveFeePlans,
    );
    int months = defaultPlan?.durationMonths ?? 1;
    GymFeePlan? selectedPlan = defaultPlan;
    bool isPt = defaultPlan?.includesPt ?? false;
    final amountCtrl = TextEditingController(
      text: (defaultPlan?.price ?? state.currentGym.monthlyFee).toString(),
    );
    final dueCtrl = TextEditingController(text: '0');
    final joinDateCtrl = TextEditingController();

    bool amountEdited = false;
    String paymentMode = 'Cash';
    String proofBase64 = '';
    Uint8List? proofBytes;
    UpiProofExtraction ocrExtraction = const UpiProofExtraction();
    DateTime joiningDate = DateTime.now();
    String selectedTrainer = state.loggedInTrainerName;
    String? errorText;

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')} ${monthNames[d.month - 1]} ${d.year}';
    joinDateCtrl.text = fmtDate(joiningDate);

    void recalcFee() {
      if (amountEdited) return;
      if (selectedPlan != null) {
        amountCtrl.text = selectedPlan!.price.toString();
        return;
      }
      final exact = GymFeePlan.matchPriceForDuration(
        state.currentGym.effectiveFeePlans,
        months: months,
        isPt: isPt,
      );
      if (exact != null) {
        amountCtrl.text = exact.toString();
        return;
      }
      final perMo =
          isPt ? state.currentGym.ptFee : state.currentGym.monthlyFee;
      amountCtrl.text = (perMo * months).toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.lightCardSurface,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        reverseDuration: Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => AppTheme.ensureOwnerLight(
        ctx,
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final mp = AppPalette.of(ctx);
            final expiryDate = (selectedPlan != null &&
                    selectedPlan!.durationMonths == null)
                ? joiningDate.add(Duration(days: selectedPlan!.durationDays))
                : DateTime(
                    joiningDate.year,
                    joiningDate.month + months,
                    joiningDate.day,
                  );
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final daysLeft = expiryDate.difference(today).inDays;
            final feePreview = int.tryParse(amountCtrl.text.trim()) ?? 0;
            final duePreview = int.tryParse(dueCtrl.text.trim()) ?? 0;

            return DraggableScrollableSheet(
              initialChildSize: 0.88,
              minChildSize: 0.55,
              maxChildSize: 0.94,
              expand: false,
              builder: (_, scrollCtrl) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: mp.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: mp.cardSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: mp.gold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: mp.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enroll Paid Customer',
                                style: TextStyle(
                                  color: mp.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Syncs live to Owner Revenue & Member Directory',
                                style: TextStyle(
                                  color: mp.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFECC2),
                            Color(0xFFFFFBF2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEBD7B0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPt ? 'PT VIP PLAN' : 'REGULAR PLAN',
                                style: TextStyle(
                                  color: isPt ? mp.gold : mp.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹$feePreview',
                                    style: TextStyle(
                                      color: mp.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (duePreview > 0)
                                    Text(
                                      '+ ₹$duePreview due',
                                      style: TextStyle(
                                        color: mp.danger,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$months ${months == 1 ? 'Month' : 'Months'} • ${fmtDate(joiningDate)} → ${fmtDate(expiryDate)} ($daysLeft days)',
                            style: TextStyle(
                              color: mp.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(
                        color: mp.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        labelText: 'Customer Full Name',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: mp.textSecondary,
                        ),
                        hintText: 'e.g. Karthikeya Rao',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: mp.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: mp.gold,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: mp.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: mp.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        counterText: '',
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(
                          color: mp.gold,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        labelText: 'Mobile Number',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: mp.textSecondary,
                        ),
                        hintText: '98480 32910',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0,
                          color: mp.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(
                          Icons.phone_android_rounded,
                          color: mp.gold,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: mp.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'MEMBERSHIP PLAN & DURATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                        color: mp.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.currentGym.effectiveFeePlans.map((plan) {
                        final sel = selectedPlan?.id == plan.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setModalState(() {
                              selectedPlan = plan;
                              months = plan.durationMonths ?? 1;
                              isPt = plan.includesPt;
                              amountEdited = false;
                              amountCtrl.text = plan.price.toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7.5,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? mp.goldButton : mp.bg,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: sel ? mp.goldButton : mp.border,
                              ),
                            ),
                            child: Text(
                              '${plan.name} • ₹${plan.price}',
                              style: TextStyle(
                                color: sel ? mp.onAccent : mp.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: mp.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: mp.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Custom Months',
                            style: TextStyle(
                              color: mp.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: months > 1
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        setModalState(() {
                                          months--;
                                          selectedPlan =
                                              GymFeePlan.matchPlanForDuration(
                                            state.currentGym.effectiveFeePlans,
                                            months: months,
                                            isPt: isPt,
                                          );
                                          recalcFee();
                                        });
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  color: months > 1 ? mp.gold : mp.textMuted,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '$months',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: mp.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: months < 36
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        setModalState(() {
                                          months++;
                                          selectedPlan =
                                              GymFeePlan.matchPlanForDuration(
                                            state.currentGym.effectiveFeePlans,
                                            months: months,
                                            isPt: isPt,
                                          );
                                          recalcFee();
                                        });
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: mp.gold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) =>
                                setModalState(() => amountEdited = true),
                            style: TextStyle(
                              color: mp.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              labelText: 'Amount Paid (₹)',
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: mp.textSecondary,
                              ),
                              prefixIcon: Icon(
                                Icons.currency_rupee_rounded,
                                color: mp.gold,
                                size: 17,
                              ),
                              filled: true,
                              fillColor: mp.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: mp.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: mp.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: joinDateCtrl,
                            readOnly: true,
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: joiningDate,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                                builder: (context, child) => Theme(
                                  data: AppTheme.lightTheme.copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: mp.goldButton,
                                      onPrimary: mp.onAccent,
                                      surface: mp.card,
                                      onSurface: mp.textPrimary,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  joiningDate = picked;
                                  joinDateCtrl.text = fmtDate(picked);
                                });
                              }
                            },
                            style: TextStyle(
                              color: mp.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              labelText: 'Joining Date',
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: mp.textSecondary,
                              ),
                              suffixIcon: Icon(
                                Icons.calendar_today_rounded,
                                color: mp.gold,
                                size: 16,
                              ),
                              filled: true,
                              fillColor: mp.bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: mp.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: mp.border),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dueCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setModalState(() {}),
                      style: TextStyle(
                        color: mp.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        labelText: 'Pending Due / Balance (₹) • Optional',
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: mp.textSecondary,
                        ),
                        hintText: '0 if paid in full',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: mp.textMuted,
                        ),
                        prefixIcon: Icon(
                          Icons.pending_actions_rounded,
                          color: mp.amber,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: mp.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: mp.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: mp.border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: mp.gold,
                            title: Text(
                              'Personal Training (PT VIP)',
                              style: TextStyle(
                                color: mp.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            value: isPt,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                isPt = v;
                                selectedPlan = GymFeePlan.matchPlanForDuration(
                                  state.currentGym.effectiveFeePlans,
                                  months: months,
                                  isPt: isPt,
                                );
                                recalcFee();
                              });
                            },
                          ),
                          if (isPt && state.trainers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: state.trainers.map((t) {
                                  final sel = t.name == selectedTrainer;
                                  return ChoiceChip(
                                    label: Text(t.name),
                                    selected: sel,
                                    selectedColor: const Color(0xFF0F766E),
                                    backgroundColor: mp.card,
                                    side: BorderSide(
                                      color: sel
                                          ? const Color(0xFF0F766E)
                                          : mp.border,
                                    ),
                                    labelStyle: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : mp.textSecondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                    onSelected: (_) => setModalState(
                                      () => selectedTrainer = t.name,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'PAYMENT MODE & PROOF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                        color: mp.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                paymentMode = 'Cash';
                                errorText = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: paymentMode == 'Cash'
                                    ? mp.accent.withValues(alpha: 0.12)
                                    : mp.bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: paymentMode == 'Cash'
                                      ? mp.accent
                                      : mp.border,
                                  width: paymentMode == 'Cash' ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.payments_rounded,
                                    size: 16,
                                    color: paymentMode == 'Cash'
                                        ? mp.accent
                                        : mp.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cash',
                                    style: TextStyle(
                                      color: paymentMode == 'Cash'
                                          ? mp.accent
                                          : mp.textSecondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                paymentMode = 'Online';
                                errorText = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: paymentMode == 'Online'
                                    ? mp.cardSubtle
                                    : mp.bg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: paymentMode == 'Online'
                                      ? mp.gold
                                      : mp.border,
                                  width: paymentMode == 'Online' ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 16,
                                    color: paymentMode == 'Online'
                                        ? mp.gold
                                        : mp.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Online / UPI',
                                    style: TextStyle(
                                      color: paymentMode == 'Online'
                                          ? mp.gold
                                          : mp.textSecondary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (paymentMode == 'Online') ...[
                      const SizedBox(height: 10),
                      UpiPaymentProofSection(
                        proofBytes: proofBytes,
                        ocrExtraction: ocrExtraction,
                        enteredAmount: feePreview,
                        existingMembers: state.members,
                        accentColor: mp.gold,
                        cardBackground: mp.bg,
                        onProofSelected: (result) {
                          setModalState(() {
                            proofBytes = result.bytes;
                            proofBase64 = result.base64;
                            ocrExtraction = result.ocr;
                            errorText = null;
                          });
                        },
                        onError: (msg) => setModalState(() => errorText = msg),
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mp.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mp.goldButton,
                          foregroundColor: mp.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final digits =
                              phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                          final fee = int.tryParse(amountCtrl.text.trim());
                          final due = int.tryParse(dueCtrl.text.trim()) ?? 0;
                          if (name.isEmpty || digits.length != 10) {
                            HapticFeedback.heavyImpact();
                            setModalState(() {
                              errorText =
                                  'Enter customer name and 10-digit mobile number.';
                            });
                            return;
                          }
                          if (fee == null || fee < 0 || due < 0) {
                            HapticFeedback.heavyImpact();
                            setModalState(() {
                              errorText = 'Enter a valid amount.';
                            });
                            return;
                          }
                          final utr = paymentMode == 'Online'
                              ? ocrExtraction.utr.trim()
                              : '';
                          if (paymentMode == 'Online') {
                            if (proofBase64.isEmpty) {
                              HapticFeedback.heavyImpact();
                              setModalState(() {
                                errorText =
                                    'Please upload payment screenshot for Online payment.';
                              });
                              return;
                            }
                            final effectiveOcr =
                                UpiProofOcrService.refineForExpectedAmount(
                              ocrExtraction,
                              fee,
                            );
                            final audit = UpiProofOcrService.auditProof(
                              extracted: effectiveOcr,
                              enteredAmount: fee,
                              existingMembers: state.members,
                            );
                            if (audit.isBlocked) {
                              HapticFeedback.heavyImpact();
                              setModalState(() => errorText = null);
                              return;
                            }
                          }
                          final planLabel = selectedPlan?.name ??
                              '$months ${months == 1 ? 'Month' : 'Months'} ${isPt ? 'PT VIP' : 'Regular'}';
                          final enrolledMember = GymMember(
                            id: 'tmp',
                            name: name,
                            phone: '+91$digits',
                            planTitle: planLabel,
                            feePaid: fee,
                            dueAmount: due,
                            joinedDate: fmtDate(joiningDate),
                            expiryDate: fmtDate(expiryDate),
                            daysLeft: daysLeft,
                            assignedTrainer: isPt ? selectedTrainer : null,
                            isPtClient: isPt,
                            addedByTrainer: state.loggedInTrainerName,
                            paymentMode: paymentMode,
                            paymentReference: utr,
                          );
                          HapticFeedback.mediumImpact();
                          bloc.add(
                            AddNewGymMemberEvent(
                              name: name,
                              phone: '+91$digits',
                              planTitle: planLabel,
                              feePaid: fee,
                              dueAmount: due,
                              daysValid: daysLeft,
                              isPtClient: isPt,
                              assignedTrainer: isPt ? selectedTrainer : null,
                              addedByTrainer: state.loggedInTrainerName,
                              joinedDate: fmtDate(joiningDate),
                              expiryDate: fmtDate(expiryDate),
                              paymentMode: paymentMode,
                              paymentReference: utr,
                              paymentProofBase64:
                                  paymentMode == 'Online' ? proofBase64 : '',
                            ),
                          );
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: mp.snackBg,
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                '✅ $name added! Owner Revenue increased by ₹$fee',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                          if (context.mounted) {
                            await MemberWhatsAppService
                                .showEnrollmentSuccessDialog(
                              context: context,
                              gymName: state.currentGym.name,
                              member: enrolledMember,
                              accentColor: mp.gold,
                            );
                          }
                        },
                        icon: const Icon(Icons.verified_rounded, size: 19),
                        label: Text(
                          'ADD CUSTOMER & COLLECT ₹$feePreview',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddEnquiryDialog(BuildContext context, SmartGymState state) {
    final bloc = context.read<SmartGymBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final planCtrl = TextEditingController(text: '3-Month Weight Loss + PT');
    String? errorText;

    const planPresets = [
      '1-Month Regular',
      '3-Month Weight Loss + PT',
      '6-Month Transformation',
      'Personal Training VIP',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.lightCardSurface,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        reverseDuration: Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => AppTheme.ensureOwnerLight(
        ctx,
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final mp = AppPalette.of(ctx);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: mp.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: mp.cardSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: mp.gold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.person_search_rounded,
                            color: mp.gold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Walk-In Enquiry',
                                style: TextStyle(
                                  color: mp.textPrimary,
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Track visitor leads & convert them in 1 tap later',
                                style: TextStyle(
                                  color: mp.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(
                        color: mp.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        labelText: 'Visitor Name',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: mp.textSecondary,
                        ),
                        hintText: 'e.g. Harish Reddy',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: mp.textMuted,
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: mp.gold,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: mp.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: mp.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        counterText: '',
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(
                          color: mp.gold,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        labelText: 'Mobile Number',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: mp.textSecondary,
                        ),
                        hintText: '90102 33445',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0,
                          color: mp.textMuted,
                        ),
                        prefixIcon: Icon(
                          Icons.phone_android_rounded,
                          color: mp.gold,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: mp.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: planCtrl,
                      style: TextStyle(
                        color: mp.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        labelText: 'Interested Plan / Goal',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: mp.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.track_changes_rounded,
                          color: mp.gold,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: mp.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: mp.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: planPresets.map((preset) {
                        return ActionChip(
                          backgroundColor: mp.cardSubtle,
                          side: BorderSide(
                            color: mp.gold.withValues(alpha: 0.35),
                          ),
                          label: Text(
                            preset,
                            style: TextStyle(
                              color: mp.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setModalState(() => planCtrl.text = preset);
                          },
                        );
                      }).toList(),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: mp.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mp.goldButton,
                          foregroundColor: mp.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final digits =
                              phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                          if (name.isEmpty || digits.length != 10) {
                            HapticFeedback.heavyImpact();
                            setModalState(() {
                              errorText =
                                  'Enter visitor name and valid 10-digit mobile number.';
                            });
                            return;
                          }
                          HapticFeedback.mediumImpact();
                          bloc.add(
                            AddWalkInEnquiryEvent(
                              name: name,
                              phone: '+91$digits',
                              interestedPlan: planCtrl.text.trim().isEmpty
                                  ? '1-Month Regular'
                                  : planCtrl.text.trim(),
                              loggedByTrainer: state.loggedInTrainerName,
                            ),
                          );
                          Navigator.pop(ctx);
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: mp.snackBg,
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                'Walk-in lead "$name" logged!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bookmark_add_rounded, size: 19),
                        label: const Text(
                          'SAVE WALK-IN ENQUIRY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.ensureOwnerLight(
      context,
      child: Builder(
        builder: (context) {
          final p = AppPalette.of(context);
          return BlocBuilder<SmartGymBloc, SmartGymState>(
            builder: (context, state) {
              return RefreshIndicator(
                color: p.gold,
                backgroundColor: p.card,
                onRefresh: () async {
                  context
                      .read<SmartGymBloc>()
                      .add(const RefreshGymDataEvent());
                  await Future<void>.delayed(
                    const Duration(milliseconds: 450),
                  );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
                  children: [
                    // Sunlit Warm Gold-to-White Admissions Hero Card
                    CredStaggeredItem(
                      index: 0,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFFFECC2),
                              Color(0xFFFFF7E4),
                              Color(0xFFFFFFFF),
                            ],
                            stops: [0.0, 0.45, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFEBD7B0)),
                          boxShadow: p.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FLOOR ADMISSIONS & ENQUIRIES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: p.gold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Onboard Walk-In Customers & Assign PT',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: p.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Every new customer added here automatically updates the Gym Owner\'s revenue and PT split.',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            CredNeoPopButton(
                              label: '+ Add New Paid Customer',
                              icon: Icons.person_add_alt_1_rounded,
                              color: p.goldButton,
                              textColor: Colors.white,
                              onTap: () => _showAddMemberSheet(context, state),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: p.gold.withValues(alpha: 0.55),
                                  ),
                                  foregroundColor: p.gold,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                onPressed: () =>
                                    _showAddEnquiryDialog(context, state),
                                icon: const Icon(
                                  Icons.note_add_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  '+ Log Walk-In Enquiry (Not Paid Yet)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pending Walk-In Enquiries (1-Tap Convert to Paid Member)
                    Text(
                      'WALK-IN ENQUIRIES (1-TAP CONVERT TO MEMBER)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(state.enquiries.length, (i) {
                      final enq = state.enquiries[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CredMetalCard(
                          glowColor: enq.converted ? p.accent : p.gold,
                          padding: const EdgeInsets.all(15),
                          borderRadius: 18,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      enq.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${enq.interestedPlan} • ${enq.timeLabel}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: enq.converted
                                      ? p.bg
                                      : p.goldButton,
                                  foregroundColor: enq.converted
                                      ? p.textMuted
                                      : p.onAccent,
                                ),
                                onPressed: enq.converted
                                    ? null
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        context.read<SmartGymBloc>().add(
                                              ConvertEnquiryToMemberEvent(i),
                                            );
                                      },
                                child: Text(
                                  enq.converted ? 'Joined' : 'Convert Paid',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: enq.converted
                                        ? p.textMuted
                                        : p.onAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    Text(
                      'ALL GYM MEMBERS (${state.members.length})',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...state.members.map((GymMember m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CredMetalCard(
                          glowColor: m.isExpired
                              ? p.danger
                              : (m.isPtClient ? p.gold : p.accent),
                          padding: const EdgeInsets.all(15),
                          borderRadius: 18,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.respectfulName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.5,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      m.isPtClient
                                          ? '${m.planTitle} • Trainer: ${m.assignedTrainer}'
                                          : '${m.planTitle} • Expires: ${m.expiryDate}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                m.isExpired ? 'EXPIRED' : '${m.daysLeft}d left',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: m.isExpired ? p.danger : p.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
