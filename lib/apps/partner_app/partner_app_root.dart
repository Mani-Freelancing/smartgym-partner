import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logout_confirm_dialog.dart';
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
          return Theme(
            data: AppTheme.lightTheme,
            child: const Scaffold(
              backgroundColor: AppTheme.lightScaffoldBg,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.lightOwnerGold,
                ),
              ),
            ),
          );
        }

        if (state.needsOnboarding) {
          return Theme(
            data: AppTheme.darkTheme,
            child: const PartnerOnboardingScreen(),
          );
        }

        if (!state.isPartnerLoggedIn) {
          return Theme(
            data: AppTheme.lightTheme,
            child: const PartnerLoginScreen(),
          );
        }

        final isOwner = state.partnerRole == PartnerRole.owner;
        if (state.gyms.isEmpty) {
          return Theme(
            data: isOwner ? AppTheme.lightTheme : AppTheme.darkTheme,
            child: Scaffold(
              backgroundColor:
                  isOwner ? AppTheme.lightScaffoldBg : AppTheme.scaffoldBg,
              body: Center(
                child: CircularProgressIndicator(
                  color: isOwner ? AppTheme.lightOwnerGold : AppTheme.ownerGold,
                ),
              ),
            ),
          );
        }

        final p = isOwner ? AppPalette.light : AppPalette.dark;

        return Theme(
          data: isOwner ? AppTheme.lightTheme : AppTheme.darkTheme,
          child: Scaffold(
            backgroundColor: p.bg,
            drawer: isOwner ? const OwnerDrawer() : null,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        if (isOwner) ...[
                          Builder(
                            builder: (ctx) => IconButton(
                              tooltip: 'Owner Menu',
                              style: IconButton.styleFrom(
                                fixedSize: const Size(40, 40),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: p.isDark
                                    ? p.gold.withValues(alpha: 0.12)
                                    : p.card,
                                foregroundColor:
                                    p.isDark ? p.gold : p.textPrimary,
                                side: p.isDark
                                    ? null
                                    : BorderSide(color: p.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
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
                                  color: isOwner ? p.gold : p.cyan,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Multi-Branch Dropdown Selector
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: state.selectedGymIndex,
                                  isDense: true,
                                  isExpanded: true,
                                  dropdownColor: p.card,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: p.textSecondary,
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
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: p.textPrimary,
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
                              fixedSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: p.isDark
                                  ? p.gold.withValues(alpha: 0.12)
                                  : p.card,
                              foregroundColor: p.gold,
                              side: p.isDark
                                  ? null
                                  : BorderSide(color: p.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: p.card,
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
                            onPressed: () => confirmAndLogout(context),
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
          ),
        );
      },
    );
  }
}
