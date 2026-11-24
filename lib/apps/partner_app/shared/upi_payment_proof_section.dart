import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/upi_proof_ocr_service.dart';
import '../../../domain/models/gym_member.dart';

/// Shared Online / UPI payment proof uploader with zero-cost on-device ML Kit
/// OCR extraction, automatic amount match error checking, and duplicate UTR guard.
class UpiPaymentProofSection extends StatefulWidget {
  final Uint8List? proofBytes;
  final UpiProofExtraction ocrExtraction;
  final int enteredAmount;
  final List<GymMember> existingMembers;
  final Color accentColor;
  final Color cardBackground;
  final ValueChanged<({Uint8List bytes, String base64, UpiProofExtraction ocr})>
      onProofSelected;
  final ValueChanged<String> onError;

  const UpiPaymentProofSection({
    super.key,
    required this.proofBytes,
    required this.ocrExtraction,
    required this.enteredAmount,
    required this.existingMembers,
    required this.onProofSelected,
    required this.onError,
    this.accentColor = AppTheme.ownerGold,
    this.cardBackground = const Color(0xFF1A1E29),
  });

  @override
  State<UpiPaymentProofSection> createState() => _UpiPaymentProofSectionState();
}

class _UpiPaymentProofSectionState extends State<UpiPaymentProofSection> {
  final ImagePicker _picker = ImagePicker();
  final UpiProofOcrService _ocrService = UpiProofOcrService();
  bool _scanning = false;

  Future<void> _pickScreenshot() async {
    HapticFeedback.selectionClick();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1E29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Payment Proof',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_rounded,
                  color: widget.accentColor,
                ),
                title: const Text(
                  'Take Photo (Camera)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'Snap payment screen to verify ₹ amount & UTR',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.trainerCyan,
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    final rawBytes = await picked.readAsBytes();
    setState(() => _scanning = true);
    final ocr = await _ocrService.scanFromFilePath(
      picked.path,
      imageBytes: rawBytes,
      expectedAmount: widget.enteredAmount,
    );
    if (!mounted) return;

    final compressedBytes = await _fitWithinStorageLimit(rawBytes);
    final encoded = base64Encode(compressedBytes);
    if (encoded.length > 140000) {
      if (mounted) {
        setState(() => _scanning = false);
        widget.onError('Screenshot too large. Please pick a smaller image.');
      }
      return;
    }

    setState(() => _scanning = false);
    widget.onProofSelected((bytes: compressedBytes, base64: encoded, ocr: ocr));
  }

  /// Downscales oversized images after OCR so Firestore base64 stays <= 140KB
  /// without hurting on-device ML Kit text recognition accuracy.
  Future<Uint8List> _fitWithinStorageLimit(Uint8List rawBytes) async {
    if (base64Encode(rawBytes).length <= 140000) return rawBytes;
    for (final width in const [560, 420, 320, 240]) {
      try {
        final codec = await ui.instantiateImageCodec(
          rawBytes,
          targetWidth: width,
        );
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        frame.image.dispose();
        codec.dispose();
        if (data != null) {
          final candidate = data.buffer.asUint8List();
          if (base64Encode(candidate).length <= 140000) {
            return candidate;
          }
        }
      } catch (_) {
        break;
      }
    }
    return rawBytes;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOcr = UpiProofOcrService.refineForExpectedAmount(
      widget.ocrExtraction,
      widget.enteredAmount,
    );
    final audit = UpiProofOcrService.auditProof(
      extracted: effectiveOcr,
      enteredAmount: widget.enteredAmount,
      existingMembers: widget.existingMembers,
    );
    final (badgeColor, badgeIcon) = switch (audit.severity) {
      UpiProofSeverity.verified => (AppTheme.accent, Icons.verified_rounded),
      UpiProofSeverity.warning => (AppTheme.amber, Icons.warning_amber_rounded),
      UpiProofSeverity.blocked => (AppTheme.danger, Icons.error_rounded),
      UpiProofSeverity.neutral => (Colors.white60, Icons.receipt_long_rounded),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('upi_proof_upload_btn'),
          onTap: _pickScreenshot,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.proofBytes != null
                    ? (audit.isBlocked
                        ? AppTheme.danger.withValues(alpha: 0.7)
                        : AppTheme.accent.withValues(alpha: 0.5))
                    : widget.accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: widget.proofBytes != null
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          widget.proofBytes!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _scanning
                                  ? 'Checking Amount & UTR...'
                                  : 'Payment Screenshot Attached',
                              style: TextStyle(
                                color: audit.isBlocked
                                    ? AppTheme.danger
                                    : AppTheme.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to change screenshot',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _scanning
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.accentColor,
                              ),
                            )
                          : Icon(
                              audit.isBlocked
                                  ? Icons.error_rounded
                                  : Icons.check_circle_rounded,
                              color: audit.isBlocked
                                  ? AppTheme.danger
                                  : AppTheme.accent,
                            ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        color: widget.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'UPLOAD PAYMENT SCREENSHOT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.accentColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (widget.proofBytes != null) ...[
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('upi_audit_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(badgeIcon, size: 17, color: badgeColor),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audit.headline,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (effectiveOcr.amountInr != null) ...[
                        Text(
                          'Paid Entered: ₹${widget.enteredAmount}  •  Screenshot: ₹${effectiveOcr.amountInr}',
                          style: TextStyle(
                            color: audit.isBlocked
                                ? AppTheme.danger
                                : AppTheme.accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        audit.detail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
