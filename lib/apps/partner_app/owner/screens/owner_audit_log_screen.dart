import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cred_neopop_widgets.dart';
import '../../../../data/services/member_whatsapp_service.dart';
import '../../../../data/services/upi_proof_ocr_service.dart';
import '../../../../domain/models/gym_fee_plan.dart';
import '../../../../domain/models/gym_member.dart';
import '../../../../shared_bloc/smart_gym_bloc.dart';
import '../../../../shared_bloc/smart_gym_event.dart';
import '../../../../shared_bloc/smart_gym_state.dart';
import '../../shared/upi_payment_proof_section.dart';

/// Formats integer rupee values using Indian comma grouping (e.g. `₹1,50,000`).
String formatInr(int amount) {
  final s = amount.toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3);
  final reg = RegExp(r'(\d+?)(?=(\d\d)+$)');
  return '₹${rest.replaceAllMapped(reg, (m) => '${m[1]},')},$last3';
}

/// Separate screen housing the full member directory, search, filters,
/// payment proofs, pending dues collection, and removal actions.
class OwnerAuditLogScreen extends StatefulWidget {
  final String initialFilter;
  final bool embedded;
  final String? activeFilter;
  final ValueChanged<String>? onFilterChanged;

  const OwnerAuditLogScreen({
    super.key,
    this.initialFilter = 'All',
    this.embedded = false,
    this.activeFilter,
    this.onFilterChanged,
  });

  /// Pushes [OwnerAuditLogScreen] wired with the active [SmartGymBloc].
  static Future<void> open(
    BuildContext context, {
    String initialFilter = 'All',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<SmartGymBloc>(),
          child: OwnerAuditLogScreen(initialFilter: initialFilter),
        ),
      ),
    );
  }

  @override
  State<OwnerAuditLogScreen> createState() => _OwnerAuditLogScreenState();
}

class _OwnerAuditLogScreenState extends State<OwnerAuditLogScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  late String _selectedFilter;

  static const _filters = [
    'All',
    'Dues',
    'Expiring',
    'PT VIP',
    'Online',
    'Cash',
  ];

  String get _effectiveFilter {
    final candidate =
        widget.onFilterChanged != null ? widget.activeFilter : _selectedFilter;
    if (candidate != null && _filters.contains(candidate)) return candidate;
    return 'All';
  }

  void _selectFilter(String f) {
    if (widget.onFilterChanged != null) {
      widget.onFilterChanged!(f);
    } else {
      setState(() => _selectedFilter = f);
    }
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.activeFilter ?? widget.initialFilter;
    _selectedFilter = _filters.contains(initial) ? initial : 'All';
  }

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
          '✅ Collected ₹$collected balance from ${m.respectfulName}',
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
      final matchesFilter = switch (_effectiveFilter) {
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
          m.respectfulName.toLowerCase().contains(q) ||
          m.genderLabel.toLowerCase().contains(q) ||
          m.phone.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmRemoveMember(BuildContext context, GymMember m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E29),
        title: Text(
          'Remove ${m.respectfulName}?',
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
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
              memberName: m.respectfulName,
              details: '${m.planTitle} • ₹${m.feePaid}',
            ),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1A1E29),
          content: Text(
            '${m.respectfulName} removed from gym.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  void _showRenewMemberSheet(
    BuildContext context,
    GymMember m,
    SmartGymState state,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(minWidth: double.infinity),
      backgroundColor: const Color(0xFF1A1E29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<SmartGymBloc>(),
        child: _RenewMemberSheet(member: m, state: state),
      ),
    );
  }

  void _showPaymentProofDialog(BuildContext context, GymMember m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E29),
        title: Text(
          '${m.respectfulName} • Payment Proof',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(m.paymentProofBase64),
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartGymBloc, SmartGymState>(
      builder: (context, state) {
        final gym = state.currentGym;
        final filteredMembers = _applyFilter(state.members);

        final content = RefreshIndicator(
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (widget.embedded) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'WHO JOINED & AUDIT LOG',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${filteredMembers.length} of ${state.members.length} shown',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  key: const ValueKey('audit_log_search_input'),
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search members by name or phone...',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 13),
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
                      final sel = _effectiveFilter == f;
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
                            _selectFilter(f);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                if (state.members.isEmpty)
                  CredMetalCard(
                    glowColor: AppTheme.ownerGold,
                    padding: const EdgeInsets.all(20),
                    child: const Text(
                      'No gym members added yet.\nOnce you or your trainers enroll paid members, the complete audit log will appear here.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  )
                else if (filteredMembers.isEmpty)
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
                ...List.generate(filteredMembers.length, (i) {
                  final GymMember m = filteredMembers[i];
                  return Padding(
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
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        m.respectfulName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (m.genderLabel.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          m.genderLabel,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    formatInr(m.feePaid),
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
                                        color: AppTheme.softRed,
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
                                  if (val == 'renew') {
                                    _showRenewMemberSheet(context, m, state);
                                    return;
                                  }
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
                                  if (val == 'remove') {
                                    await _confirmRemoveMember(context, m);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem<String>(
                                    value: 'renew',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.autorenew_rounded,
                                          color: AppTheme.ownerGold,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Renew Plan',
                                          style: TextStyle(
                                            color: AppTheme.ownerGold,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                                color: AppTheme.softRed.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.softRed.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.pending_actions_rounded,
                                    size: 15,
                                    color: AppTheme.softRed,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      '₹${m.dueAmount} pending balance',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.softRed,
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
                                        color: MemberWhatsAppService
                                            .whatsappGreen
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
                                  onTap: () =>
                                      _showPaymentProofDialog(context, m),
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
                          if (m.daysLeft <= 5) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    m.isExpired
                                        ? 'Membership expired'
                                        : 'Expires in ${m.daysLeft}d',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: m.isExpired
                                          ? AppTheme.softRed
                                          : AppTheme.amber,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  key: ValueKey('renew_member_${m.id}'),
                                  onTap: () =>
                                      _showRenewMemberSheet(context, m, state),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.ownerGold
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.ownerGold
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.autorenew_rounded,
                                          size: 13.5,
                                          color: AppTheme.ownerGold,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Renew Plan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppTheme.ownerGold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );

        if (widget.embedded) return content;

        return Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            backgroundColor: AppTheme.scaffoldBg,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Who Joined & Audit Log',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${gym.name} • ${filteredMembers.length} of ${state.members.length} shown',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          body: content,
        );
      },
    );
  }
}

class _RenewMemberSheet extends StatefulWidget {
  final GymMember member;
  final SmartGymState state;

  const _RenewMemberSheet({
    required this.member,
    required this.state,
  });

  @override
  State<_RenewMemberSheet> createState() => _RenewMemberSheetState();
}

class _RenewMemberSheetState extends State<_RenewMemberSheet> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late List<GymFeePlan> _plans;
  late GymFeePlan _selectedPlan;
  late TextEditingController _feeCtrl;
  late TextEditingController _dueCtrl;
  late bool _isPt;
  String? _selectedTrainer;
  String _paymentMode = 'Cash';
  Uint8List? _proofBytes;
  String _proofBase64 = '';
  UpiProofExtraction _ocrExtraction = const UpiProofExtraction();
  String? _errorText;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  @override
  void initState() {
    super.initState();
    _plans = widget.state.currentGym.effectiveFeePlans;
    final lowerPlan = widget.member.planTitle.toLowerCase();
    _selectedPlan = _plans.firstWhere(
      (p) => p.name.toLowerCase() == lowerPlan,
      orElse: () => _plans.first,
    );
    _feeCtrl = TextEditingController(text: '${_selectedPlan.price}');
    _dueCtrl = TextEditingController(text: '0');
    _isPt = _selectedPlan.includesPt || widget.member.isPtClient;
    final trainers = widget.state.trainers;
    if (trainers.isNotEmpty) {
      final prev = widget.member.assignedTrainer;
      _selectedTrainer = (prev != null && trainers.any((t) => t.name == prev))
          ? prev
          : trainers.first.name;
    }
  }

  @override
  void dispose() {
    _feeCtrl.dispose();
    _dueCtrl.dispose();
    super.dispose();
  }

  void _selectPlan(GymFeePlan plan) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPlan = plan;
      _feeCtrl.text = '${plan.price}';
      _isPt = plan.includesPt;
      _errorText = null;
    });
  }

  DateTime _computeNewExpiry(DateTime today) {
    final base = widget.member.daysLeft > 0
        ? today.add(Duration(days: widget.member.daysLeft))
        : today;
    return base.add(Duration(days: _selectedPlan.durationDays));
  }

  void _submit() {
    final fee = int.tryParse(_feeCtrl.text.trim()) ?? 0;
    final extraDue = int.tryParse(_dueCtrl.text.trim()) ?? 0;
    if (fee <= 0 && extraDue <= 0) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = 'Enter valid fee paid or due amount.');
      return;
    }

    final utr = _paymentMode == 'Online' ? _ocrExtraction.utr.trim() : '';
    if (_paymentMode == 'Online') {
      if (_proofBase64.isEmpty) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorText = 'Please upload UPI screenshot proof for Online renewal.';
        });
        return;
      }
      final refined = UpiProofOcrService.refineForExpectedAmount(
        _ocrExtraction,
        fee,
      );
      final audit = UpiProofOcrService.auditProof(
        extracted: refined,
        enteredAmount: fee,
        existingMembers: widget.state.members,
      );
      if (audit.isBlocked) {
        HapticFeedback.heavyImpact();
        setState(() => _errorText = audit.detail);
        return;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newExpiry = _computeNewExpiry(today);
    final daysLeft = newExpiry.difference(today).inDays.clamp(1, 3650);
    final todayStr = _formatDate(today);
    final expiryStr = _formatDate(newExpiry);
    final trainerName = _isPt
        ? (_selectedTrainer ??
            (widget.state.trainers.isNotEmpty
                ? widget.state.trainers.first.name
                : widget.state.currentGym.headTrainer))
        : null;

    HapticFeedback.mediumImpact();
    context.read<SmartGymBloc>().add(
          RenewMemberPlanEvent(
            memberId: widget.member.id,
            planTitle: _selectedPlan.name,
            feePaid: fee,
            dueAmount: widget.member.dueAmount + extraDue,
            joinedDate: todayStr,
            expiryDate: expiryStr,
            daysLeft: daysLeft,
            isPtClient: _isPt,
            assignedTrainer: trainerName,
            paymentMode: _paymentMode,
            paymentReference: utr,
            paymentProofBase64: _paymentMode == 'Online' ? _proofBase64 : '',
          ),
        );

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1E29),
        content: Text(
          '✅ Renewed ${widget.member.respectfulName} (${_selectedPlan.name}) until $expiryStr',
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newExpiry = _computeNewExpiry(today);
    final newDaysLeft = newExpiry.difference(today).inDays;
    final enteredFee = int.tryParse(_feeCtrl.text.trim()) ?? 0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
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
                  margin: const EdgeInsets.only(bottom: 16),
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
                      color: AppTheme.ownerGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.autorenew_rounded,
                      color: AppTheme.ownerGold,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Renew ${widget.member.respectfulName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.member.planTitle} • ${widget.member.isExpired ? 'Expired' : '${widget.member.daysLeft}d left'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'SELECT RENEWAL PLAN',
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
                children: _plans.map((plan) {
                  final selected = _selectedPlan.id == plan.id;
                  return ChoiceChip(
                    key: ValueKey('renew_plan_${plan.id}'),
                    label: Text(
                      '${plan.name} • ₹${plan.price}',
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppTheme.ownerGold,
                    backgroundColor: const Color(0xFF12151C),
                    side: BorderSide(
                      color: selected ? AppTheme.ownerGold : Colors.white12,
                    ),
                    onSelected: (_) => _selectPlan(plan),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('renew_fee_input'),
                      controller: _feeCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      onChanged: (_) => setState(() => _errorText = null),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        labelText: 'Fee Collected',
                        filled: true,
                        fillColor: const Color(0xFF12151C),
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
                      key: const ValueKey('renew_due_input'),
                      controller: _dueCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        labelText: 'Extra Due (Opt.)',
                        filled: true,
                        fillColor: const Color(0xFF12151C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.member.hasDue) ...[
                const SizedBox(height: 8),
                Text(
                  'Existing unpaid due of ₹${widget.member.dueAmount} will be kept alongside any new due.',
                  style: const TextStyle(
                    color: AppTheme.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Include Personal Training (PT)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: _isPt,
                          activeThumbColor: AppTheme.ownerGold,
                          onChanged: (v) => setState(() => _isPt = v),
                        ),
                      ],
                    ),
                    if (_isPt && widget.state.trainers.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.state.trainers.map((t) {
                          final sel = _selectedTrainer == t.name;
                          return ChoiceChip(
                            label: Text(
                              t.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: sel ? Colors.black : Colors.white70,
                              ),
                            ),
                            selected: sel,
                            selectedColor: AppTheme.trainerCyan,
                            backgroundColor: const Color(0xFF1A1E29),
                            onSelected: (_) =>
                                setState(() => _selectedTrainer = t.name),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      key: const ValueKey('renew_mode_cash'),
                      label: const Center(child: Text('Cash')),
                      selected: _paymentMode == 'Cash',
                      selectedColor: AppTheme.accent,
                      labelStyle: TextStyle(
                        color: _paymentMode == 'Cash'
                            ? Colors.black
                            : Colors.white70,
                        fontWeight: FontWeight.w900,
                      ),
                      backgroundColor: const Color(0xFF12151C),
                      onSelected: (_) => setState(() {
                        _paymentMode = 'Cash';
                        _errorText = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      key: const ValueKey('renew_mode_online'),
                      label: const Center(child: Text('Online / UPI')),
                      selected: _paymentMode == 'Online',
                      selectedColor: AppTheme.ownerGold,
                      labelStyle: TextStyle(
                        color: _paymentMode == 'Online'
                            ? Colors.black
                            : Colors.white70,
                        fontWeight: FontWeight.w900,
                      ),
                      backgroundColor: const Color(0xFF12151C),
                      onSelected: (_) => setState(() {
                        _paymentMode = 'Online';
                        _errorText = null;
                      }),
                    ),
                  ),
                ],
              ),
              if (_paymentMode == 'Online') ...[
                const SizedBox(height: 10),
                UpiPaymentProofSection(
                  proofBytes: _proofBytes,
                  ocrExtraction: _ocrExtraction,
                  enteredAmount: enteredFee,
                  existingMembers: widget.state.members,
                  onProofSelected: (res) {
                    setState(() {
                      _proofBytes = res.bytes;
                      _proofBase64 = res.base64;
                      _ocrExtraction = res.ocr;
                      _errorText = null;
                    });
                  },
                  onError: (msg) => setState(() => _errorText = msg),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.ownerGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.ownerGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'New Expiry: ${_formatDate(newExpiry)} ($newDaysLeft days validity)',
                  style: const TextStyle(
                    color: AppTheme.ownerGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppTheme.softRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  key: const ValueKey('renew_submit_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.ownerGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.check_circle_rounded, size: 19),
                  label: const Text(
                    'CONFIRM RENEWAL',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
