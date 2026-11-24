import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cred_neopop_widgets.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';

class CustomerStoreScreen extends StatefulWidget {
  const CustomerStoreScreen({super.key});

  @override
  State<CustomerStoreScreen> createState() => _CustomerStoreScreenState();
}

class _CustomerStoreScreenState extends State<CustomerStoreScreen> {
  final GlobalKey _prCardKey = GlobalKey();
  final TextEditingController _liftCtrl =
      TextEditingController(text: 'Deadlift');
  final TextEditingController _weightCtrl = TextEditingController(text: '140');
  bool _sharing = false;

  @override
  void dispose() {
    _liftCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _sharePrCard(String gymName) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      HapticFeedback.mediumImpact();
      final boundary =
          _prCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/smartgym_pr_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'New PR at $gymName! #SmartGymOS',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Could not share PR card: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final memberName = state.currentMember?.respectfulName.isNotEmpty == true
            ? state.currentMember!.respectfulName
            : 'Club Athlete';
        final scoopRatio = (state.wheyScoopsLeft / 30.0).clamp(0.0, 1.0);
        final lowScoops = state.wheyScoopsLeft <= 5;

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
              // 1. Animated 25-Day Whey Protein Tracker
              CredStaggeredItem(
                index: 0,
                child: CredMetalCard(
                  glowColor: lowScoops ? AppTheme.amber : AppTheme.trainerCyan,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'WHEY PROTEIN TUB TRACKER',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          if (lowScoops)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                'RUNNING LOW',
                                style: TextStyle(
                                  color: AppTheme.amber,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${state.wheyScoopsLeft} / 30 Scoops Left',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Auto-tracks 1 scoop on every gym check-in',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: scoopRatio),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: val,
                              minHeight: 10,
                              backgroundColor: const Color(0xFF12151C),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                lowScoops
                                    ? AppTheme.amber
                                    : AppTheme.trainerCyan,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.trainerCyan,
                            side: const BorderSide(color: AppTheme.trainerCyan),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            context
                                .read<SmartGymBloc>()
                                .add(const RefillWheyTubEvent());
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'REFILL NEW TUB (30 SCOOPS)',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 2. Shareable IG Story PR Card
              const Text(
                'IG STORY PR CARD GENERATOR',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _liftCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Exercise',
                        filled: true,
                        fillColor: const Color(0xFF1A1E29),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        labelText: 'PR (kg)',
                        filled: true,
                        fillColor: const Color(0xFF1A1E29),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RepaintBoundary(
                key: _prCardKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E2434), Color(0xFF12151C)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.ownerGold.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            gym.name.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.ownerGold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const Text(
                            'NEW PR 🏆',
                            style: TextStyle(
                              color: AppTheme.trainerCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _liftCtrl.text.trim().isEmpty
                            ? 'DEADLIFT'
                            : _liftCtrl.text.trim().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_weightCtrl.text.trim().isEmpty ? '140' : _weightCtrl.text.trim()} KG',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$memberName • 🔥 ${state.streakDays} Day Streak',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CredNeoPopButton(
                label: _sharing ? 'PREPARING IMAGE...' : 'SHARE PR CARD TO IG / WHATSAPP',
                icon: Icons.share_rounded,
                color: AppTheme.ownerGold,
                onTap: () => _sharePrCard(gym.name),
              ),
            ],
          ),
        );
      },
    );
  }
}
