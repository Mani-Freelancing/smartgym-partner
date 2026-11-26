import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/gym_member.dart';

/// Shared WhatsApp messaging and admission welcome-pass prompts for Partner apps.
class MemberWhatsAppService {
  static const Color whatsappGreen = Color(0xFF25D366);

  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ? '91$digits' : digits;
  }

  static Future<bool> launchMessage({
    required BuildContext context,
    required String phone,
    required String message,
  }) async {
    final waNumber = normalizePhone(phone);
    if (waNumber.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number on file')),
        );
      }
      return false;
    }

    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$waNumber?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp on this device')),
      );
    }
    return false;
  }

  static Future<bool> sendWelcomePass({
    required BuildContext context,
    required String gymName,
    required GymMember member,
  }) {
    final dueLine = member.hasDue
        ? '\nPending Balance: ₹${member.dueAmount} (kindly clear at reception)'
        : '';
    final coachLine = (member.assignedTrainer?.trim().isNotEmpty ?? false)
        ? '\nCoach Assigned: ${member.assignedTrainer}'
        : '';
    final message =
        'Welcome to *$gymName*, ${member.respectfulName}! 💪\n\n'
        'Your Digital Club Pass is now active:\n'
        '• Plan: ${member.planTitle}\n'
        '• Valid Till: ${member.expiryDate}\n'
        '• Paid Today: ₹${member.feePaid} (${member.paymentMode})'
        '$dueLine'
        '$coachLine\n\n'
        'How to access your Club Pass & Floor QR:\n'
        'Open *SmartGym Club* and sign in with your registered mobile number (${member.phone}).';
    return launchMessage(
      context: context,
      phone: member.phone,
      message: message,
    );
  }

  static Future<bool> sendDueReminder({
    required BuildContext context,
    required String gymName,
    required GymMember member,
  }) {
    final message =
        'Hi ${member.respectfulName}, gentle reminder from *$gymName* regarding your pending fee balance of *₹${member.dueAmount}* '
        '(₹${member.feePaid} paid for ${member.planTitle}). '
        'You can pay via UPI or at the front desk during your next workout. See you on the floor!';
    return launchMessage(
      context: context,
      phone: member.phone,
      message: message,
    );
  }

  static Future<bool> sendExpiryReminder({
    required BuildContext context,
    required String gymName,
    required GymMember member,
  }) {
    final message = member.isExpired
        ? 'Hi ${member.respectfulName}, your ${member.planTitle} membership at $gymName has expired. Reply here or visit the front desk to renew and keep your Digital Club Pass active!'
        : 'Hi ${member.respectfulName}, your ${member.planTitle} membership at $gymName expires in ${member.daysLeft} day(s) (${member.expiryDate}). Renew early at the front desk or via UPI!';
    return launchMessage(
      context: context,
      phone: member.phone,
      message: message,
    );
  }

  /// Shows a crisp 1-tap WhatsApp Welcome Pass confirmation dialog right after enrollment.
  static Future<void> showEnrollmentSuccessDialog({
    required BuildContext context,
    required String gymName,
    required GymMember member,
    Color accentColor = const Color(0xFFE5C158),
  }) async {
    final p = AppPalette.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => Theme(
        data: Theme.of(context),
        child: AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: whatsappGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: whatsappGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Member Enrolled!',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${member.respectfulName} • ${member.planTitle}',
                style: TextStyle(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (member.genderLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Gender: ${member.genderLabel}',
                  style: TextStyle(
                    color: p.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Paid ₹${member.feePaid} (${member.paymentMode})'
                '${member.hasDue ? ' • Pending Due ₹${member.dueAmount}' : ''}',
                style: TextStyle(
                  color: member.hasDue ? p.amber : accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Send a formatted Welcome Pass with gym validity, fee receipt & app login steps directly on WhatsApp.',
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Done',
                style: TextStyle(
                  color: p.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: whatsappGreen,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(dialogCtx);
                if (context.mounted) {
                  await sendWelcomePass(
                    context: context,
                    gymName: gymName,
                    member: member,
                  );
                }
              },
              icon: const Icon(Icons.chat_rounded, size: 17),
              label: const Text(
                'WhatsApp Welcome Pass',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
