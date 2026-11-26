import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/gym_location_service.dart';
import '../../../domain/models/gym_fee_plan.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';
import '../shared/gym_fee_plans_editor.dart';
import '../shared/gym_map_picker_screen.dart';

/// Persists just the gym's coordinates & geofence radius directly to Firestore
/// (used by Day-1 quick pin actions outside the full settings sheet).
Future<String?> saveQuickGymLocation({
  required SmartGymBloc bloc,
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) async {
  final gym = bloc.state.currentGym;
  final fs = bloc.firestoreService;
  if (fs != null && gym.id.isNotEmpty) {
    try {
      await fs
          .updateGymSettings(
            gymId: gym.id,
            name: gym.name,
            area: gym.area,
            monthlyFee: gym.monthlyFee,
            ptFee: gym.ptFee,
            maxCapacity: gym.maxCapacity,
            latitude: latitude,
            longitude: longitude,
            clearLocation: false,
            checkInRadiusMeters: radiusMeters,
            requireGpsCheckIn: true,
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return 'Could not reach database — turn on internet / Wi-Fi and try again.';
    } catch (e) {
      final diag = await fs.diagnoseGymWriteAccess(gym.id);
      return 'Failed to save location: $e ($diag)';
    }
  }
  bloc.add(
    SyncGymTenantEvent(
      gym.copyWith(
        latitude: latitude,
        longitude: longitude,
        checkInRadiusMeters: radiusMeters,
        requireGpsCheckIn: true,
      ),
    ),
  );
  return null;
}

/// Shared bottom sheet for Gym Profile, Fees, Floor Capacity & GPS/Map Lock.
void showOwnerGymSettingsSheet(BuildContext context, SmartGymState state) {
  final bloc = context.read<SmartGymBloc>();
  final messenger = ScaffoldMessenger.of(context);
  final p = AppPalette.light;
  final gym = state.currentGym;
  final nameCtrl = TextEditingController(text: gym.name);
  final areaCtrl = TextEditingController(text: gym.area);
  final capCtrl = TextEditingController(text: gym.maxCapacity.toString());
  List<GymFeePlan> feePlans = List.of(gym.effectiveFeePlans);
  double? pinnedLat = gym.latitude;
  double? pinnedLng = gym.longitude;
  bool clearPin = false;
  bool requireGps = gym.requireGpsCheckIn;
  bool ptSplitExcludesBaseFee = gym.ptSplitExcludesBaseFee;
  int radiusMeters = gym.checkInRadiusMeters;
  bool fetchingGps = false;
  bool saving = false;
  String? gpsError;
  String? formError;

  InputDecoration fieldDecoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: icon != null ? Icon(icon, color: p.gold, size: 18) : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: p.cardSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.gold),
        ),
      );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.card,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 340),
      reverseDuration: Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => AppTheme.ensureOwnerLight(
      context,
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final isPinned = pinnedLat != null && pinnedLng != null;
          final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
          final maxH = MediaQuery.of(ctx).size.height * 0.88;
          void clearFormError() {
            if (formError != null) {
              setModalState(() => formError = null);
            }
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: p.border,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: p.gold.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: p.gold,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gym Settings & Location Lock',
                                      style: TextStyle(
                                        color: p.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Fees, floor capacity & check-in geofence',
                                      style: TextStyle(
                                        color: p.textMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: p.textMuted,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(color: p.divider, height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'GYM PROFILE & FEES',
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: nameCtrl,
                              onChanged: (_) => clearFormError(),
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: fieldDecoration(
                                'Gym Name',
                                icon: Icons.storefront_rounded,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: areaCtrl,
                              onChanged: (_) => clearFormError(),
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: fieldDecoration(
                                'Area & City',
                                icon: Icons.place_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'MEMBERSHIP PLANS & FEE STRUCTURE',
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GymFeePlansEditor(
                              plans: feePlans,
                              onChanged: (next) {
                                setModalState(() {
                                  feePlans = next;
                                  formError = null;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: capCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => clearFormError(),
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: fieldDecoration(
                                'Max Floor Capacity',
                                icon: Icons.groups_rounded,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: p.cardSubtle,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: ptSplitExcludesBaseFee
                                      ? p.gold.withValues(alpha: 0.45)
                                      : p.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Keep Base Fee 100% Owner',
                                          style: TextStyle(
                                            color: p.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Apply trainer PT % only to coaching fee above base membership.',
                                          style: TextStyle(
                                            color: p.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch.adaptive(
                                    key: const ValueKey(
                                        'settings_pt_base_fee_switch'),
                                    value: ptSplitExcludesBaseFee,
                                    activeThumbColor: p.gold,
                                    onChanged: (v) {
                                      HapticFeedback.selectionClick();
                                      setModalState(
                                          () => ptSplitExcludesBaseFee = v);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'INSIDE-GYM CHECK-IN LOCK (MAP OR GPS)',
                              style: TextStyle(
                                color: p.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: p.cardSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPinned
                                      ? p.cyan.withValues(alpha: 0.42)
                                      : p.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: (isPinned ? p.cyan : p.gold)
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isPinned
                                              ? Icons.location_on_rounded
                                              : Icons.add_location_alt_rounded,
                                          color: isPinned ? p.cyan : p.gold,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isPinned
                                                  ? 'Gym Location Pinned'
                                                  : 'Gym Pin Not Set',
                                              style: TextStyle(
                                                color: p.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isPinned
                                                  ? '${pinnedLat!.toStringAsFixed(5)}, ${pinnedLng!.toStringAsFixed(5)}'
                                                  : 'Pick on map or use live GPS',
                                              style: TextStyle(
                                                color: isPinned
                                                    ? p.cyan
                                                    : p.textMuted,
                                                fontSize: 11.5,
                                                fontWeight: isPinned
                                                    ? FontWeight.w700
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isPinned) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                p.cyan.withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            'SAVED',
                                            style: TextStyle(
                                              color: p.cyan,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () => setModalState(() {
                                            pinnedLat = null;
                                            pinnedLng = null;
                                            clearPin = true;
                                            gpsError = null;
                                          }),
                                          child: Text(
                                            'Clear',
                                            style: TextStyle(
                                              color: p.danger,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor:
                                                  p.gold.withValues(alpha: 0.10),
                                              foregroundColor: p.gold,
                                              side: BorderSide(
                                                color: p.gold
                                                    .withValues(alpha: 0.45),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () async {
                                              HapticFeedback.selectionClick();
                                              final picked =
                                                  await showGymMapPicker(
                                                ctx,
                                                initialLat: pinnedLat,
                                                initialLng: pinnedLng,
                                                initialSearchQuery:
                                                    areaCtrl.text.trim(),
                                                initialRadiusMeters:
                                                    radiusMeters,
                                              );
                                              if (!ctx.mounted ||
                                                  picked == null) {
                                                return;
                                              }
                                              setModalState(() {
                                                pinnedLat = picked.latitude;
                                                pinnedLng = picked.longitude;
                                                radiusMeters =
                                                    picked.radiusMeters;
                                                clearPin = false;
                                                requireGps = true;
                                                gpsError = null;
                                                formError = null;
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.map_rounded,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Choose on Map',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SizedBox(
                                          height: 44,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor:
                                                  p.cyan.withValues(alpha: 0.08),
                                              foregroundColor: p.cyan,
                                              side: BorderSide(
                                                color: p.cyan
                                                    .withValues(alpha: 0.45),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: fetchingGps
                                                ? null
                                                : () async {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    setModalState(() {
                                                      fetchingGps = true;
                                                      gpsError = null;
                                                    });
                                                    final res =
                                                        await GymLocationService
                                                            .captureCurrentCoordinates();
                                                    if (!ctx.mounted) return;
                                                    setModalState(() {
                                                      fetchingGps = false;
                                                      if (res.isSuccess) {
                                                        pinnedLat =
                                                            res.latitude;
                                                        pinnedLng =
                                                            res.longitude;
                                                        clearPin = false;
                                                        requireGps = true;
                                                        formError = null;
                                                      } else {
                                                        gpsError = res.error;
                                                      }
                                                    });
                                                    if (res
                                                        .openLocationSettings) {
                                                      await Geolocator
                                                          .openLocationSettings();
                                                    } else if (res
                                                        .openAppSettings) {
                                                      await Geolocator
                                                          .openAppSettings();
                                                    }
                                                  },
                                            icon: fetchingGps
                                                ? SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: p.cyan,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.my_location_rounded,
                                                    size: 16,
                                                  ),
                                            label: Text(
                                              fetchingGps
                                                  ? 'Reading...'
                                                  : 'Use GPS',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (gpsError != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      gpsError!,
                                      style: TextStyle(
                                        color: p.danger,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Divider(color: p.divider, height: 1),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Require GPS Inside Gym',
                                              style: TextStyle(
                                                color: p.textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Blocks at-home scans. Turn off for basement gyms.',
                                              style: TextStyle(
                                                color: p.textMuted,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Switch.adaptive(
                                        value: requireGps,
                                        activeThumbColor: p.cyan,
                                        activeTrackColor:
                                            p.cyan.withValues(alpha: 0.35),
                                        onChanged: (v) {
                                          HapticFeedback.selectionClick();
                                          setModalState(() {
                                            requireGps = v;
                                            if (!v) formError = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  if (requireGps) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      'CHECK-IN RADIUS',
                                      style: TextStyle(
                                        color: p.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        (80, 'Strict'),
                                        (100, 'Default'),
                                        (150, 'Wide'),
                                      ].map((item) {
                                        final r = item.$1;
                                        final label = item.$2;
                                        final sel = radiusMeters == r;
                                        return Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: r == 150 ? 0 : 8,
                                            ),
                                            child: GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setModalState(
                                                  () => radiusMeters = r,
                                                );
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: sel
                                                      ? p.cyan.withValues(
                                                          alpha: 0.14)
                                                      : p.card,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        sel ? p.cyan : p.border,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      '${r}m',
                                                      style: TextStyle(
                                                        color: sel
                                                            ? p.cyan
                                                            : p.textPrimary,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      label,
                                                      style: TextStyle(
                                                        color: sel
                                                            ? p.cyan
                                                            : p.textMuted,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      decoration: BoxDecoration(
                        color: p.card,
                        border: Border(top: BorderSide(color: p.divider)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (formError != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: p.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: p.danger.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: p.danger,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      formError!,
                                      style: TextStyle(
                                        color: p.danger,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: p.goldButton,
                                foregroundColor: p.onAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final gymName = nameCtrl.text.trim();
                                      final gymArea = areaCtrl.text.trim();
                                      final planError =
                                          GymFeePlansEditor.validatePlans(
                                              feePlans);
                                      final cap =
                                          int.tryParse(capCtrl.text.trim());

                                      String? error;
                                      if (gymName.isEmpty ||
                                          gymName.length > 100) {
                                        error =
                                            'Enter a valid Gym Name (1–100 characters).';
                                      } else if (gymArea.isEmpty ||
                                          gymArea.length > 100) {
                                        error = 'Enter your gym Area & City.';
                                      } else if (planError != null) {
                                        error = planError;
                                      } else if (cap == null ||
                                          cap < 1 ||
                                          cap > 10000) {
                                        error =
                                            'Enter a valid Max Floor Capacity (1 – 10,000).';
                                      } else if (cap <
                                          gym.activeCrowdForDate()) {
                                        error =
                                            'Capacity cannot be less than current floor crowd (${gym.activeCrowdForDate()}).';
                                      } else if (requireGps &&
                                          (pinnedLat == null ||
                                              pinnedLng == null)) {
                                        error =
                                            'Pin your gym on the Map or GPS first, or turn OFF "Require GPS Inside Gym".';
                                      }

                                      if (error != null) {
                                        HapticFeedback.heavyImpact();
                                        setModalState(() => formError = error);
                                        return;
                                      }

                                      final mFee = GymFeePlan.resolveMonthlyFee(
                                        feePlans,
                                        fallback: gym.monthlyFee,
                                      );
                                      final pFee = GymFeePlan.resolvePtFee(
                                        feePlans,
                                        fallback: gym.ptFee,
                                      );

                                      HapticFeedback.mediumImpact();
                                      final fs = bloc.firestoreService;
                                      if (fs != null && gym.id.isNotEmpty) {
                                        setModalState(() {
                                          saving = true;
                                          formError = null;
                                        });
                                        try {
                                          await fs
                                              .updateGymSettings(
                                                gymId: gym.id,
                                                name: gymName,
                                                area: gymArea,
                                                monthlyFee: mFee,
                                                ptFee: pFee,
                                                maxCapacity: cap!,
                                                feePlans: feePlans,
                                                latitude: pinnedLat,
                                                longitude: pinnedLng,
                                                clearLocation: clearPin,
                                                checkInRadiusMeters:
                                                    radiusMeters,
                                                requireGpsCheckIn: requireGps,
                                                ptSplitExcludesBaseFee:
                                                    ptSplitExcludesBaseFee,
                                              )
                                              .timeout(
                                                const Duration(seconds: 10),
                                              );
                                          bloc.add(
                                            SyncGymTenantEvent(
                                              gym.copyWith(
                                                name: gymName,
                                                area: gymArea,
                                                monthlyFee: mFee,
                                                ptFee: pFee,
                                                ptSplitExcludesBaseFee:
                                                    ptSplitExcludesBaseFee,
                                                maxCapacity: cap,
                                                feePlans: feePlans,
                                                latitude: pinnedLat,
                                                longitude: pinnedLng,
                                                clearLocation: clearPin,
                                                checkInRadiusMeters:
                                                    radiusMeters,
                                                requireGpsCheckIn: requireGps,
                                              ),
                                            ),
                                          );
                                        } on TimeoutException {
                                          if (!ctx.mounted) return;
                                          setModalState(() {
                                            saving = false;
                                            formError =
                                                'Could not reach database — turn on internet / Wi-Fi and try Save again.';
                                          });
                                          return;
                                        } catch (e) {
                                          final diag = await fs
                                              .diagnoseGymWriteAccess(gym.id);
                                          if (!ctx.mounted) return;
                                          setModalState(() {
                                            saving = false;
                                            formError =
                                                'Failed to save in DB: $e ($diag)';
                                          });
                                          return;
                                        }
                                      } else {
                                        bloc.add(
                                          UpdateGymSettingsEvent(
                                            name: gymName,
                                            area: gymArea,
                                            monthlyFee: mFee,
                                            ptFee: pFee,
                                            ptSplitExcludesBaseFee:
                                                ptSplitExcludesBaseFee,
                                            maxCapacity: cap!,
                                            feePlans: feePlans,
                                            latitude: pinnedLat,
                                            longitude: pinnedLng,
                                            clearLocation: clearPin,
                                            checkInRadiusMeters: radiusMeters,
                                            requireGpsCheckIn: requireGps,
                                          ),
                                        );
                                      }

                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: p.goldButton,
                                          content: Text(
                                            'Gym settings & location saved!',
                                            style: TextStyle(
                                              color: p.onAccent,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                              child: saving
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: p.onAccent,
                                      ),
                                    )
                                  : const Text(
                                      'SAVE SETTINGS',
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
