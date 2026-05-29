import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/budget_controller.dart';

/// Hoja de alta/edición de un envelope (allocation). Espejo de
/// `EnvelopeEditorSheet` (iOS).
///
/// - **Nuevo** (`existing == null`): selector horizontal de categorías que
///   todavía NO tienen envelope (chips), subcategoría opcional, monto, modo de
///   rollover segmentado.
/// - **Editar** (`existing != null`): categoría fija (chip estático), resto
///   editable, + botón de borrar.
///
/// Al guardar llama a `BudgetController.upsertEnvelope`; al borrar a
/// `deleteEnvelope`. El controller recarga y refresca la UI.
class EnvelopeEditorSheet extends ConsumerStatefulWidget {
  const EnvelopeEditorSheet({super.key, this.existing});

  /// Allocation a editar, o null para crear una nueva.
  final BudgetAllocation? existing;

  /// Presenta la hoja modal (scroll-controlled, drag handle). [existing] null =
  /// alta; no-null = edición.
  static Future<void> show(BuildContext context, {BudgetAllocation? existing}) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EnvelopeEditorSheet(existing: existing),
    );
  }

  @override
  ConsumerState<EnvelopeEditorSheet> createState() =>
      _EnvelopeEditorSheetState();
}

class _EnvelopeEditorSheetState extends ConsumerState<EnvelopeEditorSheet> {
  late String _category;
  late final TextEditingController _subcategory;
  late final TextEditingController _amount;
  late RolloverMode _rolloverMode;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final BudgetAllocation? existing = widget.existing;
    _category = existing?.category ?? '';
    _subcategory = TextEditingController(text: existing?.subcategory ?? '');
    // El monto editable es `allocated` (no el budgeted con rollover) — es lo que
    // el usuario asignó. Igual que iOS (`"\($0.allocated)"`).
    _amount = TextEditingController(
      text: existing != null ? existing.allocated.toString() : '',
    );
    // Default `surplus` al crear (igual que iOS).
    _rolloverMode = existing?.rolloverMode ?? RolloverMode.surplus;
  }

  @override
  void dispose() {
    _subcategory.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Monto parseado y validado (>0), o null si inválido. Usa el parser tolerante
  /// de `Money` (acepta separadores es-AR / en-US y símbolos).
  Decimal? get _parsedAmount {
    final Decimal? d = Money.parse(_amount.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  /// `true` si el formulario es válido (categoría elegida + monto > 0).
  bool get _canSave => _category.isNotEmpty && _parsedAmount != null;

  /// Categorías de gasto del catálogo que aún no tienen envelope (al crear).
  /// Incluye la propia categoría si se está editando. Espejo de
  /// `availableCategories` de iOS.
  List<String> _availableCategories(Set<String> used) {
    return CategoryCatalog.defaultGastos
        .where((String cat) => _category == cat || !used.contains(cat))
        .toList();
  }

  Future<void> _save() async {
    final Decimal? amount = _parsedAmount;
    if (amount == null || _category.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(budgetControllerProvider.notifier).upsertEnvelope(
            category: _category,
            subcategory: _subcategory.text.trim(),
            allocated: amount,
            rolloverMode: _rolloverMode,
          );
      if (!mounted) return;
      HapticFeedback.selectionClick();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      HapticFeedback.vibrate();
    }
  }

  Future<void> _delete() async {
    final BudgetAllocation? existing = widget.existing;
    if (existing == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(budgetControllerProvider.notifier)
          .deleteEnvelope(existing.id);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Categorías ya usadas + moneda salen del estado del controller (sin re-fetch).
    final BudgetState? budget = ref.watch(budgetControllerProvider).valueOrNull;
    final Set<String> used = budget?.usedCategories ?? <String>{};
    final String currency = budget?.currency ?? 'USD';
    final List<String> available = _availableCategories(used);
    final Decimal? preview = _parsedAmount;

    return SafeArea(
      child: Padding(
        // Empuja el contenido por encima del teclado.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Insets.screen,
            Insets.md,
            Insets.screen,
            Insets.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título.
              Row(
                children: [
                  Icon(LucideIcons.layers, size: 20, color: c.brandPrimary),
                  const SizedBox(width: Insets.md),
                  Text(
                    _isEditing ? 'Editar sobre' : 'Nuevo sobre',
                    style: AppText.h2(c.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: Insets.section),

              // ── Categoría ──
              Text('CATEGORÍA', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              if (_isEditing)
                _StaticCategory(category: _category)
              else if (available.isEmpty)
                Text(
                  'Ya creaste un sobre para cada categoría.',
                  style: AppText.caption(c.textMuted),
                )
              else
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: available.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: Insets.md),
                    itemBuilder: (context, i) {
                      final String cat = available[i];
                      return MCChip(
                        label: cat,
                        emoji: CategoryCatalog.emojiFor(cat),
                        selected: _category == cat,
                        onTap: () => setState(() => _category = cat),
                      );
                    },
                  ),
                ),
              const SizedBox(height: Insets.section),

              // ── Subcategoría (opcional) ──
              Text('SUBCATEGORÍA (OPCIONAL)',
                  style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              _SheetField(
                controller: _subcategory,
                hint: 'Ej. Supermercado',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Insets.section),

              // ── Monto asignado ──
              Text('ASIGNADO', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              _AmountField(
                controller: _amount,
                currency: currency,
                onChanged: (_) => setState(() {}),
              ),
              if (preview != null) ...[
                const SizedBox(height: Insets.md),
                Row(
                  children: [
                    Icon(LucideIcons.checkCircle,
                        size: 14, color: c.brandSuccess),
                    const SizedBox(width: Insets.sm),
                    Text(
                      Money.format(
                        preview,
                        currencyCode: currency,
                        style: MoneyStyle.auto,
                        locale: 'es_AR',
                      ),
                      style: AppText.caption(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Insets.section),

              // ── Rollover ──
              Text('ROLLOVER', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              _RolloverSegmented(
                value: _rolloverMode,
                onChanged: (RolloverMode mode) =>
                    setState(() => _rolloverMode = mode),
              ),
              const SizedBox(height: Insets.sm),
              Text(_rolloverHint(_rolloverMode),
                  style: AppText.caption(c.textMuted)),
              const SizedBox(height: Insets.section),

              // ── Guardar ──
              MCPrimaryButton(
                label: _saving ? 'Guardando…' : 'Guardar',
                onPressed: (_canSave && !_saving) ? _save : null,
              ),

              // ── Borrar (solo edición) ──
              if (_isEditing) ...[
                const SizedBox(height: Insets.lg),
                _DeleteButton(
                  onTap: _saving ? null : _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Hint del modo de rollover. Espejo de `rolloverHint` de iOS.
  String _rolloverHint(RolloverMode mode) => switch (mode) {
        RolloverMode.none =>
          'El sobrante no se acumula: cada mes arranca en el monto asignado.',
        RolloverMode.surplus =>
          'Si te sobra, el saldo positivo se suma al mes siguiente.',
        RolloverMode.full =>
          'Se arrastra todo el saldo, incluso el sobregiro negativo.',
      };
}

/// Chip estático de categoría (modo edición): emoji + nombre, sin tap.
class _StaticCategory extends StatelessWidget {
  const _StaticCategory({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Text(
          CategoryCatalog.emojiFor(category),
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: Insets.md),
        Text(
          category,
          style:
              AppText.body(c.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Campo de texto del sheet (superficie inset + hairline sage).
class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.input),
          side: BorderSide(color: c.appBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.card,
        vertical: Insets.lg,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppText.body(c.textPrimary),
        cursorColor: c.brandPrimary,
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: AppText.body(c.textDim),
        ),
      ),
    );
  }
}

/// Campo de monto: chip de moneda a la izquierda + input numérico grande sage.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.currency,
    this.onChanged,
  });

  final TextEditingController controller;
  final String currency;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.input),
          side: BorderSide(color: c.appBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.card,
        vertical: Insets.md,
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
            decoration: ShapeDecoration(
              color: c.appSurface,
              shape: const StadiumBorder(),
            ),
            child: Text(
              currency,
              style: AppText.caption(c.textMuted)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppText.h1(c.brandPrimary),
              cursorColor: c.brandPrimary,
              decoration: InputDecoration.collapsed(
                hintText: '0',
                hintStyle: AppText.h1(c.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Control segmentado de rollover (none / surplus / full). Espejo del
/// `.pickerStyle(.segmented)` de iOS.
class _RolloverSegmented extends StatelessWidget {
  const _RolloverSegmented({required this.value, required this.onChanged});

  final RolloverMode value;
  final ValueChanged<RolloverMode> onChanged;

  /// Etiqueta corta por modo (para el segmento).
  static String _segLabel(RolloverMode mode) => switch (mode) {
        RolloverMode.none => 'Sin rollover',
        RolloverMode.surplus => 'Sobrante',
        RolloverMode.full => 'Todo',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.pill)),
      ),
      child: Row(
        children: RolloverMode.values.map((RolloverMode mode) {
          final bool selected = mode == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(mode);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: Insets.lg),
                decoration: ShapeDecoration(
                  color: selected ? c.brandPrimary : Colors.transparent,
                  shape: SmoothRectangleBorder(
                    borderRadius: Radii.smooth(Radii.badge),
                  ),
                ),
                child: Text(
                  _segLabel(mode),
                  textAlign: TextAlign.center,
                  style: AppText.caption(
                    selected ? const Color(0xFF0E1312) : c.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Botón de borrar (modo edición): coral, full-width, ícono de tacho.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.brandDanger.withValues(alpha: 0.12),
            shape: SmoothRectangleBorder(
              borderRadius: Radii.smooth(Radii.card),
              side: BorderSide(
                color: c.brandDanger.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.trash2, size: 18, color: c.brandDanger),
              const SizedBox(width: Insets.md),
              Text(
                'Eliminar sobre',
                style: AppText.body(c.brandDanger)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
