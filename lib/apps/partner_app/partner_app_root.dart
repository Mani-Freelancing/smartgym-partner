import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/partner_role.dart';
import '../../shared_bloc/smart_gym_bloc.dart';
import '../../shared_bloc/smart_gym_event.dart';
import '../../shared_bloc/smart_gym_state.dart';
import 'auth/partner_login_screen.dart';
import 'auth/partner_onboarding_screen.dart';
import 'owner/owner_drawer.dart';
import 'owner/owner_shell_screen.dart';
import 'owner/owner_team_qr_sheet.dart';
import 'trainer/trainer_shell_screen.dart';

class PartnerAppRoot extends StatelessWidget {
  const PartnerAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        if (state.isAuthChecking) {
          return const Scaffold(
            backgroundColor: AppTheme.scaffoldBg,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.ownerGold),
            ),
          );
        }

        if (state.needsOnboarding) {
          return const PartnerOnboardingScreen();
        }

        if (!state.isPartnerLoggedIn) {
          return const PartnerLoginScreen();
        }

        if (state.gyms.isEmpty) {
          return const Scaffold(
            backgroundColor: AppTheme.scaffoldBg,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.ownerGold),
            ),
          );
        }

        final isOwner = state.partnerRole == PartnerRole.owner;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          drawer: isOwner ? const OwnerDrawer() : null,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                  child: Row(
                    children: [
                      if (isOwner) ...[
                        Builder(
                          builder: (ctx) => IconButton(
                            tooltip: 'Owner Menu',
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppTheme.ownerGold.withValues(alpha: 0.14),
                              foregroundColor: AppTheme.ownerGold,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Scaffold.of(ctx).openDrawer();
                            },
                            icon: const Icon(Icons.menu_rounded, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOwner
                                  ? 'OWNER CEO PORTAL • VERIFIED'
                                  : 'TRAINER PORTAL • ${state.loggedInTrainerName.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: isOwner
                                    ? AppTheme.ownerGold
                                    : AppTheme.trainerCyan,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Multi-Branch Dropdown Selector
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: state.selectedGymIndex,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF171A24),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                items:
                                    List.generate(state.gyms.length, (index) {
                                  final g = state.gyms[index];
                                  return DropdownMenuItem<int>(
                                    value: index,
                                    child: Text(
                                      '${g.name} (${g.area})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }),
                                onChanged: (idx) {
                                  if (idx != null) {
                                    HapticFeedback.selectionClick();
                                    context
                                        .read<SmartGymBloc>()
                                        .add(SelectGymTenantEvent(idx));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Team & Gym QRs',
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.ownerGold.withValues(alpha: 0.14),
                            foregroundColor: AppTheme.ownerGold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: const Color(0xFF1A1E29),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (_) => BlocProvider.value(
                                value: context.read<SmartGymBloc>(),
                                child: const OwnerTeamQrSheet(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_2_rounded, size: 19),
                        ),
                      ],
                      if (!isOwner) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white70,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            context
                                .read<SmartGymBloc>()
                                .add(const LogoutPartnerEvent());
                          },
                          icon: const Icon(Icons.logout_rounded, size: 15),
                          label: const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: isOwner
                      ? const OwnerShellScreen()
                      : const TrainerShellScreen(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
