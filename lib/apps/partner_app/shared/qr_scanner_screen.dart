import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const QrScannerScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.accentColor = AppTheme.trainerCyan,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _picker = ImagePicker();
  bool _handled = false;
  bool _scanningGallery = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scanFromGallery() async {
    if (_handled || _scanningGallery) return;
    setState(() => _scanningGallery = true);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final capture = await _controller.analyzeImage(picked.path);
      if (!mounted) return;
      final barcodes = capture?.barcodes ?? [];
      for (final barcode in barcodes) {
        final raw = barcode.rawValue;
        if (raw != null && raw.isNotEmpty) {
          _handled = true;
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop(raw);
          return;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFFF6B6B),
          content: Text(
            'No QR code found in the selected image.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFFF6B6B),
          content: Text(
            'Could not read QR from image. Please try again.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningGallery = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _handled = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan from Gallery',
            icon: const Icon(Icons.photo_library_rounded),
            onPressed: _scanningGallery ? null : _scanFromGallery,
          ),
          IconButton(
            tooltip: 'Toggle Flash',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.accentColor, width: 3),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xCC12151C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.accentColor,
                        side: BorderSide(color: widget.accentColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _scanningGallery ? null : _scanFromGallery,
                      icon: _scanningGallery
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.accentColor,
                              ),
                            )
                          : const Icon(Icons.photo_library_rounded, size: 18),
                      label: Text(
                        _scanningGallery
                            ? 'READING IMAGE...'
                            : 'UPLOAD QR FROM GALLERY',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
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
