import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../data/services/register_ai_importer_service.dart';
import '../../../domain/models/gym_member.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class OwnerRegisterImportScreen extends StatefulWidget {
  const OwnerRegisterImportScreen({super.key});

  @override
  State<OwnerRegisterImportScreen> createState() =>
      _OwnerRegisterImportScreenState();
}

class _OwnerRegisterImportScreenState extends State<OwnerRegisterImportScreen> {
  final _service = RegisterAiImporterService();
  final _picker = ImagePicker();

  bool _isScanning = false;
  bool _hasApiKey = false;
  String? _statusMessage;
  List<ImportedRegisterRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final key = await _service.getEffectiveApiKey();
    if (mounted) setState(() => _hasApiKey = key.isNotEmpty);
  }

  Future<void> _showDeveloperKeyDialog() async {
    final current = await _service.getEffectiveApiKey();
    if (!mounted) return;
    final p = AppPalette.light;
    final ctrl = TextEditingController(text: current);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AppTheme.ensureOwnerLight(
        context,
        child: AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'AI Vision Engine (Admin)',
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optional: Set your Gemini API key for high-accuracy handwriting & column-header recognition. (For production builds, pass --dart-define=GEMINI_API_KEY=...)',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                style: TextStyle(color: p.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: TextStyle(color: p.textMuted),
                  filled: true,
                  fillColor: p.cardSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: p.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: p.textMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.goldButton,
                foregroundColor: p.onAccent,
              ),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved != null) {
      await _service.saveApiKey(saved);
      if (mounted) {
        setState(() => _hasApiKey = saved.isNotEmpty);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved.isEmpty
                  ? 'Switched to On-Device OCR'
                  : 'Gemini Vision AI enabled',
            ),
          ),
        );
      }
    }
  }

  Future<void> _scanFromImage(ImageSource source, int defaultFee) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning register page...';
    });

    try {
      final Uint8List bytes = await file.readAsBytes();
      final ext = file.path.toLowerCase();
      final mime = ext.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final extracted = await _service.extractFromImageFile(
        imagePath: file.path,
        imageBytes: bytes,
        mimeType: mime,
        defaultFee: defaultFee,
      );

      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _rows = extracted;
        _statusMessage = extracted.isEmpty
            ? 'No readable member rows found. Try a clearer photo or Paste CSV.'
            : 'Extracted ${extracted.length} members from register photo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan failed: $e';
      });
    }
  }

  Future<void> _showPasteTextSheet(int defaultFee) async {
    final p = AppPalette.light;
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => AppTheme.ensureOwnerLight(
        context,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Paste Excel / CSV / WhatsApp List',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Format: Name, Phone, Plan, Fee, DaysLeft (1 member per line)',
                style: TextStyle(color: p.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 6,
                style: TextStyle(color: p.textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText:
                      'Rahul Sharma, 9876543210, Monthly, 1500, 24\nKarthik V, 9849011223, 3 Months, 4000, 72',
                  hintStyle: TextStyle(color: p.textMuted),
                  filled: true,
                  fillColor: p.cardSubtle,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      ctrl.text =
                          'Rahul Sharma, 9876543210, Monthly, $defaultFee, 25\n'
                          'Karthik R, 9849012345, 3 Months, ${defaultFee * 3}, 78\n'
                          'Priya Nair, 9123456789, PT Plan, 6500, 18';
                    },
                    child: Text(
                      'Load Sample',
                      style: TextStyle(
                        color: p.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: p.goldButton,
                      foregroundColor: p.onAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      final parsed = _service.parseFromText(
                        rawText: ctrl.text,
                        defaultFee: defaultFee,
                      );
                      Navigator.pop(ctx);
                      setState(() {
                        _rows = parsed;
                        _statusMessage = parsed.isEmpty
                            ? 'Could not parse any rows. Check format.'
                            : 'Parsed ${parsed.length} members from text.';
                      });
                    },
                    child: const Text(
                      'Parse Rows',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editRowDialog(int index) async {
    final p = AppPalette.light;
    final row = _rows[index];
    final nameCtrl = TextEditingController(text: row.name);
    final phoneCtrl = TextEditingController(
      text: row.phone.replaceFirst('+91', ''),
    );
    final planCtrl = TextEditingController(text: row.planTitle);
    final feeCtrl = TextEditingController(text: '${row.feePaid}');
    final daysCtrl = TextEditingController(text: '${row.daysLeft}');

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppTheme.ensureOwnerLight(
        context,
        child: AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Member Row',
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editField(nameCtrl, 'Name', p: p),
                const SizedBox(height: 10),
                _editField(phoneCtrl, 'Phone (10 digits)', isNumber: true, p: p),
                const SizedBox(height: 10),
                _editField(planCtrl, 'Plan Title', p: p),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _editField(feeCtrl, 'Fee (₹)', isNumber: true, p: p),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _editField(daysCtrl, 'Days Left', isNumber: true, p: p),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: p.textMuted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      setState(() {
        row.name = nameCtrl.text.trim();
        final digits = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
        row.phone = digits.length >= 10
            ? '+91${digits.substring(digits.length - 10)}'
            : digits;
        row.planTitle = planCtrl.text.trim().isEmpty
            ? 'Monthly'
            : planCtrl.text.trim();
        row.feePaid = int.tryParse(feeCtrl.text.trim()) ?? row.feePaid;
        row.daysLeft = int.tryParse(daysCtrl.text.trim()) ?? row.daysLeft;
      });
    }
  }

  Widget _editField(
    TextEditingController ctrl,
    String label, {
    bool isNumber = false,
    required AppPalette p,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: p.textPrimary, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
        filled: true,
        fillColor: p.cardSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
      ),
    );
  }

  void _importSelected(SmartGymState state) {
    final p = AppPalette.light;
    final selectedRows = _rows.where((r) => r.selected && r.name.isNotEmpty).toList();
    if (selectedRows.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final addedBy = state.loggedInTrainerName.isEmpty
        ? 'Owner'
        : state.loggedInTrainerName;

    final members = <GymMember>[];
    for (int i = 0; i < selectedRows.length; i++) {
      final r = selectedRows[i];
      members.add(
        GymMember(
          id: 'mem_${nowMs}_$i',
          name: r.name,
          phone: r.phone.isEmpty ? '+910000000000' : r.phone,
          planTitle: r.planTitle,
          feePaid: r.feePaid,
          joinedDate: 'Register Import',
          expiryDate: r.daysLeft >= 0
              ? '${r.daysLeft}d left'
              : 'Expired ${r.daysLeft.abs()}d ago',
          daysLeft: r.daysLeft,
          assignedTrainer: r.planTitle.toLowerCase().contains('pt')
              ? state.currentGym.headTrainer
              : null,
          isPtClient: r.planTitle.toLowerCase().contains('pt'),
          addedByTrainer: addedBy,
          paymentMode: 'Cash',
        ),
      );
    }

    HapticFeedback.heavyImpact();
    context.read<SmartGymBloc>().add(ImportBulkMembersEvent(members));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: p.accent,
        content: Text(
          'Imported ${members.length} members into ${state.currentGym.name}!',
          style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800),
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.ensureOwnerLight(
      context,
      child: BlocBuilder<SmartGymBloc, SmartGymState>(
        builder: (context, state) {
          final p = AppPalette.of(context);
          final defaultFee = state.currentGym.monthlyFee;
          final selectedCount = _rows.where((r) => r.selected).length;

          return Scaffold(
            backgroundColor: p.bg,
            appBar: AppBar(
              backgroundColor: p.bg,
              foregroundColor: p.textPrimary,
              elevation: 0,
              title: const Text(
                'Register Photo Importer',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              actions: [
                IconButton(
                  tooltip: _hasApiKey ? 'Gemini AI Active' : 'AI Engine Settings',
                  onPressed: _showDeveloperKeyDialog,
                  icon: Icon(
                    _hasApiKey ? Icons.auto_awesome_rounded : Icons.tune_rounded,
                    color: _hasApiKey ? p.accent : p.textMuted,
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      CredMetalCard(
                        glowColor: p.cyan,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZERO-TYPING GYM ONBOARDING',
                              style: TextStyle(
                                color: p.cyan,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Snap a photo of any paper register page or paste Excel/CSV rows to import dozens of members in seconds.',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _SourceButton(
                                    icon: Icons.camera_alt_rounded,
                                    label: 'Snap Photo',
                                    color: p.gold,
                                    onTap: _isScanning
                                        ? null
                                        : () => _scanFromImage(
                                              ImageSource.camera,
                                              defaultFee,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SourceButton(
                                    icon: Icons.photo_library_rounded,
                                    label: 'Gallery',
                                    color: p.cyan,
                                    onTap: _isScanning
                                        ? null
                                        : () => _scanFromImage(
                                              ImageSource.gallery,
                                              defaultFee,
                                            ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SourceButton(
                                    icon: Icons.paste_rounded,
                                    label: 'Paste CSV',
                                    color: p.accent,
                                    onTap: _isScanning
                                        ? null
                                        : () => _showPasteTextSheet(defaultFee),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_isScanning) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: CircularProgressIndicator(
                            color: p.cyan,
                          ),
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.cardSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.border),
                          ),
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      if (_rows.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              'REVIEW EXTRACTED MEMBERS (${_rows.length})',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: p.textMuted,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                final allSelected =
                                    _rows.every((element) => element.selected);
                                setState(() {
                                  for (final r in _rows) {
                                    r.selected = !allSelected;
                                  }
                                });
                              },
                              child: Text(
                                _rows.every((r) => r.selected)
                                    ? 'Unselect All'
                                    : 'Select All',
                                style: TextStyle(
                                  color: p.gold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...List.generate(_rows.length, (i) {
                          final row = _rows[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _editRowDialog(i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: p.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: row.selected
                                        ? p.accent.withValues(alpha: 0.45)
                                        : p.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: row.selected,
                                      activeColor: p.accent,
                                      checkColor: p.onAccent,
                                      onChanged: (v) {
                                        setState(
                                            () => row.selected = v ?? false);
                                      },
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.name,
                                            style: TextStyle(
                                              color: p.textPrimary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${row.phone.isEmpty ? "No phone" : row.phone} • ${row.planTitle} • ₹${row.feePaid} • ${row.daysLeft}d left',
                                            style: TextStyle(
                                              color: p.textSecondary,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.edit_outlined,
                                      color: p.textMuted,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                if (selectedCount > 0)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: p.accent,
                            foregroundColor: p.onAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => _importSelected(state),
                          icon: const Icon(Icons.bolt_rounded),
                          label: Text(
                            'IMPORT $selectedCount MEMBERS TO GYM',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
