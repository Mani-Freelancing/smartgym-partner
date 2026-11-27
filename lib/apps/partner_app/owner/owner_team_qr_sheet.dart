import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class OwnerTeamQrSheet extends StatefulWidget {
  const OwnerTeamQrSheet({super.key});

  @override
  State<OwnerTeamQrSheet> createState() => _OwnerTeamQrSheetState();
}

class _OwnerTeamQrSheetState extends State<OwnerTeamQrSheet> {
  int _tab = 0; // 0 = Staff Invite QR, 1 = Duty QR, 2 = Add Trainer by Phone
  String? _inviteCode;
  bool _loadingInvite = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _specialtyCtrl =
      TextEditingController(text: 'Strength & Transformation');
  String? _formError;

  @override
  void initState() {
    super.initState();
    _loadInviteCode();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInviteCode() async {
    final bloc = context.read<SmartGymBloc>();
    final fs = bloc.firestoreService;
    final gym = bloc.state.currentGym;
    if (fs == null || gym.id.isEmpty) return;
    setState(() => _loadingInvite = true);
    try {
      final code = await fs.ensureActiveInviteCode(gym.id, gym.name);
      if (mounted) setState(() => _inviteCode = code);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingInvite = false);
    }
  }

  void _submitAddTrainer(SmartGymState state) {
    final name = _nameCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (name.isEmpty || digits.length != 10) {
      HapticFeedback.heavyImpact();
      setState(() {
        _formError = 'Enter trainer name and valid 10-digit phone number.';
      });
      return;
    }
    setState(() => _formError = null);
    HapticFeedback.mediumImpact();
    context.read<SmartGymBloc>().add(
          AddTrainerToGymEvent(
            name: name,
            phone: '+91$digits',
            specialty: _specialtyCtrl.text.trim().isEmpty
                ? 'Floor & Transformation Coach'
                : _specialtyCtrl.text.trim(),
          ),
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.trainerCyan,
        content: Text(
          '$name (+91$digits) added! They can now log in via OTP.',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.ensureOwnerLight(
      context,
      child: BlocBuilder<SmartGymBloc, SmartGymState>(
        builder: (context, state) {
          final p = AppPalette.of(context);
          final gym = state.currentGym;
          final dutyPayload = 'smartgym://duty?gymId=${gym.id}';
          final invitePayload = _inviteCode != null
              ? 'smartgym://invite?gymId=${gym.id}&code=$_inviteCode'
              : '';

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text(
                    '${gym.name} • Team & QRs',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite trainers via QR or Phone, or print your Reception Duty QR.',
                    style: TextStyle(color: p.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _TabPill(
                        label: 'Invite QR',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: 'Duty QR',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: '+ Add Trainer',
                        selected: _tab == 2,
                        onTap: () => setState(() => _tab = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_tab == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.cardSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: p.cyan.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          if (_loadingInvite)
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: CircularProgressIndicator(color: p.cyan),
                            )
                          else if (invitePayload.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: p.border),
                              ),
                              child: QrImageView(
                                data: invitePayload,
                                size: 180,
                                backgroundColor: Colors.white,
                              ),
                            )
                          else
                            Text(
                              'Could not load invite QR.',
                              style: TextStyle(color: p.textSecondary),
                            ),
                          const SizedBox(height: 14),
                          Text(
                            'STAFF INVITE CODE: ${_inviteCode ?? '...'}',
                            style: TextStyle(
                              color: p.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'New trainer opens SmartGym Partner → OTP → Floor Trainer → Scan Invite QR.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_tab == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.cardSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: p.gold.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: p.border),
                            ),
                            child: QrImageView(
                              data: dutyPayload,
                              size: 180,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'RECEPTION / DUTY CHECK-IN QR',
                            style: TextStyle(
                              color: p.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Print & stick at reception. Trainers scan this daily to clock in on duty.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _nameCtrl,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        labelText: 'Trainer Name',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                        floatingLabelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.gold,
                        ),
                        hintText: 'e.g. Coach Vikram',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: p.textMuted,
                        ),
                        filled: true,
                        fillColor: p.cardSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: p.textPrimary,
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
                          color: p.gold,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                        labelText: 'Trainer Mobile Number',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                        floatingLabelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.gold,
                        ),
                        hintText: '98490 00000',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: p.textMuted,
                        ),
                        filled: true,
                        fillColor: p.cardSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _specialtyCtrl,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        labelText: 'Specialty / Category',
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: p.textSecondary,
                        ),
                        floatingLabelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.gold,
                        ),
                        hintText: 'e.g. Strength & Fat Loss Coach',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: p.textMuted,
                        ),
                        filled: true,
                        fillColor: p.cardSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                      ),
                    ),
                    if (_formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formError!,
                        style: TextStyle(
                          color: p.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.goldButton,
                          foregroundColor: p.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _submitAddTrainer(state),
                        child: const Text(
                          'ADD TRAINER TO GYM',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? p.gold.withValues(alpha: 0.14)
                : p.cardSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? p.gold : p.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? p.gold : p.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
