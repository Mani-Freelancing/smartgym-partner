import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register_ai_importer_service.dart';

class HeroPoseOption {
  final String id;
  final String title;
  final String subtitle;
  final String assetPath;
  final Color accentColor;

  const HeroPoseOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.accentColor,
  });
}

class CustomAvatarResult {
  final String filePath;
  final bool generatedWithAi;
  final String message;

  const CustomAvatarResult({
    required this.filePath,
    required this.generatedWithAi,
    required this.message,
  });
}

class HeroAvatarService {
  static const String _prefKey = 'customer_primary_hero_pose_v1';
  static const String _customPathKey = 'customer_custom_hero_file_v1';

  static const List<HeroPoseOption> poses = [
    HeroPoseOption(
      id: 'bicep_curl',
      title: 'Biceps',
      subtitle: 'Dumbbell Curl • Last Rep',
      assetPath: 'assets/images/poses/pose_bicep_curl.png',
      accentColor: Color(0xFFFF7A2F),
    ),
    HeroPoseOption(
      id: 'chest_squeeze',
      title: 'Chest',
      subtitle: 'Dumbbell Chest Squeeze',
      assetPath: 'assets/images/poses/pose_chest.png',
      accentColor: Color(0xFFE5C158),
    ),
    HeroPoseOption(
      id: 'shoulder_press',
      title: 'Shoulders',
      subtitle: 'Overhead Dumbbell Press',
      assetPath: 'assets/images/poses/pose_shoulder.png',
      accentColor: Color(0xFF38BDF8),
    ),
    HeroPoseOption(
      id: 'triceps_pushdown',
      title: 'Triceps',
      subtitle: 'Cable Rope Pushdown',
      assetPath: 'assets/images/poses/pose_triceps.png',
      accentColor: Color(0xFF22C55E),
    ),
    HeroPoseOption(
      id: 'squat_rack',
      title: 'Squats & Legs',
      subtitle: 'Barbell Back Squat',
      assetPath: 'assets/images/poses/pose_squat_rack.png',
      accentColor: Color(0xFFFF5A1F),
    ),
    HeroPoseOption(
      id: 'deadlift',
      title: 'Back Deadlift',
      subtitle: 'Heavy Olympic Barbell',
      assetPath: 'assets/images/poses/pose_deadlift.png',
      accentColor: Color(0xFFF59E0B),
    ),
    HeroPoseOption(
      id: 'lat_pulldown',
      title: 'Lats Pulldown',
      subtitle: 'Wide-Grip Overhead Pull',
      assetPath: 'assets/images/poses/pose_lats.png',
      accentColor: Color(0xFF06B6D4),
    ),
    HeroPoseOption(
      id: 'abs_core',
      title: 'Abs & Core',
      subtitle: '20kg Weighted Plate Hold',
      assetPath: 'assets/images/poses/pose_abs.png',
      accentColor: Color(0xFFEC4899),
    ),
    HeroPoseOption(
      id: 'cable_fly',
      title: 'Upper Chest',
      subtitle: 'Cable Crossover Fly',
      assetPath: 'assets/images/poses/pose_cable_fly.png',
      accentColor: Color(0xFFA855F7),
    ),
    HeroPoseOption(
      id: 'lateral_raise',
      title: 'Side Delts',
      subtitle: 'Dumbbell Lateral Raise',
      assetPath: 'assets/images/poses/pose_lateral_raise.png',
      accentColor: Color(0xFF14B8A6),
    ),
    HeroPoseOption(
      id: 'overhead_triceps',
      title: 'Tricep Stretch',
      subtitle: 'Overhead Dumbbell Ext.',
      assetPath: 'assets/images/poses/pose_overhead_triceps.png',
      accentColor: Color(0xFFF97316),
    ),
  ];

  static final ValueNotifier<HeroPoseOption> selectedPose =
      ValueNotifier<HeroPoseOption>(poses.first);

  /// When non-null and the file exists, this customer-uploaded / AI-generated
  /// avatar is used as the Primary Hero on both Splash and Club Pass.
  static final ValueNotifier<String?> customAvatarPath =
      ValueNotifier<String?>(null);

  static Future<void> loadSavedPose() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      if (savedId != null) {
        final match = poses.where((p) => p.id == savedId);
        if (match.isNotEmpty) {
          selectedPose.value = match.first;
        }
      }
      final savedCustom = prefs.getString(_customPathKey);
      if (savedCustom != null &&
          savedCustom.isNotEmpty &&
          await File(savedCustom).exists()) {
        customAvatarPath.value = savedCustom;
      }
    } catch (_) {}
  }

  static Future<void> setPrimaryPose(HeroPoseOption pose) async {
    selectedPose.value = pose;
    customAvatarPath.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, pose.id);
      await prefs.remove(_customPathKey);
    } catch (_) {}
  }

  static Future<void> _saveCustomPath(String path) async {
    customAvatarPath.value = path;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_customPathKey, path);
    } catch (_) {}
  }

  /// Converts a customer's uploaded selfie/photo into a matching 2D cel-shaded
  /// anime workout avatar using the selected workout pose as style/pose reference.
  static Future<CustomAvatarResult> setCustomPhotoAvatar({
    required Uint8List photoBytes,
    required String mimeType,
    required HeroPoseOption pose,
  }) async {
    final keys = await RegisterAiImporterService().getEffectiveApiKeys();
    if (keys.isEmpty) {
      throw Exception(
        'AI key not configured yet. Add your free Gemini API key in Firebase Console -> app_config/ai (field: geminiApiKeys).',
      );
    }

    // Load the selected built-in workout pose image so Gemini matches the exact
    // anime style, lighting, and exercise pose while converting the customer's face & body.
    final poseByteData = await rootBundle.load(pose.assetPath);
    final poseBytes = poseByteData.buffer.asUint8List();

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    Object? lastError;

    const models = [
      'gemini-2.5-flash-image',
      'gemini-2.0-flash-exp-image-generation',
    ];

    for (final key in keys) {
      for (final model in models) {
        try {
          final generated = await _generateAnimeAvatarWithGemini(
            photoBytes: photoBytes,
            mimeType: mimeType,
            poseBytes: poseBytes,
            poseLabel: pose.title,
            apiKey: key,
            model: model,
          );
          if (generated != null && generated.isNotEmpty) {
            final file = File('${dir.path}/custom_hero_ai_$ts.png');
            await file.writeAsBytes(generated, flush: true);
            await _saveCustomPath(file.path);
            return CustomAvatarResult(
              filePath: file.path,
              generatedWithAi: true,
              message: 'Your ${pose.title} Anime Avatar is ready!',
            );
          }
        } catch (e) {
          lastError = e;
        }
      }
    }

    throw Exception(
      'Could not convert photo to anime avatar: ${lastError ?? "Unknown AI error"}',
    );
  }

  static Future<Uint8List?> _generateAnimeAvatarWithGemini({
    required Uint8List photoBytes,
    required String mimeType,
    required Uint8List poseBytes,
    required String poseLabel,
    required String apiKey,
    required String model,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final prompt = '''
Image 1 is a real photo of a gym member. Image 2 is the target 2D cel-shaded anime workout style and "$poseLabel" exercise pose.
Create a NEW 2D cel-shaded anime gym avatar illustration that:
1. Replaces the person in Image 2 with the EXACT face, hairstyle, skin tone, facial hair (if any), and natural body build/visibility of the person in Image 1.
2. Keeps the exact "$poseLabel" workout exercise pose, dark charcoal gym tank top, crisp 2D cel-shaded anime ink style, and subtle warm orange-gold rim lighting from Image 2, with a realistic focused "last rep" expression.
3. Uses a 100% pure solid flat #000000 black background with zero text, zero borders, and zero watermarks.
''';

    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(photoBytes),
              },
            },
            {
              'inline_data': {
                'mime_type': 'image/png',
                'data': base64Encode(poseBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE', 'TEXT'],
      },
    });

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.add(utf8.encode(payload));
      final res = await req.close().timeout(const Duration(seconds: 60));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = 'HTTP ${res.statusCode}';
        try {
          final err = jsonDecode(body) as Map<String, dynamic>;
          msg = err['error']?['message']?.toString() ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts = candidates.first['content']?['parts'] as List<dynamic>?;
      if (parts == null) return null;
      for (final p in parts) {
        if (p is Map<String, dynamic>) {
          final inline = p['inlineData'] ?? p['inline_data'];
          if (inline is Map<String, dynamic> && inline['data'] is String) {
            return base64Decode(inline['data'] as String);
          }
        }
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// Renders whichever avatar is currently Primary (customer custom photo/AI
/// avatar OR selected built-in transparent workout pose), with seamless edge
/// feathering for custom photos so there is never a harsh box border.
class HeroAvatarImage extends StatelessWidget {
  final double width;
  final double height;

  const HeroAvatarImage({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: HeroAvatarService.customAvatarPath,
      builder: (context, customPath, _) {
        if (customPath != null &&
            customPath.isNotEmpty &&
            File(customPath).existsSync()) {
          return ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.12, 0.84, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.14, 0.86, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Image.file(
                File(customPath),
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
          );
        }

        return ValueListenableBuilder<HeroPoseOption>(
          valueListenable: HeroAvatarService.selectedPose,
          builder: (context, pose, _) => Image.asset(
            pose.assetPath,
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
