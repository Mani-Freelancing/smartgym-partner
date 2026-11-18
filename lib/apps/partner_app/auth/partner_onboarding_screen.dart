import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';
import '../shared/qr_scanner_screen.dart';

class PartnerOnboardingScreen extends StatefulWidget {
  const PartnerOnboardingScreen({super.key});

  @override
  State<PartnerOnboardingScreen> createState() =>
      _PartnerOnboardingScreenState();
}

class _PartnerOnboardingScreenState extends State<PartnerOnboardingScreen> {
  bool _isOwnerForm = true;
  final _gymNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _trainerNameCtrl = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _gymNameCtrl.dispose();
    _areaCtrl.dispose();
    _ownerNameCtrl.dispose();
    _trainerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanInviteQr() async {
    final trainerName = _trainerNameCtrl.text.trim();
    if (trainerName.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _localError = 'Enter your name first before scanning QR.');
      return;
    }
    setState(() => _localError = null);
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(
          title: 'Scan Gym Invite QR',
          subtitle: 'Point camera at the Staff Invite QR on your Gym Owner\'s phone.',
          accentColor: AppTheme.trainerCyan,
        ),
      ),
    );
    if (raw == null || !mounted) return;
    final uri = Uri.tryParse(raw);
    final gymId = uri?.queryParameters['gymId'] ?? '';
    final code = uri?.queryParameters['code'] ?? '';
    if (uri?.scheme != 'smartgym' ||
        uri?.host != 'invite' ||
        gymId.isEmpty ||
        code.isEmpty) {
      setState(() => _localError = 'Invalid Staff Invite QR. Please scan the Owner\'s Invite QR.');
      return;
    }
    context.read<SmartGymBloc>().add(
          JoinGymWithInviteQrEvent(
            gymId: gymId,
            inviteCode: code,
            trainerName: trainerName,
          ),
        );
  }

  void _submitNewGym() {
    final gymName = _gymNameCtrl.text.trim();
    final area = _areaCtrl.text.trim();
    final ownerName = _ownerNameCtrl.text.trim();
    if (gymName.isEmpty || area.isEmpty || ownerName.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _localError = 'Please fill in all 3 fields to continue.');
      return;
    }
    setState(() => _localError = null);
    HapticFeedback.mediumImpact();
    context.read<SmartGymBloc>().add(
          CreateNewGymOnboardingEvent(
            gymName: gymName,
            area: area,
            ownerName: ownerName,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final showTrainerPending = state.pendingApprovalGymName != null;
        final isOwnerView = _isOwnerForm && !showTrainerPending;
        final error = _localError ?? state.authError;
        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppTheme.ownerGold,
              backgroundColor: const Color(0xFF1A1E29),
              onRefresh: () async {
                context
                    .read<SmartGymBloc>()
                    .add(const CheckAuthSessionEvent());
                await Future<void>.delayed(const Duration(milliseconds: 450));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1E29),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          state.authenticatedPhone,
                          style: const TextStyle(
                            color: AppTheme.ownerGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: state.isOnboardingBusy
                            ? null
                            : () => context
                                .read<SmartGymBloc>()
                                .add(const LogoutPartnerEvent()),
                        child: const Text(
                          'Switch Number',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (showTrainerPending) ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E29),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppTheme.ownerGold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            color: AppTheme.ownerGold,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Approval Pending',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Request sent to ${state.pendingApprovalGymName}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.ownerGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Your Gym Owner needs to tap Approve in their Trainers & PT Split tab.\nPull down or tap Check Status below once approved.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.trainerCyan,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                context
                                    .read<SmartGymBloc>()
                                    .add(const CheckAuthSessionEvent());
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'CHECK APPROVAL STATUS',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              context
                                  .read<SmartGymBloc>()
                                  .add(const CancelPendingRequestEvent());
                            },
                            child: const Text(
                              'Cancel Request & Go Back',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Welcome to\nSmartGym Partner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your phone number is verified. Choose how you want to get started:',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceChipCard(
                            title: 'Gym Owner',
                            subtitle: 'Register new gym',
                            icon: Icons.storefront_rounded,
                            accent: AppTheme.ownerGold,
                            selected: isOwnerView,
                            onTap: () => setState(() {
                              _isOwnerForm = true;
                              _localError = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChoiceChipCard(
                            title: 'Floor Trainer',
                            subtitle: 'Join existing gym',
                            icon: Icons.fitness_center_rounded,
                            accent: AppTheme.trainerCyan,
                            selected: !isOwnerView,
                            onTap: () => setState(() {
                            _isOwnerForm = false;
                            _localError = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (isOwnerView) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E29),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppTheme.ownerGold.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'REGISTER YOUR GYM',
                            style: TextStyle(
                              color: AppTheme.ownerGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _InputBox(
                            controller: _gymNameCtrl,
                            label: 'Gym Name',
                            hint: "e.g. I'mFit Studio",
                          ),
                          const SizedBox(height: 12),
                          _InputBox(
                            controller: _areaCtrl,
                            label: 'Area & City',
                            hint: 'e.g. Hitech City, Hyderabad',
                          ),
                          const SizedBox(height: 12),
                          _InputBox(
                            controller: _ownerNameCtrl,
                            label: 'Owner Name',
                            hint: 'e.g. Aman Kumar',
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              error,
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.ownerGold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed:
                                  state.isOnboardingBusy ? null : _submitNewGym,
                              child: state.isOnboardingBusy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'LAUNCH MY GYM',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E29),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppTheme.trainerCyan,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Join Your Gym as Trainer',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (state.pendingApprovalGymName != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.ownerGold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.ownerGold.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.hourglass_top_rounded,
                                    color: AppTheme.ownerGold,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Approval Pending • ${state.pendingApprovalGymName}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.ownerGold,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Your request has been sent. Ask the Gym Owner to tap Approve in their Trainers tab, then tap Check Status below.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ] else ...[
                            Text(
                              'Option 1: Scan the Staff Invite QR on your Owner\'s phone (requires Owner approval).\nOption 2: Ask your Owner to add ${state.authenticatedPhone} in Team & QR.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _InputBox(
                              controller: _trainerNameCtrl,
                              label: 'Your Name (for QR Invite)',
                              hint: 'e.g. Coach Vikram',
                            ),
                          ],
                          if (error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              error,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.trainerCyan,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed:
                                  state.isOnboardingBusy ? null : _scanInviteQr,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 19,
                              ),
                              label: state.isOnboardingBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'SCAN OWNER INVITE QR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.trainerCyan,
                                side: const BorderSide(
                                    color: AppTheme.trainerCyan),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: state.isOnboardingBusy
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      context
                                          .read<SmartGymBloc>()
                                          .add(const CheckAuthSessionEvent());
                                    },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'CHECK PHONE INVITE STATUS',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  ],
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}

class _ChoiceChipCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChipCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : const Color(0xFF1A1E29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? accent : Colors.white54, size: 22),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _InputBox({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF12151C),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
