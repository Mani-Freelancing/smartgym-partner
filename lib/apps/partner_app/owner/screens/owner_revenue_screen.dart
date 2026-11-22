import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../data/services/member_whatsapp_service.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';

class OwnerRevenueScreen extends StatefulWidget {
  const OwnerRevenueScreen({super.key});

  @override
  State<OwnerRevenueScreen> createState() => _OwnerRevenueScreenState();
}

class _OwnerRevenueScreenState extends State<OwnerRevenueScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';

  static const _filters = [
    'All',
    'Dues',
    'Expiring',
    'PT VIP',
    'Online',
    'Cash',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _collectMemberDue(BuildContext context, GymMember m) {
    HapticFeedback.mediumImpact();
    final collected = m.dueAmount;
    context.read<SmartGymBloc>().add(
          CollectMemberDueEvent(
            memberId: m.id,
            duePaid: collected,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1E29),
        content: Text(
          '✅ Collected ₹$collected balance from ${m.name}',
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  List<GymMember> _applyFilter(List<GymMember> all) {
    return all.where((m) {
      final matchesFilter = switch (_selectedFilter) {
        'Dues' => m.hasDue,
        'Expiring' => m.daysLeft <= 5,
        'PT VIP' => m.isPtClient,
        'Online' => m.paymentMode == 'Online',
        'Cash' => m.paymentMode != 'Online',
        _ => true,
      };
      if (!matchesFilter) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.phone.toLowerCase().contains(q);
    }).toList();
  }

  String _formatInr(int amount) {
    final s = amount.toString();
    if (s.length <= 3) return '₹$s';
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final reg = RegExp(r'(\d+?)(?=(\d\d)+$ )');
    return '₹${rest.replaceAllMapped(reg, (m) => '${m[1]},')},$last3';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final expiringList = state.expiringOrExpiredMembers;
        final pendingEnquiries =
            state.enquiries.where((e) => !e.converted).length;

        return RefreshIndicator(
          color: AppTheme.ownerGold,
          backgroundColor: const Color(0xFF1A1E29),
          onRefresh: () async {
            context.read<SmartGymBloc>().add(const RefreshGymDataEvent());
            await Future<void>.delayed(const Duration(milliseconds: 450));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            // 1. CEO Revenue & Active Member Summary Card
            CredStaggeredItem(
              index: 0,
              child: CredMetalCard(
                glowColor: AppTheme.ownerGold,
                enableShimmer: true,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${gym.name.toUpperCase()} • CEO OVERVIEW',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ownerGold,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1A1E29),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  'Reset Live Floor Count?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                                content: Text(
                                  'Currently showing ${state.liveCrowd} member(s) on the floor. Reset count to 0 for a fresh shift/day?',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.accent,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () {
                                      context
                                          .read<SmartGymBloc>()
                                          .add(const ResetGymFloorCrowdEvent());
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      'Reset to 0',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${state.liveCrowd} IN FLOOR NOW',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.accent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.refresh_rounded,
                                  size: 11,
                                  color: AppTheme.accent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatInr(state.totalMonthlyRevenue),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Total Monthly Revenue (Memberships + Personal Training)',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildStatTile(
                          label: 'Active Members',
                          value: '${state.activeMembersCount}',
                          sub: '${state.ptMembers.length} on PT VIP',
                          valueColor: AppTheme.accent,
                        ),
                        const SizedBox(width: 10),
                        _buildStatTile(
                          label: state.totalPendingDues > 0
                              ? 'Pending Dues'
                              : 'Expiring / Due',
                          value: state.totalPendingDues > 0
                              ? _formatInr(state.totalPendingDues)
                              : '${expiringList.length}',
                          sub: state.totalPendingDues > 0
                              ? '${state.dueMembers.length} member(s) owe'
                              : 'Within 5 days',
                          valueColor: state.totalPendingDues > 0
                              ? AppTheme.amber
                              : AppTheme.danger,
                        ),
                        const SizedBox(width: 10),
                        _buildStatTile(
                          label: 'Walk-In Leads',
                          value: '$pendingEnquiries',
                          sub: 'Pending follow-up',
                          valueColor: AppTheme.champagne,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Expiry & Renewal Alert Section
            const Text(
              'EXPIRING & OVERDUE MEMBERSHIPS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            ...expiringList.map((GymMember m) {
              final expired = m.isExpired;
              final statusColor = expired ? AppTheme.danger : AppTheme.amber;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CredMetalCard(
                  glowColor: statusColor,
                  padding: const EdgeInsets.all(16),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${m.planTitle} • Expiry: ${m.expiryDate}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Send WhatsApp Reminder',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF25D366).withValues(alpha: 0.16),
                          foregroundColor: const Color(0xFF25D366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          MemberWhatsAppService.sendExpiryReminder(
                            context: context,
                            gymName: gym.name,
                            member: m,
                          );
                        },
                        icon: const Icon(Icons.chat_rounded, size: 17),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          expired ? 'EXPIRED' : '${m.daysLeft}D LEFT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 18),

            // 3. Who Joined & Anti-Fraud Audit Log
            const Text(
              'WHO JOINED & MEMBER DIRECTORY (AUDIT LOG)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Search members by name or phone...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.ownerGold,
                  size: 19,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A1E29),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.ownerGold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final sel = _selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        f,
                        style: TextStyle(
                          color: sel ? Colors.black : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      selected: sel,
                      selectedColor: AppTheme.ownerGold,
                      backgroundColor: const Color(0xFF1A1E29),
                      side: BorderSide(
                        color: sel ? AppTheme.ownerGold : Colors.white12,
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedFilter = f);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (state.members.isEmpty)
              CredMetalCard(
                glowColor: AppTheme.ownerGold,
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'No gym members added yet.\nOnce your trainers add paid members or convert walk-in leads, they will appear here live.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
              )
            else if (_applyFilter(state.members).isEmpty)
              CredMetalCard(
                glowColor: AppTheme.ownerGold,
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'No members match your search or filter.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
            ...List.generate(_applyFilter(state.members).length, (i) {
              final GymMember m = _applyFilter(state.members)[i];
              return CredStaggeredItem(
                index: i + 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CredMetalCard(
                    glowColor:
                        m.isPtClient ? AppTheme.champagne : AppTheme.accent,
                    padding: const EdgeInsets.all(16),
                    borderRadius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${m.feePaid}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppTheme.accent,
                                  ),
                                ),
                                if (m.hasDue)
                                  Text(
                                    '₹${m.dueAmount} DUE',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      color: AppTheme.amber,
                                    ),
                                  ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                              color: const Color(0xFF1A1E29),
                              onSelected: (val) async {
                                if (val == 'welcome') {
                                  HapticFeedback.selectionClick();
                                  await MemberWhatsAppService.sendWelcomePass(
                                    context: context,
                                    gymName: gym.name,
                                    member: m,
                                  );
                                  return;
                                }
                                if (val == 'remind_due') {
                                  HapticFeedback.selectionClick();
                                  await MemberWhatsAppService.sendDueReminder(
                                    context: context,
                                    gymName: gym.name,
                                    member: m,
                                  );
                                  return;
                                }
                                if (val == 'mark_paid') {
                                  _collectMemberDue(context, m);
                                  return;
                                }
                                if (val != 'remove') return;
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1E29),
                                    title: Text(
                                      'Remove ${m.name}?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    content: const Text(
                                      'This will remove this member from your gym directory and database.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.danger,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  context.read<SmartGymBloc>().add(
                                        RemoveMemberFromGymEvent(
                                          memberId: m.id,
                                          phone: m.phone,
                                          memberName: m.name,
                                          details: '${m.planTitle} • ₹${m.feePaid}',
                                        ),
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF1A1E29),
                                      content: Text(
                                        '${m.name} removed from gym.',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem<String>(
                                  value: 'welcome',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.chat_rounded,
                                        color: MemberWhatsAppService
                                            .whatsappGreen,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Send Welcome Pass',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (m.hasDue) ...[
                                  const PopupMenuItem<String>(
                                    value: 'remind_due',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_active_rounded,
                                          color: AppTheme.amber,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'WhatsApp Due Reminder',
                                          style: TextStyle(
                                            color: AppTheme.amber,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'mark_paid',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppTheme.accent,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Mark ₹${m.dueAmount} Due Paid',
                                          style: const TextStyle(
                                            color: AppTheme.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_remove_rounded,
                                        color: AppTheme.danger,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Remove Member',
                                        style: TextStyle(
                                          color: AppTheme.danger,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m.planTitle} • Joined: ${m.joinedDate} • Expires: ${m.expiryDate} (${m.daysLeft}d)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        if (m.hasDue) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.amber.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.pending_actions_rounded,
                                  size: 15,
                                  color: AppTheme.amber,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    '₹${m.dueAmount} pending balance',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.amber,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    MemberWhatsAppService.sendDueReminder(
                                      context: context,
                                      gymName: gym.name,
                                      member: m,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MemberWhatsAppService.whatsappGreen
                                          .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.chat_rounded,
                                          size: 13,
                                          color: MemberWhatsAppService
                                              .whatsappGreen,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Remind',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: MemberWhatsAppService
                                                .whatsappGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _collectMemberDue(context, m),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Mark Paid',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 13,
                              color: AppTheme.champagne,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                m.isPtClient
                                    ? 'PT Trainer: ${m.assignedTrainer}  •  Added by ${m.addedByTrainer}'
                                    : 'General Floor  •  Added by ${m.addedByTrainer}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.champagne,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: (m.paymentMode == 'Online'
                                        ? AppTheme.ownerGold
                                        : AppTheme.accent)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                m.paymentMode.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: m.paymentMode == 'Online'
                                      ? AppTheme.ownerGold
                                      : AppTheme.accent,
                                ),
                              ),
                            ),
                            if (m.paymentMode == 'Online' &&
                                (m.paymentProofBase64.isNotEmpty ||
                                    m.paymentReference.isNotEmpty)) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1A1E29),
                                      title: Text(
                                        '${m.name} • Payment Proof',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (m.paymentReference.isNotEmpty)
                                            Text(
                                              'UTR / Ref: ${m.paymentReference}',
                                              style: const TextStyle(
                                                color: AppTheme.ownerGold,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          if (m.paymentProofBase64.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                base64Decode(
                                                    m.paymentProofBase64),
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text(
                                  'View Proof',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.ownerGold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required String sub,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Colors.white54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
