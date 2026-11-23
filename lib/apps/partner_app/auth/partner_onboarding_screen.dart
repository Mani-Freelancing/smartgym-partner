import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/gym_location_service.dart';
import '../../../data/services/onboarding_draft_service.dart';
import '../../../domain/models/gym_fee_plan.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';
import '../shared/gym_fee_plans_editor.dart';
import '../shared/qr_scanner_screen.dart';

class PartnerOnboardingScreen extends StatefulWidget {
  const PartnerOnboardingScreen({super.key});

  @override
  State<PartnerOnboardingScreen> createState() =>
      _PartnerOnboardingScreenState();
}

class _PartnerOnboardingScreenState extends State<PartnerOnboardingScreen>
    with WidgetsBindingObserver {
  bool _isOwnerForm = true;
  int _ownerStep = 0; // 0: Gym Info, 1: Fees & Capacity, 2: Gym Location
  bool _stepForward = true;

  final _gymNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _monthlyFeeCtrl = TextEditingController(text: '1500');
  final _ptFeeCtrl = TextEditingController(text: '6000');
  final _capacityCtrl = TextEditingController(text: '60');
  final _mapsLinkCtrl = TextEditingController();
  final _trainerNameCtrl = TextEditingController();

  double? _pinnedLat;
  double? _pinnedLng;
  String? _pinSource; // 'gps' | 'maps'
  int _radiusMeters = 100;
  bool _requireGpsCheckIn = true;
  bool _fetchingGps = false;
  bool _resolvingLink = false;
  bool _editingLocation = false;
  String? _linkStatusText;
  bool _linkStatusIsError = false;
  int _resolveRequestId = 0;
  bool _showLatLngGuide = false;
  List<GymFeePlan> _feePlans = GymFeePlan.defaultPlans();
  String? _localError;

  Timer? _draftDebounce;
  bool _draftLoaded = false;
  bool _resumedFromDraft = false;
  bool _skipDisposeSave = false;
  String _loadedPhone = '';

  static const _stepTitles = [
    'Gym Info',
    'Fees',
    'Location',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attachDraftListeners();
    _loadedPhone = context.read<SmartGymBloc>().state.authenticatedPhone;
    _restoreDraft(_loadedPhone);
  }

  void _attachDraftListeners() {
    for (final ctrl in [
      _gymNameCtrl,
      _areaCtrl,
      _ownerNameCtrl,
      _monthlyFeeCtrl,
      _ptFeeCtrl,
      _capacityCtrl,
      _trainerNameCtrl,
    ]) {
      ctrl.addListener(_scheduleDraftSave);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentPhone = context.read<SmartGymBloc>().state.authenticatedPhone;
    if (currentPhone.isNotEmpty) {
      _loadedPhone = currentPhone;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistDraftNow());
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!_skipDisposeSave && _draftLoaded) {
      unawaited(_persistDraftNow());
    }
    _gymNameCtrl.dispose();
    _areaCtrl.dispose();
    _ownerNameCtrl.dispose();
    _monthlyFeeCtrl.dispose();
    _ptFeeCtrl.dispose();
    _capacityCtrl.dispose();
    _mapsLinkCtrl.dispose();
    _trainerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft(String phone) async {
    final draft = await OnboardingDraftService.loadDraft(phone);
    if (!mounted) return;
    setState(() {
      _draftLoaded = true;
      if (draft != null) {
        _resumedFromDraft = true;
        _isOwnerForm = draft.isOwnerForm;
        _ownerStep = draft.ownerStep.clamp(0, 2);
        if (draft.gymName.isNotEmpty) _gymNameCtrl.text = draft.gymName;
        if (draft.area.isNotEmpty) _areaCtrl.text = draft.area;
        if (draft.ownerName.isNotEmpty) _ownerNameCtrl.text = draft.ownerName;
        if (draft.monthlyFee.isNotEmpty) {
          _monthlyFeeCtrl.text = draft.monthlyFee;
        }
        if (draft.ptFee.isNotEmpty) _ptFeeCtrl.text = draft.ptFee;
        if (draft.maxCapacity.isNotEmpty) {
          _capacityCtrl.text = draft.maxCapacity;
        }
        if (draft.feePlans.isNotEmpty) {
          _feePlans = draft.feePlans;
        } else {
          final parsedM = int.tryParse(draft.monthlyFee) ?? 1500;
          final parsedPt = int.tryParse(draft.ptFee) ?? 6000;
          _feePlans = GymFeePlan.defaultPlans(
            monthlyFee: parsedM,
            ptFee: parsedPt,
          );
        }
        _pinnedLat = draft.latitude;
        _pinnedLng = draft.longitude;
        if (draft.latitude != null && draft.longitude != null) {
          _pinSource = 'gps';
        }
        _radiusMeters = draft.radiusMeters;
        _requireGpsCheckIn = draft.requireGpsCheckIn;
        if (draft.trainerName.isNotEmpty) {
          _trainerNameCtrl.text = draft.trainerName;
        }
      }
    });
  }

  void _scheduleDraftSave() {
    if (!_draftLoaded || _skipDisposeSave) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_persistDraftNow());
    });
  }

  OnboardingDraft _currentDraft() => OnboardingDraft(
        ownerStep: _ownerStep,
        isOwnerForm: _isOwnerForm,
        gymName: _gymNameCtrl.text,
        area: _areaCtrl.text,
        ownerName: _ownerNameCtrl.text,
        monthlyFee: _monthlyFeeCtrl.text,
        ptFee: _ptFeeCtrl.text,
        maxCapacity: _capacityCtrl.text,
        feePlans: _feePlans,
        latitude: _pinnedLat,
        longitude: _pinnedLng,
        radiusMeters: _radiusMeters,
        requireGpsCheckIn: _requireGpsCheckIn,
        trainerName: _trainerNameCtrl.text,
      );

  Future<void> _persistDraftNow() async {
    if (_skipDisposeSave) return;
    await OnboardingDraftService.saveDraft(_loadedPhone, _currentDraft());
  }

  Future<void> _resetDraft() async {
    HapticFeedback.selectionClick();
    _draftDebounce?.cancel();
    final phone = context.read<SmartGymBloc>().state.authenticatedPhone;
    await OnboardingDraftService.clearDraft(phone);
    if (!mounted) return;
    setState(() {
      _resumedFromDraft = false;
      _isOwnerForm = true;
      _ownerStep = 0;
      _stepForward = false;
      _gymNameCtrl.clear();
      _areaCtrl.clear();
      _ownerNameCtrl.clear();
      _monthlyFeeCtrl.text = '1500';
      _ptFeeCtrl.text = '6000';
      _capacityCtrl.text = '60';
      _feePlans = GymFeePlan.defaultPlans();
      _trainerNameCtrl.clear();
      _mapsLinkCtrl.clear();
      _pinnedLat = null;
      _pinnedLng = null;
      _pinSource = null;
      _resolvingLink = false;
      _editingLocation = false;
      _linkStatusText = null;
      _linkStatusIsError = false;
      _resolveRequestId++;
      _showLatLngGuide = false;
      _radiusMeters = 100;
      _requireGpsCheckIn = true;
      _localError = null;
    });
  }

  void _goToStep(int targetStep) {
    if (targetStep == _ownerStep) return;
    HapticFeedback.selectionClick();
    setState(() {
      _stepForward = targetStep > _ownerStep;
      _ownerStep = targetStep.clamp(0, 2);
      _localError = null;
    });
    unawaited(_persistDraftNow());
  }

  Future<void> _scanInviteQr() async {
    final trainerName = _trainerNameCtrl.text.trim();
    if (trainerName.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _localError = 'Enter your name first before scanning QR.');
      return;
    }
    setState(() => _localError = null);
    await _persistDraftNow();
    if (!mounted) return;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(
          title: 'Scan Gym Invite QR',
          subtitle:
              'Point camera at the Staff Invite QR on your Gym Owner\'s phone.',
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
      setState(
        () => _localError =
            'Invalid Staff Invite QR. Please scan the Owner\'s Invite QR.',
      );
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

  Future<void> _saveAndNextFromStep1() async {
    final gymName = _gymNameCtrl.text.trim();
    final area = _areaCtrl.text.trim();
    final ownerName = _ownerNameCtrl.text.trim();
    if (gymName.isEmpty || area.isEmpty || ownerName.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _localError = 'Please fill in all 3 fields to continue.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _stepForward = true;
      _ownerStep = 1;
      _localError = null;
    });
    await _persistDraftNow();
  }

  void _onFeePlansChanged(List<GymFeePlan> nextPlans) {
    final resolvedMonthly = GymFeePlan.resolveMonthlyFee(nextPlans);
    final resolvedPt = GymFeePlan.resolvePtFee(nextPlans);
    setState(() {
      _feePlans = nextPlans;
      _monthlyFeeCtrl.text = '$resolvedMonthly';
      _ptFeeCtrl.text = '$resolvedPt';
      _localError = null;
    });
    _scheduleDraftSave();
  }

  Future<void> _saveAndNextFromStep2() async {
    final planError = GymFeePlansEditor.validatePlans(_feePlans);
    final cap = int.tryParse(_capacityCtrl.text.trim());

    if (planError != null) {
      HapticFeedback.heavyImpact();
      setState(() => _localError = planError);
      return;
    }
    if (cap == null || cap < 1 || cap > 10000) {
      HapticFeedback.heavyImpact();
      setState(
          () => _localError = 'Enter a valid Max Capacity (1 – 10,000).');
      return;
    }

    _monthlyFeeCtrl.text = '${GymFeePlan.resolveMonthlyFee(_feePlans)}';
    _ptFeeCtrl.text = '${GymFeePlan.resolvePtFee(_feePlans)}';
    HapticFeedback.mediumImpact();
    setState(() {
      _stepForward = true;
      _ownerStep = 2;
      _localError = null;
    });
    await _persistDraftNow();
  }

  void _onMapsLinkChanged(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      _resolveRequestId++;
      setState(() {
        _resolvingLink = false;
        _linkStatusText = null;
        _linkStatusIsError = false;
        if (_pinSource == 'maps') {
          _pinnedLat = null;
          _pinnedLng = null;
          _pinSource = null;
        }
      });
      unawaited(_persistDraftNow());
      return;
    }
    final direct = GymLocationService.parseCoordinatePair(text);
    if (direct != null || text.contains('http') || text.contains('maps.')) {
      unawaited(_resolveMapsLinkInput(text));
    } else {
      setState(() {
        _linkStatusText =
            'Paste a Google Maps share link (e.g. https://maps.app.goo.gl/...)';
        _linkStatusIsError = false;
      });
    }
  }

  Future<void> _resolveMapsLinkInput(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _resolvingLink = false;
        _linkStatusText =
            'Nothing in clipboard yet. Open Google Maps -> Share -> Copy link first.';
        _linkStatusIsError = true;
      });
      return;
    }

    final reqId = ++_resolveRequestId;
    setState(() {
      _resolvingLink = true;
      _linkStatusText = null;
      _linkStatusIsError = false;
      _localError = null;
    });

    final res = await GymLocationService.resolveCoordinatesFromInput(trimmed);
    if (!mounted || reqId != _resolveRequestId) return;

    if (!res.isSuccess) {
      setState(() {
        _resolvingLink = false;
        _linkStatusText = res.error ?? 'Could not read that Google Maps link.';
        _linkStatusIsError = true;
        _showLatLngGuide = true;
      });
      return;
    }

    setState(() {
      _resolvingLink = false;
      _pinnedLat = res.latitude;
      _pinnedLng = res.longitude;
      _pinSource = 'maps';
      _editingLocation = false;
      _requireGpsCheckIn = true;
      _linkStatusText =
          'Locked via Maps: ${res.latitude!.toStringAsFixed(5)}, ${res.longitude!.toStringAsFixed(5)}';
      _linkStatusIsError = false;
      _localError = null;
    });
    await _persistDraftNow();
  }

  Future<void> _pasteMapsLinkFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = (data?.text ?? '').trim();
    if (!mounted) return;
    if (raw.isEmpty) {
      setState(() {
        _linkStatusText =
            'Clipboard is empty. In Google Maps tap Share -> Copy link first.';
        _linkStatusIsError = true;
        _showLatLngGuide = true;
      });
      return;
    }
    _mapsLinkCtrl.value = TextEditingValue(
      text: raw,
      selection: TextSelection.collapsed(offset: raw.length),
    );
    await _resolveMapsLinkInput(raw);
  }

  Future<void> _openGoogleMapsForCoords() async {
    HapticFeedback.selectionClick();
    setState(() => _localError = null);
    final rawQuery =
        '${_gymNameCtrl.text.trim()} ${_areaCtrl.text.trim()}'.trim();
    final encoded = Uri.encodeComponent(rawQuery);
    final candidates = <Uri>[
      if (defaultTargetPlatform == TargetPlatform.android)
        Uri.parse(
          encoded.isEmpty ? 'geo:0,0' : 'geo:0,0?q=$encoded',
        ),
      if (defaultTargetPlatform == TargetPlatform.iOS)
        Uri.parse(
          encoded.isEmpty ? 'comgooglemaps://' : 'comgooglemaps://?q=$encoded',
        ),
      Uri.parse(
        encoded.isEmpty
            ? 'https://www.google.com/maps'
            : 'https://www.google.com/maps/search/?api=1&query=$encoded',
      ),
    ];

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {
        // Try next candidate
      }
    }

    try {
      final fallback = Uri.parse(
        encoded.isEmpty
            ? 'https://www.google.com/maps'
            : 'https://www.google.com/maps/search/?api=1&query=$encoded',
      );
      if (await launchUrl(fallback, mode: LaunchMode.platformDefault)) {
        return;
      }
    } catch (_) {
      // Handled below
    }

    if (mounted) {
      setState(() {
        _localError = 'Could not open Google Maps on this device.';
      });
    }
  }

  Future<void> _captureOnboardingGps() async {
    HapticFeedback.selectionClick();
    setState(() {
      _fetchingGps = true;
      _localError = null;
    });
    final res = await GymLocationService.captureCurrentCoordinates();
    if (!mounted) return;
    setState(() {
      _fetchingGps = false;
      if (res.isSuccess) {
        _pinnedLat = res.latitude;
        _pinnedLng = res.longitude;
        _pinSource = 'gps';
        _editingLocation = false;
        _mapsLinkCtrl.clear();
        _linkStatusText = null;
        _linkStatusIsError = false;
        _requireGpsCheckIn = true;
      } else {
        _localError = res.error;
      }
    });
    if (res.isSuccess) {
      await _persistDraftNow();
    }
    if (res.openLocationSettings) {
      await Geolocator.openLocationSettings();
    } else if (res.openAppSettings) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _submitNewGym({bool allowSkipLocation = false}) async {
    final gymName = _gymNameCtrl.text.trim();
    final area = _areaCtrl.text.trim();
    final ownerName = _ownerNameCtrl.text.trim();
    final planError = GymFeePlansEditor.validatePlans(_feePlans);
    final cap = int.tryParse(_capacityCtrl.text.trim());

    if (gymName.isEmpty || area.isEmpty || ownerName.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _stepForward = false;
        _ownerStep = 0;
        _localError = 'Please complete Step 1 (Gym Name, Area & Owner Name).';
      });
      return;
    }
    if (planError != null || cap == null || cap < 1 || cap > 10000) {
      HapticFeedback.heavyImpact();
      setState(() {
        _stepForward = false;
        _ownerStep = 1;
        _localError = planError ?? 'Enter a valid Max Capacity (1 – 10,000).';
      });
      return;
    }
    if (!allowSkipLocation &&
        _requireGpsCheckIn &&
        (_pinnedLat == null || _pinnedLng == null)) {
      HapticFeedback.heavyImpact();
      setState(() {
        _localError =
            'Choose Option 1 (Use Current Location) or Option 2 (Paste Google Maps link), or skip below.';
      });
      return;
    }

    final monthlyFee = GymFeePlan.resolveMonthlyFee(_feePlans);
    final ptFee = GymFeePlan.resolvePtFee(_feePlans);
    await _persistDraftNow();
    if (!mounted) return;
    setState(() => _localError = null);
    HapticFeedback.mediumImpact();
    context.read<SmartGymBloc>().add(
          CreateNewGymOnboardingEvent(
            gymName: gymName,
            area: area,
            ownerName: ownerName,
            monthlyFee: monthlyFee,
            ptFee: ptFee,
            maxCapacity: cap,
            feePlans: _feePlans,
            latitude: _pinnedLat,
            longitude: _pinnedLng,
            checkInRadiusMeters: _radiusMeters,
            requireGpsCheckIn: _requireGpsCheckIn,
          ),
        );
  }

  Widget _buildOwnerStepContent(SmartGymState state, String? error) {
    if (_ownerStep == 0) {
      return KeyedSubtree(
        key: const ValueKey(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tell us about your gym studio',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
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
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ownerGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: state.isOnboardingBusy ? null : _saveAndNextFromStep1,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'SAVE & NEXT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_ownerStep == 1) {
      return KeyedSubtree(
        key: const ValueKey(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Customize your standard packages, add custom plans & set floor capacity',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            GymFeePlansEditor(
              plans: _feePlans,
              onChanged: _onFeePlansChanged,
            ),
            const SizedBox(height: 14),
            _InputBox(
              controller: _capacityCtrl,
              label: 'Max Floor Capacity',
              hint: '60',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(82, 50),
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed:
                      state.isOnboardingBusy ? null : () => _goToStep(0),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.ownerGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: state.isOnboardingBusy
                          ? null
                          : _saveAndNextFromStep2,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text(
                        'SAVE & NEXT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Step 3 (index 2): Confirmed location view OR 2 options (GPS / Google Maps Link)
    final isPinned = _pinnedLat != null && _pinnedLng != null;
    final isGpsPinned = isPinned && _pinSource == 'gps';
    final isMapsPinned = isPinned && _pinSource == 'maps';
    final showTwoOptions = !isPinned || _editingLocation;
    final pinColor = isMapsPinned ? AppTheme.ownerGold : AppTheme.trainerCyan;

    return KeyedSubtree(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPinned && !_editingLocation) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pinColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: pinColor.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: pinColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.verified_rounded,
                          color: pinColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gym Location Added',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMapsPinned
                                  ? 'Locked via Google Maps Link'
                                  : 'Locked via Live Phone GPS',
                              style: TextStyle(
                                color: pinColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12151C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: pinColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_pinnedLat!.toStringAsFixed(5)}, ${_pinnedLng!.toStringAsFixed(5)} • ${_radiusMeters}m check-in range',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('step3_edit_location_btn'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.ownerGold,
                            side: BorderSide(
                              color: AppTheme.ownerGold.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _editingLocation = true;
                              _localError = null;
                            });
                          },
                          icon: const Icon(Icons.edit_location_alt_rounded,
                              size: 16),
                          label: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const ValueKey('step3_clear_location_btn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(
                            color: AppTheme.danger.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          _resolveRequestId++;
                          setState(() {
                            _pinnedLat = null;
                            _pinnedLng = null;
                            _pinSource = null;
                            _editingLocation = false;
                            _mapsLinkCtrl.clear();
                            _resolvingLink = false;
                            _linkStatusText = null;
                            _linkStatusIsError = false;
                          });
                          unawaited(_persistDraftNow());
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (showTwoOptions) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Pick one option to lock your gym location:',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                if (isPinned && _editingLocation) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _editingLocation = false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.ownerGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // OPTION 1: Live GPS (When standing inside the gym)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF12151C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isGpsPinned
                      ? AppTheme.trainerCyan
                      : AppTheme.trainerCyan.withValues(alpha: 0.28),
                  width: isGpsPinned ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'OPTION 1 • WHEN AT GYM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.trainerCyan,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      if (isGpsPinned) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppTheme.trainerCyan,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Live Floor GPS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Standing inside your gym? Tap below to capture live phone GPS.',
                    style: TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.trainerCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: _fetchingGps || _resolvingLink
                          ? null
                          : _captureOnboardingGps,
                      icon: _fetchingGps
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded, size: 17),
                      label: Text(
                        _fetchingGps
                            ? 'Reading Current GPS...'
                            : (isGpsPinned
                                ? 'Re-capture Current Location'
                                : 'Use Current Location'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Visual "OR" divider differentiating the two choices
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white12)),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12151C),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white12)),
                ],
              ),
            ),

            // OPTION 2: Google Maps Share Link (Great when registering from home)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF12151C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _resolvingLink || isMapsPinned
                      ? AppTheme.ownerGold
                      : (_linkStatusIsError
                          ? AppTheme.danger.withValues(alpha: 0.55)
                          : AppTheme.ownerGold.withValues(alpha: 0.28)),
                  width: isMapsPinned ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.ownerGold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'OPTION 2 • FROM GOOGLE MAPS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.ownerGold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        key: const ValueKey('step3_paste_link_btn'),
                        onTap:
                            _resolvingLink ? null : _pasteMapsLinkFromClipboard,
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.ownerGold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.content_paste_rounded,
                                size: 13,
                                color: AppTheme.ownerGold,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Paste',
                                style: TextStyle(
                                  color: AppTheme.ownerGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste from Google Maps',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Not at your gym right now? Paste your gym\'s Google Maps share link.',
                    style: TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('step3_maps_link_input'),
                    controller: _mapsLinkCtrl,
                    onChanged: _onMapsLinkChanged,
                    onSubmitted: _resolveMapsLinkInput,
                    enabled: !_resolvingLink,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://maps.app.goo.gl/...',
                      hintStyle: const TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF1A1E29),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      suffixIcon: _resolvingLink
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.ownerGold,
                                ),
                              ),
                            )
                          : (_mapsLinkCtrl.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear link',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () {
                                    _mapsLinkCtrl.clear();
                                    _onMapsLinkChanged('');
                                  },
                                )
                              : null),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.ownerGold),
                      ),
                    ),
                  ),
                  if (_resolvingLink) ...[
                    const SizedBox(height: 8),
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: AppTheme.ownerGold,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.ownerGold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reading Google Maps link & fetching gym location...',
                            style: TextStyle(
                              color: AppTheme.ownerGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_linkStatusText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _linkStatusIsError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_rounded,
                          size: 14,
                          color: _linkStatusIsError
                              ? AppTheme.danger
                              : AppTheme.ownerGold,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _linkStatusText!,
                            style: TextStyle(
                              color: _linkStatusIsError
                                  ? AppTheme.danger
                                  : AppTheme.ownerGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  InkWell(
                    key: const ValueKey('toggle_lat_lng_guide'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _showLatLngGuide = !_showLatLngGuide);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.ownerGold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.ownerGold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.help_outline_rounded,
                            color: AppTheme.ownerGold,
                            size: 15,
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'How to copy Google Maps link?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.ownerGold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            _showLatLngGuide
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.ownerGold,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showLatLngGuide) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E29),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '1. Tap "Open Google Maps" below & select your gym.\n'
                            '2. Tap Share -> Copy link.\n'
                            '3. Come back here and tap "Paste" above.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 9),
                          SizedBox(
                            height: 35,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.ownerGold,
                                side: BorderSide(
                                  color:
                                      AppTheme.ownerGold.withValues(alpha: 0.45),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              onPressed: _openGoogleMapsForCoords,
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 14,
                              ),
                              label: const Text(
                                'Open Google Maps',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF12151C),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Require GPS Inside Gym',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Turn off for QR-only / basement gyms',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _requireGpsCheckIn,
                      activeThumbColor: AppTheme.trainerCyan,
                      activeTrackColor:
                          AppTheme.trainerCyan.withValues(alpha: 0.4),
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _requireGpsCheckIn = v;
                          _localError = null;
                        });
                        unawaited(_persistDraftNow());
                      },
                    ),
                  ],
                ),
                if (_requireGpsCheckIn) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      (80, 'Strict'),
                      (100, 'Default'),
                      (150, 'Wide'),
                    ].map((item) {
                      final r = item.$1;
                      final label = item.$2;
                      final sel = _radiusMeters == r;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: r == 150 ? 0 : 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _radiusMeters = r);
                              unawaited(_persistDraftNow());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.trainerCyan
                                        .withValues(alpha: 0.18)
                                    : const Color(0xFF1A1E29),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: sel
                                      ? AppTheme.trainerCyan
                                      : Colors.white12,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${r}m',
                                    style: TextStyle(
                                      color: sel
                                          ? AppTheme.trainerCyan
                                          : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: sel
                                          ? AppTheme.trainerCyan
                                          : Colors.white54,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
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
          Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(82, 50),
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: state.isOnboardingBusy ? null : () => _goToStep(1),
                child: const Text(
                  'Back',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
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
                        state.isOnboardingBusy ? null : () => _submitNewGym(),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (!isPinned && _requireGpsCheckIn) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: state.isOnboardingBusy
                  ? null
                  : () => _submitNewGym(allowSkipLocation: true),
              child: const Text(
                'Skip location for now & launch →',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SmartGymBloc, SmartGymState>(
      listenWhen: (prev, curr) => prev.needsOnboarding && !curr.needsOnboarding,
      listener: (context, state) {
        _skipDisposeSave = true;
        unawaited(OnboardingDraftService.clearDraft(_loadedPhone));
      },
      child: BlocBuilder<SmartGymBloc, SmartGymState>(
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1E29),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
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
                                : () async {
                                    await _persistDraftNow();
                                    if (!context.mounted) return;
                                    context
                                        .read<SmartGymBloc>()
                                        .add(const LogoutPartnerEvent());
                                  },
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
                      const SizedBox(height: 16),
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
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
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
                                onTap: () {
                                  setState(() {
                                    _isOwnerForm = true;
                                    _localError = null;
                                  });
                                  unawaited(_persistDraftNow());
                                },
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
                                onTap: () {
                                  setState(() {
                                    _isOwnerForm = false;
                                    _localError = null;
                                  });
                                  unawaited(_persistDraftNow());
                                },
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
                                color: AppTheme.ownerGold.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'REGISTER YOUR GYM',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.ownerGold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.ownerGold
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        'STEP ${_ownerStep + 1} OF 3',
                                        style: const TextStyle(
                                          color: AppTheme.ownerGold,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_resumedFromDraft) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.trainerCyan
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.trainerCyan
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.restore_rounded,
                                          color: AppTheme.trainerCyan,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 6),
                                        const Expanded(
                                          child: Text(
                                            'Resumed where you left off',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppTheme.trainerCyan,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: _resetDraft,
                                          child: const Text(
                                            'Reset',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                _HorizontalStepBar(
                                  currentStep: _ownerStep,
                                  titles: _stepTitles,
                                  onStepTap: (idx) {
                                    if (idx < _ownerStep) {
                                      _goToStep(idx);
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 240),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, anim) {
                                    final begin = Offset(
                                      _stepForward ? 0.12 : -0.12,
                                      0,
                                    );
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: begin,
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildOwnerStepContent(state, error),
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
                                color: AppTheme.trainerCyan
                                    .withValues(alpha: 0.3),
                              ),
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
                                      color: AppTheme.ownerGold
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.ownerGold
                                            .withValues(alpha: 0.4),
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
                                    onPressed: state.isOnboardingBusy
                                        ? null
                                        : _scanInviteQr,
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
                                const Text(
                                  'Or ask your Owner to add your phone — it will open automatically.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _HorizontalStepBar extends StatelessWidget {
  final int currentStep;
  final List<String> titles;
  final ValueChanged<int> onStepTap;

  const _HorizontalStepBar({
    required this.currentStep,
    required this.titles,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < titles.length; i++) ...[
              GestureDetector(
                onTap: i < currentStep ? () => onStepTap(i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentStep
                        ? AppTheme.ownerGold
                        : const Color(0xFF12151C),
                    border: Border.all(
                      color: i <= currentStep
                          ? AppTheme.ownerGold
                          : Colors.white24,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: i < currentStep
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.black,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == currentStep
                                  ? Colors.black
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
              if (i < titles.length - 1)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i < currentStep
                          ? AppTheme.ownerGold
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(titles.length, (i) {
            final isActive = i == currentStep;
            final isDone = i < currentStep;
            return Expanded(
              child: Text(
                titles[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: i == 0
                    ? TextAlign.left
                    : (i == titles.length - 1
                        ? TextAlign.right
                        : TextAlign.center),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive || isDone
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: isActive
                      ? AppTheme.ownerGold
                      : (isDone ? Colors.white70 : Colors.white38),
                ),
              ),
            );
          }),
        ),
      ],
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
          color:
              selected ? accent.withValues(alpha: 0.14) : const Color(0xFF1A1E29),
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
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _InputBox({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
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
