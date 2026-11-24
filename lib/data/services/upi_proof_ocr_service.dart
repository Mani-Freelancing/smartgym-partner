import 'dart:math' as math;
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/models/gym_member.dart';

enum UpiProofSeverity { verified, warning, blocked, neutral }

class UpiProofExtraction {
  final String utr;
  final int? amountInr;
  final bool isStatusFailedOrPending;
  final String rawText;

  const UpiProofExtraction({
    this.utr = '',
    this.amountInr,
    this.isStatusFailedOrPending = false,
    this.rawText = '',
  });

  bool get hasData =>
      utr.isNotEmpty || amountInr != null || isStatusFailedOrPending;
}

class UpiProofAuditResult {
  final UpiProofSeverity severity;
  final String headline;
  final String detail;
  final String? duplicateMemberName;

  const UpiProofAuditResult({
    required this.severity,
    required this.headline,
    required this.detail,
    this.duplicateMemberName,
  });

  bool get isBlocked => severity == UpiProofSeverity.blocked;
}

/// Zero-cost on-device ML Kit OCR scanner and parser for Indian UPI payment
/// screenshots (PhonePe, GPay, Paytm, BHIM, bank UPI apps).
class UpiProofOcrService {
  static final _statusAlertPattern = RegExp(
    r'\b(failed|declined|pending|processing|cancelled|reversed)\b',
    caseSensitive: false,
  );

  static final _labeledUtrPattern = RegExp(
    r'(?:utr|upi\s*(?:ref(?:\.|erence)?(?:\s*(?:id|no\.?|number))?|id)|ref(?:erence)?\s*(?:id|no\.?|number)|txn\s*(?:id|no\.?)|transaction\s*(?:id|no\.?))\s*[:#\-]?\s*([A-Z0-9]{10,22})',
    caseSensitive: false,
  );

  static final _twelveDigitUtrPattern = RegExp(r'\b(\d{12})\b');
  static final _phonePeTxnPattern = RegExp(r'\b(T\d{14,22})\b');

  static final _currencyAmountPattern = RegExp(
    r'(?:₹|र|Rs\.?|INR|\?)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _suffixCurrencyAmountPattern = RegExp(
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:₹|र|(?:Rs\.?|INR)\b)',
    caseSensitive: false,
  );

  static final _rupeeMarkerPattern = RegExp(
    r'(?:₹|र|Rs\.?|INR|\?)',
    caseSensitive: false,
  );

  static final _pureAmountPattern = RegExp(r'^[\d,]+(?:\.\d{1,2})?$');

  static final _receiptContextPattern = RegExp(
    r'\b(paid|payment|received|sent|completed|successful|success|upi|utr|ref|transaction|txn|gpay|phonepe|paytm|bhim|cred|to)\b',
    caseSensitive: false,
  );

  static final _nonPaymentNoisePattern = RegExp(
    r'\b(cashback|reward|scratch|offer|discount|balance|bal|fee|gst|limit|save|won)\b',
    caseSensitive: false,
  );

  /// Runs on-device ML Kit Latin text recognition on [filePath] and extracts
  /// UPI UTR/reference ID, INR amount near the rupee symbol, and status flags.
  Future<UpiProofExtraction> scanFromFilePath(String filePath) async {
    if (filePath.trim().isEmpty) return const UpiProofExtraction();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(filePath);
      final recognized = await recognizer.processImage(image);
      return parseRecognizedText(recognized);
    } catch (_) {
      return const UpiProofExtraction();
    } finally {
      try {
        await recognizer.close();
      } catch (_) {}
    }
  }

  /// Parses ML Kit [RecognizedText] using bounding-box proximity around the
  /// rupee symbol (`₹` / `Rs.` / `INR`), falling back to text matching.
  static UpiProofExtraction parseRecognizedText(RecognizedText recognized) {
    final boxes = <({String text, Rect box})>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) {
          boxes.add((text: t, box: line.boundingBox));
        }
      }
    }
    final spatialAmount = extractAmountNearRupeeBoxes(boxes);
    final parsed = parseExtractedText(recognized.text);
    if (spatialAmount != null && spatialAmount != parsed.amountInr) {
      return UpiProofExtraction(
        utr: parsed.utr,
        amountInr: spatialAmount,
        isStatusFailedOrPending: parsed.isStatusFailedOrPending,
        rawText: parsed.rawText,
      );
    }
    return parsed;
  }

  /// Finds the primary rupee amount closest to a rupee symbol (`₹`, `Rs`, `INR`)
  /// using OCR bounding-box layout.
  static int? extractAmountNearRupeeBoxes(
    List<({String text, Rect box})> boxes,
  ) {
    if (boxes.isEmpty) return null;
    final candidates = <({int amount, double score})>[];

    for (final item in boxes) {
      if (!_rupeeMarkerPattern.hasMatch(item.text)) continue;

      final inline = _firstValidRupeeMatch(_currencyAmountPattern, item.text) ??
          _firstValidRupeeMatch(_suffixCurrencyAmountPattern, item.text);
      if (inline != null) {
        final isNoise = _nonPaymentNoisePattern.hasMatch(item.text);
        final score = (isNoise ? -1000.0 : 100.0) + item.box.height;
        candidates.add((amount: inline, score: score));
        continue;
      }

      // Rupee symbol is in its own box (e.g. "₹" next to "2,000"). Find the
      // closest numeric box on the same horizontal row.
      final rupeeBox = item.box;
      final rupeeCenterY = rupeeBox.center.dy;
      int? bestVal;
      double bestDist = double.infinity;
      double bestHeight = 0;
      bool bestIsNoise = false;

      for (final other in boxes) {
        if (identical(other, item)) continue;
        final cleaned = other.text.trim();
        if (!_pureAmountPattern.hasMatch(cleaned)) continue;
        final val = _parseRupeeInt(cleaned);
        if (val == null) continue;

        final otherBox = other.box;
        final maxH = math.max(rupeeBox.height, otherBox.height);
        final dy = (otherBox.center.dy - rupeeCenterY).abs();
        if (dy > math.max(24.0, maxH * 1.1)) continue;

        final dx = otherBox.left - rupeeBox.right;
        // Prefer numbers immediately to the right of the rupee symbol, or just left.
        if (dx < -rupeeBox.width - 24 || dx > math.max(160.0, maxH * 4.0)) {
          continue;
        }
        final dist = dx.abs() + dy * 2.0;
        if (dist < bestDist) {
          bestDist = dist;
          bestVal = val;
          bestHeight = otherBox.height;
          bestIsNoise = _nonPaymentNoisePattern.hasMatch(item.text);
        }
      }

      if (bestVal != null) {
        final score =
            (bestIsNoise ? -1000.0 : 100.0) + bestHeight - (bestDist * 0.25);
        candidates.add((amount: bestVal, score: score));
      }
    }

    if (candidates.isEmpty) {
      // Many UPI apps (PhonePe / GPay) draw ₹ as a vector icon so ML Kit may
      // omit ₹ and read only the large standalone amount on a payment screen.
      final combinedText = boxes.map((b) => b.text).join('\n');
      if (!_receiptContextPattern.hasMatch(combinedText)) return null;

      final heights = boxes.map((b) => b.box.height).toList()..sort();
      final medianHeight = heights[heights.length ~/ 2];
      final heroCandidates = <({int amount, double score})>[];

      for (final item in boxes) {
        final cleaned = item.text.trim();
        if (!_pureAmountPattern.hasMatch(cleaned)) continue;
        final val = _parseRupeeInt(cleaned);
        if (val == null) continue;
        if (_nonPaymentNoisePattern.hasMatch(cleaned)) continue;
        final isLargeText =
            item.box.height >= math.max(22.0, medianHeight * 1.3);
        final score = item.box.height + (isLargeText ? 200.0 : 0.0);
        heroCandidates.add((amount: val, score: score));
      }
      if (heroCandidates.isEmpty) return null;
      heroCandidates.sort((a, b) => b.score.compareTo(a.score));
      return heroCandidates.first.amount;
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.amount;
  }

  /// Parses raw OCR text from a UPI screenshot into structured fields.
  static UpiProofExtraction parseExtractedText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return const UpiProofExtraction();

    final isStatusAlert = _statusAlertPattern.hasMatch(text);
    final utr = _extractUtr(text);
    final amountInr = _extractAmount(text);

    return UpiProofExtraction(
      utr: utr,
      amountInr: amountInr,
      isStatusFailedOrPending: isStatusAlert,
      rawText: text,
    );
  }

  /// Audits OCR-extracted UPI proof metadata against entered fee and
  /// existing gym members to catch duplicates, mismatches, or failed txns.
  static UpiProofAuditResult auditProof({
    required UpiProofExtraction extracted,
    required int enteredAmount,
    required List<GymMember> existingMembers,
  }) {
    final cleanUtr = extracted.utr.trim();
    if (cleanUtr.isNotEmpty) {
      final normalized = cleanUtr.toLowerCase();
      for (final m in existingMembers) {
        if (m.paymentReference.trim().toLowerCase() == normalized) {
          final dupLabel = m.respectfulName.isEmpty ? m.name : m.respectfulName;
          return UpiProofAuditResult(
            severity: UpiProofSeverity.blocked,
            headline: 'Duplicate UTR Detected',
            detail:
                'UTR $cleanUtr was already used by $dupLabel. Request a fresh payment.',
            duplicateMemberName: dupLabel,
          );
        }
      }
    }

    if (extracted.isStatusFailedOrPending) {
      return const UpiProofAuditResult(
        severity: UpiProofSeverity.blocked,
        headline: 'Payment Not Confirmed',
        detail:
            'Screenshot appears to show a Failed or Pending status. Verify before enrolling.',
      );
    }

    if (extracted.amountInr == null) {
      return const UpiProofAuditResult(
        severity: UpiProofSeverity.blocked,
        headline: 'Amount Not Detected Error',
        detail:
            'Could not detect ₹ amount from screenshot. Upload a clear payment receipt showing the paid amount.',
      );
    }

    if (extracted.amountInr != enteredAmount) {
      return UpiProofAuditResult(
        severity: UpiProofSeverity.blocked,
        headline: 'Amount Mismatch Error',
        detail:
            'Screenshot shows ₹${extracted.amountInr}, but Amount Paid is ₹$enteredAmount. Amounts must match.',
      );
    }

    if (cleanUtr.isNotEmpty) {
      return UpiProofAuditResult(
        severity: UpiProofSeverity.verified,
        headline: 'UPI Proof Verified',
        detail: 'UTR $cleanUtr • ₹${extracted.amountInr} matched on-device',
      );
    }

    return UpiProofAuditResult(
      severity: UpiProofSeverity.verified,
      headline: '₹${extracted.amountInr} Matched on Screenshot',
      detail: 'Paid amount matches the uploaded screenshot.',
    );
  }

  static String _extractUtr(String text) {
    for (final match in _labeledUtrPattern.allMatches(text)) {
      final candidate = (match.group(1) ?? '').trim();
      final digitCount = RegExp(r'\d').allMatches(candidate).length;
      if (digitCount >= 6) return candidate;
    }

    final twelveMatch = _twelveDigitUtrPattern.firstMatch(text);
    if (twelveMatch != null) {
      return twelveMatch.group(1) ?? '';
    }

    final phonePeMatch = _phonePeTxnPattern.firstMatch(text);
    if (phonePeMatch != null) {
      return phonePeMatch.group(1) ?? '';
    }

    return '';
  }

  static int? _extractAmount(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    int? noiseFallback;
    for (final line in lines) {
      final candidate = _firstValidRupeeMatch(_currencyAmountPattern, line) ??
          _firstValidRupeeMatch(_suffixCurrencyAmountPattern, line);
      if (candidate == null) continue;
      if (_nonPaymentNoisePattern.hasMatch(line)) {
        noiseFallback ??= candidate;
        continue;
      }
      return candidate;
    }

    // Handle multi-line rupee symbol followed on the next line by the amount (e.g. "₹\n2,000").
    final multiLine = _firstValidRupeeMatch(_currencyAmountPattern, text) ??
        _firstValidRupeeMatch(_suffixCurrencyAmountPattern, text);
    if (multiLine != null) return multiLine;
    if (noiseFallback != null) return noiseFallback;

    // Fallback when UPI app rendered ₹ as a vector icon and OCR extracted
    // only a standalone numeric amount line on a payment receipt.
    if (_receiptContextPattern.hasMatch(text)) {
      for (final line in lines) {
        if (!_pureAmountPattern.hasMatch(line)) continue;
        final val = _parseRupeeInt(line);
        if (val != null) return val;
      }
    }
    return null;
  }

  static int? _firstValidRupeeMatch(RegExp pattern, String text) {
    for (final match in pattern.allMatches(text)) {
      final val = _parseRupeeInt(match.group(1) ?? '');
      if (val != null) return val;
    }
    return null;
  }

  static int? _parseRupeeInt(String rawInput) {
    final raw = rawInput.replaceAll(',', '').trim();
    final val = double.tryParse(raw)?.round();
    if (val != null && val > 0 && val <= 500000) {
      return val;
    }
    return null;
  }
}
