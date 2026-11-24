import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../data/services/attendance_guard_service.dart';
import '../../../data/services/gym_location_service.dart';
import '../../../data/services/hero_avatar_service.dart';
import '../../../domain/services/member_intelligence_service.dart';
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
  bool _checkedInToday = false;
  String _checkedInTime = '';
  bool _checkedOutToday = false;
  String _checkedOutTime = '';
  String _loadedAttendanceScope = '';
  GymProximityResult? _passiveProximity;
  String _checkedProximityScope = '';
  bool _checkingGpsGate = false;

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    AttendanceGuardService.version.addListener(_onAttendanceReset);
  }

  void _onAttendanceReset() {
    if (!mounted) return;
    setState(() {
      _checkedInToday = false;
      _checkedInTime = '';
      _checkedOutToday = false;
      _checkedOutTime = '';
      _loadedAttendanceScope = '';
    });
  }

  Future<void> _syncTodayAttendance(SmartGymState state) async {
    final gymId = state.currentGym.id;
    final memberKey = state.currentMember?.phone.isNotEmpty == true
        ? state.currentMember!.phone
        : state.authenticatedPhone;
    final scope = '$gymId|$memberKey';
    if (scope == _loadedAttendanceScope || gymId.isEmpty) return;
    _loadedAttendanceScope = scope;

    final record = await AttendanceGuardService.getTodayStatus(
      gymId: gymId,
      memberKey: memberKey,
    );
    if (mounted) {
      setState(() {
        _checkedInToday = record.checkedInToday;
        _checkedInTime = record.timeLabel;
        _checkedOutToday = record.checkedOutToday;
        _checkedOutTime = record.checkOutTimeLabel;
      });
    }
  }

  Future<void> _syncPassiveProximity(
    BuildContext context,
    SmartGymState state,
  ) async {
    final bloc = context.read<SmartGymBloc>();
    final gym = state.currentGym;
    if (bloc.firestoreService == null ||
        !gym.requireGpsCheckIn ||
        !gym.hasLocation) {
      return;
    }
    final scope =
        '${gym.id}|${gym.latitude}|${gym.longitude}|${gym.checkInRadiusMeters}|${gym.requireGpsCheckIn}';
    if (scope == _checkedProximityScope) return;
    _checkedProximityScope = scope;

    final status = await GymLocationService.checkPassiveProximityIfPermitted(
      gymLat: gym.latitude!,
      gymLng: gym.longitude!,
      radiusMeters: gym.checkInRadiusMeters,
    );
    if (mounted) {
      setState(() => _passiveProximity = status);
    }
  }

  int? _parseTimeMinutes(String timeStr) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(timeStr.trim());
    if (m == null) return null;
    int hour = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final isPm = m.group(3)!.toUpperCase() == 'PM';
    if (hour == 12) hour = 0;
    if (isPm) hour += 12;
    return hour * 60 + min;
  }

  String _computeSessionDuration() {
    final start = _parseTimeMinutes(_checkedInTime);
    final end = _parseTimeMinutes(_checkedOutTime);
    if (start == null || end == null || end < start) return 'DONE';
    final diff = end - start;
    if (diff < 1) return '< 1m';
    final h = diff ~/ 60;
    final m = diff % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Future<void> _handleCheckOut(BuildContext context, SmartGymState state) async {
    if (!_checkedInToday || _checkedOutToday) return;
    final bloc = context.read<SmartGymBloc>();
    final gym = state.currentGym;
    final member = state.currentMember;
    final memberKey = member?.phone.isNotEmpty == true
        ? member!.phone
        : state.authenticatedPhone;

    final saved = await AttendanceGuardService.recordCheckOutToday(
      gymId: gym.id,
      memberKey: memberKey,
    );
    if (mounted) {
      setState(() {
        _checkedOutToday = true;
        _checkedOutTime = saved.checkOutTimeLabel;
      });
    }
    HapticFeedback.heavyImpact();
    bloc.add(const CustomerCheckOutEvent());
    if (!context.mounted) return;
    _showWalkOutOverlay(context, saved.checkOutTimeLabel);
  }

  void _showWalkOutOverlay(BuildContext context, String outTime) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CheckOut',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, _, _) => _GymWalkOutCelebration(
        outTime: outTime,
        onDone: () {
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    AttendanceGuardService.version.removeListener(_onAttendanceReset);
    _radarCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanDoorQr(BuildContext context, SmartGymState state) async {
    if (_checkingGpsGate) return;
    final bloc = context.read<SmartGymBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final member = state.currentMember;
    final expired =
        member != null ? member.isExpired : state.isMembershipExpired;
    final gym = state.currentGym;
    final memberKey = member?.phone.isNotEmpty == true
        ? member!.phone
        : state.authenticatedPhone;

    // 1. Once-Per-Day Attendance Lock (persistent across restarts)
    final todayRecord = await AttendanceGuardService.getTodayStatus(
      gymId: gym.id,
      memberKey: memberKey,
    );
    if (todayRecord.checkedInToday || _checkedInToday) {
      HapticFeedback.lightImpact();
      final timeStr = todayRecord.timeLabel.isNotEmpty
          ? todayRecord.timeLabel
          : _checkedInTime;
      if (mounted) {
        setState(() {
          _checkedInToday = true;
          _checkedInTime = timeStr;
        });
      }
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1E29),
          content: Text(
            todayRecord.checkedOutToday || _checkedOutToday
                ? 'Today\'s session is complete. Next check-in opens tomorrow!'
                : 'Already checked in today${timeStr.isNotEmpty ? " at $timeStr" : ""}. Swipe to walk out when leaving.',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      return;
    }

    // 2. Membership Expired Gate
    if (expired) {
      HapticFeedback.heavyImpact();
      if (!context.mounted) return;
      _showUpiRenewalSheet(context, state);
      return;
    }

    // 3. Vacation Freeze Gate
    if (state.isMembershipFrozen) {
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.amber,
          content: Text(
            'Your pass is Frozen. Unfreeze Vacation Mode in Profile Drawer to check in.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
          ),
        ),
      );
      return;
    }

    // 4. Gym Operating Hours Gate (5:00 AM - 11:00 PM)
    if (!AttendanceGuardService.isWithinGymHours()) {
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(
            'Check-in is only open during gym hours (5:00 AM – 11:00 PM).',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
      return;
    }

    // 5. Gym Full Capacity Gate
    final maxCap = gym.maxCapacity > 0 ? gym.maxCapacity : 60;
    if (state.liveCrowd >= maxCap) {
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.amber,
          content: Text(
            'Gym floor is at full capacity (${state.liveCrowd}/$maxCap). Please check with reception.',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
      return;
    }

    // 5.5. Inside-Gym GPS Geofence + Anti-Fake-GPS Gate (if pinned & enabled)
    if (bloc.firestoreService != null &&
        gym.requireGpsCheckIn &&
        gym.hasLocation) {
      if (mounted) setState(() => _checkingGpsGate = true);
      final GymProximityResult gpsResult;
      try {
        gpsResult = await GymLocationService.verifyInsideGym(
          gymLat: gym.latitude!,
          gymLng: gym.longitude!,
          radiusMeters: gym.checkInRadiusMeters,
          gymName: gym.name,
        );
      } finally {
        if (mounted) setState(() => _checkingGpsGate = false);
      }
      if (!context.mounted) return;
      setState(() => _passiveProximity = gpsResult);

      if (!gpsResult.allowed) {
        HapticFeedback.heavyImpact();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor:
                gpsResult.isMocked ? AppTheme.danger : const Color(0xFF1A1E29),
            duration: const Duration(seconds: 4),
            content: Text(
              gpsResult.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            action: (gpsResult.openLocationSettings ||
                    gpsResult.openAppSettings)
                ? SnackBarAction(
                    label: 'Settings',
                    textColor: AppTheme.trainerCyan,
                    onPressed: () {
                      if (gpsResult.openLocationSettings) {
                        Geolocator.openLocationSettings();
                      } else if (gpsResult.openAppSettings) {
                        Geolocator.openAppSettings();
                      }
                    },
                  )
                : null,
          ),
        );
        return;
      }
    }

    // 6. Strict Reception QR Verification (must match this exact gymId)
    if (bloc.firestoreService != null) {
      if (!context.mounted) return;
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
          scannedGymId != gym.id) {
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text(
              'Invalid QR! Please scan your gym\'s official Reception QR.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        );
        return;
      }
    }

    // Record once-per-day check-in persistently BEFORE updating streak & crowd
    final saved = await AttendanceGuardService.recordCheckInToday(
      gymId: gym.id,
      memberKey: memberKey,
    );
    if (mounted) {
      setState(() {
        _checkedInToday = true;
        _checkedInTime = saved.timeLabel;
      });
    }

    HapticFeedback.mediumImpact();
    bloc.add(const SimulateQrCheckInEvent());
    if (!context.mounted) return;
    _showCheckInSuccessSheet(context, state);
  }

  Widget _buildGpsProximityRow(int radiusMeters) {
    final p = _passiveProximity;
    final IconData icon;
    final Color color;
    final String text;
    if (p == null) {
      icon = Icons.my_location_rounded;
      color = Colors.white54;
      text = 'GPS checked within ${radiusMeters}m when scanning door QR';
    } else if (p.isMocked) {
      icon = Icons.warning_amber_rounded;
      color = AppTheme.danger;
      text = 'Fake GPS detected • Disable mock location apps';
    } else if (p.allowed && p.distanceMeters != null) {
      icon = Icons.my_location_rounded;
      color = AppTheme.trainerCyan;
      text =
          'Inside gym floor (${GymLocationService.formatDistance(p.distanceMeters!)}) • Ready to check in';
    } else {
      icon = Icons.home_outlined;
      color = Colors.white60;
      final dist = p.distanceMeters != null
          ? GymLocationService.formatDistance(p.distanceMeters!)
          : 'Away';
      text = '$dist from gym • Check-in works only inside the gym';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 13.5, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
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
        _syncTodayAttendance(state);
        _syncPassiveProximity(context, state);
        final gym = state.currentGym;
        final member = state.currentMember;
        final memberName = member != null && member.respectfulName.isNotEmpty
            ? member.respectfulName
            : 'Club Member';
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
            _checkedProximityScope = '';
            context.read<SmartGymBloc>().add(const RefreshGymDataEvent());
            await Future<void>.delayed(const Duration(milliseconds: 450));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            children: [
              // 1. Metallic CRED Digital Club Pass with carried-forward Hero Avatar
              CredStaggeredItem(
                index: 0,
                child: CredMetalCard(
                  glowColor:
                      isExpired ? AppTheme.danger : AppTheme.trainerCyan,
                  enableShimmer: !isExpired,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header Row: Gym Brand + Days Left Pill (full width)
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isExpired
                                  ? AppTheme.danger
                                  : AppTheme.trainerCyan,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              gym.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isExpired
                                    ? AppTheme.danger
                                    : AppTheme.trainerCyan,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: (isExpired || (!state.isMembershipFrozen && daysLeft <= 5))
                                ? () {
                                    HapticFeedback.selectionClick();
                                    _showUpiRenewalSheet(context, state);
                                  }
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (isExpired
                                        ? AppTheme.danger
                                        : state.isMembershipFrozen
                                            ? AppTheme.amber
                                            : AppTheme.trainerCyan)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: (isExpired
                                          ? AppTheme.danger
                                          : state.isMembershipFrozen
                                              ? AppTheme.amber
                                              : AppTheme.trainerCyan)
                                      .withValues(alpha: 0.38),
                                ),
                              ),
                              child: Text(
                                isExpired
                                    ? 'EXPIRED • RENEW'
                                    : state.isMembershipFrozen
                                        ? 'FROZEN'
                                        : daysLeft <= 5
                                            ? '${daysLeft}D LEFT • RENEW'
                                            : '$daysLeft DAYS LEFT',
                                style: TextStyle(
                                  color: isExpired
                                      ? AppTheme.danger
                                      : state.isMembershipFrozen
                                          ? AppTheme.amber
                                          : AppTheme.trainerCyan,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Middle Row: Member Identity + Carried-Forward Anime Hero
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MEMBER PASS',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  memberName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Text(
                                    planTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Hero(
                            tag: 'power_hero_avatar',
                            child: HeroAvatarImage(
                              width: 96,
                              height: 112,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),

                      // Bottom Wallet-Style Metadata Strip
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VALID TILL',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  expiryDate,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'COACH',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  member?.assignedTrainer?.isNotEmpty == true
                                      ? member!.assignedTrainer!
                                      : gym.headTrainer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'ACCESS',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  member?.isPtClient == true
                                      ? 'VIP • PT'
                                      : 'CLUB',
                                  style: TextStyle(
                                    color: member?.isPtClient == true
                                        ? AppTheme.ownerGold
                                        : AppTheme.trainerCyan,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (member?.hasDue == true) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.amber,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'BALANCE DUE • PAY AT FRONT DESK',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                            Text(
                              '₹${member!.dueAmount}',
                              style: const TextStyle(
                                color: AppTheme.amber,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 2. Open Floating Attendance Action / Slide-to-Walk-Out (no outer box)
              Builder(
                builder: (context) {
                  final isFrozen = state.isMembershipFrozen;
                  final Color btnColor = isExpired
                      ? AppTheme.danger
                      : isFrozen
                          ? AppTheme.amber
                          : AppTheme.trainerCyan;

                  if (_checkedInToday && !_checkedOutToday) {
                    return CredStaggeredItem(
                      index: 1,
                      child: CredMetalCard(
                        glowColor: AppTheme.trainerCyan,
                        borderRadius: 22,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.trainerCyan
                                        .withValues(alpha: 0.14),
                                    border: Border.all(
                                      color: AppTheme.trainerCyan
                                          .withValues(alpha: 0.48),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    color: AppTheme.trainerCyan,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CHECKED IN${_checkedInTime.isNotEmpty ? " • $_checkedInTime" : " TODAY"}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Daily attendance marked • Swipe below when leaving',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _SlideToCheckOutBar(
                              onCompleted: () =>
                                  _handleCheckOut(context, state),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (_checkedInToday && _checkedOutToday) {
                    final durationLabel = _computeSessionDuration();
                    return CredStaggeredItem(
                      index: 1,
                      child: CredMetalCard(
                        glowColor: AppTheme.trainerCyan,
                        borderRadius: 22,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.trainerCyan,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                const Expanded(
                                  child: Text(
                                    'TODAY\'S WORKOUT',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      color: AppTheme.trainerCyan,
                                      size: 13,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'SESSION COMPLETE',
                                      style: TextStyle(
                                        color: AppTheme.trainerCyan,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CHECKED IN',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _checkedInTime.isNotEmpty
                                          ? _checkedInTime
                                          : '--:--',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 1.2,
                                          color: AppTheme.trainerCyan
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.trainerCyan
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          border: Border.all(
                                            color: AppTheme.trainerCyan
                                                .withValues(alpha: 0.38),
                                          ),
                                        ),
                                        child: Text(
                                          durationLabel,
                                          style: const TextStyle(
                                            color: AppTheme.trainerCyan,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 1.2,
                                          color: AppTheme.trainerCyan
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'CHECKED OUT',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _checkedOutTime.isNotEmpty
                                          ? _checkedOutTime
                                          : '--:--',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final IconData btnIcon = isExpired
                      ? Icons.lock_rounded
                      : isFrozen
                          ? Icons.pause_circle_filled_rounded
                          : Icons.qr_code_scanner_rounded;
                  final String btnTitle = _checkingGpsGate
                      ? 'CHECKING GYM LOCATION...'
                      : isExpired
                          ? 'PASS EXPIRED • RENEW NOW'
                          : isFrozen
                              ? 'PASS FROZEN • VACATION MODE'
                              : 'SCAN DOOR QR TO CHECK IN';
                  final showGpsHint = !isExpired &&
                      !isFrozen &&
                      context.read<SmartGymBloc>().firestoreService != null &&
                      gym.requireGpsCheckIn &&
                      gym.hasLocation;

                  return CredStaggeredItem(
                    index: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedBuilder(
                          animation: _radarCtrl,
                          builder: (context, child) {
                            final pulse = (isFrozen || _checkingGpsGate)
                                ? 1.0
                                : 1.0 + (_radarCtrl.value * 0.03);
                            return Transform.scale(scale: pulse, child: child);
                          },
                          child: GestureDetector(
                            onTap: () => _scanDoorQr(context, state),
                            child: Container(
                              height: 58,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: LinearGradient(
                                  colors: [
                                    btnColor.withValues(alpha: 0.22),
                                    btnColor.withValues(alpha: 0.07),
                                  ],
                                ),
                                border: Border.all(
                                  color: btnColor.withValues(alpha: 0.75),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: btnColor.withValues(alpha: 0.16),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: btnColor,
                                    ),
                                    child: _checkingGpsGate
                                        ? const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.black,
                                            ),
                                          )
                                        : Icon(
                                            btnIcon,
                                            color: Colors.black,
                                            size: 20,
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      btnTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: btnColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (showGpsHint) ...[
                          const SizedBox(height: 9),
                          _buildGpsProximityRow(gym.checkInRadiusMeters),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 18),

              // 3. Open Editorial Live Floor Telemetry (aligned cleanly to outer 20px grid)
              CredStaggeredItem(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: crowdColor,
                              boxShadow: [
                                BoxShadow(
                                  color: crowdColor.withValues(alpha: 0.7),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'LIVE FLOOR OCCUPANCY',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          Text(
                            crowdLabel.toUpperCase(),
                            style: TextStyle(
                              color: crowdColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: crowdRatio),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          final maxCap =
                              gym.maxCapacity > 0 ? gym.maxCapacity : 60;
                          final freeSpots =
                              (maxCap - state.liveCrowd).clamp(0, maxCap);
                          final pct = (val * 100).round();

                          return Column(
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 96,
                                    height: 96,
                                    child: CustomPaint(
                                      painter: _CrowdGaugePainter(
                                        progress: val,
                                        accentColor: crowdColor,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$pct%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                height: 1,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            const Text(
                                              'FULL',
                                              style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '${state.liveCrowd}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 38,
                                                fontWeight: FontWeight.w900,
                                                height: 1,
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                '/ $maxCap active',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          crowdRatio > 0.8
                                              ? 'Floor busy • Expect short rack waits'
                                              : crowdRatio > 0.5
                                                  ? 'Steady crowd • Good energy on floor'
                                                  : 'Racks & benches open • Zero wait',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: _CrowdStatCell(
                                      label: 'OPEN SPOTS',
                                      value: '$freeSpots',
                                      valueColor: Colors.white,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 28,
                                    color: Colors.white12,
                                  ),
                                  Expanded(
                                    child: _CrowdStatCell(
                                      label: 'FLOOR LIMIT',
                                      value: '$maxCap',
                                      valueColor: Colors.white70,
                                      alignment: CrossAxisAlignment.center,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 28,
                                    color: Colors.white12,
                                  ),
                                  Expanded(
                                    child: _CrowdStatCell(
                                      label: 'EST. WAIT',
                                      value: crowdRatio > 0.85
                                          ? '5–10m'
                                          : '0 MIN',
                                      valueColor: crowdColor,
                                      alignment: CrossAxisAlignment.end,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Builder(
                                builder: (_) {
                                  final rush =
                                      MemberIntelligenceService.forecastRushHours(
                                    gym,
                                  );
                                  return Container(
                                    key: const ValueKey('rush_forecast_strip'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.04,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 15,
                                          color: rush.isCurrentHourBusy
                                              ? AppTheme.amber
                                              : AppTheme.trainerCyan,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Quiet: ${rush.quietestWindowLabel} • Peak: ${rush.peakHoursLabel}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlideToCheckOutBar extends StatefulWidget {
  final VoidCallback onCompleted;

  const _SlideToCheckOutBar({required this.onCompleted});

  @override
  State<_SlideToCheckOutBar> createState() => _SlideToCheckOutBarState();
}

class _SlideToCheckOutBarState extends State<_SlideToCheckOutBar> {
  double _dragRatio = 0.0;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    const double height = 56;
    const double knobSize = 46;
    const double pad = 5;
    const Color sliderAccent = Color(0xFFFF6B35);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTravel =
            (constraints.maxWidth - knobSize - pad * 2).clamp(1.0, 1000.0);
        final knobLeft = pad + (_dragRatio * maxTravel);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (_completed) return;
            final next = (_dragRatio + details.delta.dx / maxTravel)
                .clamp(0.0, 1.0);
            if (next >= 0.90 && !_completed) {
              setState(() {
                _dragRatio = 1.0;
                _completed = true;
              });
              HapticFeedback.heavyImpact();
              widget.onCompleted();
            } else {
              setState(() => _dragRatio = next);
            }
          },
          onHorizontalDragEnd: (_) {
            if (!_completed) {
              setState(() => _dragRatio = 0.0);
            }
          },
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.44),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: sliderAccent.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Glowing fiery-orange walk trail
                AnimatedContainer(
                  duration: const Duration(milliseconds: 60),
                  width: knobLeft + knobSize + pad,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        sliderAccent.withValues(
                          alpha: 0.24 + (_dragRatio * 0.24),
                        ),
                        sliderAccent.withValues(
                          alpha: 0.08 + (_dragRatio * 0.16),
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                // Exit door target icon on the right end
                Positioned(
                  right: 16,
                  child: Icon(
                    Icons.door_front_door_rounded,
                    color: sliderAccent.withValues(
                      alpha: 0.70 + (_dragRatio * 0.30),
                    ),
                    size: 22,
                  ),
                ),
                // Centered label that fades as avatar walks across
                Center(
                  child: Opacity(
                    opacity: (1.0 - _dragRatio * 1.4).clamp(0.0, 1.0),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 24),
                        Text(
                          'SLIDE TO WALK OUT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                          color: sliderAccent,
                          size: 19,
                        ),
                      ],
                    ),
                  ),
                ),
                // Glowing fiery-orange circular knob with walking hero avatar
                AnimatedPositioned(
                  duration: _dragRatio == 0.0
                      ? const Duration(milliseconds: 220)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  left: knobLeft,
                  top: pad,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141824),
                      border: Border.all(
                        color: sliderAccent,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: sliderAccent.withValues(alpha: 0.55),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Image.asset(
                          'assets/images/poses/pose_walkout_bag.png',
                          fit: BoxFit.contain,
                        ),
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

class _GymWalkOutCelebration extends StatefulWidget {
  final String outTime;
  final VoidCallback onDone;

  const _GymWalkOutCelebration({
    required this.outTime,
    required this.onDone,
  });

  @override
  State<_GymWalkOutCelebration> createState() => _GymWalkOutCelebrationState();
}

class _GymWalkOutCelebrationState extends State<_GymWalkOutCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDone();
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          // Smooth continuous walk-in -> brief confident pause -> smooth walk-out
          final double xOffset;
          final double strideTilt;
          final double strideSwayY;
          if (t < 0.32) {
            final p = Curves.easeOutCubic.transform((t / 0.32).clamp(0.0, 1.0));
            xOffset = -width * 0.36 * (1.0 - p);
            strideSwayY = math.sin(p * math.pi * 2) * 2.2;
            strideTilt = 0.025 * (1.0 - p * 0.6);
          } else if (t < 0.58) {
            // Standing still briefly (zero jumping)
            xOffset = 0;
            strideSwayY = 0;
            strideTilt = 0;
          } else {
            final p = Curves.easeInOutCubic
                .transform(((t - 0.58) / 0.42).clamp(0.0, 1.0));
            xOffset = width * 0.70 * p;
            strideSwayY = math.sin(p * math.pi * 3) * 2.4;
            strideTilt = 0.03 * math.sin(p * math.pi);
          }
          final opacity = t > 0.82
              ? (1.0 - (t - 0.82) / 0.18).clamp(0.0, 1.0)
              : (t / 0.14).clamp(0.0, 1.0);
          final blurSigma = (12.0 * opacity).clamp(0.01, 12.0);

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(xOffset, strideSwayY),
                      child: Transform.rotate(
                        angle: strideTilt,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/poses/pose_walkout_bag.png',
                              width: 220,
                              height: 270,
                              fit: BoxFit.contain,
                            ),
                            // Grounded floor shadow under sneakers
                            Container(
                              width: 110,
                              height: 10,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'WORKOUT CRUSHED!',
                      style: TextStyle(
                        color: AppTheme.trainerCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Checked out at ${widget.outTime} • See you tomorrow!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CrowdStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final CrossAxisAlignment alignment;

  const _CrowdStatCell({
    required this.label,
    required this.value,
    required this.valueColor,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CrowdGaugePainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  const _CrowdGaugePainter({
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 6;
    const startAngle = math.pi * 0.78;
    const totalSweep = math.pi * 1.44;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Subtle background track arc
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawArc(rect, startAngle, totalSweep, false, trackPaint);

    // Subtle calibrated tick marks around the dial
    final tickPaint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16);
    const tickCount = 12;
    for (int i = 0; i <= tickCount; i++) {
      final angle = startAngle + (totalSweep * (i / tickCount));
      final p1 = Offset(
        center.dx + (radius - 10) * math.cos(angle),
        center.dy + (radius - 10) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 7) * math.cos(angle),
        center.dy + (radius - 7) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Glowing active telemetry arc
    final sweep = totalSweep * progress.clamp(0.0, 1.0);
    if (sweep > 0.01) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..color = accentColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawArc(rect, startAngle, sweep, false, glowPaint);

      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5
        ..strokeCap = StrokeCap.round
        ..color = accentColor;
      canvas.drawArc(rect, startAngle, sweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrowdGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accentColor != accentColor;
}
