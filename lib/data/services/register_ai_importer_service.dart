import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImportedRegisterRow {
  String name;
  String phone;
  String planTitle;
  int feePaid;
  int daysLeft;
  bool selected;

  ImportedRegisterRow({
    required this.name,
    required this.phone,
    required this.planTitle,
    required this.feePaid,
    required this.daysLeft,
    this.selected = true,
  });
}

class RegisterAiImporterService {
  static const String _apiKeyPref = 'smartgym_gemini_api_key';

  /// Optional developer key supplied at build time:
  /// flutter build apk --dart-define=GEMINI_API_KEY=your_key
  static const String _builtInGeminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );

  Future<String> getEffectiveApiKey() async {
    final keys = await getEffectiveApiKeys();
    return keys.isEmpty ? '' : keys.first;
  }

  /// Collects Gemini API keys in priority order:
  /// 1. `--dart-define=GEMINI_API_KEY=...`
  /// 2. Local developer override in SharedPreferences
  /// 3. Firestore `app_config/ai` (`geminiApiKeys` list and/or `geminiApiKey`)
  Future<List<String>> getEffectiveApiKeys() async {
    final keys = <String>[];
    if (_builtInGeminiKey.trim().isNotEmpty) {
      keys.add(_builtInGeminiKey.trim());
    }
    final prefs = await SharedPreferences.getInstance();
    final localKey = prefs.getString(_apiKeyPref)?.trim() ?? '';
    if (localKey.isNotEmpty && !keys.contains(localKey)) {
      keys.add(localKey);
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('ai')
          .get();
      final data = doc.data();
      if (data != null) {
        final list = data['geminiApiKeys'];
        if (list is List) {
          for (final item in list) {
            final k = item?.toString().trim() ?? '';
            if (k.isNotEmpty && !keys.contains(k)) {
              keys.add(k);
            }
          }
        }
        final single = data['geminiApiKey']?.toString().trim() ?? '';
        if (single.isNotEmpty && !keys.contains(single)) {
          keys.add(single);
        }
      }
    } catch (_) {
      // Firestore offline or app_config/ai not created yet; fall back cleanly.
    }
    return keys;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  /// Seamless entry point for gym owners:
  /// - Tries each configured Gemini API key in order (auto-rotating if one
  ///   expires or hits quota).
  /// - Falls back to free on-device ML Kit OCR if no keys are configured/valid.
  Future<List<ImportedRegisterRow>> extractFromImageFile({
    required String imagePath,
    required Uint8List imageBytes,
    required String mimeType,
    required int defaultFee,
  }) async {
    final keys = await getEffectiveApiKeys();
    Object? lastError;
    for (final key in keys) {
      try {
        return await extractFromRegisterImage(
          imageBytes: imageBytes,
          mimeType: mimeType,
          apiKey: key,
          defaultFee: defaultFee,
        );
      } catch (e) {
        lastError = e;
      }
    }
    try {
      return await extractOnDeviceFromPath(
        imagePath: imagePath,
        defaultFee: defaultFee,
      );
    } catch (_) {
      if (lastError != null) {
        throw lastError;
      }
      rethrow;
    }
  }

  /// 100% free on-device OCR using Google ML Kit (no API key or internet needed).
  /// Groups horizontally aligned text lines into table rows before parsing.
  Future<List<ImportedRegisterRow>> extractOnDeviceFromPath({
    required String imagePath,
    required int defaultFee,
  }) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(inputImage);
      final allLines = <TextLine>[];
      for (final block in recognized.blocks) {
        allLines.addAll(block.lines);
      }
      if (allLines.isEmpty) return [];

      // Sort top-to-bottom, then left-to-right so tabular columns merge cleanly.
      allLines.sort((a, b) {
        final dy = a.boundingBox.top - b.boundingBox.top;
        if (dy.abs() > 18) return dy.compareTo(0);
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      });

      final mergedRows = <List<TextLine>>[];
      for (final line in allLines) {
        if (mergedRows.isEmpty) {
          mergedRows.add([line]);
          continue;
        }
        final currentRow = mergedRows.last;
        final avgTop =
            currentRow
                .map((l) => l.boundingBox.top)
                .reduce((a, b) => a + b) /
            currentRow.length;
        if ((line.boundingBox.top - avgTop).abs() <= 22) {
          currentRow.add(line);
        } else {
          mergedRows.add([line]);
        }
      }

      final buffer = StringBuffer();
      for (final row in mergedRows) {
        row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        buffer.writeln(row.map((l) => l.text.trim()).join(', '));
      }

      return parseFromText(
        rawText: buffer.toString(),
        defaultFee: defaultFee,
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Calls Gemini 2.5 Flash Vision API to extract member rows from a
  /// handwritten or printed gym register photo.
  Future<List<ImportedRegisterRow>> extractFromRegisterImage({
    required Uint8List imageBytes,
    required String mimeType,
    required String apiKey,
    required int defaultFee,
  }) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      throw Exception('Gemini API key is empty.');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$cleanKey',
    );

    final prompt = '''
You are reading a photo of a gym membership register (handwritten or printed).
Step 1: First read the column headers / categories at the top of the page (for example: Sl.No, Name, Phone/Mobile, Plan/Months, Fee/Amount, Join Date, Expiry Date).
Step 2: Map each row's values strictly according to those column categories.
Return ONLY a JSON array of objects with these exact keys:
- "name": string (member full name)
- "phone": string (10-digit mobile number if visible, digits only, or empty string if unreadable)
- "planTitle": string (e.g. "Monthly", "3 Months", "6 Months", "Annual", or "PT Plan")
- "feePaid": integer (amount in INR, default $defaultFee if missing)
- "daysLeft": integer (remaining days from today, default 30 if missing; estimate from expiry date if shown)

Ignore header rows, totals, or completely blank lines.
''';

    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.1,
      },
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(payload));

      final response =
          await request.close().timeout(const Duration(seconds: 45));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Gemini API error (${response.statusCode})';
        try {
          final errJson = jsonDecode(body) as Map<String, dynamic>;
          final errMsg = errJson['error']?['message'] as String?;
          if (errMsg != null && errMsg.isNotEmpty) {
            message = errMsg;
          }
        } catch (_) {}
        throw Exception(message);
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No readable data returned from image.');
      }
      final text =
          candidates.first['content']?['parts']?[0]?['text'] as String? ?? '[]';

      final cleanedText = _stripMarkdownJsonFence(text);
      final list = jsonDecode(cleanedText) as List<dynamic>;

      final rows = <ImportedRegisterRow>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final rawPhone = (item['phone'] ?? '').toString();
        final phone = _normalizeIndianPhone(rawPhone);
        final planTitle = (item['planTitle'] ?? 'Monthly').toString().trim();
        final feePaid =
            int.tryParse('${item['feePaid'] ?? defaultFee}') ?? defaultFee;
        final daysLeft =
            (int.tryParse('${item['daysLeft'] ?? 30}') ?? 30).clamp(-365, 1095);

        rows.add(
          ImportedRegisterRow(
            name: name,
            phone: phone,
            planTitle: planTitle.isEmpty ? 'Monthly' : planTitle,
            feePaid: feePaid < 0 ? defaultFee : feePaid,
            daysLeft: daysLeft,
          ),
        );
      }
      return rows;
    } finally {
      client.close(force: true);
    }
  }

  /// Offline parser for pasted Excel / CSV / WhatsApp register lines & OCR rows.
  List<ImportedRegisterRow> parseFromText({
    required String rawText,
    required int defaultFee,
  }) {
    final rows = <ImportedRegisterRow>[];
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('name') && lower.contains('phone')) continue;

      final parts = line.contains('\t')
          ? line.split('\t').map((e) => e.trim()).toList()
          : line.split(',').map((e) => e.trim()).toList();

      if (parts.isEmpty) continue;

      String name = parts[0];
      String phone = '';
      String planTitle = 'Monthly';
      int feePaid = defaultFee;
      int daysLeft = 30;

      if (parts.length == 1) {
        final phoneMatch =
            RegExp(r'(?:\+91[\s-]?)?[6-9]\d{9}').firstMatch(line);
        if (phoneMatch != null) {
          phone = _normalizeIndianPhone(phoneMatch.group(0)!);
          name = line
              .replaceFirst(phoneMatch.group(0)!, '')
              .replaceAll(RegExp(r'[-|]+'), ' ')
              .trim();
        }
      } else {
        for (int i = 1; i < parts.length; i++) {
          final token = parts[i];
          if (token.isEmpty) continue;
          final digits = token.replaceAll(RegExp(r'\D'), '');
          if (phone.isEmpty && digits.length >= 10) {
            phone = _normalizeIndianPhone(digits);
            continue;
          }
          final numVal = int.tryParse(digits);
          if (numVal != null &&
              digits == token.replaceAll(RegExp(r'[₹,\s]'), '')) {
            if (numVal >= 200 && feePaid == defaultFee) {
              feePaid = numVal;
            } else if (numVal > -365 && numVal <= 730) {
              daysLeft = numVal;
            }
            continue;
          }
          if (planTitle == 'Monthly') {
            planTitle = token;
          }
        }
      }

      if (name.isEmpty) continue;
      rows.add(
        ImportedRegisterRow(
          name: name,
          phone: phone,
          planTitle: planTitle,
          feePaid: feePaid,
          daysLeft: daysLeft,
        ),
      );
    }
    return rows;
  }

  String _stripMarkdownJsonFence(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      s = s.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return s.trim();
  }

  String _normalizeIndianPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final last10 = digits.substring(digits.length - 10);
      return '+91$last10';
    }
    return digits;
  }
}
