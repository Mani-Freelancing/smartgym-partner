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
