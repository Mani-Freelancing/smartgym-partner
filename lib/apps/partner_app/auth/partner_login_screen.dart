import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../domain/models/partner_role.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class PartnerLoginScreen extends StatefulWidget {
  const PartnerLoginScreen({super.key});

  @override
  State<PartnerLoginScreen> createState() => _PartnerLoginScreenState();
}

class _PartnerLoginScreenState extends State<PartnerLoginScreen>
    with SingleTickerProviderStateMixin {
  PartnerRole _selectedRole = PartnerRole.owner;
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  late final AnimationController _pulseCtrl;
  bool _otpSent = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _handleSendOtp() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorText = 'Enter a valid 10-digit mobile number';
      });
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _errorText = null;
      _otpSent = true;
    });
  }

  void _handleVerifyOtp(SmartGymState state) {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 4) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorText = 'Enter the 4-digit code sent to your phone';
      });
      return;
    }
    HapticFeedback.mediumImpact();
    final isOwner = _selectedRole == PartnerRole.owner;
    final trainerName = isOwner ? null : state.currentGym.headTrainer;

    context.read<SmartGymBloc>().add(
          LoginPartnerEvent(
            role: _selectedRole,
            phone: '+91 ${_phoneCtrl.text.trim()}',
            trainerName: trainerName,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final isOwner = _selectedRole == PartnerRole.owner;
        final accent = isOwner ? AppTheme.ownerGold : AppTheme.trainerCyan;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: accent,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SMARTGYM PARTNER',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // =============================================================
                // TOP STAGE: Animated Pulse Emblem + Clean Human Copywriting
                // =============================================================
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (context, _) {
                              final scale = 1.0 + (_pulseCtrl.value * 0.08);
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Transform.scale(
                                    scale: scale * 1.35,
                                    child: Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent.withValues(alpha: 0.06),
                                      ),
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 82,
                                      height: 82,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent.withValues(alpha: 0.12),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1E2330),
                                      border: Border.all(
                                        color: accent,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.3),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isOwner
                                          ? Icons.insights_rounded
                                          : Icons.fitness_center_rounded,
                                      color: accent,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(
                              _otpSent
                                  ? 'Verify your number'
                                  : isOwner
                                      ? 'Your gym, in your pocket.'
                                      : 'Coach smarter, every day.',
                              key: ValueKey('title_${isOwner}_$_otpSent'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _otpSent
                                ? 'We sent a 4-digit code to +91 ${_phoneCtrl.text}'
                                : isOwner
                                    ? 'Track memberships, renewals, and trainer sessions in real time.'
                                    : 'Manage walk-ins, client workouts, and daily nutrition effortlessly.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // =============================================================
                // BOTTOM DOCKED SHEET: Clean Role Pill + Phone / OTP
                // =============================================================
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    MediaQuery.of(context).padding.bottom + 30,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E29),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: accent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 30,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 5),
                      if (!_otpSent) ...[
                        // Clean Role Switcher
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF12151D),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              _buildRoleSegment(
                                label: 'Gym Owner',
                                icon: Icons.workspace_premium_rounded,
                                selected: isOwner,
                                activeColor: AppTheme.ownerGold,
                                onTap: () => setState(() {
                                  _selectedRole = PartnerRole.owner;
                                  _errorText = null;
                                }),
                              ),
                              _buildRoleSegment(
                                label: 'Trainer',
                                icon: Icons.sports_mma_rounded,
                                selected: !isOwner,
                                activeColor: AppTheme.trainerCyan,
                                onTap: () => setState(() {
                                  _selectedRole = PartnerRole.trainer;
                                  _errorText = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Mobile Number',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey('phone_input'),
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '98490 00000',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white24,
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 0,
                              minHeight: 0,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 16, right: 12),
                              child: Text(
                                '+91',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF12151D),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: Colors.white12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: accent, width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() => _errorText = null);
                            }
                          },
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        CredNeoPopButton(
                          label: 'Continue',
                          icon: Icons.arrow_forward_rounded,
                          color: accent,
                          textColor: Colors.black,
                          onTap: _handleSendOtp,
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'Secured with instant OTP verification',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ] else ...[
                        // STEP 2: OTP VERIFICATION
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Enter 4-digit OTP',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _otpSent = false;
                                  _otpCtrl.clear();
                                  _errorText = null;
                                });
                              },
                              child: Text(
                                'Edit number',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('otp_input'),
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 18,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••',
                            hintStyle: const TextStyle(
                              fontSize: 26,
                              letterSpacing: 18,
                              color: Colors.white24,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF12151D),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: accent, width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            if (_errorText != null) {
                              setState(() => _errorText = null);
                            }
                          },
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        CredNeoPopButton(
                          label: 'Verify & Continue',
                          icon: Icons.check_circle_outline_rounded,
                          color: accent,
                          textColor: Colors.black,
                          onTap: () => _handleVerifyOtp(state),
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'By continuing, you sign in to your gym branch',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleSegment({
    required String label,
    required IconData icon,
    required bool selected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.black : Colors.white54,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.black : Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
