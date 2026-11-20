import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../shared_bloc/smart_gym_bloc.dart';
import '../../shared_bloc/smart_gym_event.dart';
import '../../shared_bloc/smart_gym_state.dart';
import 'auth/customer_cinematic_intro.dart';

class CustomerDrawer extends StatelessWidget {
  const CustomerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final member = state.currentMember;
        final memberName = member?.name ?? 'Club Member';
        final phone = member?.phone ?? state.authenticatedPhone;
        final planTitle = member?.planTitle ?? '1-Month Regular';
        final expiry = member?.expiryDate ?? '30d validity';

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
                          color: AppTheme.trainerCyan.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          gym.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.trainerCyan,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        memberName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
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
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    children: [
                      ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.ownerGold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.card_membership_rounded,
                            color: AppTheme.ownerGold,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          planTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Valid till $expiry',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      SwitchListTile(
                        secondary: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.ac_unit_rounded,
                            color: AppTheme.trainerCyan,
                            size: 20,
                          ),
                        ),
                        activeThumbColor: AppTheme.trainerCyan,
                        title: const Text(
                          'Vacation Freeze',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${state.freezeDaysLeft} freeze days left',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        value: state.isMembershipFrozen,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          context
                              .read<SmartGymBloc>()
                              .add(ToggleVacationFreezeEvent(v));
                        },
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B2B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFFF6B2B),
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Replay Power Intro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Preview the fire & power entrance',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => CustomerCinematicIntro(
                                gymName: gym.name,
                                memberName: memberName,
                                planTitle: planTitle,
                                onFinished: () => Navigator.of(ctx).pop(),
                              ),
                            ),
                          );
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
