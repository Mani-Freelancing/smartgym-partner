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
  static const _filters = ['All', 'Chest', 'Back', 'Legs', 'Shoulders'];

  void _showMachineGuideSheet(BuildContext context, MachineGuide g) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1E29),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
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
                  color: AppTheme.trainerCyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${g.code} • ${g.muscle}',
                  style: const TextStyle(
                    color: AppTheme.trainerCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                g.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.ownerGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TRAINER FORM & POSTURE TIP',
                      style: TextStyle(
                        color: AppTheme.ownerGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'GOT IT',
                    style: TextStyle(fontWeight: FontWeight.w900),
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
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(
          title: 'Scan Machine QR',
          subtitle: 'Point camera at any gym machine QR sticker.',
          accentColor: AppTheme.ownerGold,
        ),
      ),
    );
    if (raw == null || !context.mounted) return;
    final match = guides.where(
      (g) => raw.toLowerCase().contains(g.code.toLowerCase()),
    );
    if (match.isNotEmpty) {
      _showMachineGuideSheet(context, match.first);
    } else if (guides.isNotEmpty) {
      _showMachineGuideSheet(context, guides.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('No machine guide found for this QR yet.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              CredNeoPopButton(
                label: 'SCAN MACHINE QR FOR FORM GUIDE',
                icon: Icons.qr_code_scanner_rounded,
                color: AppTheme.ownerGold,
                onTap: () => _scanMachineQr(context, state.machineGuides),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.map((f) {
                    final sel = _muscleFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: sel,
                        selectedColor: AppTheme.trainerCyan,
                        backgroundColor: const Color(0xFF1A1E29),
                        labelStyle: TextStyle(
                          color: sel ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _muscleFilter = f);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'EQUIPMENT FORM GUIDES',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                CredMetalCard(
                  glowColor: AppTheme.trainerCyan,
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'No machine guides added yet.\nYour trainers can add Machine QR guides from the Trainer Portal.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ...List.generate(filtered.length, (i) {
                final g = filtered[i];
                return CredStaggeredItem(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _showMachineGuideSheet(context, g),
                      child: CredMetalCard(
                        glowColor: AppTheme.trainerCyan,
                        padding: const EdgeInsets.all(16),
                        borderRadius: 18,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.trainerCyan
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    g.muscle,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppTheme.ownerGold,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              CredMetalCard(
                glowColor: AppTheme.champagne,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BOOK PERSONAL TRAINING (VIP)',
                      style: TextStyle(
                        color: AppTheme.champagne,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1-on-1 Coaching + Custom Diet Plan • ₹${gym.ptFee}/mo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.champagne,
                          side: const BorderSide(color: AppTheme.champagne),
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
          ),
        );
      },
    );
  }
}
