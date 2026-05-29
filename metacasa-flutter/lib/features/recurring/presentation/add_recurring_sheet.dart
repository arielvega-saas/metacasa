import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/supabase_init.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/presentation/edit_transaction_sheet.dart'
    show TxChipRow, TxDateField, TxTypeToggle;
import '../application/recurring_controller.dart';

/// Hoja "Nueva recurrente" — espejo de `AddRecurringView` (iOS).
///
/// Flujo (de arriba a abajo), 1:1 con iOS:
///   1. Toggle Gasto/Ingreso.
///   2. Monto hero (serif, tinte por tipo).
///   3. Categoría (chips del catálogo del tipo actual).
///   4. Frecuencia (Diario / Semanal / Mensual / Anual).
///   5. Fecha de inicio + (opcional) fecha de fin.
///   6. Nota (opcional).
///   7. Botón guardar (sticky abajo). Valida monto > 0 + categoría; inserta vía
///      el controller (el repo inyecta `user_id` y defaultea `next_date`) y
///      cierra con `true`.
class AddRecurringSheet extends ConsumerStatefulWidget {
  const AddRecurringSheet({super.key, required this.householdId});

  /// Hogar al que pertenece la recurrente (se setea en `household_id`).
  final String householdId;

  /// Presenta la hoja modal con el look del design system. Devuelve `true` si se
  /// guardó (para que el caller refresque).
  static Future<bool?> show(BuildContext context, String householdId) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AddRecurringSheet(householdId: householdId),
    );
  }

  @override
  ConsumerState<AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends ConsumerState<AddRecurringSheet> {
  TxType _type = TxType.gasto;
  String? _category;
  Frequency _frequency = Frequency.monthly;
  DateTime _startDate = DateTime.now();
  bool _hasEndDate = false;
  // Default de fin: un año después del inicio (igual que iOS).
  DateTime _endDate = DateTime(
    DateTime.now().year + 1,
    DateTime.now().month,
    DateTime.now().day,
  );

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  CategoriesData? _categoriesData;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
    _loadCategories();
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  /// Carga el blob de categorías del hogar para poblar la grilla por tipo.
  Future<void> _loadCategories() async {
    final CategoriesBlob? blob =
        await ref.read(categoryRepositoryProvider).fetch(widget.householdId);
    if (!mounted) return;
    setState(() {
      _categoriesData = blob?.data;
      // Default de categoría: la primera del catálogo del tipo actual.
      _category ??= _categories.isNotEmpty ? _categories.first.name : null;
    });
  }

  /// Categorías disponibles para el tipo actual (defaults + custom mergeados).
  List<CategoryItem> get _categories =>
      TransactionsController.mergedCategories(_categoriesData, _type);

  /// Monto parseado (> 0) o null.
  Decimal? get _parsedAmount {
    final Decimal? d = Money.parse(_amountCtrl.text);
    if (d == null || d <= Decimal.zero) return null;
    return d;
  }

  /// Moneda base del hogar (cae a USD) — para el símbolo del monto.
  String get _currency =>
      ref.read(currentHouseholdProvider).valueOrNull?.defaultCurrency ?? 'USD';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool canSave = _parsedAmount != null && _category != null;

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
                        Icon(LucideIcons.repeat,
                            size: 20, color: c.brandPrimary),
                        const SizedBox(width: Insets.md),
                        Text('Nueva recurrente',
                            style: AppText.h2(c.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: Insets.section),
                    TxTypeToggle(type: _type, onChanged: _onTypeChanged),
                    const SizedBox(height: Insets.section),
                    _amountField(context),
                    const SizedBox(height: Insets.section),
                    _categorySection(context),
                    const SizedBox(height: Insets.section),
                    _frequencySection(context),
                    const SizedBox(height: Insets.section),
                    // Fecha de inicio.
                    Text('EMPIEZA EL', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TxDateField(
                      date: _startDate,
                      onChanged: (DateTime d) => setState(() => _startDate = d),
                    ),
                    const SizedBox(height: Insets.section),
                    _endDateSection(context),
                    const SizedBox(height: Insets.section),
                    // Nota.
                    Text('NOTA', style: AppText.label(c.textMuted)),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _noteCtrl,
                      style: AppText.body(c.textPrimary),
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
            // Barra de guardado (sticky abajo) con divider superior.
            Container(
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
                label: _saving ? 'Guardando…' : 'Guardar recurrente',
                icon: LucideIcons.check,
                onPressed: (canSave && !_saving) ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Amount ──────────────────────────────────────────────────────────────

  /// Campo de monto: hero serif con tinte por tipo (gasto coral / ingreso sage).
  Widget _amountField(BuildContext context) {
    final c = context.colors;
    final Color tint = _type == TxType.gasto ? c.brandDanger : c.brandSuccess;
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
                style: AppText.serifDisplay(amount == null ? c.textDim : tint),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppText.serifHero(amount == null ? c.textDim : tint),
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
      ],
    );
  }

  // ── Category ────────────────────────────────────────────────────────────

  Widget _categorySection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CATEGORÍA', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TxChipRow(
          children: _categories
              .map((CategoryItem ci) => MCChip(
                    emoji: ci.emoji ?? CategoryCatalog.emojiFor(ci.name),
                    label: ci.name,
                    selected: _category == ci.name,
                    onTap: () => setState(() => _category = ci.name),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Frequency ───────────────────────────────────────────────────────────

  Widget _frequencySection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FRECUENCIA', style: AppText.label(c.textMuted)),
        const SizedBox(height: Insets.md),
        TxChipRow(
          children: Frequency.values
              .map((Frequency f) => MCChip(
                    label: _frequencyLabel(f),
                    selected: _frequency == f,
                    onTap: () => setState(() => _frequency = f),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── End date ──────────────────────────────────────────────────────────────

  Widget _endDateSection(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tiene fecha de fin',
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _hasEndDate,
              activeColor: c.brandPrimary,
              onChanged: (bool v) {
                HapticFeedback.selectionClick();
                setState(() => _hasEndDate = v);
              },
            ),
          ],
        ),
        if (_hasEndDate) ...[
          const SizedBox(height: Insets.md),
          TxDateField(
            date: _endDate,
            onChanged: (DateTime d) => setState(() => _endDate = d),
          ),
        ],
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _onTypeChanged(TxType t) {
    setState(() {
      _type = t;
      // Si la categoría no existe para el nuevo tipo, caemos a la primera.
      final List<CategoryItem> cats = _categories;
      if (_category == null ||
          !cats.any((CategoryItem ci) => ci.name == _category)) {
        _category = cats.isNotEmpty ? cats.first.name : null;
      }
    });
  }

  /// Valida e inserta la recurrente. El repo inyecta `user_id` y defaultea
  /// `next_date` a `start_date`; acá completamos el resto.
  Future<void> _save() async {
    setState(() => _error = null);
    final Decimal? amount = _parsedAmount;
    if (amount == null) {
      setState(() => _error = 'Ingresá un monto válido mayor a cero.');
      return;
    }
    final String? category = _category;
    if (category == null) {
      setState(() => _error = 'Elegí una categoría.');
      return;
    }
    final String? userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error = 'No encontramos tu sesión. Reintentá.');
      return;
    }

    setState(() => _saving = true);
    final String note = _noteCtrl.text.trim();
    // `id` es server-generated: el repo lo descarta en el payload de insert.
    final RecurringTransaction recurring = RecurringTransaction(
      id: '',
      householdId: widget.householdId,
      userId: userId,
      type: _type,
      amount: amount,
      category: category,
      startDate: _startDate,
      endDate: _hasEndDate ? _endDate : null,
      nextDate: _startDate,
      note: note.isEmpty ? null : note,
      frequency: _frequency,
      active: true,
    );

    try {
      await ref.read(recurringControllerProvider.notifier).add(recurring);
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos guardar la recurrente. Reintentá.';
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Etiqueta legible de la frecuencia (es-AR).
  static String _frequencyLabel(Frequency f) {
    switch (f) {
      case Frequency.daily:
        return 'Diario';
      case Frequency.weekly:
        return 'Semanal';
      case Frequency.monthly:
        return 'Mensual';
      case Frequency.yearly:
        return 'Anual';
    }
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
}
