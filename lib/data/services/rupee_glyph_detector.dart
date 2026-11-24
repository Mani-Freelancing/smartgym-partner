import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Decoded RGBA bitmap wrapper used for pure-Dart geometric verification of
/// Indian Rupee (`₹`) glyphs misread by Latin OCR (e.g. `₹300` -> `7300`).
class DecodedRgbaImage {
  final int width;
  final int height;
  final Uint8List rgba;

  const DecodedRgbaImage({
    required this.width,
    required this.height,
    required this.rgba,
  });

  double luminanceAt(int x, int y) {
    final cx = x.clamp(0, width - 1);
    final cy = y.clamp(0, height - 1);
    final idx = (cy * width + cx) * 4;
    return 0.299 * rgba[idx] +
        0.587 * rgba[idx + 1] +
        0.114 * rgba[idx + 2];
  }
}

class RupeeGlyphMetrics {
  final int width;
  final int height;
  final double topBarMax;
  final double secondBarMax;
  final bool hasUpperValley;
  final double botRightFill;
  final double botLeftFill;
  final double botCenterX;
  final double botMaxRow;
  final double leftSpineLower;

  const RupeeGlyphMetrics({
    required this.width,
    required this.height,
    required this.topBarMax,
    required this.secondBarMax,
    required this.hasUpperValley,
    required this.botRightFill,
    required this.botLeftFill,
    required this.botCenterX,
    required this.botMaxRow,
    required this.leftSpineLower,
  });

  /// Distinguishes `₹` (top horizontal bar + gap + second horizontal bar +
  /// diagonal lower-right tail with empty bottom-left) from real `7`, `2`, `3`, `F`, `R`.
  bool get looksLikeRupee =>
      width >= 5 &&
      height >= 8 &&
      topBarMax >= 0.45 &&
      secondBarMax >= 0.44 &&
      hasUpperValley &&
      botCenterX >= 0.45 &&
      botRightFill >= 0.06 &&
      botLeftFill <= 0.30 &&
      leftSpineLower <= 0.36 &&
      botMaxRow <= 0.58;

  @override
  String toString() =>
      'RupeeGlyphMetrics(w=$width, h=$height, top=${topBarMax.toStringAsFixed(2)}, '
      'sec=${secondBarMax.toStringAsFixed(2)}, valley=$hasUpperValley, '
      'botX=${botCenterX.toStringAsFixed(2)}, botR=${botRightFill.toStringAsFixed(2)}, '
      'botL=${botLeftFill.toStringAsFixed(2)}, spine=${leftSpineLower.toStringAsFixed(2)}, '
      'botRow=${botMaxRow.toStringAsFixed(2)})';
}

class RupeeGlyphDetector {
  /// Decodes encoded JPEG/PNG image bytes into an RGBA buffer using `dart:ui`.
  static Future<DecodedRgbaImage?> decodeBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (data == null || w <= 0 || h <= 0) return null;
      return DecodedRgbaImage(
        width: w,
        height: h,
        rgba: data.buffer.asUint8List(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Checks whether the cropped region [region] (or its leading connected glyph
  /// when [isolateFirstGlyph] is true) geometrically matches `₹`.
  static bool isRupeeGlyph(
    DecodedRgbaImage image,
    ui.Rect region, {
    bool isolateFirstGlyph = false,
  }) {
    final metrics = analyzeRegion(
      image,
      region,
      isolateFirstGlyph: isolateFirstGlyph,
    );
    return metrics?.looksLikeRupee ?? false;
  }

  /// Computes normalized stroke metrics for the target glyph in [region].
  static RupeeGlyphMetrics? analyzeRegion(
    DecodedRgbaImage image,
    ui.Rect region, {
    bool isolateFirstGlyph = false,
  }) {
    final x0 = (region.left.floor() - 2).clamp(0, image.width - 1);
    final y0 = (region.top.floor() - 2).clamp(0, image.height - 1);
    final x1 = (region.right.ceil() + 2).clamp(0, image.width - 1);
    final y1 = (region.bottom.ceil() + 2).clamp(0, image.height - 1);
    if (x1 - x0 < 5 || y1 - y0 < 8) return null;

    final bgLum = _estimateBackgroundLuminance(image, x0, y0, x1, y1);

    // Measure contrast inside region so faint background watermarks (e.g. CRED) are ignored.
    final diffs = <double>[];
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        diffs.add((image.luminanceAt(x, y) - bgLum).abs());
      }
    }
    if (diffs.isEmpty) return null;
    diffs.sort();
    final maxContrast = diffs[((diffs.length - 1) * 0.96).round()];
    if (maxContrast < 28.0) return null;
    final fgCutoff = maxContrast * 0.42;

    bool isInk(int x, int y) => (image.luminanceAt(x, y) - bgLum).abs() >= fgCutoff;

    // Optionally split off the leading glyph (e.g. `₹` from `₹300` -> `7300`).
    var gxStart = x0;
    var gxEnd = x1;
    if (isolateFirstGlyph) {
      final totalW = x1 - x0 + 1;
      final totalH = y1 - y0 + 1;

      // Measure tight ink height from the leftmost region so loose box padding
      // does not skew aspect-ratio bounds when locating the first inter-glyph gap.
      var approxMinY = y1 + 1;
      var approxMaxY = y0 - 1;
      final approxScanEnd =
          (x0 + math.min(totalW * 0.52, totalH).round()).clamp(x0, x1);
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= approxScanEnd; x++) {
          if (isInk(x, y)) {
            if (y < approxMinY) approxMinY = y;
            if (y > approxMaxY) approxMaxY = y;
          }
        }
      }
      final inkH =
          (approxMaxY >= approxMinY) ? (approxMaxY - approxMinY + 1) : totalH;

      var sawInk = false;
      var peakCol = 0;
      var minAfterPeak = inkH + 1;
      var minColX = -1;
      var searchLimit =
          (x0 + math.min(totalW * 0.52, inkH * 0.95).round()).clamp(x0, x1);

      for (var x = x0; x <= searchLimit; x++) {
        var colInk = 0;
        for (var y = y0; y <= y1; y++) {
          if (isInk(x, y)) colInk++;
        }
        if (colInk > 0) {
          if (!sawInk) {
            gxStart = x;
            searchLimit = (gxStart +
                    math.min((x1 - gxStart) * 0.65, inkH * 0.95).round())
                .clamp(gxStart, x1);
          }
          sawInk = true;
          if (colInk > peakCol) peakCol = colInk;

          final pastHalfGlyph =
              (x - gxStart) >= math.max(5, (inkH * 0.45).round());
          if (pastHalfGlyph) {
            if (colInk < minAfterPeak) {
              minAfterPeak = colInk;
              minColX = x;
            } else if (minColX >= 0 &&
                minAfterPeak <= math.max(2, (inkH * 0.14).round()) &&
                colInk >= math.max(minAfterPeak + 2, (peakCol * 0.35).round())) {
              // Ink rose cleanly into the second glyph after a tight anti-aliased valley.
              gxEnd = minColX;
              break;
            }
          }
          gxEnd = x;
        } else if (sawInk &&
            (x - gxStart) >= math.max(4, (inkH * 0.38).round())) {
          gxEnd = x - 1;
          break;
        }

        if (x == searchLimit &&
            sawInk &&
            minColX >= 0 &&
            minAfterPeak <= math.max(2, (inkH * 0.16).round())) {
          gxEnd = minColX;
        }
      }
    }

    // Tighten to exact ink bounding box of the isolated glyph.
    var minX = gxEnd + 1;
    var maxX = gxStart - 1;
    var minY = y1 + 1;
    var maxY = y0 - 1;
    for (var y = y0; y <= y1; y++) {
      for (var x = gxStart; x <= gxEnd; x++) {
        if (isInk(x, y)) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    final gw = maxX - minX + 1;
    final gh = maxY - minY + 1;
    if (gw < 5 || gh < 8) return null;

    final rowDensity = List<double>.filled(gh, 0.0);
    for (var dy = 0; dy < gh; dy++) {
      var count = 0;
      for (var dx = 0; dx < gw; dx++) {
        if (isInk(minX + dx, minY + dy)) count++;
      }
      rowDensity[dy] = count / gw;
    }

    // Analyze top bar vs gap vs second horizontal bar in upper ~56% of height.
    final topEnd = math.max(1, (gh * 0.25).round());
    final midStart = math.max(topEnd, (gh * 0.22).round());
    final midEnd = math.min(gh - 1, (gh * 0.56).round());

    var topBarMax = 0.0;
    var topBarRow = 0;
    for (var dy = 0; dy < topEnd; dy++) {
      if (rowDensity[dy] > topBarMax) {
        topBarMax = rowDensity[dy];
        topBarRow = dy;
      }
    }

    var secondBarMax = 0.0;
    var secondBarRow = midStart;
    for (var dy = midStart; dy <= midEnd; dy++) {
      if (rowDensity[dy] > secondBarMax) {
        secondBarMax = rowDensity[dy];
        secondBarRow = dy;
      }
    }

    var minGapBetweenBars = 1.0;
    if (secondBarRow > topBarRow + 1) {
      for (var dy = topBarRow + 1; dy < secondBarRow; dy++) {
        if (rowDensity[dy] < minGapBetweenBars) {
          minGapBetweenBars = rowDensity[dy];
        }
      }
    }
    final hasUpperValley = secondBarRow > topBarRow + 1 &&
        minGapBetweenBars <= 0.48 &&
        minGapBetweenBars <= math.min(topBarMax, secondBarMax) * 0.72;

    // Bottom zone analysis (v in 0.72..1.00)
    final botYStart = (gh * 0.72).floor().clamp(0, gh - 1);
    final rightXStart = (gw * 0.52).floor().clamp(0, gw - 1);
    final leftXEnd = (gw * 0.38).ceil().clamp(1, gw);

    var botRightInk = 0;
    var botRightArea = 0;
    var botLeftInk = 0;
    var botLeftArea = 0;
    var botInkCount = 0;
    var botNormXSum = 0.0;
    var botMaxRow = 0.0;
    final flatBotStart = (gh * 0.80).floor().clamp(0, gh - 1);

    for (var dy = botYStart; dy < gh; dy++) {
      if (dy >= flatBotStart && rowDensity[dy] > botMaxRow) {
        botMaxRow = rowDensity[dy];
      }
      for (var dx = 0; dx < gw; dx++) {
        final ink = isInk(minX + dx, minY + dy);
        if (dx >= rightXStart) {
          botRightArea++;
          if (ink) botRightInk++;
        }
        if (dx < leftXEnd) {
          botLeftArea++;
          if (ink) botLeftInk++;
        }
        if (ink) {
          botInkCount++;
          botNormXSum += gw > 1 ? dx / (gw - 1) : 0.5;
        }
      }
    }

    // Lower-left spine check (rejects F, R, B, E which have continuous left vertical stem)
    final spineYStart = (gh * 0.68).floor().clamp(0, gh - 1);
    final spineYEnd = (gh * 0.96).ceil().clamp(spineYStart + 1, gh);
    final spineXEnd = (gw * 0.28).ceil().clamp(1, gw);
    var spineInk = 0;
    var spineArea = 0;
    for (var dy = spineYStart; dy < spineYEnd; dy++) {
      for (var dx = 0; dx < spineXEnd; dx++) {
        spineArea++;
        if (isInk(minX + dx, minY + dy)) spineInk++;
      }
    }

    return RupeeGlyphMetrics(
      width: gw,
      height: gh,
      topBarMax: topBarMax,
      secondBarMax: secondBarMax,
      hasUpperValley: hasUpperValley,
      botRightFill: botRightArea > 0 ? botRightInk / botRightArea : 0.0,
      botLeftFill: botLeftArea > 0 ? botLeftInk / botLeftArea : 0.0,
      botCenterX: botInkCount > 0 ? botNormXSum / botInkCount : 0.0,
      botMaxRow: botMaxRow,
      leftSpineLower: spineArea > 0 ? spineInk / spineArea : 0.0,
    );
  }

  static double _estimateBackgroundLuminance(
    DecodedRgbaImage image,
    int x0,
    int y0,
    int x1,
    int y1,
  ) {
    final samples = <double>[];
    for (var x = x0; x <= x1; x++) {
      samples.add(image.luminanceAt(x, y0));
      samples.add(image.luminanceAt(x, y1));
    }
    for (var y = y0; y <= y1; y++) {
      samples.add(image.luminanceAt(x0, y));
      samples.add(image.luminanceAt(x1, y));
    }
    if (samples.isEmpty) return 255.0;
    samples.sort();
    return samples[samples.length ~/ 2];
  }
}
