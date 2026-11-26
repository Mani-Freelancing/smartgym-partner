import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/app_theme.dart';
import '../../shared_bloc/smart_gym_bloc.dart';
import '../../shared_bloc/smart_gym_event.dart';

/// Shows an explicit confirmation modal before dispatching [LogoutPartnerEvent]
/// across Owner, Trainer, and Customer flows.
Future<bool> confirmAndLogout(
  BuildContext context, {
  bool closeDrawer = false,
  Future<void> Function()? beforeLogout,
  String title = 'Log Out?',
  String message = 'Are you sure you want to log out of this account?',
  String confirmLabel = 'Log Out',
}) async {
  HapticFeedback.selectionClick();
  final bloc = context.read<SmartGymBloc>();
  final p = AppPalette.of(context);
  final dangerColor = p.danger;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: dangerColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.logout_rounded,
              color: dangerColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: p.textSecondary,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('logout_cancel_btn'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: p.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton(
          key: const ValueKey('logout_confirm_btn'),
          style: FilledButton.styleFrom(
            backgroundColor: dangerColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  HapticFeedback.mediumImpact();
  if (beforeLogout != null) {
    await beforeLogout();
  }
  if (closeDrawer && context.mounted) {
    Navigator.of(context).pop();
  }
  bloc.add(const LogoutPartnerEvent());
  return true;
}
