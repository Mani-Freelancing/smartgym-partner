import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/phone_auth_service.dart';
import '../../../domain/models/partner_role.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class PartnerLoginScreen extends StatefulWidget {
  final PhoneAuthService? authService;

  const PartnerLoginScreen({super.key, this.authService});

  @override
  State<PartnerLoginScreen> createState() => _PartnerLoginScreenState();
}

class _PartnerLoginScreenState extends State<PartnerLoginScreen>
    with SingleTickerProviderStateMixin {
  final PartnerRole _selectedRole = PartnerRole.owner;
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  late final AnimationController _pulseCtrl;
  PhoneAuthService? _authService;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  PhoneAuthService _getAuthService() {
    return _authService ??= widget.authService ?? PhoneAuthService();
  }

  Future<void> _handleSendOtp(SmartGymState state) async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    debugPrint(
      '[LOGIN][PartnerLoginScreen._handleSendOtp] raw="${_phoneCtrl.text}" '
      'digitsLen=${digits.length}',
    );
    if (digits.length != 10) {
      HapticFeedback.heavyImpact();
      debugPrint(
        '[LOGIN][PartnerLoginScreen._handleSendOtp] validation failed: invalid digitsLen=${digits.length}',
      );
      setState(() {
        _errorText = 'Enter a valid 10-digit mobile number';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final fullPhone = '+91$digits';
    debugPrint(
      '[LOGIN][PartnerLoginScreen._handleSendOtp] calling sendOtp(phone=$fullPhone)',
    );
    try {
      await _getAuthService().sendOtp(
        phoneNumber: fullPhone,
        onCodeSent: (verId) {
          debugPrint(
            '[LOGIN][PartnerLoginScreen._handleSendOtp -> onCodeSent] '
            'phone=$fullPhone verIdLen=${verId.length}',
          );
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _otpSent = true;
          });
        },
        onError: (msg) {
          debugPrint(
            '[LOGIN][PartnerLoginScreen._handleSendOtp -> onError] '
            'phone=$fullPhone error=$msg',
          );
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorText = msg;
          });
        },
        onAutoVerified: (cred) {
          debugPrint(
            '[LOGIN][PartnerLoginScreen._handleSendOtp -> onAutoVerified] '
            'phone=$fullPhone uid=${cred.user?.uid}',
          );
          if (!mounted) return;
          _completeLogin(state, fullPhone);
        },
      );
    } catch (e, st) {
      debugPrint(
        '[LOGIN][PartnerLoginScreen._handleSendOtp CATCH] phone=$fullPhone '
        'error=$e\n$st',
      );
      if (!mounted) return;
      if (PhoneAuthService.isOfflineTestError(e)) {
        debugPrint(
          '[LOGIN][PartnerLoginScreen._handleSendOtp] offline/no-app test mode -> showing OTP step',
        );
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _errorText = PhoneAuthService.formatAuthError(e);
      });
    }
  }

  Future<void> _handleVerifyOtp(SmartGymState state) async {
    final otp = _otpCtrl.text.trim();
    debugPrint(
      '[LOGIN][PartnerLoginScreen._handleVerifyOtp] otpLen=${otp.length}',
    );
    if (otp.length != 6) {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorText = 'Enter the 6-digit OTP sent to your phone';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final fullPhone = '+91$digits';

    try {
      await _getAuthService().verifyOtp(smsCode: otp);
      debugPrint(
        '[LOGIN][PartnerLoginScreen._handleVerifyOtp] OTP verified for $fullPhone',
      );
      if (!mounted) return;
      _completeLogin(state, fullPhone);
    } catch (e, st) {
      debugPrint(
        '[LOGIN][PartnerLoginScreen._handleVerifyOtp CATCH] phone=$fullPhone '
        'error=$e\n$st',
      );
      if (!mounted) return;
      if (PhoneAuthService.isOfflineTestError(e)) {
        _completeLogin(state, fullPhone);
        return;
      }
      setState(() {
        _isLoading = false;
        _errorText = PhoneAuthService.formatAuthError(e);
      });
    }
  }

  void _completeLogin(SmartGymState state, String fullPhone) {
    final isOwner = _selectedRole == PartnerRole.owner;
    final trainerName = isOwner ? null : state.currentGym.headTrainer;
    debugPrint(
      '[LOGIN][PartnerLoginScreen._completeLogin] dispatching LoginPartnerEvent '
      'role=$_selectedRole phone=$fullPhone trainerName=$trainerName',
    );
    setState(() => _isLoading = false);
    context.read<SmartGymBloc>().add(
          LoginPartnerEvent(
            role: _selectedRole,
            phone: fullPhone,
            trainerName: trainerName,
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
          final isOwner = _selectedRole == PartnerRole.owner;

          return Scaffold(
            backgroundColor: p.bg,
            body: Stack(
              children: [
                // Soft warm golden-cream radial glow
                Positioned(
                  top: -120,
                  left: -60,
                  right: -60,
                  height: 360,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 0.9,
                          colors: [
                            const Color(0xFFF6C667).withValues(alpha: 0.25),
                            const Color(0xFFF6C667).withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Brand Crest Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: p.border),
                              boxShadow: p.cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: p.cardSubtle,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Icon(
                                    Icons.shield_rounded,
                                    color: p.gold,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'SMARTGYM PARTNER',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // TOP STAGE: Golden Crest Medallion + Headline
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 112,
                                  height: 112,
                                  child: Center(
                                    child: AnimatedBuilder(
                                      animation: _pulseCtrl,
                                      builder: (context, _) {
                                        final scale =
                                            1.0 + (_pulseCtrl.value * 0.07);
                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Transform.scale(
                                              scale: scale * 1.18,
                                              child: Container(
                                                width: 82,
                                                height: 82,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: p.gold.withValues(
                                                    alpha: 0.08,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Transform.scale(
                                              scale: scale,
                                              child: Container(
                                                width: 76,
                                                height: 76,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: p.cardSubtle,
                                                  border: Border.all(
                                                    color: p.gold.withValues(
                                                      alpha: 0.35,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 62,
                                              height: 62,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFFF3B43F),
                                                    Color(0xFFD98A16),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: p.gold.withValues(
                                                      alpha: 0.32,
                                                    ),
                                                    blurRadius: 18,
                                                    offset: const Offset(0, 6),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                _otpSent
                                                    ? Icons.sms_outlined
                                                    : isOwner
                                                        ? Icons.insights_rounded
                                                        : Icons
                                                            .fitness_center_rounded,
                                                color: Colors.white,
                                                size: 27,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
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
                                    style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.7,
                                      height: 1.14,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 306),
                                  child: Text(
                                    _otpSent
                                        ? 'We sent a 6-digit SMS code to +91 ${_phoneCtrl.text}'
                                        : isOwner
                                            ? 'Track memberships, renewals, and trainer sessions in real time.'
                                            : 'Manage walk-ins, client workouts, and daily nutrition effortlessly.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: p.textSecondary,
                                      height: 1.46,
                                    ),
                                  ),
                                ),
                                if (!_otpSent) ...[
                                  const SizedBox(height: 18),
                                  Container(
                                    width: 44,
                                    height: 1.5,
                                    color: p.gold.withValues(alpha: 0.45),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '0% UPI FEES  •  CASH & PT CONTROL  •  OWNER & COACH',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // BOTTOM DOCKED WHITE LOGIN SHEET
                      Flexible(
                        flex: 0,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            24,
                            14,
                            24,
                            MediaQuery.of(context).padding.bottom + 20,
                          ),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                            border: Border(
                              top: BorderSide(color: p.border, width: 1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8C6218)
                                    .withValues(alpha: 0.08),
                                blurRadius: 28,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 38,
                                    height: 3.5,
                                    margin: const EdgeInsets.only(bottom: 18),
                                    decoration: BoxDecoration(
                                      color: p.border,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                                if (!_otpSent) ...[
                                  Text(
                                    'Mobile Number',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: p.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    key: const ValueKey('phone_input'),
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: p.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '98490 00000',
                                      hintStyle: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.6,
                                        color: p.textMuted
                                            .withValues(alpha: 0.55),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                        minWidth: 0,
                                        minHeight: 0,
                                      ),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16,
                                          right: 12,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '+91',
                                              maxLines: 1,
                                              softWrap: false,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: p.gold,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              color: p.border,
                                            ),
                                          ],
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: p.bg,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(color: p.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(color: p.border),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: p.gold,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_errorText != null) {
                                        setState(() => _errorText = null);
                                      }
                                    },
                                  ),
                                  if ((_errorText ?? state.authError) !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      (_errorText ?? state.authError)!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: p.danger,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  if (_isLoading)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: CircularProgressIndicator(
                                          color: p.gold,
                                        ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: p.goldButton,
                                          foregroundColor: p.onAccent,
                                          elevation: 3,
                                          shadowColor: p.goldButton
                                              .withValues(alpha: 0.35),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                        ),
                                        onPressed: () => _handleSendOtp(state),
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'CONTINUE',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock_outline_rounded,
                                          size: 13,
                                          color: p.textMuted,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            'Secured with Firebase SMS OTP',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: p.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  // STEP 2: 6-DIGIT OTP VERIFICATION
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Enter 6-digit OTP',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.textSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: p.gold,
                                        ),
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
                                            color: p.gold,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    key: const ValueKey('otp_input'),
                                    controller: _otpCtrl,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 12,
                                      color: p.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '••••••',
                                      hintStyle: TextStyle(
                                        fontSize: 24,
                                        letterSpacing: 12,
                                        color: p.textMuted
                                            .withValues(alpha: 0.45),
                                      ),
                                      filled: true,
                                      fillColor: p.bg,
                                      contentPadding:
                                          const EdgeInsets.fromLTRB(
                                        28,
                                        16,
                                        16,
                                        16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(color: p.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(color: p.border),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: p.gold,
                                          width: 1.6,
                                        ),
                                      ),
                                    ),
                                    onChanged: (_) {
                                      if (_errorText != null) {
                                        setState(() => _errorText = null);
                                      }
                                    },
                                  ),
                                  if ((_errorText ?? state.authError) !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      (_errorText ?? state.authError)!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: p.danger,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  if (_isLoading)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: CircularProgressIndicator(
                                          color: p.gold,
                                        ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: p.goldButton,
                                          foregroundColor: p.onAccent,
                                          elevation: 3,
                                          shadowColor: p.goldButton
                                              .withValues(alpha: 0.35),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                        ),
                                        onPressed: () =>
                                            _handleVerifyOtp(state),
                                        icon: const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'VERIFY & CONTINUE',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 14),
                                  Center(
                                    child: Text(
                                      'By continuing, you sign in to your gym branch',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: p.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
