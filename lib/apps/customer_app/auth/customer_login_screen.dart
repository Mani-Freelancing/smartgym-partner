import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/phone_auth_service.dart';
import '../../../domain/models/partner_role.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class CustomerLoginScreen extends StatefulWidget {
  final PhoneAuthService? authService;

  const CustomerLoginScreen({super.key, this.authService});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  late final AnimationController _pulseCtrl;
  PhoneAuthService? _authService;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorText;

  PhoneAuthService _getAuthService() =>
      _authService ??= widget.authService ?? PhoneAuthService();

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
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp(SmartGymState state) async {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    debugPrint(
      '[LOGIN][CustomerLoginScreen._handleSendOtp] raw="${_phoneCtrl.text}" '
      'digitsLen=${digits.length}',
    );
    if (digits.length != 10) {
      HapticFeedback.heavyImpact();
      debugPrint(
        '[LOGIN][CustomerLoginScreen._handleSendOtp] validation failed: invalid digitsLen=${digits.length}',
      );
      setState(() => _errorText = 'Enter a valid 10-digit mobile number');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final fullPhone = '+91$digits';
    debugPrint(
      '[LOGIN][CustomerLoginScreen._handleSendOtp] calling sendOtp(phone=$fullPhone)',
    );
    try {
      await _getAuthService().sendOtp(
        phoneNumber: fullPhone,
        onCodeSent: (verId) {
          debugPrint(
            '[LOGIN][CustomerLoginScreen._handleSendOtp -> onCodeSent] '
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
            '[LOGIN][CustomerLoginScreen._handleSendOtp -> onError] '
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
            '[LOGIN][CustomerLoginScreen._handleSendOtp -> onAutoVerified] '
            'phone=$fullPhone uid=${cred.user?.uid}',
          );
          if (!mounted) return;
          _completeLogin(fullPhone);
        },
      );
    } catch (e, st) {
      debugPrint(
        '[LOGIN][CustomerLoginScreen._handleSendOtp CATCH] phone=$fullPhone '
        'error=$e\n$st',
      );
      if (!mounted) return;
      if (PhoneAuthService.isOfflineTestError(e)) {
        debugPrint(
          '[LOGIN][CustomerLoginScreen._handleSendOtp] offline/no-app test mode -> showing OTP step',
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

  Future<void> _handleVerifyOtp() async {
    final otp = _otpCtrl.text.trim();
    debugPrint(
      '[LOGIN][CustomerLoginScreen._handleVerifyOtp] otpLen=${otp.length}',
    );
    if (otp.length != 6) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = 'Enter the 6-digit OTP sent to your phone');
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
        '[LOGIN][CustomerLoginScreen._handleVerifyOtp] OTP verified for $fullPhone',
      );
      if (!mounted) return;
      _completeLogin(fullPhone);
    } catch (e, st) {
      debugPrint(
        '[LOGIN][CustomerLoginScreen._handleVerifyOtp CATCH] phone=$fullPhone '
        'error=$e\n$st',
      );
      if (!mounted) return;
      if (PhoneAuthService.isOfflineTestError(e)) {
        _completeLogin(fullPhone);
        return;
      }
      setState(() {
        _isLoading = false;
        _errorText = PhoneAuthService.formatAuthError(e);
      });
    }
  }

  void _completeLogin(String fullPhone) {
    debugPrint(
      '[LOGIN][CustomerLoginScreen._completeLogin] dispatching LoginPartnerEvent '
      'phone=$fullPhone',
    );
    setState(() => _isLoading = false);
    context.read<SmartGymBloc>().add(
          LoginPartnerEvent(
            role: PartnerRole.trainer,
            phone: fullPhone,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.trainerCyan;
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
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
                        child: const Icon(
                          Icons.bolt_rounded,
                          color: accent,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SMARTGYM CLUB',
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
                                    child: const Icon(
                                      Icons.qr_code_2_rounded,
                                      color: accent,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          Text(
                            _otpSent
                                ? 'Verify your number'
                                : 'Your digital\nclub pass.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                              height: 1.15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _otpSent
                                ? 'We sent a 6-digit SMS code to +91 ${_phoneCtrl.text}'
                                : 'Scan in, check live gym crowd, and track your PRs.',
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
                Flexible(
                  flex: 0,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.of(context).padding.bottom + 20,
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
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 22),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          if (!_otpSent) ...[
                            const Text(
                              'Mobile Number',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('customer_phone_input'),
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
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white24,
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 10,
                                  ),
                                  child: Text(
                                    '+91',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0,
                                  minHeight: 0,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF12151D),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '6-Digit OTP',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _otpSent = false;
                                    _otpCtrl.clear();
                                    _errorText = null;
                                  }),
                                  child: const Text(
                                    'Change number',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('customer_otp_input'),
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 10,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '••••••',
                                hintStyle: const TextStyle(
                                  color: Colors.white24,
                                  letterSpacing: 10,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF12151D),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                          if ((_errorText ?? state.authError) != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              (_errorText ?? state.authError)!,
                              style: const TextStyle(
                                color: AppTheme.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => _otpSent
                                      ? _handleVerifyOtp()
                                      : _handleSendOtp(state),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Text(
                                      _otpSent
                                          ? 'VERIFY & ENTER CLUB'
                                          : 'CONTINUE',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                            ),
                          ),
                        ],
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
