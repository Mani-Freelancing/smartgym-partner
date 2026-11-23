import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class GymPlaceSuggestion {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  const GymPlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  String get displayLabel => subtitle.isEmpty ? title : '$title, $subtitle';
}

class GymPlaceSearchResult {
  final List<GymPlaceSuggestion> suggestions;
  final String? error;

  const GymPlaceSearchResult({
    this.suggestions = const [],
    this.error,
  });

  bool get hasError => error != null && error!.isNotEmpty;
}

class GymLocationCapture {
  final double? latitude;
  final double? longitude;
  final String? error;
  final bool openLocationSettings;
  final bool openAppSettings;

  const GymLocationCapture({
    this.latitude,
    this.longitude,
    this.error,
    this.openLocationSettings = false,
    this.openAppSettings = false,
  });

  bool get isSuccess => latitude != null && longitude != null && error == null;
}

class GymProximityResult {
  final bool allowed;
  final double? distanceMeters;
  final bool isMocked;
  final bool openLocationSettings;
  final bool openAppSettings;
  final String message;

  const GymProximityResult({
    required this.allowed,
    this.distanceMeters,
    this.isMocked = false,
    this.openLocationSettings = false,
    this.openAppSettings = false,
    this.message = '',
  });
}

/// Centralized GPS geofence & anti-mock verification for gym check-ins.
class GymLocationService {
  static bool isValidCoordinates(double lat, double lng) {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    if (lat == 0 && lng == 0) return false;
    return true;
  }

  /// Parses coordinate text such as "17.44852, 78.39081", "17.4485 78.3908",
  /// or Google Maps URLs containing "!3dLAT!4dLNG", "@lat,lng", or "q=lat,lng".
  static ({double latitude, double longitude})? parseCoordinatePair(
    String raw, {
    bool allowBarePair = true,
  }) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final pinData = RegExp(
      r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)',
    ).firstMatch(text);
    final urlSpecific = RegExp(
      r'(?:@|[?&](?:q|ll|query|center)=)(-?\d+\.\d+)(?:,|%2C)\s*(-?\d+\.\d+)',
      caseSensitive: false,
    ).firstMatch(text);
    final match = pinData ??
        urlSpecific ??
        (allowBarePair
            ? RegExp(
                r'(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)',
              ).firstMatch(text)
            : null);
    if (match == null) return null;

    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null || !isValidCoordinates(lat, lng)) {
      return null;
    }
    return (latitude: lat, longitude: lng);
  }

  /// Resolves either plain coordinates OR a shared Google Maps URL
  /// (including short links like https://maps.app.goo.gl/...).
  static Future<GymLocationCapture> resolveCoordinatesFromInput(
    String raw,
  ) async {
    final direct = parseCoordinatePair(raw);
    if (direct != null) {
      return GymLocationCapture(
        latitude: direct.latitude,
        longitude: direct.longitude,
      );
    }

    final urlMatch = RegExp(r'https?://\S+').firstMatch(raw);
    if (urlMatch == null) {
      return const GymLocationCapture(
        error:
            'Could not read Lat & Lng. Share your gym link from Google Maps or type numbers like 17.44852, 78.39081.',
      );
    }
    if (kIsWeb) {
      return const GymLocationCapture(
        error: 'Short link resolution is only supported on mobile devices.',
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      var currentUri = Uri.parse(urlMatch.group(0)!);
      for (var hop = 0; hop < 6; hop++) {
        final request = await client.getUrl(currentUri).timeout(
              const Duration(seconds: 6),
            );
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (compatible; SmartGymPartner/1.0)',
        );
        final response = await request.close().timeout(
              const Duration(seconds: 6),
            );
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location != null && location.isNotEmpty) {
          final nextUri = currentUri.resolve(location);
          final resolved = parseCoordinatePair(nextUri.toString());
          if (resolved != null) {
            await response.drain<void>();
            return GymLocationCapture(
              latitude: resolved.latitude,
              longitude: resolved.longitude,
            );
          }
          await response.drain<void>();
          currentUri = nextUri;
          continue;
        }

        final body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 6));
        final fromUrl = parseCoordinatePair(currentUri.toString());
        if (fromUrl != null) {
          return GymLocationCapture(
            latitude: fromUrl.latitude,
            longitude: fromUrl.longitude,
          );
        }
        final fromBody = parseCoordinatePair(body, allowBarePair: false);
        if (fromBody != null) {
          return GymLocationCapture(
            latitude: fromBody.latitude,
            longitude: fromBody.longitude,
          );
        }
        break;
      }
      return const GymLocationCapture(
        error:
            'No coordinates found in that Maps link. Try dropping a pin on Google Maps or using Current Location.',
      );
    } on TimeoutException {
      return const GymLocationCapture(
        error: 'Timed out reading Maps link. Check internet and try again.',
      );
    } on SocketException {
      return const GymLocationCapture(
        error: 'Turn on internet to resolve a shared Google Maps link.',
      );
    } catch (e) {
      return GymLocationCapture(
        error: 'Could not read that Maps link ($e).',
      );
    } finally {
      client.close(force: true);
    }
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  static Future<Position> _fetchFreshPosition({
    Duration maxCachedAge = const Duration(minutes: 3),
    bool allowAnyCachedFallback = false,
  }) async {
    Object? lastErr;
    // 1. High-accuracy GPS/Fused fix
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } on MissingPluginException {
      rethrow;
    } on LocationServiceDisabledException {
      rethrow;
    } on PermissionDeniedException {
      rethrow;
    } catch (e) {
      lastErr = e;
    }

    // 2. Balanced accuracy (Wi-Fi/cell triangulation indoors)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      lastErr = e;
    }

    // 3. Low accuracy coarse Wi-Fi/cell fix
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      lastErr = e;
    }

    // 4. Android LocationManager fallback (devices without GMS or slow fused)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.low,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 4),
          ),
        );
      } catch (e) {
        lastErr = e;
      }
    }

    // 5. OS cached fix (fresh for check-in; any non-mocked for Owner pin)
    final last = await Geolocator.getLastKnownPosition();
    if (last != null &&
        (allowAnyCachedFallback ||
            DateTime.now().difference(last.timestamp) <= maxCachedAge)) {
      return last;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final legacyLast = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: true,
      );
      if (legacyLast != null &&
          (allowAnyCachedFallback ||
              DateTime.now().difference(legacyLast.timestamp) <=
                  maxCachedAge)) {
        return legacyLast;
      }
    }

    throw lastErr;
  }

  /// Owner calls this inside the gym to save its exact latitude & longitude.
  static Future<GymLocationCapture> captureCurrentCoordinates() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return const GymLocationCapture(
          error: 'Please turn on device GPS / Location Services first.',
          openLocationSettings: true,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const GymLocationCapture(
          error: 'Location permission is needed to pin your gym coordinates.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const GymLocationCapture(
          error:
              'Location permission is permanently denied. Enable it in App Settings.',
          openAppSettings: true,
        );
      }

      final pos = await _fetchFreshPosition(
        allowAnyCachedFallback: true,
      );
      if (pos.isMocked) {
        return const GymLocationCapture(
          error:
              'Mock / Fake GPS location detected. Disable mock location apps first.',
        );
      }
      return GymLocationCapture(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } on MissingPluginException {
      return const GymLocationCapture(
        error:
            'GPS plugin needs a fresh app install. Stop and re-run with flutter run.',
      );
    } on LocationServiceDisabledException {
      return const GymLocationCapture(
        error: 'Turn on device GPS / Location Services first.',
        openLocationSettings: true,
      );
    } on PermissionDeniedException {
      return const GymLocationCapture(
        error: 'Location permission denied. Allow Location access in Settings.',
        openAppSettings: true,
      );
    } on TimeoutException {
      return const GymLocationCapture(
        error:
            'No GPS lock right now. Turn on Wi-Fi/Mobile Data & Location Accuracy, or try near an entrance.',
      );
    } catch (e) {
      return GymLocationCapture(
        error: 'GPS read failed ($e). Turn on internet & GPS and try again.',
      );
    }
  }

  /// Customer calls this right before opening the Reception QR scanner.
  static Future<GymProximityResult> verifyInsideGym({
    required double gymLat,
    required double gymLng,
    required int radiusMeters,
    required String gymName,
  }) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return const GymProximityResult(
          allowed: false,
          openLocationSettings: true,
          message:
              'Turn on device Location (GPS) to prove you are inside the gym.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const GymProximityResult(
          allowed: false,
          message:
              'Location permission is required to verify you are inside the gym.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const GymProximityResult(
          allowed: false,
          openAppSettings: true,
          message:
              'Location permission is blocked. Allow it in Settings to check in.',
        );
      }

      final pos = await _fetchFreshPosition(
        maxCachedAge: const Duration(minutes: 3),
      );
      if (pos.isMocked) {
        return const GymProximityResult(
          allowed: false,
          isMocked: true,
          message:
              'Fake GPS / Mock Location detected! Turn off location spoofing to check in.',
        );
      }

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        gymLat,
        gymLng,
      );
      if (distance > radiusMeters) {
        return GymProximityResult(
          allowed: false,
          distanceMeters: distance,
          message:
              'You are ${formatDistance(distance)} away from $gymName. Check in only inside the gym (${radiusMeters}m range).',
        );
      }

      return GymProximityResult(
        allowed: true,
        distanceMeters: distance,
      );
    } on MissingPluginException {
      return const GymProximityResult(
        allowed: false,
        message:
            'GPS plugin needs a fresh app build. Please restart with flutter run.',
      );
    } on LocationServiceDisabledException {
      return const GymProximityResult(
        allowed: false,
        openLocationSettings: true,
        message:
            'Turn on device Location (GPS) to prove you are inside the gym.',
      );
    } on PermissionDeniedException {
      return const GymProximityResult(
        allowed: false,
        openAppSettings: true,
        message:
            'Location permission is required. Allow it in App Settings.',
      );
    } on TimeoutException {
      return const GymProximityResult(
        allowed: false,
        message:
            'GPS timed out indoors. Turn on Wi-Fi / Google Location Accuracy and retry.',
      );
    } catch (e) {
      return GymProximityResult(
        allowed: false,
        message: 'Unable to verify GPS location ($e).',
      );
    }
  }

  /// Non-intrusive check for displaying an "Inside Gym vs Away" indicator
  /// ONLY when location permission is already granted and GPS is on.
  static Future<GymProximityResult?> checkPassiveProximityIfPermitted({
    required double gymLat,
    required double gymLng,
    required int radiusMeters,
  }) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      final Position pos;
      if (last != null &&
          DateTime.now().difference(last.timestamp) <=
              const Duration(minutes: 2)) {
        pos = last;
      } else {
        pos = await _fetchFreshPosition(
          maxCachedAge: const Duration(minutes: 10),
        );
      }
      if (pos.isMocked) {
        return const GymProximityResult(
          allowed: false,
          isMocked: true,
          message: 'Mock location detected',
        );
      }
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        gymLat,
        gymLng,
      );
      return GymProximityResult(
        allowed: distance <= radiusMeters,
        distanceMeters: distance,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses Photon GeoJSON feature collection into place suggestions.
  @visibleForTesting
  static List<GymPlaceSuggestion> parsePhotonResponse(
    Map<String, dynamic> decoded,
  ) {
    final features = decoded['features'];
    if (features is! List) return const [];
    final results = <GymPlaceSuggestion>[];
    for (final raw in features) {
      if (raw is! Map) continue;
      final geom = raw['geometry'];
      final props = raw['properties'];
      if (geom is! Map || props is! Map) continue;
      final coords = geom['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final parts = <String>[
        for (final key in ['name', 'street', 'district', 'locality', 'city', 'state', 'country'])
          if (props[key] is String && (props[key] as String).trim().isNotEmpty)
            (props[key] as String).trim(),
      ];
      final unique = <String>[];
      for (final p in parts) {
        if (!unique.any((e) => e.toLowerCase() == p.toLowerCase())) {
          unique.add(p);
        }
      }
      if (unique.isEmpty) continue;
      results.add(
        GymPlaceSuggestion(
          title: unique.first,
          subtitle: unique.skip(1).take(3).join(', '),
          latitude: lat,
          longitude: lng,
        ),
      );
    }
    return results;
  }

  /// Parses OpenStreetMap Nominatim search array into place suggestions.
  @visibleForTesting
  static List<GymPlaceSuggestion> parseNominatimResponse(List<dynamic> decoded) {
    final results = <GymPlaceSuggestion>[];
    for (final raw in decoded) {
      if (raw is! Map) continue;
      final lat = double.tryParse('${raw['lat'] ?? ''}');
      final lng = double.tryParse('${raw['lon'] ?? ''}');
      if (lat == null || lng == null) continue;
      final display = (raw['display_name'] ?? '').toString().trim();
      final parts = display
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final explicitName = (raw['name'] ?? '').toString().trim();
      final title = explicitName.isNotEmpty
          ? explicitName
          : (parts.isNotEmpty ? parts.first : '$lat, $lng');
      final subtitleParts = parts
          .where((p) => p.toLowerCase() != title.toLowerCase())
          .take(3)
          .toList();
      results.add(
        GymPlaceSuggestion(
          title: title,
          subtitle: subtitleParts.join(', '),
          latitude: lat,
          longitude: lng,
        ),
      );
    }
    return results;
  }

  static Future<dynamic> _getJson(Uri uri) async {
    if (kIsWeb) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client.getUrl(uri).timeout(
            const Duration(seconds: 6),
          );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'SmartGymPartner/1.0 (com.smartgym.partner)',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
            const Duration(seconds: 6),
          );
      if (response.statusCode != 200) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
      return jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }

  /// Searches free OpenStreetMap / Photon place data (no API key needed).
  static Future<GymPlaceSearchResult> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return const GymPlaceSearchResult();

    try {
      final photonUri = Uri.https('photon.komoot.io', '/api/', {
        'q': q,
        'limit': '6',
        'lang': 'en',
      });
      final photonJson = await _getJson(photonUri);
      if (photonJson is Map<String, dynamic>) {
        final hits = parsePhotonResponse(photonJson);
        if (hits.isNotEmpty) {
          return GymPlaceSearchResult(suggestions: hits);
        }
      }
    } on TimeoutException {
      return const GymPlaceSearchResult(
        error: 'Search timed out — check internet or pan the map directly.',
      );
    } on SocketException {
      return const GymPlaceSearchResult(
        error: 'No internet connection — pan the map or use GPS.',
      );
    } catch (_) {
      // Fall through to Nominatim backup
    }

    try {
      final nominatimUri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '6',
      });
      final nominatimJson = await _getJson(nominatimUri);
      if (nominatimJson is List<dynamic>) {
        return GymPlaceSearchResult(
          suggestions: parseNominatimResponse(nominatimJson),
        );
      }
      return const GymPlaceSearchResult();
    } on TimeoutException {
      return const GymPlaceSearchResult(
        error: 'Search timed out — pan the map directly.',
      );
    } on SocketException {
      return const GymPlaceSearchResult(
        error: 'No internet connection — pan the map or use GPS.',
      );
    } catch (e) {
      return GymPlaceSearchResult(
        error: 'Could not search location ($e). Pan the map instead.',
      );
    }
  }
}
