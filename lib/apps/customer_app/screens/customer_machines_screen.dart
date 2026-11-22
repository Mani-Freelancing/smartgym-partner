import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../domain/models/machine_guide.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';
import '../../partner_app/shared/qr_scanner_screen.dart';

class CustomerMachinesScreen extends StatefulWidget {
  const CustomerMachinesScreen({super.key});

  @override
  State<CustomerMachinesScreen> createState() => _CustomerMachinesScreenState();
}

class _CustomerMachinesScreenState extends State<CustomerMachinesScreen> {
  String _muscleFilter = 'All';
  static const _filters = [
    'All',
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
  ];

  void _showMachineGuideSheet(BuildContext context, MachineGuide g) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141822),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppTheme.trainerCyan.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '${g.code} • ${g.muscle.toUpperCase()}',
                  style: const TextStyle(
                    color: AppTheme.trainerCyan,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                g.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1118),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.trainerCyan.withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRAINER FORM & POSTURE TIP',
                      style: TextStyle(
                        color: AppTheme.trainerCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      g.mistakeTip,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.trainerCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'GOT IT',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanMachineQr(
    BuildContext context,
    List<MachineGuide> guides,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(
          title: 'Scan Machine QR',
          subtitle: 'Point camera at any gym machine QR sticker.',
          accentColor: AppTheme.trainerCyan,
        ),
      ),
    );
    if (raw == null || !context.mounted) return;

    final uri = Uri.tryParse(raw);
    final codeParam = uri?.queryParameters['code'] ?? '';
    final target = (codeParam.isNotEmpty ? codeParam : raw).trim().toLowerCase();

    final match = guides.where(
      (g) => target == g.code.toLowerCase() || target.contains(g.code.toLowerCase()),
    );
    if (match.isNotEmpty) {
      HapticFeedback.mediumImpact();
      _showMachineGuideSheet(context, match.first);
    } else {
      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(
            'Unrecognized Machine QR. Please scan an official equipment sticker.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final isPtActive = state.currentMember?.isPtClient ?? false;
        final filtered = state.machineGuides.where((g) {
          if (_muscleFilter == 'All') return true;
          return g.muscle.toLowerCase().contains(_muscleFilter.toLowerCase());
        }).toList();

        return RefreshIndicator(
          color: AppTheme.trainerCyan,
          backgroundColor: const Color(0xFF1A1E29),
          onRefresh: () async {
            context.read<SmartGymBloc>().add(const RefreshGymDataEvent());
            await Future<void>.delayed(const Duration(milliseconds: 450));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              // 1. Sleek Stadium Pill Machine QR CTA (matches Home)
              GestureDetector(
                onTap: () => _scanMachineQr(context, state.machineGuides),
                child: Container(
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.trainerCyan.withValues(alpha: 0.22),
                        AppTheme.trainerCyan.withValues(alpha: 0.07),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.trainerCyan.withValues(alpha: 0.75),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.trainerCyan.withValues(alpha: 0.16),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.trainerCyan,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'SCAN MACHINE QR FOR FORM GUIDE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.trainerCyan,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Clean Muscle Group Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final sel = _muscleFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _muscleFilter = f);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.trainerCyan
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: sel
                                  ? AppTheme.trainerCyan
                                  : Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: sel ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Open Editorial Equipment List (hairline divided, no outer boxes)
              Row(
                children: [
                  const Text(
                    'EQUIPMENT FORM GUIDES',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length} ${filtered.length == 1 ? "GUIDE" : "GUIDES"}',
                    style: const TextStyle(
                      color: AppTheme.trainerCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No machine guides matching this filter yet.\nTrainers can add Machine QR guides from the Partner App.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ...List.generate(filtered.length, (i) {
                final g = filtered[i];
                final isLast = i == filtered.length - 1;
                return CredStaggeredItem(
                  index: i,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showMachineGuideSheet(context, g),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.trainerCyan
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.trainerCyan
                                        .withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Text(
                                  g.code,
                                  style: const TextStyle(
                                    color: AppTheme.trainerCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      g.muscle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                color: AppTheme.trainerCyan,
                                size: 26,
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(color: Colors.white12, height: 1),
                      ],
                    ),
                  ),
                );
              }),

              // 4. Smart VIP PT Card (only shown if not already a VIP PT member)
              if (!isPtActive) ...[
                const SizedBox(height: 20),
                CredMetalCard(
                  glowColor: AppTheme.trainerCyan,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PERSONAL TRAINING • VIP',
                        style: TextStyle(
                          color: AppTheme.trainerCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1-on-1 Coaching + Custom Diet • ₹${gym.ptFee}/mo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.trainerCyan,
                            side: BorderSide(
                              color:
                                  AppTheme.trainerCyan.withValues(alpha: 0.65),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final upiUri = Uri.parse(
                              'upi://pay?pa=smartgym@upi&pn=${Uri.encodeComponent(gym.name)}&am=${gym.ptFee}&cu=INR&tn=${Uri.encodeComponent('PT VIP Plan')}',
                            );
                            await launchUrl(
                              upiUri,
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          child: Text(
                            'UPGRADE VIA ₹0-FEE UPI (₹${gym.ptFee})',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
