import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/goals_controller.dart';

/// Hoja "Nueva meta" — espejo de `AddGoalView` (iOS), adaptada al look de los
/// otros formularios Flutter (bottom-sheet con monto hero serif).
///
/// Flujo (de arriba a abajo), 1:1 con iOS:
///   1. Nombre de la meta.
///   2. Monto objetivo (hero serif + quick-amount chips).
///   3. Toggle "Tiene fecha límite" + DatePicker (default: hoy + 6 meses).
///   4. Selector de ícono (16 emojis).
///   5. Prioridad (stepper 0–10).
///   6. Botón guardar (sticky abajo). Valida nombre + monto > 0; **setea
///      `created_by` con el usuario autenticado** (el repo NO lo inyecta) y
///      delega en el controller; haptic de éxito.
class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({super.key});

  /// Presenta la hoja modal con el look del design system. Devuelve `true` si se
  /// guardó (para que el caller refresque si hiciera falta).
  static Future<bool?> show(BuildContext context) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const AddGoalSheet(),
    );
  }

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  /// Catálogo de íconos (16 emojis) — subconjunto del set de iOS, acotado a 16
  /// por el spec del port.
  static const List<String> _icons = <String>[
    '🎯',
    '✈️',
    '🏠',
    '🚗',
    '💻',
    '📱',
    '🎓',
    '💍',
    '🏖️',
    '🎸',
    '🐕',
    '🌍',
    '🏋️',
    '🎮',
    '👶',
    '🌿',
  ];

  // Quick-amount chips (mismos valores que el alta de movimiento).
  static const List<int> _quickAmounts = <int>[10000, 50000, 100000, 500000];

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _targetCtrl = TextEditingController();

  bool _hasTargetDate = false;
  late DateTime _targetDate;
  String _icon = '🎯';
  int _priority = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default de fecha: hoy + 6 meses (igual que iOS). Runtime, no const.
    final DateTime now = DateTime.now();
    _targetDate = DateTime(now.year, now.month + 6, now.day);
    _targetCtrl.addListener(_onChanged);
    _nameCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _targetCtrl.removeListener(_onChanged);
    _nameCtrl.removeListener(_onChanged);
    _targetCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Moneda base del hogar (cae a USD), para el monto hero.
  String get _currency =>
      ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ?? 'USD';

  /// Monto objetivo parseado (> 0) o null.
  Decimal? get _parsedTarget {
    final Decimal? d = Money.parse(_targetCtrl.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave =
        _nameCtrl.text.trim().isNotEmpty && _parsedTarget != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.screen,
                  Insets.md,
                  Insets.screen,
                  Insets.card,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.target,
                            size: 20, color: c.brandPrimary),
                        const SizedBox(width: Insets.md),
                        Text('Nueva meta', style: AppText.h2(c.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: Insets.section),
                    Text('NOMBRE', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _nameCtrl,
                      style: AppText.body(c.textPrimary),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(context,
                          hint: 'Ej. Viaje a la playa'),
                    ),
                    const SizedBox(height: Insets.section),
                    _targetField(context),
                    const SizedBox(height: Insets.section),
                    _targetDateSection(context),
                    const SizedBox(height: Insets.section),
                    _iconSection(context),
                    const SizedBox(height: Insets.section),
                    _prioritySection(context),
                    if (_error != null) ...[
                      const SizedBox(height: Insets.card),
                      Text(_error!, style: AppText.caption(c.brandDanger)),
                    ],
                  ],
                ),
              ),
            ),
            _saveBar(context, canSave),
          ],
        ),
      ),
    );
  }

  // ── Monto objetivo ──────────────────────────────────────────────────────────

  /// Campo de monto objetivo: label con código de moneda, hero serif sage,
  /// quick-amount chips y preview en tiempo real.
  Widget _targetField(BuildContext context) {
    final c = context.colors;
    final Decimal? amount = _parsedTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('OBJETIVO', style: AppText.label(c.textMuted)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: 2),
              decoration: ShapeDecoration(
                color: c.appSurfaceInset,
                shape: const StadiumBorder(),
              ),
              child: Text(
                _currency,
                style: AppText.caption(c.textMuted)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        // Card del monto: gradiente sutil sage→champagne, hero serif sage.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.cardLg,
            vertical: Insets.section,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.brandPrimary.withValues(alpha: 0.10),
                c.brandSecondary.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Radii.hero),
          ),
          child: Row(
            children: [
              Text(
                Money.symbolFor(_currency),
                style: AppText.serifDisplay(
                  amount == null ? c.textDim : c.brandPrimary,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TextField(
                  controller: _targetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.serifHero(
                      amount == null ? c.textDim : c.brandPrimary),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: AppText.serifHero(c.textDim),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        // Quick-amount chips + Limpiar.
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final int v in _quickAmounts) ...[
                _quickAmountChip(context, v),
                const SizedBox(width: Insets.md),
              ],
              _clearChip(context),
            ],
          ),
        ),
        if (amount != null) ...[
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Icon(LucideIcons.check, size: 14, color: c.brandSuccess),
              const SizedBox(width: Insets.sm),
              Text(
                Money.format(amount,
                    currencyCode: _currency,
                    style: MoneyStyle.auto,
                    locale: _locale(context)),
                style: AppText.caption(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Chip "+10k / +50k / …": suma el valor al objetivo actual.
  Widget _quickAmountChip(BuildContext context, int value) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        final Decimal current = Money.parse(_targetCtrl.text) ?? Decimal.zero;
        final Decimal next = current + Decimal.fromInt(value);
        _targetCtrl.text = next.toString().endsWith('.0')
            ? next.toBigInt().toString()
            : next.toString();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        decoration: ShapeDecoration(
          color: c.appSurface,
          shape: StadiumBorder(side: BorderSide(color: c.appBorder)),
        ),
        child: Text(
          '+${_compact(value)}',
          style: AppText.caption(c.textPrimary)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Chip "Limpiar": vacía el objetivo.
  Widget _clearChip(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _targetCtrl.clear();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
        decoration: ShapeDecoration(
          color: c.brandDanger.withValues(alpha: 0.10),
          shape: StadiumBorder(
            side: BorderSide(color: c.brandDanger.withValues(alpha: 0.30)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.x, size: 12, color: c.brandDanger),
            const SizedBox(width: Insets.xs),
            Text(
              'Limpiar',
              style: AppText.caption(c.brandDanger)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fecha límite ────────────────────────────────────────────────────────────

  /// Toggle "Tiene fecha límite" + (si on) selector de fecha. Espejo del
  /// `Toggle` + `DatePicker` de iOS.
  Widget _targetDateSection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.calendarClock, size: 16, color: c.brandPrimary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                'Tiene fecha límite',
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _hasTargetDate,
              activeColor: c.brandPrimary,
              onChanged: (bool v) {
                HapticFeedback.selectionClick();
                setState(() => _hasTargetDate = v);
              },
            ),
          ],
        ),
        if (_hasTargetDate) ...[
          const SizedBox(height: Insets.md),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.screen,
                vertical: Insets.card,
              ),
              decoration: BoxDecoration(
                color: c.appSurfaceInset,
                borderRadius: BorderRadius.circular(Radii.input),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.calendar, size: 16, color: c.textMuted),
                  const SizedBox(width: Insets.md),
                  Text(
                    _formatDate(_targetDate),
                    style: AppText.body(c.textPrimary),
                  ),
                  const Spacer(),
                  Icon(LucideIcons.chevronRight, size: 16, color: c.textMuted),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  // ── Ícono ─────────────────────────────────────────────────────────────────

  /// Selector de ícono: grilla horizontal de emojis seleccionables. Espejo del
  /// `ScrollView(.horizontal)` de íconos de iOS.
  Widget _iconSection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ÍCONO', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _icons.length,
            separatorBuilder: (_, __) => const SizedBox(width: Insets.md),
            itemBuilder: (BuildContext context, int i) {
              final String emoji = _icons[i];
              final bool selected = _icon == emoji;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _icon = emoji);
                },
                child: Container(
                  width: 52,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: selected
                        ? c.brandPrimary.withValues(alpha: 0.18)
                        : c.appSurfaceInset,
                    shape: SmoothRectangleBorder(
                      borderRadius: Radii.smooth(Radii.badge),
                      side: BorderSide(
                        color: selected ? c.brandPrimary : c.appBorder,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Prioridad ───────────────────────────────────────────────────────────────

  /// Stepper de prioridad (0–10). Espejo del `Stepper` de iOS, con − / + y el
  /// valor en el medio.
  Widget _prioritySection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRIORIDAD', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.screen,
            vertical: Insets.lg,
          ),
          decoration: BoxDecoration(
            color: c.appSurfaceInset,
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Prioridad $_priority',
                  style: AppText.body(c.textPrimary),
                ),
              ),
              _StepperButton(
                icon: LucideIcons.minus,
                onTap: _priority > 0 ? () => setState(() => _priority--) : null,
              ),
              const SizedBox(width: Insets.md),
              _StepperButton(
                icon: LucideIcons.plus,
                onTap:
                    _priority < 10 ? () => setState(() => _priority++) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Widget _saveBar(BuildContext context, bool canSave) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.appSurface,
        border: Border(
          top: BorderSide(color: c.appBorder.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.xl,
        Insets.screen,
        Insets.xl,
      ),
      child: MCPrimaryButton(
        label: _saving ? 'Guardando…' : 'Crear meta',
        icon: LucideIcons.check,
        onPressed: (canSave && !_saving) ? _save : null,
      ),
    );
  }

  /// Valida y crea la meta. **Setea `created_by` con el usuario autenticado** (el
  /// repo no lo inyecta) y delega en el controller. 1:1 con el `submit` de iOS.
  Future<void> _save() async {
    setState(() => _error = null);
    final Decimal? target = _parsedTarget;
    if (target == null) {
      setState(() => _error = 'Ingresá un objetivo válido mayor a cero.');
      return;
    }
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ponele un nombre a tu meta.');
      return;
    }
    final String? householdId =
        ref.read(currentHouseholdIdProvider).valueOrNull;
    final String? userId = supabase.auth.currentUser?.id;
    if (householdId == null || userId == null) {
      setState(() => _error = 'No encontramos tu hogar. Reintentá.');
      return;
    }

    setState(() => _saving = true);
    // `id` vacío → el controller lo trata como alta. `currentAmount`/`status`
    // arrancan en cero/active; los defaults de DB también los cubren, pero el
    // modelo los exige no-nulos.
    final Goal goal = Goal(
      id: '',
      householdId: householdId,
      name: name,
      targetAmount: target,
      currentAmount: Decimal.zero,
      currency: _currency,
      targetDate: _hasTargetDate ? _targetDate : null,
      status: GoalStatus.active,
      icon: _icon,
      priority: _priority,
      createdBy: userId,
    );

    try {
      await ref.read(goalsControllerProvider.notifier).saveGoal(goal);
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos crear la meta. Reintentá.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Decoración de input consistente (surface inset + squircle).
  InputDecoration _inputDecoration(BuildContext context,
      {required String hint}) {
    final c = context.colors;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppText.body(c.textDim),
      filled: true,
      fillColor: c.appSurfaceInset,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.screen,
        vertical: Insets.card,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide.none,
      ),
    );
  }

  /// Locale ICU del contexto (es_AR) para `Money.format`.
  String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag().replaceAll('-', '_');

  /// Fecha legible corta (dd MMM yyyy) — formato manual para no depender de
  /// `initializeDateFormatting` con locale arbitrario.
  String _formatDate(DateTime d) {
    const List<String> months = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Etiqueta compacta de un valor entero para el chip (+10k / +500k).
  static String _compact(int value) {
    if (value >= 1000 && value % 1000 == 0) return '${value ~/ 1000}k';
    return '$value';
  }
}

/// Botón circular − / + del stepper de prioridad. Privado a la hoja.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.appSurface,
            shape: StadiumBorder(side: BorderSide(color: c.appBorder)),
          ),
          child: Icon(icon, size: 16, color: c.brandPrimary),
        ),
      ),
    );
  }
}
