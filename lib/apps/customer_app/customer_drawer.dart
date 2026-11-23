import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/attendance_guard_service.dart';
import '../../data/services/hero_avatar_service.dart';
import '../../shared_bloc/smart_gym_bloc.dart';
import '../../shared_bloc/smart_gym_event.dart';
import '../../shared_bloc/smart_gym_state.dart';
import 'auth/customer_cinematic_intro.dart';

class CustomerDrawer extends StatelessWidget {
  /// Toggle to true once Gemini API keys are configured in Firestore `app_config/ai`.
  static const bool _enableCustomPhotoUpload = false;

  const CustomerDrawer({super.key});

  void _openSplashPreview(
    BuildContext context, {
    required String gymName,
    required String memberName,
    required String planTitle,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (ctx, _, _) => CustomerCinematicIntro(
          gymName: gymName,
          memberName: memberName,
          planTitle: planTitle,
          onFinished: () {
            if (Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
          },
        ),
        transitionsBuilder: (ctx, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
          child: child,
        ),
      ),
    );
  }

  void _showAvatarPosePicker(
    BuildContext context, {
    required String gymName,
    required String memberName,
    required String planTitle,
  }) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final picker = ImagePicker();
    bool isProcessingPhoto = false;
    String? inlineStatus;
    bool isStatusError = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          Future<void> pickCustomPhoto(ImageSource source) async {
            setSheetState(() {
              inlineStatus = source == ImageSource.camera
                  ? 'Opening camera...'
                  : 'Opening gallery...';
              isStatusError = false;
            });
            try {
              final XFile? file = await picker.pickImage(
                source: source,
                imageQuality: 85,
                maxWidth: 1200,
              );
              if (file == null) {
                if (sheetCtx.mounted) {
                  setSheetState(() => inlineStatus = null);
                }
                return;
              }
              final selectedPose = HeroAvatarService.selectedPose.value;
              if (sheetCtx.mounted) {
                setSheetState(() {
                  isProcessingPhoto = true;
                  inlineStatus =
                      'Converting your photo into ${selectedPose.title} anime avatar...';
                  isStatusError = false;
                });
              }
              final bytes = await file.readAsBytes();
              final mime = file.path.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : 'image/jpeg';
              final result = await HeroAvatarService.setCustomPhotoAvatar(
                photoBytes: bytes,
                mimeType: mime,
                pose: selectedPose,
              );
              HapticFeedback.heavyImpact();
              if (sheetCtx.mounted) {
                setSheetState(() {
                  inlineStatus = result.message;
                  isStatusError = false;
                });
              }
            } catch (e) {
              if (sheetCtx.mounted) {
                setSheetState(() {
                  inlineStatus = e.toString().replaceFirst('Exception: ', '');
                  isStatusError = true;
                });
              }
            } finally {
              if (sheetCtx.mounted) {
                setSheetState(() => isProcessingPhoto = false);
              }
            }
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.84,
            minChildSize: 0.60,
            maxChildSize: 0.94,
            expand: false,
            builder: (ctx, scrollCtrl) => ValueListenableBuilder<String?>(
              valueListenable: HeroAvatarService.customAvatarPath,
              builder: (ctx, customPath, _) =>
                  ValueListenableBuilder<HeroPoseOption>(
                valueListenable: HeroAvatarService.selectedPose,
                builder: (ctx, currentPose, _) {
                  final hasCustom = customPath != null &&
                      customPath.isNotEmpty &&
                      File(customPath).existsSync();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CHANGE AVATAR POSE',
                                    style: TextStyle(
                                      color: AppTheme.ownerGold,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Your Hero Photo & Poses',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                _openSplashPreview(
                                  rootNavigator.context,
                                  gymName: gymName,
                                  memberName: memberName,
                                  planTitle: planTitle,
                                );
                              },
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                color: AppTheme.trainerCyan,
                                size: 18,
                              ),
                              label: const Text(
                                'Preview',
                                style: TextStyle(
                                  color: AppTheme.trainerCyan,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Customer's Own Photo Upload / Change Card (disabled until AI keys are configured)
                        if (_enableCustomPhotoUpload) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B202C),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: hasCustom
                                  ? AppTheme.trainerCyan
                                  : Colors.white12,
                              width: hasCustom ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 62,
                                  height: 72,
                                  color: const Color(0xFF0D1017),
                                  child: hasCustom
                                      ? Image.file(
                                          File(customPath),
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: AppTheme.trainerCyan,
                                          size: 28,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          hasCustom
                                              ? 'My Custom Avatar'
                                              : 'Use Your Own Photo',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (hasCustom) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.trainerCyan,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: const Text(
                                              'PRIMARY',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isProcessingPhoto
                                          ? 'Converting into ${currentPose.title} anime avatar...'
                                          : 'Converts your photo into ${currentPose.title} anime pose. Tap a pose below first to switch.',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (inlineStatus != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (isStatusError
                                                  ? AppTheme.danger
                                                  : AppTheme.accent)
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: (isStatusError
                                                    ? AppTheme.danger
                                                    : AppTheme.accent)
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                        child: Text(
                                          inlineStatus!,
                                          style: TextStyle(
                                            color: isStatusError
                                                ? AppTheme.danger
                                                : AppTheme.accent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    if (isProcessingPhoto)
                                      const LinearProgressIndicator(
                                        color: AppTheme.trainerCyan,
                                        backgroundColor: Colors.white10,
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppTheme.trainerCyan,
                                                side: BorderSide(
                                                  color: AppTheme.trainerCyan
                                                      .withValues(alpha: 0.45),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 6,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: () => pickCustomPhoto(
                                                ImageSource.camera,
                                              ),
                                              icon: const Icon(
                                                Icons.camera_alt_rounded,
                                                size: 15,
                                              ),
                                              label: Text(
                                                hasCustom ? 'Retake' : 'Camera',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    AppTheme.trainerCyan,
                                                foregroundColor: Colors.black,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 6,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: () => pickCustomPhoto(
                                                ImageSource.gallery,
                                              ),
                                              icon: const Icon(
                                                Icons.photo_library_rounded,
                                                size: 15,
                                              ),
                                              label: Text(
                                                hasCustom
                                                    ? 'Change'
                                                    : 'Gallery',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                        const SizedBox(height: 14),
                        const Text(
                          'WORKOUT POSES (TAP TO SET PRIMARY)',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: GridView.builder(
                            controller: scrollCtrl,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: HeroAvatarService.poses.length,
                            itemBuilder: (ctx, i) {
                              final pose = HeroAvatarService.poses[i];
                              final isPrimary =
                                  !hasCustom && pose.id == currentPose.id;
                              return GestureDetector(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  await HeroAvatarService.setPrimaryPose(pose);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    10,
                                    10,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B202C),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isPrimary
                                          ? pose.accentColor
                                          : Colors.white12,
                                      width: isPrimary ? 2.0 : 1.0,
                                    ),
                                    boxShadow: isPrimary
                                        ? [
                                            BoxShadow(
                                              color: pose.accentColor
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 18,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      Align(
                                        alignment: Alignment.topRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isPrimary
                                                ? pose.accentColor
                                                : Colors.white10,
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            isPrimary ? 'PRIMARY' : 'SELECT',
                                            style: TextStyle(
                                              color: isPrimary
                                                  ? Colors.black
                                                  : Colors.white54,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Image.asset(
                                          pose.assetPath,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        pose.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        pose.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

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
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                    children: [
                      const _DrawerSectionHeader('MEMBERSHIP'),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.card_membership_rounded,
                            color: AppTheme.trainerCyan,
                            size: 19,
                          ),
                        ),
                        title: Text(
                          planTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Valid till $expiry',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                        secondary: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.ac_unit_rounded,
                            color: AppTheme.trainerCyan,
                            size: 19,
                          ),
                        ),
                        activeThumbColor: AppTheme.trainerCyan,
                        title: const Text(
                          'Vacation Freeze',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${state.freezeDaysLeft} freeze days left',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
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
                      const Divider(color: Colors.white10, height: 18),
                      const _DrawerSectionHeader('AVATAR & INTRO'),
                      ValueListenableBuilder<HeroPoseOption>(
                        valueListenable: HeroAvatarService.selectedPose,
                        builder: (context, pose, _) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 2,
                          ),
                          visualDensity: VisualDensity.compact,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.trainerCyan.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.accessibility_new_rounded,
                              color: AppTheme.trainerCyan,
                              size: 19,
                            ),
                          ),
                          title: const Text(
                            'Change Avatar Pose',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            'Primary: ${pose.title} (${HeroAvatarService.poses.length} poses)',
                            style: const TextStyle(
                              color: AppTheme.trainerCyan,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () {
                            final hostCtx =
                                Navigator.of(context, rootNavigator: true)
                                    .context;
                            Navigator.pop(context);
                            _showAvatarPosePicker(
                              hostCtx,
                              gymName: gym.name,
                              memberName: memberName,
                              planTitle: planTitle,
                            );
                          },
                        ),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: AppTheme.trainerCyan,
                            size: 19,
                          ),
                        ),
                        title: const Text(
                          'Replay Power Intro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Preview the fire & power entrance',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _openSplashPreview(
                            context,
                            gymName: gym.name,
                            memberName: memberName,
                            planTitle: planTitle,
                          );
                        },
                      ),
                      const Divider(color: Colors.white10, height: 18),
                      const _DrawerSectionHeader('TEST TOOLS'),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.trainerCyan.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppTheme.trainerCyan,
                            size: 19,
                          ),
                        ),
                        title: const Text(
                          'Reset Today\'s Scan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'Clear today check-in/out to scan freshly',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                        ),
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final memberKey = member?.phone.isNotEmpty == true
                              ? member!.phone
                              : state.authenticatedPhone;
                          Navigator.pop(context);
                          await AttendanceGuardService.clearTodayStatus(
                            gymId: gym.id,
                            memberKey: memberKey,
                          );
                          HapticFeedback.mediumImpact();
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: AppTheme.trainerCyan,
                              content: Text(
                                'Today\'s entry cleared — you can scan Door QR freshly!',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                ),
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

class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  const _DrawerSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
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
