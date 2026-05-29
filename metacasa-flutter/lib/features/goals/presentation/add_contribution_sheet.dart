import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/goals_controller.dart';

/// Hoja "Nuevo aporte" — espejo de `AddContributionView` (iOS), adaptada al look
/// de los formularios Flutter (bottom-sheet con monto hero serif).
///
/// Flujo (de arriba a abajo):
///   1. Monto a aportar (hero serif sage + quick-amount chips).
///   2. "Restante: X" — cuánto falta para completar la meta (chip "Completar"
///      que precarga el monto restante exacto).
///   3. Nota opcional.
///   4. Botón guardar (sticky abajo). Valida monto > 0 y delega en
///      `GoalsController.contribute`, que inserta el aporte y devuelve la meta YA
///      recargada (el trigger de DB ajusta `current_amount`). Esa meta se
///      devuelve al caller (detalle) vía `Navigator.pop`.
class AddContributionSheet extends ConsumerStatefulWidget {
  const AddContributionSheet({super.key, required this.goal});

  /// Meta a la que se aporta (provee moneda + restante).
  final Goal goal;

  /// Presenta la hoja modal. Devuelve la [Goal] recargada (con `current_amount`
  /// ya actualizado) si se guardó, o `null` si se canceló.
  static Future<Goal?> show(BuildContext context, Goal goal) {
    final c = context.colors;
    return showModalBottomSheet<Goal>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddContributionSheet(goal: goal),
    );
  }

  @override
  ConsumerState<AddContributionSheet> createState() =>
      _AddContributionSheetState();
}

class _AddContributionSheetState extends ConsumerState<AddContributionSheet> {
  // Quick-amount chips para aportes.
  static const List<int> _quickAmounts = <int>[5000, 10000, 50000, 100000];

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onChanged);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String get _currency => widget.goal.currency;

  /// Monto restante para completar la meta (target − current), nunca negativo.
  Decimal get _remaining {
    final Decimal diff = widget.goal.targetAmount - widget.goal.currentAmount;
    return diff > Decimal.zero ? diff : Decimal.zero;
  }

  /// Monto parseado (> 0) o null.
  Decimal? get _parsedAmount {
    final Decimal? d = Money.parse(_amountCtrl.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave = _parsedAmount != null;

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
                        Text(widget.goal.icon ?? '🎯',
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Text(
                            'Aportar a ${widget.goal.name}',
                            style: AppText.h2(c.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.section),
                    _amountField(context),
                    const SizedBox(height: Insets.card),
                    _remainingRow(context),
                    const SizedBox(height: Insets.section),
                    Text('NOTA', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _noteCtrl,
                      style: AppText.body(c.textPrimary),
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          _inputDecoration(context, hint: 'Detalle (opcional)'),
                    ),
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

  // ── Monto ─────────────────────────────────────────────────────────────────

  Widget _amountField(BuildContext context) {
    final c = context.colors;
    final Decimal? amount = _parsedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MONTO', style: AppText.label(c.textMuted)),
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
                  // Aporte = ingreso al ahorro → tinte sage (success), igual
                  // que la convención de income en el resto de la app.
                  amount == null ? c.textDim : c.brandSuccess,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.serifHero(
                      amount == null ? c.textDim : c.brandSuccess),
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
      ],
    );
  }

  /// Chip "+5k / +10k / …": suma el valor al monto actual.
  Widget _quickAmountChip(BuildContext context, int value) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        final Decimal current = Money.parse(_amountCtrl.text) ?? Decimal.zero;
        _setAmount(current + Decimal.fromInt(value));
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

  /// Chip "Limpiar": vacía el monto.
  Widget _clearChip(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _amountCtrl.clear();
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

  // ── Restante ────────────────────────────────────────────────────────────────

  /// Fila "Restante: X" con un chip "Completar" que precarga el monto restante.
  /// Si la meta ya está completa (restante 0), muestra el estado celebratorio.
  Widget _remainingRow(BuildContext context) {
    final c = context.colors;
    final Decimal remaining = _remaining;
    final bool done = remaining <= Decimal.zero;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.card,
        vertical: Insets.lg,
      ),
      decoration: BoxDecoration(
        color: c.appSurfaceInset,
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      child: Row(
        children: [
          Icon(
            done ? LucideIcons.partyPopper : LucideIcons.flag,
            size: 16,
            color: done ? c.brandSuccess : c.brandPrimary,
          ),
          const SizedBox(width: Insets.md),
          Text(
            done ? '¡Meta alcanzada!' : 'Restante',
            style: AppText.caption(c.textMuted),
          ),
          const SizedBox(width: Insets.md),
          if (!done)
            AmountText(
              value: remaining,
              currencyCode: _currency,
              kind: AmountKind.neutro,
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          const Spacer(),
          if (!done)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                _setAmount(remaining);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.card, vertical: Insets.sm),
                decoration: ShapeDecoration(
                  color: c.brandPrimary.withValues(alpha: 0.15),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Completar',
                  style: AppText.caption(c.brandPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
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
        label: _saving ? 'Guardando…' : 'Registrar aporte',
        icon: LucideIcons.check,
        onPressed: (canSave && !_saving) ? _save : null,
      ),
    );
  }

  /// Valida e inserta el aporte vía el controller, que devuelve la meta YA
  /// recargada (con `current_amount` actualizado por el trigger de DB). Esa meta
  /// se devuelve al caller (detalle).
  Future<void> _save() async {
    setState(() => _error = null);
    final Decimal? amount = _parsedAmount;
    if (amount == null) {
      setState(() => _error = 'Ingresá un monto válido mayor a cero.');
      return;
    }

    setState(() => _saving = true);
    final String note = _noteCtrl.text.trim();
    try {
      final Goal updated =
          await ref.read(goalsControllerProvider.notifier).contribute(
                widget.goal.id,
                amount,
                notes: note.isEmpty ? null : note,
              );
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos registrar el aporte. Reintentá.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Setea el monto en el campo, mostrando el entero sin `.0` colgando.
  void _setAmount(Decimal value) {
    _amountCtrl.text = value.toString().endsWith('.0')
        ? value.toBigInt().toString()
        : value.toString();
  }

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

  /// Etiqueta compacta de un valor entero para el chip (+5k / +100k).
  static String _compact(int value) {
    if (value >= 1000 && value % 1000 == 0) return '${value ~/ 1000}k';
    return '$value';
  }
}
