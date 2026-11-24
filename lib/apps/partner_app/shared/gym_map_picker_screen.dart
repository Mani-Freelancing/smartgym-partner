import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/gym_location_service.dart';

/// Centralized tile provider settings so tiles can be swapped (e.g. MapTiler,
/// Stadia, or a self-hosted CDN) in one place as the platform scales.
class GymMapTileConfig {
  static const String urlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static String get userAgentPackageName => AppConfig.packageId;
  static const String attributionLabel = '© OpenStreetMap contributors';
}

class GymMapSelection {
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const GymMapSelection({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

Future<GymMapSelection?> showGymMapPicker(
  BuildContext context, {
  double? initialLat,
  double? initialLng,
  String? initialSearchQuery,
  int initialRadiusMeters = 100,
}) {
  return Navigator.of(context).push<GymMapSelection>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GymMapPickerScreen(
        initialLat: initialLat,
        initialLng: initialLng,
        initialSearchQuery: initialSearchQuery,
        initialRadiusMeters: initialRadiusMeters,
      ),
    ),
  );
}

class GymMapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialSearchQuery;
  final int initialRadiusMeters;

  const GymMapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialSearchQuery,
    this.initialRadiusMeters = 100,
  });

  @override
  State<GymMapPickerScreen> createState() => _GymMapPickerScreenState();
}

class _GymMapPickerScreenState extends State<GymMapPickerScreen> {
  static const LatLng _defaultCenter = LatLng(17.4485, 78.3908);

  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  late LatLng _selectedCenter;
  late double _zoom;
  late int _radiusMeters;
  bool _mapReady = false;
  LatLng? _pendingMoveTarget;
  double? _pendingMoveZoom;

  bool _searching = false;
  bool _fetchingGps = false;
  String? _statusMessage;
  bool _statusIsError = false;
  List<GymPlaceSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    final hasInitial = widget.initialLat != null && widget.initialLng != null;
    _selectedCenter = hasInitial
        ? LatLng(widget.initialLat!, widget.initialLng!)
        : _defaultCenter;
    _zoom = hasInitial ? 17.5 : 13.5;
    _radiusMeters = widget.initialRadiusMeters;

    final seedQuery = widget.initialSearchQuery?.trim() ?? '';
    if (!hasInitial && seedQuery.isNotEmpty) {
      _searchCtrl.text = seedQuery;
      _autoCenterFromArea(seedQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _autoCenterFromArea(String query) async {
    final res = await GymLocationService.searchPlaces(query);
    if (!mounted || res.suggestions.isEmpty) return;
    final top = res.suggestions.first;
    _moveCamera(LatLng(top.latitude, top.longitude), zoom: 16.0);
    setState(() {
      _statusMessage = 'Centered near ${top.title} — drag map onto your gym';
      _statusIsError = false;
    });
  }

  void _moveCamera(LatLng target, {double? zoom}) {
    final nextZoom = (zoom ?? _zoom).clamp(4.0, 19.0);
    setState(() {
      _selectedCenter = target;
      _zoom = nextZoom;
    });
    if (_mapReady) {
      _mapController.move(target, nextZoom);
    } else {
      _pendingMoveTarget = target;
      _pendingMoveZoom = nextZoom;
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      setState(() {
        _suggestions = const [];
        _searching = false;
        if (_statusIsError) _statusMessage = null;
      });
      return;
    }
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 650), () {
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.length < 2) {
      setState(() {
        _suggestions = const [];
        _statusMessage = 'Type at least 2 characters to search a street or area.';
        _statusIsError = true;
      });
      return;
    }
    setState(() {
      _searching = true;
      _statusMessage = null;
    });
    final result = await GymLocationService.searchPlaces(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _suggestions = result.suggestions;
      if (result.hasError) {
        _statusMessage = result.error;
        _statusIsError = true;
      } else if (result.suggestions.isEmpty) {
        _statusMessage =
            'No places found for "$q". Try adding city name or drag the map.';
        _statusIsError = false;
      } else {
        _statusMessage = null;
      }
    });
  }

  void _selectSuggestion(GymPlaceSuggestion suggestion) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _searchCtrl.text = suggestion.title;
      _statusMessage = 'Adjust the pin right over your gym entrance';
      _statusIsError = false;
    });
    _moveCamera(
      LatLng(suggestion.latitude, suggestion.longitude),
      zoom: 17.5,
    );
  }

  Future<void> _centerOnCurrentGps() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _fetchingGps = true;
      _statusMessage = null;
      _suggestions = const [];
    });
    final res = await GymLocationService.captureCurrentCoordinates();
    if (!mounted) return;
    setState(() => _fetchingGps = false);
    if (res.isSuccess) {
      _moveCamera(LatLng(res.latitude!, res.longitude!), zoom: 18.0);
      setState(() {
        _statusMessage = 'Centered on your live GPS — fine-tune pin if needed';
        _statusIsError = false;
      });
      return;
    }
    setState(() {
      _statusMessage = res.error ?? 'Could not read GPS location.';
      _statusIsError = true;
    });
    if (res.openLocationSettings) {
      await Geolocator.openLocationSettings();
    } else if (res.openAppSettings) {
      await Geolocator.openAppSettings();
    }
  }

  void _confirmSelection() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      GymMapSelection(
        latitude: _selectedCenter.latitude,
        longitude: _selectedCenter.longitude,
        radiusMeters: _radiusMeters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedCenter,
              initialZoom: _zoom,
              minZoom: 4.0,
              maxZoom: 19.0,
              onMapReady: () {
                _mapReady = true;
                if (_pendingMoveTarget != null) {
                  _mapController.move(
                    _pendingMoveTarget!,
                    _pendingMoveZoom ?? _zoom,
                  );
                  _pendingMoveTarget = null;
                  _pendingMoveZoom = null;
                }
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _selectedCenter = camera.center;
                    _zoom = camera.zoom;
                  });
                }
              },
              onTap: (_, point) {
                HapticFeedback.selectionClick();
                _moveCamera(point, zoom: _zoom < 16.5 ? 17.5 : _zoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: GymMapTileConfig.urlTemplate,
                userAgentPackageName: GymMapTileConfig.userAgentPackageName,
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _selectedCenter,
                    radius: _radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: AppTheme.trainerCyan.withValues(alpha: 0.18),
                    borderColor: AppTheme.trainerCyan,
                    borderStrokeWidth: 2.2,
                  ),
                ],
              ),
            ],
          ),

          // Fixed Center Target Pin
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -18),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppTheme.ownerGold,
                        size: 46,
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.trainerCyan,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Search & Back Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Material(
                        color: const Color(0xFF141822).withValues(alpha: 0.94),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        child: IconButton(
                          tooltip: 'Close Map',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF141822).withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppTheme.ownerGold.withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            onSubmitted: _runSearch,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search area, street or landmark...',
                              hintStyle: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppTheme.ownerGold,
                                size: 20,
                              ),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(13),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.ownerGold,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_searchCtrl.text.isNotEmpty)
                                          IconButton(
                                            tooltip: 'Clear search',
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              color: Colors.white54,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              setState(() {
                                                _suggestions = const [];
                                                _statusMessage = null;
                                              });
                                            },
                                          ),
                                        IconButton(
                                          tooltip: 'Search',
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: AppTheme.ownerGold,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _runSearch(_searchCtrl.text),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141822).withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (ctx, idx) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.place_rounded,
                              color: AppTheme.trainerCyan,
                              size: 19,
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: item.subtitle.isEmpty
                                ? null
                                : Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11.5,
                                    ),
                                  ),
                            onTap: () => _selectSuggestion(item),
                          );
                        },
                      ),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (_statusIsError
                                ? const Color(0xFF2D161A)
                                : const Color(0xFF141822))
                            .withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _statusIsError
                              ? AppTheme.danger.withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color:
                              _statusIsError ? AppTheme.danger : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Right-Side Floating Zoom + GPS Controls & Attribution
          Positioned(
            right: 14,
            bottom: 228,
            child: Column(
              children: [
                _MapFloatingButton(
                  tooltip: 'Zoom in',
                  icon: Icons.add_rounded,
                  onTap: () => _moveCamera(
                    _selectedCenter,
                    zoom: (_zoom + 1.0).clamp(4.0, 19.0),
                  ),
                ),
                const SizedBox(height: 8),
                _MapFloatingButton(
                  tooltip: 'Zoom out',
                  icon: Icons.remove_rounded,
                  onTap: () => _moveCamera(
                    _selectedCenter,
                    zoom: (_zoom - 1.0).clamp(4.0, 19.0),
                  ),
                ),
                const SizedBox(height: 10),
                _MapFloatingButton(
                  tooltip: 'Use Current GPS',
                  icon: Icons.my_location_rounded,
                  iconColor: AppTheme.trainerCyan,
                  loading: _fetchingGps,
                  onTap: _fetchingGps ? null : _centerOnCurrentGps,
                ),
              ],
            ),
          ),

          Positioned(
            left: 14,
            bottom: 224,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                GymMapTileConfig.attributionLabel,
                style: TextStyle(color: Colors.white70, fontSize: 9.5),
              ),
            ),
          ),

          // Bottom Dark Confirmation Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF141822),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.radar_rounded,
                        color: AppTheme.trainerCyan,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pin: ${_selectedCenter.latitude.toStringAsFixed(5)}, '
                          '${_selectedCenter.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${_radiusMeters}m lock zone',
                        style: const TextStyle(
                          color: AppTheme.trainerCyan,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Drag the map or tap a building so the cyan circle covers your gym floor.',
                    style: TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  const SizedBox(height: 12),
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
                            borderRadius: BorderRadius.circular(11),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _radiusMeters = r);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.trainerCyan
                                        .withValues(alpha: 0.18)
                                    : const Color(0xFF1A1E29),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: sel
                                      ? AppTheme.trainerCyan
                                      : Colors.white12,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${r}m • $label',
                                  style: TextStyle(
                                    color: sel
                                        ? AppTheme.trainerCyan
                                        : Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
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
                      onPressed: _confirmSelection,
                      icon: const Icon(Icons.check_circle_rounded, size: 19),
                      label: const Text(
                        'CONFIRM GYM LOCATION',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final bool loading;
  final VoidCallback? onTap;

  const _MapFloatingButton({
    required this.tooltip,
    required this.icon,
    this.iconColor = Colors.white,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF141822).withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}
