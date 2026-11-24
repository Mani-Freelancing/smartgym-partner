import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared_bloc/smart_gym_bloc.dart';
import '../../../shared_bloc/smart_gym_event.dart';
import '../../../shared_bloc/smart_gym_state.dart';
import 'owner_add_member_screen.dart';
import 'owner_gym_settings_sheet.dart';
import 'owner_qr_poster_screen.dart';
import 'owner_register_import_screen.dart';

class OwnerDrawer extends StatelessWidget {
  const OwnerDrawer({super.key});

  void _showAddTrainerSheet(BuildContext context) {
    final bloc = context.read<SmartGymBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final specCtrl =
        TextEditingController(text: 'Floor & Transformation Coach');
    final commCtrl = TextEditingController(text: '50');
    String selectedSlot = 'Morning (6–10 AM)';
    String? errorText;

    const presets = [
      'Floor & Transformation Coach',
      'Strength & Hypertrophy',
      'Fat Loss & Conditioning',
      'CrossFit & Mobility',
    ];
    const slots = [
      'Morning (6–10 AM)',
      'Afternoon (12–4 PM)',
      'Evening (5–9:30 PM)',
      'Full Day',
    ];
    const commPresets = [30, 40, 50, 60, 100];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1E29),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 340),
        reverseDuration: Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.trainerCyan.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppTheme.trainerCyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Trainer by Phone',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Grants instant Trainer Portal access on OTP login',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Trainer Full Name',
                    hintText: 'e.g. Coach Vikram',
                    prefixIcon: const Icon(
                      Icons.badge_outlined,
                      color: AppTheme.trainerCyan,
                      size: 19,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF12151C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(
                      color: AppTheme.trainerCyan,
                      fontWeight: FontWeight.w800,
                    ),
                    labelText: 'Mobile Number',
                    hintText: '98490 00000',
                    prefixIcon: const Icon(
                      Icons.phone_android_rounded,
                      color: AppTheme.trainerCyan,
                      size: 19,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF12151C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specCtrl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Specialty',
                    prefixIcon: const Icon(
                      Icons.fitness_center_rounded,
                      color: AppTheme.trainerCyan,
                      size: 19,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF12151C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((p) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF12151C),
                      side: BorderSide(
                        color: AppTheme.trainerCyan.withValues(alpha: 0.35),
                      ),
                      label: Text(
                        p,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setModalState(() => specCtrl.text = p);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'DUTY SHIFT SLOT',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((slot) {
                    final sel = selectedSlot == slot;
                    return ChoiceChip(
                      label: Text(
                        slot,
                        style: TextStyle(
                          color: sel ? Colors.black : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      selected: sel,
                      selectedColor: AppTheme.ownerGold,
                      backgroundColor: const Color(0xFF12151C),
                      side: BorderSide(
                        color: sel ? AppTheme.ownerGold : Colors.white12,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setModalState(() => selectedSlot = slot);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'TRAINER PT COMMISSION (%)',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: TextField(
                        key: const ValueKey('add_trainer_comm_input'),
                        controller: commCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setModalState(() => errorText = null),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                        decoration: InputDecoration(
                          suffixText: '%',
                          filled: true,
                          fillColor: const Color(0xFF12151C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: commPresets.map((p) {
                          final currentPct =
                              int.tryParse(commCtrl.text.trim()) ?? 50;
                          final sel = currentPct == p;
                          return ChoiceChip(
                            key: ValueKey('add_trainer_comm_$p'),
                            label: Text('$p%'),
                            selected: sel,
                            selectedColor: AppTheme.trainerCyan,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.black : Colors.white70,
                            ),
                            backgroundColor: const Color(0xFF12151C),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                commCtrl.text = '$p';
                                errorText = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.trainerCyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final digits =
                          phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                      final commPct = int.tryParse(commCtrl.text.trim());
                      if (name.isEmpty || digits.length != 10) {
                        HapticFeedback.heavyImpact();
                        setModalState(() {
                          errorText =
                              'Enter trainer name and valid 10-digit mobile number.';
                        });
                        return;
                      }
                      if (commPct == null || commPct < 0 || commPct > 100) {
                        HapticFeedback.heavyImpact();
                        setModalState(() {
                          errorText = 'Commission % must be between 0 and 100.';
                        });
                        return;
                      }
                      HapticFeedback.mediumImpact();
                      bloc.add(
                        AddTrainerToGymEvent(
                          name: name,
                          phone: '+91$digits',
                          specialty: specCtrl.text.trim().isEmpty
                              ? 'Floor & Transformation Coach'
                              : specCtrl.text.trim(),
                          shiftSlot: selectedSlot,
                          commissionPercent: commPct,
                        ),
                      );
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.trainerCyan,
                          content: Text(
                            '$name (+91$digits) added! They can now log in via OTP.',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 19),
                    label: const Text(
                      'ADD TRAINER TO GYM',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRemovedModal(BuildContext context, SmartGymState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(minWidth: double.infinity),
      backgroundColor: const Color(0xFF1A1E29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Text(
                  'Removed Staff & Members (${state.removedRecords.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.removedRecords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No removed trainers or members yet.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.removedRecords.length,
                      itemBuilder: (_, i) {
                        final r = state.removedRecords[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.person_remove_rounded,
                            color: AppTheme.danger,
                          ),
                          title: Text(
                            r.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${r.phone.isNotEmpty ? '${r.phone} • ' : ''}${r.details}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            r.type.toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
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
        return Drawer(
          backgroundColor: const Color(0xFF12151C),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1E29),
                    border: Border(
                      bottom: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.ownerGold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OWNER CEO CONTROL',
                          style: TextStyle(
                            color: AppTheme.ownerGold,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        gym.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (gym.area.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          gym.area,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
                    children: [
                      const _DrawerSectionHeader('ADMISSIONS & MEMBERS'),
                      _DrawerItem(
                        icon: Icons.group_add_rounded,
                        color: AppTheme.ownerGold,
                        title: 'Enroll Paid Member',
                        subtitle: 'Single admission, dues & WhatsApp pass',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<SmartGymBloc>(),
                                child: const OwnerAddMemberScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.document_scanner_rounded,
                        color: AppTheme.ownerGold,
                        title: 'Import From Register / CSV',
                        subtitle: 'AI photo scan or Excel upload',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<SmartGymBloc>(),
                                child: const OwnerRegisterImportScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 18),
                      const _DrawerSectionHeader('STAFF & TEAM'),
                      _DrawerItem(
                        icon: Icons.person_add_alt_1_rounded,
                        color: AppTheme.trainerCyan,
                        title: 'Add Trainer by Phone',
                        subtitle: 'Direct OTP Trainer Portal access',
                        onTap: () {
                          Navigator.pop(context);
                          _showAddTrainerSheet(context);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.qr_code_2_rounded,
                        color: AppTheme.trainerCyan,
                        title: 'Staff Invite QR',
                        subtitle: 'Shareable QR for trainers to join',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<SmartGymBloc>(),
                                child: const OwnerQrPosterScreen(
                                  type: QrPosterType.invite,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 18),
                      const _DrawerSectionHeader('GYM SETUP & CHECK-IN'),
                      _DrawerItem(
                        icon: Icons.storefront_rounded,
                        color: AppTheme.champagne,
                        title: 'Gym Door Check-In QR',
                        subtitle: 'Printable QR poster for floor desk',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<SmartGymBloc>(),
                                child: const OwnerQrPosterScreen(
                                  type: QrPosterType.duty,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.tune_rounded,
                        color: AppTheme.champagne,
                        title: 'Fees, Capacity & GPS Lock',
                        subtitle:
                            '₹${gym.monthlyFee}/mo • ₹${gym.ptFee} PT • ${!gym.requireGpsCheckIn ? 'QR Only' : gym.hasLocation ? 'GPS ${gym.checkInRadiusMeters}m' : 'Set Map / GPS Pin'}',
                        onTap: () {
                          Navigator.pop(context);
                          showOwnerGymSettingsSheet(context, state);
                        },
                      ),
                      const Divider(color: Colors.white10, height: 18),
                      const _DrawerSectionHeader('RECORDS'),
                      _DrawerItem(
                        icon: Icons.person_remove_rounded,
                        color: AppTheme.danger,
                        title: 'Removed Staff & Members',
                        subtitle: '${state.removedRecords.length} total recorded',
                        onTap: () {
                          Navigator.pop(context);
                          _showRemovedModal(context, state);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.logout_rounded, color: Colors.white60),
                  title: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                    context
                        .read<SmartGymBloc>()
                        .add(const LogoutPartnerEvent());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  const _DrawerSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      visualDensity: VisualDensity.compact,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
