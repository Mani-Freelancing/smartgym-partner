import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/gym_fee_plan.dart';

/// Shared multi-plan fee structure editor used in Onboarding Step 2 and Gym Settings.
/// Lets owners customize standard tiers (1M, 3M, 6M, 1Y, PT) and add custom packages.
class GymFeePlansEditor extends StatefulWidget {
  final List<GymFeePlan> plans;
  final ValueChanged<List<GymFeePlan>> onChanged;
  final Color? accentColor;

  const GymFeePlansEditor({
    super.key,
    required this.plans,
    required this.onChanged,
    this.accentColor,
  });

  static String? validatePlans(List<GymFeePlan> plans) {
    if (plans.isEmpty) {
      return 'Keep at least 1 membership plan.';
    }
    if (plans.length > 25) {
      return 'Maximum 25 plans allowed.';
    }
    for (final p in plans) {
      if (p.name.trim().isEmpty || p.name.trim().length > 60) {
        return 'Every plan needs a valid name.';
      }
      if (p.price <= 0 || p.price > 1000000) {
        return 'Enter a valid price (₹1 – ₹10,00,000) for "${p.name}".';
      }
    }
    return null;
  }

  @override
  State<GymFeePlansEditor> createState() => _GymFeePlansEditorState();
}

class _GymFeePlansEditorState extends State<GymFeePlansEditor> {
  final Map<String, TextEditingController> _priceCtrls = {};
  final Map<String, FocusNode> _focusNodes = {};

  static const _quickPresets = [
    GymFeePlan(
      id: 'preset_couple',
      name: 'Couple Plan',
      price: 2500,
      durationDays: 30,
      durationMonths: 1,
      isCustom: true,
    ),
    GymFeePlan(
      id: 'preset_student',
      name: 'Student Offer',
      price: 1200,
      durationDays: 30,
      durationMonths: 1,
      isCustom: true,
    ),
    GymFeePlan(
      id: 'preset_trial_15',
      name: '15-Day Trial',
      price: 700,
      durationDays: 15,
      isCustom: true,
    ),
    GymFeePlan(
      id: 'preset_transform_90',
      name: '90D Transformation PT',
      price: 15000,
      durationDays: 90,
      durationMonths: 3,
      includesPt: true,
      isCustom: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant GymFeePlansEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    final activeIds = widget.plans.map((p) => p.id).toSet();
    final staleIds =
        _priceCtrls.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in staleIds) {
      _priceCtrls.remove(id)?.dispose();
      _focusNodes.remove(id)?.dispose();
    }
    for (final p in widget.plans) {
      final ctrl = _priceCtrls.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.price > 0 ? '${p.price}' : ''),
      );
      final focus = _focusNodes.putIfAbsent(p.id, () => FocusNode());
      final expected = p.price > 0 ? '${p.price}' : '';
      if (!focus.hasFocus && ctrl.text != expected) {
        ctrl.text = expected;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _updatePlanPrice(String id, String rawText) {
    final parsed = int.tryParse(rawText.trim()) ?? 0;
    final next = [
      for (final p in widget.plans)
        if (p.id == id) p.copyWith(price: parsed) else p,
    ];
    widget.onChanged(next);
  }

  void _removePlan(String id) {
    if (widget.plans.length <= 1) return;
    HapticFeedback.selectionClick();
    widget.onChanged(widget.plans.where((p) => p.id != id).toList());
  }

  void _addPreset(GymFeePlan preset) {
    if (widget.plans.length >= 25) return;
    HapticFeedback.selectionClick();
    final alreadyHasName = widget.plans.any(
      (p) => p.name.toLowerCase() == preset.name.toLowerCase(),
    );
    if (alreadyHasName) return;
    final uniqueId =
        'custom_${DateTime.now().millisecondsSinceEpoch}_${widget.plans.length}';
    widget.onChanged([
      ...widget.plans,
      preset.copyWith(id: uniqueId, isCustom: true),
    ]);
  }

  Future<void> _showAddCustomPlanSheet() async {
    if (widget.plans.length >= 25) return;
    HapticFeedback.selectionClick();
    final p = AppPalette.of(context);
    final accent = widget.accentColor ?? p.gold;
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durCtrl = TextEditingController(text: '1');
    bool useMonths = true;
    bool includesPt = false;
    String? sheetError;

    final created = await showModalBottomSheet<GymFeePlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Theme(
        data: Theme.of(context),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: p.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      'Add Custom Plan',
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create packages like Couple Plan, Day Pass, Student Offer, or 45-Day Challenge.',
                      style: TextStyle(color: p.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Plan Name',
                        hintText: 'e.g. Couple Plan / Day Pass',
                        labelStyle: TextStyle(color: p.textSecondary),
                        hintStyle: TextStyle(color: p.textMuted),
                        filled: true,
                        fillColor: p.cardSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Price (₹)',
                              hintText: '2500',
                              prefixText: '₹ ',
                              prefixStyle: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                              labelStyle: TextStyle(color: p.textSecondary),
                              hintStyle: TextStyle(color: p.textMuted),
                              filled: true,
                              fillColor: p.cardSubtle,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: durCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: InputDecoration(
                              labelText: useMonths ? 'Months' : 'Days',
                              hintText: useMonths ? '3' : '15',
                              labelStyle: TextStyle(color: p.textSecondary),
                              hintStyle: TextStyle(color: p.textMuted),
                              filled: true,
                              fillColor: p.cardSubtle,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: p.border),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Months'),
                          selected: useMonths,
                          selectedColor: accent,
                          backgroundColor: p.cardSubtle,
                          side: BorderSide(
                            color: useMonths ? accent : p.border,
                          ),
                          labelStyle: TextStyle(
                            color: useMonths ? p.onAccent : p.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setModalState(() {
                            useMonths = true;
                            if (durCtrl.text == '15' || durCtrl.text == '7') {
                              durCtrl.text = '1';
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Days'),
                          selected: !useMonths,
                          selectedColor: accent,
                          backgroundColor: p.cardSubtle,
                          side: BorderSide(
                            color: !useMonths ? accent : p.border,
                          ),
                          labelStyle: TextStyle(
                            color: !useMonths ? p.onAccent : p.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setModalState(() {
                            useMonths = false;
                            if (durCtrl.text == '1') durCtrl.text = '15';
                          }),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              'PT',
                              style: TextStyle(
                                color: p.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Switch.adaptive(
                              value: includesPt,
                              activeThumbColor: p.gold,
                              onChanged: (v) =>
                                  setModalState(() => includesPt = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (sheetError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        sheetError!,
                        style: TextStyle(
                          color: p.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: p.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final price = int.tryParse(priceCtrl.text.trim());
                          final dur = int.tryParse(durCtrl.text.trim());
                          if (name.isEmpty || name.length > 60) {
                            setModalState(
                              () =>
                                  sheetError = 'Enter a plan name (1–60 chars).',
                            );
                            return;
                          }
                          if (price == null || price <= 0 || price > 1000000) {
                            setModalState(
                              () => sheetError =
                                  'Enter a valid price (₹1 – ₹10,00,000).',
                            );
                            return;
                          }
                          if (dur == null ||
                              dur < 1 ||
                              (useMonths && dur > 36) ||
                              (!useMonths && dur > 1095)) {
                            setModalState(
                              () => sheetError = useMonths
                                  ? 'Enter 1–36 months.'
                                  : 'Enter 1–1095 days.',
                            );
                            return;
                          }
                          Navigator.pop(
                            ctx,
                            GymFeePlan(
                              id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              price: price,
                              durationDays: useMonths ? dur * 30 : dur,
                              durationMonths: useMonths ? dur : null,
                              includesPt: includesPt,
                              isCustom: true,
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_circle_rounded, size: 18),
                        label: const Text(
                          'ADD PLAN',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    priceCtrl.dispose();
    durCtrl.dispose();

    if (created != null && mounted) {
      widget.onChanged([...widget.plans, created]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final baseAccent = widget.accentColor ?? p.gold;
    final availablePresets = _quickPresets
        .where(
          (preset) => !widget.plans.any(
            (plan) => plan.name.toLowerCase() == preset.name.toLowerCase(),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...widget.plans.map((plan) {
          final ctrl = _priceCtrls[plan.id]!;
          final focus = _focusNodes[plan.id]!;
          final accent = plan.includesPt
              ? p.gold
              : (plan.isCustom ? p.cyan : baseAccent);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: p.cardSubtle,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: accent.withValues(alpha: plan.isCustom ? 0.35 : 0.22),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            plan.durationLabel,
                            style: TextStyle(
                              color: p.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (plan.includesPt)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: p.gold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'PT',
                                style: TextStyle(
                                  color: p.gold,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          if (plan.isCustom)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: p.cyan.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'CUSTOM',
                                style: TextStyle(
                                  color: p.cyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: TextField(
                    key: ValueKey('plan_price_${plan.id}'),
                    controller: ctrl,
                    focusNode: focus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    onChanged: (v) => _updatePlanPrice(plan.id, v),
                    style: TextStyle(
                      color: accent,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹',
                      prefixStyle: TextStyle(
                        color: accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      filled: true,
                      fillColor: p.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: p.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: p.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                  ),
                ),
                if (widget.plans.length > 1) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Remove plan',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => _removePlan(plan.id),
                    icon: Icon(
                      Icons.close_rounded,
                      color: p.textMuted,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        if (availablePresets.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'QUICK ADD SPECIAL PACKAGES',
            style: TextStyle(
              color: p.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availablePresets.map((preset) {
              return ActionChip(
                backgroundColor: p.cardSubtle,
                side: BorderSide(
                  color: p.cyan.withValues(alpha: 0.35),
                ),
                label: Text(
                  '+ ${preset.name} (₹${preset.price})',
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => _addPreset(preset),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: p.cyan,
              side: BorderSide(
                color: p.cyan.withValues(alpha: 0.45),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _showAddCustomPlanSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'ADD CUSTOM PLAN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
