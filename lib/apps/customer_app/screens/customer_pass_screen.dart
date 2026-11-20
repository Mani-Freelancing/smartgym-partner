import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';
import '../../partner_app/shared/qr_scanner_screen.dart';

class CustomerPassScreen extends StatefulWidget {
  const CustomerPassScreen({super.key});

  @override
  State<CustomerPassScreen> createState() => _CustomerPassScreenState();
}

class _CustomerPassScreenState extends State<CustomerPassScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanDoorQr(BuildContext context, SmartGymState state) async {
    final bloc = context.read<SmartGymBloc>();
    final member = state.currentMember;
    final expired = member != null ? member.isExpired : state.isMembershipExpired;

    if (expired) {
      HapticFeedback.heavyImpact();
      _showUpiRenewalSheet(context, state);
      return;
    }

    if (bloc.firestoreService != null) {
      final raw = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const QrScannerScreen(
            title: 'Scan Gym Door QR',
            subtitle: 'Point camera at the Reception QR at the gym desk.',
            accentColor: AppTheme.trainerCyan,
          ),
        ),
      );
      if (raw == null || !context.mounted) return;
      final uri = Uri.tryParse(raw);
      final scannedGymId = uri?.queryParameters['gymId'] ?? '';
      if (uri?.scheme != 'smartgym' ||
          uri?.host != 'duty' ||
          scannedGymId != state.currentGym.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text(
              'Invalid QR! Please scan your gym\'s Reception QR.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
        return;
      }
    }

    HapticFeedback.mediumImpact();
    bloc.add(const SimulateQrCheckInEvent());
    if (!context.mounted) return;
    _showCheckInSuccessSheet(context, state);
  }

  void _showCheckInSuccessSheet(BuildContext context, SmartGymState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1E29),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.16),
                  border: Border.all(color: AppTheme.accent, width: 2),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppTheme.accent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'CHECKED IN!',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome to ${state.currentGym.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '🔥 ${state.streakDays + 1} Day Streak • Have a beast workout!',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'LET\'S GO',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpiRenewalSheet(BuildContext context, SmartGymState state) {
    final gym = state.currentGym;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1E29),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'MEMBERSHIP RENEWAL • ₹0 EXTRA FEE',
                style: TextStyle(
                  color: AppTheme.ownerGold,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Renew ${gym.name} Pass',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pay directly via UPI (0% gateway charge) or renew at the gym desk.',
                style: TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.ownerGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final upiUri = Uri.parse(
                      'upi://pay?pa=smartgym@upi&pn=${Uri.encodeComponent(gym.name)}&am=${gym.monthlyFee}&cu=INR&tn=${Uri.encodeComponent('Gym Renewal')}',
                    );
                    await launchUrl(
                      upiUri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                  label: Text(
                    'PAY ₹${gym.monthlyFee} VIA UPI APP',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final member = state.currentMember;
        final memberName = member?.name ?? 'Club Member';
        final planTitle = member?.planTitle ?? '1-Month Regular';
        final daysLeft = member?.daysLeft ?? (state.isMembershipExpired ? 0 : 24);
        final expiryDate = member?.expiryDate ?? '30d validity';
        final isExpired = daysLeft <= 0 || state.isMembershipExpired;
        final crowdRatio =
            (state.liveCrowd / (gym.maxCapacity > 0 ? gym.maxCapacity : 60))
                .clamp(0.0, 1.0);
        final crowdColor = crowdRatio > 0.8
            ? AppTheme.danger
            : crowdRatio > 0.5
                ? AppTheme.amber
                : AppTheme.trainerCyan;
        final crowdLabel = crowdRatio > 0.8
            ? 'Peak Rush'
            : crowdRatio > 0.5
                ? 'Moderate Floor'
                : 'Quiet • Best Time';

        return RefreshIndicator(
          color: AppTheme.trainerCyan,
          backgroundColor: const Color(0xFF1A1E29),
          onRefresh: () async {
            context.read<SmartGymBloc>().add(const RefreshGymDataEvent());
            await Future<void>.delayed(const Duration(milliseconds: 450));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // 1. Metallic CRED Digital Club Pass
              CredStaggeredItem(
                index: 0,
                child: CredMetalCard(
                  glowColor:
                      isExpired ? AppTheme.danger : AppTheme.trainerCyan,
                  enableShimmer: !isExpired,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            gym.name.toUpperCase(),
                            style: TextStyle(
                              color: isExpired
                                  ? AppTheme.danger
                                  : AppTheme.trainerCyan,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (isExpired
                                      ? AppTheme.danger
                                      : AppTheme.accent)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              isExpired ? 'EXPIRED' : '$daysLeft DAYS LEFT',
                              style: TextStyle(
                                color:
                                    isExpired ? AppTheme.danger : AppTheme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        memberName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$planTitle • Valid till $expiryDate',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Pulsing Door QR Scanner Button
              CredStaggeredItem(
                index: 1,
                child: AnimatedBuilder(
                  animation: _radarCtrl,
                  builder: (context, child) {
                    final pulse = 1.0 + (_radarCtrl.value * 0.04);
                    return Transform.scale(
                      scale: pulse,
                      child: child,
                    );
                  },
                  child: GestureDetector(
                    onTap: () => _scanDoorQr(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isExpired
                              ? [
                                  AppTheme.danger.withValues(alpha: 0.28),
                                  const Color(0xFF1A1E29),
                                ]
                              : [
                                  AppTheme.trainerCyan.withValues(alpha: 0.25),
                                  const Color(0xFF1A1E29),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isExpired
                              ? AppTheme.danger
                              : AppTheme.trainerCyan,
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isExpired
                                    ? AppTheme.danger
                                    : AppTheme.trainerCyan)
                                .withValues(alpha: 0.22),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isExpired
                                  ? AppTheme.danger
                                  : AppTheme.trainerCyan,
                            ),
                            child: Icon(
                              isExpired
                                  ? Icons.lock_rounded
                                  : Icons.qr_code_scanner_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isExpired
                                      ? 'PASS EXPIRED • RENEW NOW'
                                      : 'SCAN DOOR QR TO CHECK IN',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isExpired
                                      ? 'Tap to renew via ₹0-fee UPI'
                                      : 'Verify entry at ${gym.name} desk',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Animated Live Gym Crowd Meter
              CredStaggeredItem(
                index: 2,
                child: CredMetalCard(
                  glowColor: crowdColor,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'LIVE FLOOR CROWD METER',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
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
                              color: crowdColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              crowdLabel,
                              style: TextStyle(
                                color: crowdColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${state.liveCrowd}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '/ ${gym.maxCapacity} active on floor',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: crowdRatio),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: val,
                              minHeight: 10,
                              backgroundColor: const Color(0xFF12151C),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(crowdColor),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
