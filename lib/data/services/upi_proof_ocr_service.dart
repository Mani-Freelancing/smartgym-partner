import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/models/gym_member.dart';
import 'rupee_glyph_detector.dart';

enum UpiProofSeverity { verified, warning, blocked, neutral }

typedef OcrTextBox = ({String text, Rect box});

class UpiProofExtraction {
  final String utr;
  final int? amountInr;
  final bool isStatusFailedOrPending;
  final String rawText;
  final List<OcrTextBox> textBoxes;
  final bool hasPixelVerification;

  const UpiProofExtraction({
    this.utr = '',
    this.amountInr,
    this.isStatusFailedOrPending = false,
    this.rawText = '',
    this.textBoxes = const [],
    this.hasPixelVerification = false,
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
/// screenshots (PhonePe, GPay, Paytm, BHIM, CRED, bank UPI apps).
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

  static const _currencyNumGroup =
      r'((?:\d{1,3}(?:[,\s]\d{2,3})+|\d+(?:\.\d{3})?)(?:\.\d{1,2})?)';

  static final _currencyAmountPattern = RegExp(
    '(?:₹|र|Rs\\.?|Re\\.?|INR|\\?|(?<=\\s|^)[£€*](?=\\s*[\\d,]))\\s*$_currencyNumGroup',
    caseSensitive: false,
  );

  static final _misreadCurrencyAmountPattern = RegExp(
    '(?<=\\s|^)[FR]\\s*$_currencyNumGroup',
  );

  static final _suffixCurrencyAmountPattern = RegExp(
    '$_currencyNumGroup\\s*(?:₹|र|(?:Rs\\.?|INR)\\b)',
    caseSensitive: false,
  );

  static final _rupeeMarkerPattern = RegExp(
    r'(?:₹|र|Rs\.?|Re\.?|INR|\?|(?<=\s|^)[£€*](?=\s*[\d,]))',
    caseSensitive: false,
  );

  static final _misreadRupeeMarkerPattern = RegExp(
    r'(?<=\s|^)[FR](?=\s*[\d,])',
  );

  static final _pureAmountPattern = RegExp(
    r'^(?:\d{1,3}(?:,\d{2,3})+|\d+(?:\.\d{3})?)(?:\.\d{1,2})?(?:\s*/[-–])?$',
  );

  static final _contextAmountPattern = RegExp(
    r'(?:paid|amount|sent|received|debited|credited|total|payment(?:\s+of)?|transfer)\s*[:\-]?\s*((?:\d{1,3}(?:,\d{2,3})+|\d+)(?:\.\d{1,2})?)\b',
    caseSensitive: false,
  );

  static final _receiptContextPattern = RegExp(
    r'\b(paid|payment|received|sent|completed|successful|successfully|success|upi|utr|ref|transaction|txn|gpay|phonepe|paytm|bhim|cred|debited|credited|to)\b',
    caseSensitive: false,
  );

  static final _nonPaymentNoisePattern = RegExp(
    r'\b(cashback|reward|scratch|offer|discount|balance|bal|avl|avail|available|closing|fee|convenience|gst|tax|charge|limit|save|saved|won|coins|points|bill|invoice)\b',
    caseSensitive: false,
  );

  static final _nonAmountMetadataPattern = RegExp(
    r'(?:\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\b|\b\d{1,2}:\d{2}\b|\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\+91|\b\d{5}\s+\d{5}\b|\b(?:phone|mobile|mob|a/c|acct|account|ifsc|card|ending|bank|wallet|pin|otp)\b|[x*•]{2,}\s*\d+|\S+@[a-z0-9]{2,})',
    caseSensitive: false,
  );

  static final _yearOnlyPattern = RegExp(r'^(?:199\d|20[0-4]\d)$');

  static final RegExp _leadingRupeeAttachedRegExp = RegExp(
    r'^([237FRTEZrtz\?])(\d[\d,]*(?:\.\d{1,2})?)(\/-)?$',
  );
  static final RegExp _singleRupeeCharRegExp = RegExp(r'^[237FRTEZrtz\?]$');

  /// Runs on-device ML Kit Latin text recognition on [filePath] and extracts
  /// UPI UTR/reference ID, INR amount near the rupee symbol, and status flags.
  ///
  /// When [imageBytes] (or readable [filePath] bytes) are available, leading
  /// characters commonly misread from `₹` by the Latin OCR model (such as `7`,
  /// `2`, `3`, `F`, `R`, `T`, `E`, `Z`) are verified pixel-by-pixel via
  /// [RupeeGlyphDetector] and normalized back to `₹` before amount scoring.
  Future<UpiProofExtraction> scanFromFilePath(
    String filePath, {
    Uint8List? imageBytes,
    int? expectedAmount,
  }) async {
    if (filePath.trim().isEmpty) return const UpiProofExtraction();
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      DecodedRgbaImage? rgbaImage;
      try {
        final bytes = imageBytes ?? await File(filePath).readAsBytes();
        if (bytes.isNotEmpty) {
          rgbaImage = await RupeeGlyphDetector.decodeBytes(bytes);
        }
      } catch (_) {}

      final image = InputImage.fromFilePath(filePath);
      final recognized = await recognizer.processImage(image);
      return parseRecognizedTextWithImage(
        recognized,
        rgbaImage: rgbaImage,
        expectedAmount: expectedAmount,
      );
    } catch (_) {
      return const UpiProofExtraction();
    } finally {
      try {
        await recognizer.close();
      } catch (_) {}
    }
  }

  /// Parses ML Kit [RecognizedText] using both `TextLine` and `TextElement`
  /// bounding-box proximity around rupee markers & payment hero digits.
  static UpiProofExtraction parseRecognizedText(
    RecognizedText recognized, {
    int? expectedAmount,
  }) {
    return parseRecognizedTextWithImage(
      recognized,
      expectedAmount: expectedAmount,
    );
  }

  /// Parses ML Kit [RecognizedText] with optional pixel-level [rgbaImage]
  /// verification so misread `₹` glyphs (e.g. `₹300` read as `7300`) are
  /// corrected independently of [expectedAmount].
  static UpiProofExtraction parseRecognizedTextWithImage(
    RecognizedText recognized, {
    DecodedRgbaImage? rgbaImage,
    int? expectedAmount,
  }) {
    final boxes = <OcrTextBox>[];
    final normalizedLines = <String>[];
    var anyLineRewritten = false;

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isEmpty) continue;

        final elementPairs = <({String text, Rect box})>[];
        var lineRewritten = false;

        for (final element in line.elements) {
          final et = element.text.trim();
          if (et.isEmpty) continue;
          final normalizedElement = _normalizeMisreadRupeeElement(
            element,
            et,
            rgbaImage,
          );
          if (normalizedElement != et) {
            lineRewritten = true;
            anyLineRewritten = true;
          }
          elementPairs.add((text: normalizedElement, box: element.boundingBox));
        }

        final normalizedLine = lineRewritten && elementPairs.isNotEmpty
            ? elementPairs.map((pair) => pair.text).join(' ')
            : t;
        boxes.add((text: normalizedLine, box: line.boundingBox));
        normalizedLines.add(normalizedLine);

        // Also inspect individual elements when ML Kit merges unrelated text
        // onto a line or splits `₹` and `2,000` into adjacent tokens.
        if (elementPairs.length > 1) {
          for (final pair in elementPairs) {
            boxes.add(pair);
          }
        }
      }
    }

    final normalizedText =
        anyLineRewritten ? normalizedLines.join('\n') : recognized.text;
    final hasPixels = rgbaImage != null;

    final spatialAmount = extractAmountNearRupeeBoxes(
      boxes,
      expectedAmount: expectedAmount,
      allowTextUnfuse: !hasPixels,
    );
    final parsed = parseExtractedText(
      normalizedText,
      expectedAmount: expectedAmount,
      allowTextUnfuse: !hasPixels,
    );

    final resolvedAmount = spatialAmount ?? parsed.amountInr;
    return UpiProofExtraction(
      utr: parsed.utr,
      amountInr: resolvedAmount,
      isStatusFailedOrPending: parsed.isStatusFailedOrPending,
      rawText: parsed.rawText,
      textBoxes: boxes,
      hasPixelVerification: hasPixels,
    );
  }

  static String _normalizeMisreadRupeeElement(
    TextElement element,
    String text,
    DecodedRgbaImage? rgbaImage,
  ) {
    if (rgbaImage == null) return text;

    if (_singleRupeeCharRegExp.hasMatch(text)) {
      final probe = _selectLeadingGlyphProbe(element, text);
      if (RupeeGlyphDetector.isRupeeGlyph(
        rgbaImage,
        probe.rect,
        isolateFirstGlyph: probe.isolateFirstGlyph,
      )) {
        return '₹';
      }
      return text;
    }

    final match = _leadingRupeeAttachedRegExp.firstMatch(text);
    if (match == null) return text;

    final numericPart = match.group(2)!;
    final digitCount = numericPart.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount < 1 || digitCount > 7) return text;

    final probe = _selectLeadingGlyphProbe(element, text);
    if (!RupeeGlyphDetector.isRupeeGlyph(
      rgbaImage,
      probe.rect,
      isolateFirstGlyph: probe.isolateFirstGlyph,
    )) {
      return text;
    }

    final suffix = match.group(3) ?? '';
    return '₹$numericPart$suffix';
  }

  static ({Rect rect, bool isolateFirstGlyph}) _selectLeadingGlyphProbe(
    TextElement element,
    String text,
  ) {
    if (element.symbols.isNotEmpty) {
      final firstSymbol = element.symbols.first;
      final symRect = firstSymbol.boundingBox;
      final elemRect = element.boundingBox;
      final symbolMatchesSingleGlyph = text.length == 1 ||
          element.symbols.length == text.length ||
          (elemRect.width > 0 &&
              symRect.width > 0 &&
              symRect.width < elemRect.width * 0.75);
      if (symbolMatchesSingleGlyph && symRect.width > 0 && symRect.height > 0) {
        return (rect: symRect, isolateFirstGlyph: false);
      }
    }
    return (
      rect: element.boundingBox,
      isolateFirstGlyph: text.length > 1,
    );
  }

  /// Re-evaluates [extraction] if the user edits `Amount Paid` after uploading.
  static UpiProofExtraction refineForExpectedAmount(
    UpiProofExtraction extraction,
    int? expectedAmount,
  ) {
    if (extraction.rawText.isEmpty && extraction.textBoxes.isEmpty) {
      return extraction;
    }
    final allowTextUnfuse = !extraction.hasPixelVerification;
    final spatialAmount = extraction.textBoxes.isNotEmpty
        ? extractAmountNearRupeeBoxes(
            extraction.textBoxes,
            expectedAmount: expectedAmount,
            allowTextUnfuse: allowTextUnfuse,
          )
        : null;
    final textParsed = parseExtractedText(
      extraction.rawText,
      expectedAmount: expectedAmount,
      allowTextUnfuse: allowTextUnfuse,
    );
    return UpiProofExtraction(
      utr: extraction.utr.isNotEmpty ? extraction.utr : textParsed.utr,
      amountInr: spatialAmount ?? textParsed.amountInr ?? extraction.amountInr,
      isStatusFailedOrPending:
          extraction.isStatusFailedOrPending || textParsed.isStatusFailedOrPending,
      rawText: extraction.rawText,
      textBoxes: extraction.textBoxes,
      hasPixelVerification: extraction.hasPixelVerification,
    );
  }

  /// Finds the primary rupee amount closest to a rupee symbol (`₹`, `Rs`, `INR`)
  /// or large payment hero text using OCR bounding-box layout.
  static int? extractAmountNearRupeeBoxes(
    List<OcrTextBox> boxes, {
    int? expectedAmount,
    bool allowTextUnfuse = true,
  }) {
    if (boxes.isEmpty) return null;

    final maxBottom =
        boxes.map((b) => b.box.bottom).fold<double>(0.0, math.max);
    final statusBarCutoff = maxBottom > 240 ? maxBottom * 0.08 : 0.0;
    final candidates = <({int amount, double score, bool hasCurrency})>[];

    for (final item in boxes) {
      if (!_hasCurrencyMarker(item.text)) continue;

      final inline = _matchCurrencyAmount(item.text);
      if (inline != null) {
        final isNoise = _nonPaymentNoisePattern.hasMatch(item.text) ||
            _nonAmountMetadataPattern.hasMatch(item.text);
        final matchBonus =
            (expectedAmount != null && inline == expectedAmount) ? 80.0 : 0.0;
        final score =
            (isNoise ? -1000.0 : 140.0) + item.box.height + matchBonus;
        candidates.add((amount: inline, score: score, hasCurrency: true));
        continue;
      }

      // Rupee symbol is in its own box (e.g. "₹" next to "2,000"). Find the
      // closest numeric box on the same horizontal row or overlapping vertically.
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
        final verticalOverlap = math.min(rupeeBox.bottom, otherBox.bottom) -
            math.max(rupeeBox.top, otherBox.top);
        final dy = (otherBox.center.dy - rupeeCenterY).abs();
        if (verticalOverlap <= 0 && dy > math.max(32.0, maxH * 1.35)) {
          continue;
        }

        final dx = otherBox.left - rupeeBox.right;
        if (dx < -rupeeBox.width - 30 || dx > math.max(200.0, maxH * 4.5)) {
          continue;
        }
        final dist = dx.abs() + dy * 1.6;
        if (dist < bestDist) {
          bestDist = dist;
          bestVal = val;
          bestHeight = otherBox.height;
          bestIsNoise = _nonPaymentNoisePattern.hasMatch(item.text);
        }
      }

      if (bestVal != null) {
        final matchBonus =
            (expectedAmount != null && bestVal == expectedAmount) ? 80.0 : 0.0;
        final score = (bestIsNoise ? -1000.0 : 140.0) +
            bestHeight -
            (bestDist * 0.25) +
            matchBonus;
        candidates.add((amount: bestVal, score: score, hasCurrency: true));
      }
    }

    // Check payment-context phrases inside boxes (e.g. "Paid 1,500") and large
    // standalone hero numbers when ML Kit dropped or fused `₹`.
    final combinedText = boxes.map((b) => b.text).join('\n');
    final hasReceiptContext =
        candidates.isNotEmpty || _receiptContextPattern.hasMatch(combinedText);

    if (hasReceiptContext) {
      final heights = boxes.map((b) => b.box.height).toList()..sort();
      final medianHeight = heights[heights.length ~/ 2];

      for (final item in boxes) {
        if (item.box.top < statusBarCutoff && item.box.height < medianHeight * 1.2) {
          continue;
        }
        final line = item.text.trim();
        if (_nonPaymentNoisePattern.hasMatch(line)) continue;

        // Check `Paid 1,500` / `Amount 2000` style text boxes
        final ctxVal = _firstValidRupeeMatch(_contextAmountPattern, line);
        if (ctxVal != null && !_nonAmountMetadataPattern.hasMatch(line)) {
          final matchBonus =
              (expectedAmount != null && ctxVal == expectedAmount) ? 90.0 : 0.0;
          candidates.add((
            amount: ctxVal,
            score: 110.0 + item.box.height + matchBonus,
            hasCurrency: false,
          ));
        }

        if (_pureAmountPattern.hasMatch(line) &&
            !_nonAmountMetadataPattern.hasMatch(line)) {
          final rawVal = _parseRupeeInt(line);
          if (rawVal != null) {
            final resolvedVal = allowTextUnfuse
                ? _maybeUnfuseRupeeDigit(
                    rawTextToken: line,
                    parsedVal: rawVal,
                    expectedAmount: expectedAmount,
                  )
                : rawVal;
            final isYearPenalty =
                _yearOnlyPattern.hasMatch(line) && resolvedVal != expectedAmount
                    ? -250.0
                    : 0.0;
            final isLargeText =
                item.box.height >= math.max(22.0, medianHeight * 1.3);
            final matchBonus = (expectedAmount != null &&
                    resolvedVal == expectedAmount)
                ? 110.0
                : 0.0;
            final score = item.box.height +
                (isLargeText ? 180.0 : 0.0) +
                isYearPenalty +
                matchBonus;
            candidates.add((
              amount: resolvedVal,
              score: score,
              hasCurrency: false,
            ));
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    if (expectedAmount != null) {
      final positiveCurrencyMatches = candidates
          .where((c) => c.hasCurrency && c.score > 0 && c.amount == expectedAmount);
      if (positiveCurrencyMatches.isNotEmpty) {
        return expectedAmount;
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.score > -200 ? candidates.first.amount : null;
  }

  /// Parses raw OCR text from a UPI screenshot into structured fields.
  static UpiProofExtraction parseExtractedText(
    String rawText, {
    int? expectedAmount,
    bool allowTextUnfuse = true,
  }) {
    final text = rawText.trim();
    if (text.isEmpty) return const UpiProofExtraction();

    final isStatusAlert = _statusAlertPattern.hasMatch(text);
    final utr = _extractUtr(text);
    final amountInr = _extractAmount(
      text,
      expectedAmount: expectedAmount,
      allowTextUnfuse: allowTextUnfuse,
    );

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

  static int? _extractAmount(
    String text, {
    int? expectedAmount,
    bool allowTextUnfuse = true,
  }) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final scored = <({int amount, double score})>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isNoise = _nonPaymentNoisePattern.hasMatch(line);
      final isMetadata = _nonAmountMetadataPattern.hasMatch(line);

      // 1. Explicit currency marker on this line (`₹`, `Rs`, `INR`, `?`, `F`, `R`, `*`)
      final cur = _matchCurrencyAmount(line);
      if (cur != null) {
        final resolved = allowTextUnfuse
            ? _maybeUnfuseRupeeDigit(
                rawTextToken: line,
                parsedVal: cur,
                expectedAmount: expectedAmount,
              )
            : cur;
        final score = (isNoise ? -900.0 : 140.0) +
            (isMetadata ? -40.0 : 0.0) +
            ((expectedAmount != null && resolved == expectedAmount) ? 80.0 : 0.0);
        scored.add((amount: resolved, score: score));
        continue;
      }

      // 2. Payment-context keywords right before amount (`Paid 1,500`, `Amount 2000`)
      if (!isNoise && !isMetadata) {
        final ctx = _firstValidRupeeMatch(_contextAmountPattern, line);
        if (ctx != null) {
          final resolved = allowTextUnfuse
              ? _maybeUnfuseRupeeDigit(
                  rawTextToken: line,
                  parsedVal: ctx,
                  expectedAmount: expectedAmount,
                )
              : ctx;
          final score = 100.0 +
              ((expectedAmount != null && resolved == expectedAmount)
                  ? 80.0
                  : 0.0);
          scored.add((amount: resolved, score: score));
        }
      }
    }

    // 3. Multi-line rupee symbol followed on the next line by digits ("₹\n2,500")
    final multiLine = _matchCurrencyAmount(text);
    if (multiLine != null) {
      scored.add((
        amount: multiLine,
        score: 120.0 +
            ((expectedAmount != null && multiLine == expectedAmount)
                ? 80.0
                : 0.0),
      ));
    }

    // 4. Standalone numeric lines on payment receipts where ₹ vector icon dropped
    if (_receiptContextPattern.hasMatch(text)) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!_pureAmountPattern.hasMatch(line)) continue;
        if (_nonPaymentNoisePattern.hasMatch(line) ||
            _nonAmountMetadataPattern.hasMatch(line)) {
          continue;
        }
        final val = _parseRupeeInt(line);
        if (val == null) continue;
        final resolved = allowTextUnfuse
            ? _maybeUnfuseRupeeDigit(
                rawTextToken: line,
                parsedVal: val,
                expectedAmount: expectedAmount,
              )
            : val;
        final isYearPenalty =
            _yearOnlyPattern.hasMatch(line) && resolved != expectedAmount
                ? -250.0
                : 0.0;
        // Prefer lines with comma formatting (e.g. 2,000) and after index 0
        final hasCommaBoost = line.contains(',') ? 40.0 : 0.0;
        final prevLine = i > 0 ? lines[i - 1] : '';
        final afterPaidBoost =
            _receiptContextPattern.hasMatch(prevLine) ? 35.0 : 0.0;
        final matchBoost =
            (expectedAmount != null && resolved == expectedAmount) ? 95.0 : 0.0;
        scored.add((
          amount: resolved,
          score: 30.0 +
              hasCommaBoost +
              afterPaidBoost +
              isYearPenalty +
              matchBoost,
        ));
      }
    }

    if (scored.isEmpty) return null;
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.first.score > -200 ? scored.first.amount : null;
  }

  /// Corrects ML Kit Latin's frequent quirk of fusing `₹` into a leading
  /// `2`, `3`, or `7` onto the real amount (e.g. `₹1,500` -> `71,500` / `21,500`),
  /// strictly gated so it only resolves when [expectedAmount] matches the suffix.
  static int _maybeUnfuseRupeeDigit({
    required String rawTextToken,
    required int parsedVal,
    int? expectedAmount,
  }) {
    if (expectedAmount == null || parsedVal == expectedAmount) {
      return parsedVal;
    }
    final digits = rawTextToken.replaceAll(RegExp(r'[^\d.]'), '').split('.').first;
    final expStr = expectedAmount.toString();
    if (digits.length == expStr.length + 1 &&
        (digits.startsWith('2') ||
            digits.startsWith('3') ||
            digits.startsWith('7')) &&
        digits.substring(1) == expStr) {
      return expectedAmount;
    }
    return parsedVal;
  }

  static bool _hasCurrencyMarker(String text) =>
      _rupeeMarkerPattern.hasMatch(text) ||
      _misreadRupeeMarkerPattern.hasMatch(text);

  static int? _matchCurrencyAmount(String text) =>
      _firstValidRupeeMatch(_currencyAmountPattern, text) ??
      _firstValidRupeeMatch(_suffixCurrencyAmountPattern, text) ??
      _firstValidRupeeMatch(_misreadCurrencyAmountPattern, text);

  static int? _firstValidRupeeMatch(RegExp pattern, String text) {
    for (final match in pattern.allMatches(text)) {
      final val = _parseRupeeInt(match.group(1) ?? '');
      if (val != null) return val;
    }
    return null;
  }

  static int? _parseRupeeInt(String rawInput) {
    var raw = rawInput.replaceAll('/-', '').replaceAll('/–', '').trim();
    raw = raw.replaceAll(',', '').replaceAll(' ', '');
    // Handle dot used as Indian thousand separator (e.g. `₹1.500` -> 3 digits after `.`)
    if (RegExp(r'^\d{1,3}\.\d{3}$').hasMatch(raw)) {
      raw = raw.replaceAll('.', '');
    }
    final val = double.tryParse(raw)?.round();
    if (val != null && val > 0 && val <= 500000) {
      return val;
    }
    return null;
  }
}
