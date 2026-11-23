import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../data/services/member_whatsapp_service.dart';
import '../../../domain/models/gym_fee_plan.dart';
import '../../../domain/models/gym_member.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class OwnerAddMemberScreen extends StatefulWidget {
  const OwnerAddMemberScreen({super.key});

  @override
  State<OwnerAddMemberScreen> createState() => _OwnerAddMemberScreenState();
}

class _OwnerAddMemberScreenState extends State<OwnerAddMemberScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dueCtrl = TextEditingController(text: '0');
  final _weightCtrl = TextEditingController(text: '70.0');
  final _joinDateCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int _months = 1;
  GymFeePlan? _selectedPlan;
  bool _isPt = false;
  String _paymentMode = 'Cash'; // 'Cash' | 'Online'
  String _paymentProofBase64 = '';
  Uint8List? _paymentProofBytes;
  DateTime _joiningDate = DateTime.now();
  String? _selectedTrainer;
  String? _errorText;
  bool _amountEditedManually = false;

  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    final gym = context.read<SmartGymBloc>().state.currentGym;
    _amountCtrl.text = gym.monthlyFee.toString();
    _joinDateCtrl.text = _toInputDate(_joiningDate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _dueCtrl.dispose();
    _weightCtrl.dispose();
    _joinDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentScreenshot() async {
    HapticFeedback.selectionClick();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1E29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Payment Proof',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppTheme.ownerGold,
                ),
                title: const Text(
                  'Take Photo (Camera)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'Snap customer\'s payment screen directly',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.trainerCyan,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 480,
      imageQuality: 50,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final encoded = base64Encode(bytes);
    if (encoded.length > 140000) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Screenshot too large. Please pick a smaller image.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _paymentProofBytes = bytes;
      _paymentProofBase64 = encoded;
      _errorText = null;
    });
  }

  String _toInputDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  void _recalculateSuggestedAmount(SmartGymState state) {
    if (_amountEditedManually) return;
    if (_selectedPlan != null) {
      _amountCtrl.text = _selectedPlan!.price.toString();
      return;
    }
    final exactMatch = GymFeePlan.matchPriceForDuration(
      state.currentGym.effectiveFeePlans,
      months: _months,
      isPt: _isPt,
    );
    if (exactMatch != null) {
      _amountCtrl.text = exactMatch.toString();
      return;
    }
    final perMonth = _isPt ? state.currentGym.ptFee : state.currentGym.monthlyFee;
    _amountCtrl.text = (perMonth * _months).toString();
  }

  DateTime get _expiryDate {
    final plan = _selectedPlan;
    if (plan != null && plan.durationMonths == null) {
      return _joiningDate.add(Duration(days: plan.durationDays));
    }
    return DateTime(
      _joiningDate.year,
      _joiningDate.month + _months,
      _joiningDate.day,
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')} ${_monthNames[dt.month - 1]} ${dt.year}';

  Future<void> _pickJoiningDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.ownerGold,
              onPrimary: Colors.black,
              surface: Color(0xFF1A1E29),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _joiningDate = picked;
        _joinDateCtrl.text = _toInputDate(picked);
      });
    }
  }

  Future<void> _submit(SmartGymState state) async {
    final name = _nameCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final fee = int.tryParse(_amountCtrl.text.trim());
    final due = int.tryParse(_dueCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 70.0;

    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = 'Enter member full name.');
      return;
    }
    if (digits.length != 10) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = 'Enter a valid 10-digit mobile number.');
      return;
    }
    if (fee == null || fee < 0 || due < 0) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = 'Enter valid fee and due amounts.');
      return;
    }
    if (_paymentMode == 'Online' && _paymentProofBase64.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorText = 'Please upload payment screenshot for Online payment.';
      });
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = _expiryDate.difference(today).inDays;
    final planLabel = _selectedPlan?.name ??
        '$_months ${_months == 1 ? 'Month' : 'Months'} ${_isPt ? 'PT VIP' : 'Regular'}';
    final trainerName = _isPt
        ? (_selectedTrainer ??
            (state.trainers.isNotEmpty
                ? state.trainers.first.name
                : state.currentGym.headTrainer))
        : null;
    final joinedStr = _formatDate(_joiningDate);
    final expiryStr = _formatDate(_expiryDate);
    final enrolledMember = GymMember(
      id: 'tmp',
      name: name,
      phone: '+91$digits',
      planTitle: planLabel,
      feePaid: fee,
      dueAmount: due,
      joinedDate: joinedStr,
      expiryDate: expiryStr,
      daysLeft: daysLeft,
      assignedTrainer: trainerName,
      isPtClient: _isPt,
      addedByTrainer: 'Owner (${state.currentGym.headTrainer})',
      currentWeightKg: weight.clamp(20.0, 300.0),
      paymentMode: _paymentMode,
    );

    HapticFeedback.mediumImpact();
    context.read<SmartGymBloc>().add(
          AddNewGymMemberEvent(
            name: name,
            phone: '+91$digits',
            planTitle: planLabel,
            feePaid: fee,
            dueAmount: due,
            daysValid: daysLeft,
            isPtClient: _isPt,
            assignedTrainer: trainerName,
            addedByTrainer: 'Owner (${state.currentGym.headTrainer})',
            joinedDate: joinedStr,
            expiryDate: expiryStr,
            currentWeightKg: weight.clamp(20.0, 300.0),
            paymentMode: _paymentMode,
            paymentProofBase64:
                _paymentMode == 'Online' ? _paymentProofBase64 : '',
          ),
        );

    await MemberWhatsAppService.showEnrollmentSuccessDialog(
      context: context,
      gymName: state.currentGym.name,
      member: enrolledMember,
      accentColor: AppTheme.ownerGold,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final feePreview = int.tryParse(_amountCtrl.text.trim()) ?? 0;
        final duePreview = int.tryParse(_dueCtrl.text.trim()) ?? 0;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysLeft = _expiryDate.difference(today).inDays;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            backgroundColor: AppTheme.scaffoldBg,
            foregroundColor: Colors.white,
            title: const Text(
              'Enroll Paid Member',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Live Membership Summary Card
                CredMetalCard(
                  glowColor: _isPt ? AppTheme.champagne : AppTheme.ownerGold,
                  enableShimmer: true,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            gym.name.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.ownerGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (_isPt
                                      ? AppTheme.champagne
                                      : AppTheme.accent)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              _isPt ? 'PT VIP PLAN' : 'REGULAR PLAN',
                              style: TextStyle(
                                color:
                                    _isPt ? AppTheme.champagne : AppTheme.accent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹$feePreview',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          if (duePreview > 0) ...[
                            const SizedBox(width: 10),
                            Text(
                              '+ ₹$duePreview due',
                              style: const TextStyle(
                                color: AppTheme.amber,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_months ${_months == 1 ? 'Month' : 'Months'} • ${_formatDate(_joiningDate)} → ${_formatDate(_expiryDate)} ($daysLeft days)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 2. Member Details
                const _SectionLabel('MEMBER DETAILS'),
                const SizedBox(height: 10),
                _PremiumField(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  hint: 'e.g. Rahul Sharma',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PremiumField(
                        controller: _phoneCtrl,
                        label: 'Mobile Number',
                        hint: '98490 00000',
                        icon: Icons.phone_android_rounded,
                        prefixText: '+91 ',
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _PremiumField(
                        controller: _weightCtrl,
                        label: 'Weight (kg)',
                        hint: '70.0',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 3. Gym Packages + Plan Duration
                const _SectionLabel('MEMBERSHIP PLAN & DURATION'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: gym.effectiveFeePlans.map((plan) {
                    final selected = _selectedPlan?.id == plan.id;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedPlan = plan;
                          _months = plan.durationMonths ?? 1;
                          _isPt = plan.includesPt;
                          _amountEditedManually = false;
                          _amountCtrl.text = plan.price.toString();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.ownerGold.withValues(alpha: 0.18)
                              : const Color(0xFF1A1E29),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppTheme.ownerGold
                                : Colors.white12,
                          ),
                        ),
                        child: Text(
                          '${plan.name} • ₹${plan.price}',
                          style: TextStyle(
                            color: selected
                                ? AppTheme.ownerGold
                                : Colors.white70,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1, 3, 6, 12].map((m) {
                    final selected = _selectedPlan == null && _months == m;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedPlan = null;
                          _months = m;
                          _recalculateSuggestedAmount(state);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.ownerGold.withValues(alpha: 0.18)
                              : const Color(0xFF1A1E29),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                selected ? AppTheme.ownerGold : Colors.white12,
                          ),
                        ),
                        child: Text(
                          '$m ${m == 1 ? 'Mo' : 'Mos'}',
                          style: TextStyle(
                            color:
                                selected ? AppTheme.ownerGold : Colors.white70,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E29),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Custom Months',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _months > 1
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedPlan = null;
                                      _months--;
                                      _recalculateSuggestedAmount(state);
                                    });
                                  }
                                : null,
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              color: AppTheme.ownerGold,
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$_months',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _months < 36
                                ? () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedPlan = null;
                                      _months++;
                                      _recalculateSuggestedAmount(state);
                                    });
                                  }
                                : null,
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppTheme.ownerGold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 4. Amount & Joining Date
                const _SectionLabel('PAYMENT & JOINING DATE'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PremiumField(
                        controller: _amountCtrl,
                        label: 'Amount Paid (₹)',
                        hint: '1500',
                        icon: Icons.currency_rupee_rounded,
                        keyboardType: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {
                          _amountEditedManually = true;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _joinDateCtrl,
                        readOnly: true,
                        onTap: _pickJoiningDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Joining Date',
                          hintText: '18/11/2026',
                          labelStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                          hintStyle: const TextStyle(color: Colors.white24),
                          suffixIcon: IconButton(
                            tooltip: 'Pick from Calendar',
                            icon: const Icon(
                              Icons.calendar_today_rounded,
                              color: AppTheme.ownerGold,
                              size: 18,
                            ),
                            onPressed: _pickJoiningDate,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1A1E29),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppTheme.ownerGold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PremiumField(
                  controller: _dueCtrl,
                  label: 'Pending Due / Balance (₹) • Optional',
                  hint: '0 (if paid in full)',
                  icon: Icons.pending_actions_rounded,
                  keyboardType: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // 5. Personal Training Toggle + Trainer Selector
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E29),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isPt
                          ? AppTheme.champagne.withValues(alpha: 0.45)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppTheme.champagne,
                        title: const Text(
                          'Personal Training (PT VIP)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Includes 50/50 trainer split & meal tracking',
                          style: TextStyle(color: Colors.white54, fontSize: 11.5),
                        ),
                        value: _isPt,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isPt = v;
                            _recalculateSuggestedAmount(state);
                          });
                        },
                      ),
                      if (_isPt && state.trainers.isNotEmpty) ...[
                        const Divider(color: Colors.white12, height: 8),
                        DropdownButtonFormField<String>(
                          initialValue:
                              _selectedTrainer ?? state.trainers.first.name,
                          dropdownColor: const Color(0xFF1A1E29),
                          decoration: const InputDecoration(
                            labelText: 'Assign Personal Trainer',
                            labelStyle: TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                          ),
                          items: state.trainers
                              .map(
                                (t) => DropdownMenuItem<String>(
                                  value: t.name,
                                  child: Text(
                                    t.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedTrainer = val),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // 6. Payment Mode (Cash vs Online + Screenshot)
                const _SectionLabel('PAYMENT MODE & PROOF'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: 'Cash',
                        icon: Icons.payments_rounded,
                        selected: _paymentMode == 'Cash',
                        accent: AppTheme.accent,
                        onTap: () => setState(() {
                          _paymentMode = 'Cash';
                          _errorText = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeChip(
                        label: 'Online / UPI',
                        icon: Icons.qr_code_2_rounded,
                        selected: _paymentMode == 'Online',
                        accent: AppTheme.ownerGold,
                        onTap: () => setState(() {
                          _paymentMode = 'Online';
                          _errorText = null;
                        }),
                      ),
                    ),
                  ],
                ),
                if (_paymentMode == 'Online') ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickPaymentScreenshot,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E29),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _paymentProofBytes != null
                              ? AppTheme.accent.withValues(alpha: 0.5)
                              : AppTheme.ownerGold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: _paymentProofBytes != null
                          ? Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    _paymentProofBytes!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment Screenshot Attached',
                                        style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Tap to change screenshot',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.accent,
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file_rounded,
                                  color: AppTheme.ownerGold,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'UPLOAD PAYMENT SCREENSHOT',
                                  style: TextStyle(
                                    color: AppTheme.ownerGold,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],

                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.ownerGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _submit(state),
                    icon: const Icon(Icons.verified_rounded, size: 20),
                    label: const Text(
                      'ENROLL PAID MEMBER',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.prefixText,
    this.keyboardType,
    this.maxLength,
    this.formatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: formatters,
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          color: AppTheme.ownerGold,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(icon, color: AppTheme.ownerGold, size: 19),
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12.5),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1A1E29),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.ownerGold),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : const Color(0xFF1A1E29),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: selected ? accent : Colors.white54),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
