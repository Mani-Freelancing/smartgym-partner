import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_state.dart';

enum QrPosterType { invite, duty }

class OwnerQrPosterScreen extends StatefulWidget {
  final QrPosterType type;

  const OwnerQrPosterScreen({super.key, required this.type});

  @override
  State<OwnerQrPosterScreen> createState() => _OwnerQrPosterScreenState();
}

class _OwnerQrPosterScreenState extends State<OwnerQrPosterScreen> {
  final GlobalKey _posterKey = GlobalKey();
  String? _inviteCode;
  bool _loadingCode = false;
  bool _exporting = false;

  bool get _isInvite => widget.type == QrPosterType.invite;

  @override
  void initState() {
    super.initState();
    if (_isInvite) _loadInviteCode();
  }

  Future<void> _loadInviteCode() async {
    final bloc = context.read<SmartGymBloc>();
    final fs = bloc.firestoreService;
    final gym = bloc.state.currentGym;
    if (fs == null || gym.id.isEmpty) return;
    setState(() => _loadingCode = true);
    try {
      final code = await fs.ensureActiveInviteCode(gym.id, gym.name);
      if (mounted) setState(() => _inviteCode = code);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  Future<String> _saveToDownloads(List<int> bytes, String fileName) async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      try {
        if (await publicDownloads.exists()) {
          final out = File('${publicDownloads.path}/$fileName');
          await out.writeAsBytes(bytes);
          return 'Downloads/$fileName';
        }
      } catch (_) {}
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final out = File('${extDir.path}/$fileName');
        await out.writeAsBytes(bytes);
        return out.path;
      }
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final out = File('${docsDir.path}/$fileName');
    await out.writeAsBytes(bytes);
    return out.path;
  }

  Future<File?> _capturePosterPng(String filePrefix) async {
    final boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _shareOrSavePng({required bool isDownload}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      HapticFeedback.mediumImpact();
      final gym = context.read<SmartGymBloc>().state.currentGym;
      final prefix = _isInvite ? 'smartgym_invite_qr' : 'smartgym_duty_qr';
      final file = await _capturePosterPng(prefix);
      if (file == null || !mounted) return;

      if (isDownload) {
        final bytes = await file.readAsBytes();
        final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedLocation = await _saveToDownloads(bytes, fileName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.trainerCyan,
            content: Text(
              'Image saved to $savedLocation',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${gym.name} - ${_isInvite ? 'Staff Invite QR' : 'Duty QR'}',
        text: 'Scan this QR in SmartGym Partner for ${gym.name}.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Could not export image: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf(String payload, SmartGymState state) async {
    if (_exporting || payload.isEmpty) return;
    setState(() => _exporting = true);
    try {
      HapticFeedback.mediumImpact();
      final gym = state.currentGym;
      final doc = pw.Document();
      final title = _isInvite ? 'STAFF INVITE QR' : 'RECEPTION DUTY CHECK-IN QR';
      final desc = _isInvite
          ? 'Open SmartGym Partner -> Verify OTP -> Floor Trainer -> Scan Invite QR.\nOwner approval is required after scanning.'
          : 'Open SmartGym Partner -> Radar & QR -> Scan Duty QR at gym reception.';

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Container(
                width: 420,
                padding: const pw.EdgeInsets.all(32),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(18),
                  border: pw.Border.all(color: PdfColors.grey800, width: 2),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      gym.name.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (gym.area.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        gym.area,
                        style: const pw.TextStyle(
                          fontSize: 13,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 20),
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber800,
                      ),
                    ),
                    pw.SizedBox(height: 18),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: payload,
                      width: 240,
                      height: 240,
                    ),
                    if (_isInvite && _inviteCode != null) ...[
                      pw.SizedBox(height: 14),
                      pw.Text(
                        'INVITE CODE: $_inviteCode',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 16),
                    pw.Text(
                      desc,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Text(
                      'Powered by SmartGym OS',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final prefix = _isInvite ? 'smartgym_invite_qr' : 'smartgym_duty_qr';
      final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfBytes = await doc.save();
      final savedLocation = await _saveToDownloads(pdfBytes, fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.ownerGold,
          content: Text(
            'PDF saved to $savedLocation',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Could not export PDF: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showDownloadOptions(String payload, SmartGymState state) {
    showModalBottomSheet(
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
                'Download QR Poster',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppTheme.ownerGold,
                ),
                title: const Text(
                  'Download as PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'Printable A4 gym poster',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportPdf(payload, state);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.image_rounded,
                  color: AppTheme.trainerCyan,
                ),
                title: const Text(
                  'Download as Image (PNG)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: const Text(
                  'High-res image with gym & section name',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareOrSavePng(isDownload: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final accent = _isInvite ? AppTheme.trainerCyan : AppTheme.ownerGold;
        final payload = _isInvite
            ? (_inviteCode != null
                ? 'smartgym://invite?gymId=${gym.id}&code=$_inviteCode'
                : '')
            : 'smartgym://duty?gymId=${gym.id}';

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            backgroundColor: AppTheme.scaffoldBg,
            foregroundColor: Colors.white,
            title: Text(
              _isInvite ? 'Staff Invite QR' : 'Reception Duty QR',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            actions: [
              IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download_rounded),
                onPressed: (_exporting || payload.isEmpty)
                    ? null
                    : () => _showDownloadOptions(payload, state),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RepaintBoundary(
                  key: _posterKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1E29),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: accent.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          gym.name.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (gym.area.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            gym.area,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            _isInvite
                                ? 'STAFF INVITE QR'
                                : 'RECEPTION DUTY CHECK-IN QR',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_loadingCode)
                          Padding(
                            padding: const EdgeInsets.all(60),
                            child: CircularProgressIndicator(color: accent),
                          )
                        else if (payload.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: QrImageView(
                              data: payload,
                              size: 210,
                              backgroundColor: Colors.white,
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'Could not load QR.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        if (_isInvite && _inviteCode != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            'CODE: $_inviteCode',
                            style: TextStyle(
                              color: accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          _isInvite
                              ? 'Trainers scan this QR to request access. You approve them in Trainers & PT Split.'
                              : 'Print & stick at reception. Trainers scan this daily to mark duty attendance.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (_exporting || payload.isEmpty)
                        ? null
                        : () => _shareOrSavePng(isDownload: false),
                    icon: const Icon(Icons.share_rounded, size: 19),
                    label: const Text(
                      'SHARE QR',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
