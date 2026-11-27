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

        const p = AppPalette.light;

        return Theme(
          data: AppTheme.lightTheme,
          child: Scaffold(
            backgroundColor: p.bg,
            drawer: isOwner ? const OwnerDrawer() : null,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 15, 14, 6),
                    child: Row(
                      children: [
                        if (isOwner) ...[
                          // Golden Brand Crest / Menu Trigger (matches reference header)
                          Builder(
                            builder: (ctx) => GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Scaffold.of(ctx).openDrawer();
                              },
                              child: Tooltip(
                                message: 'Owner Menu',
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFF4D9),
                                        Color(0xFFFDE4B0),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: p.gold.withValues(alpha: 0.45),
                                      width: 1.2,
                                    ),
                                    boxShadow: p.cardShadow,
                                  ),
                                  child: Icon(
                                    Icons.shield_rounded,
                                    color: p.gold,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                        ] else ...[
                          // Trainer Crest Badge in matching sunlit warm theme
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFF4D9),
                                  Color(0xFFFDE4B0),
                                ],
                              ),
                              border: Border.all(
                                color: p.gold.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                              boxShadow: p.cardShadow,
                            ),
                            child: Icon(
                              Icons.fitness_center_rounded,
                              color: p.gold,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 11),
                        ],
                        Expanded(
                          child: isOwner
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: state.selectedGymIndex,
                                        isDense: true,
                                        isExpanded: true,
                                        dropdownColor: p.card,
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: p.textSecondary,
                                          size: 19,
                                        ),
                                        items: List.generate(state.gyms.length,
                                            (index) {
                                          final g = state.gyms[index];
                                          return DropdownMenuItem<int>(
                                            value: index,
                                            child: Text(
                                              g.name.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.4,
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
                                    const SizedBox(height: 1),
                                    Text(
                                      state.currentGym.area.trim().isNotEmpty
                                          ? 'Stronger Together • ${_titleCase(state.currentGym.area)}'
                                          : 'Stronger Together',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TRAINER PORTAL • ${state.loggedInTrainerName.toUpperCase()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.4,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: state.selectedGymIndex,
                                        isDense: true,
                                        isExpanded: true,
                                        dropdownColor: p.card,
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: p.textSecondary,
                                          size: 19,
                                        ),
                                        items: List.generate(state.gyms.length,
                                            (index) {
                                          final g = state.gyms[index];
                                          final areaLabel =
                                              g.area.trim().isNotEmpty
                                                  ? ' (${_titleCase(g.area)})'
                                                  : '';
                                          return DropdownMenuItem<int>(
                                            value: index,
                                            child: Text(
                                              '${g.name.toUpperCase()}$areaLabel',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14.5,
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
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Team & Gym QRs',
                            style: IconButton.styleFrom(
                              fixedSize: const Size(38, 38),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: p.card,
                              foregroundColor: p.gold,
                              side: BorderSide(color: p.border),
                              shape: const CircleBorder(),
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
                              backgroundColor: p.card,
                              side: BorderSide(color: p.border),
                              foregroundColor: p.danger,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
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

String _titleCase(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}
