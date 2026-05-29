import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../home/application/home_controller.dart';
import '../application/transactions_controller.dart';

/// Hoja de edición de un movimiento — espejo de `EditTransactionView` (iOS).
/// Permite editar los campos editables (tipo, monto, categoría, subcategoría,
/// cuenta, nota, fecha) y guarda vía `TransactionRepository.update`, que solo
/// manda el patch de columnas editables (no pisa FX/`period_*`/generadas).
class EditTransactionSheet extends ConsumerStatefulWidget {
  const EditTransactionSheet({
    super.key,
    required this.transaction,
    required this.currency,
  });

  /// Movimiento original a editar.
  final Transaction transaction;

  /// Moneda base del hogar (para el placeholder del monto).
  final String currency;

  /// Presenta la hoja modal con el look del design system.
  static Future<void> show(
    BuildContext context, {
    required Transaction transaction,
    required String currency,
  }) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EditTransactionSheet(
        transaction: transaction,
        currency: currency,
      ),
    );
  }

  @override
  ConsumerState<EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late TxType _type;
  late String _category;
  late String? _subcategory;
  late DateTime _date;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  CategoriesData? _categoriesData;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Transaction t = widget.transaction;
    _type = t.type;
    _category = t.category;
    _subcategory = t.subcategory;
    _date = t.date;
    // El monto se muestra plano (sin agrupar) para que el decimalPad sea cómodo.
    _amountCtrl = TextEditingController(text: _plainAmount(t.amount));
    _noteCtrl = TextEditingController(text: t.note ?? '');
    _loadCategories();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Carga el blob de categorías del hogar para poblar la grilla por tipo.
  Future<void> _loadCategories() async {
    final String? householdId =
        ref.read(currentHouseholdIdProvider).valueOrNull;
    if (householdId == null) return;
    final CategoriesBlob? blob =
        await ref.read(categoryRepositoryProvider).fetch(householdId);
    if (!mounted) return;
    setState(() => _categoriesData = blob?.data);
  }

  /// Categorías disponibles para el tipo actual (defaults + custom mergeados).
  List<CategoryItem> get _categories =>
      TransactionsController.mergedCategories(_categoriesData, _type);

  /// Subcategorías de la categoría seleccionada (si tiene definidas).
  List<String> get _subcategories {
    for (final CategoryItem c in _categories) {
      if (c.name == _category) return c.subcategories ?? const <String>[];
    }
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
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
              Row(
                children: [
                  Icon(LucideIcons.pencil, size: 20, color: c.brandPrimary),
                  const SizedBox(width: Insets.md),
                  Text('Editar movimiento', style: AppText.h2(c.textPrimary)),
                ],
              ),
              const SizedBox(height: Insets.section),
              // Toggle de tipo.
              TxTypeToggle(
                type: _type,
                onChanged: (TxType t) {
                  setState(() {
                    _type = t;
                    // Si la categoría no existe para el nuevo tipo, caemos a la
                    // primera del catálogo (igual que iOS).
                    final List<CategoryItem> cats = _categories;
                    if (!cats.any((CategoryItem ci) => ci.name == _category)) {
                      _category = cats.isNotEmpty ? cats.first.name : _category;
                    }
                    _subcategory = null;
                  });
                },
              ),
              const SizedBox(height: Insets.section),
              // Monto.
              Text('MONTO', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              TextField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: AppText.serifDisplay(
                  _type == TxType.gasto ? c.brandDanger : c.brandSuccess,
                ),
                decoration: _inputDecoration(context, hint: '0'),
              ),
              const SizedBox(height: Insets.section),
              // Categoría.
              Text('CATEGORÍA', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              TxChipRow(
                children: _categories
                    .map((CategoryItem ci) => MCChip(
                          emoji: ci.emoji ?? CategoryCatalog.emojiFor(ci.name),
                          label: ci.name,
                          selected: _category == ci.name,
                          onTap: () => setState(() {
                            _category = ci.name;
                            _subcategory = null;
                          }),
                        ))
                    .toList(),
              ),
              if (_subcategories.isNotEmpty) ...[
                const SizedBox(height: Insets.card),
                Text('SUBCATEGORÍA', style: AppText.label(c.textMuted)),
                const SizedBox(height: Insets.md),
                TxChipRow(
                  children: <Widget>[
                    MCChip(
                      label: 'Ninguna',
                      selected: _subcategory == null,
                      onTap: () => setState(() => _subcategory = null),
                    ),
                    ..._subcategories.map((String s) => MCChip(
                          label: s,
                          selected: _subcategory == s,
                          onTap: () => setState(() => _subcategory = s),
                        )),
                  ],
                ),
              ],
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
              const SizedBox(height: Insets.section),
              // Fecha.
              Text('FECHA', style: AppText.label(c.textMuted)),
              const SizedBox(height: Insets.md),
              TxDateField(
                date: _date,
                onChanged: (DateTime d) => setState(() => _date = d),
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.card),
                Text(_error!, style: AppText.caption(c.brandDanger)),
              ],
              const SizedBox(height: Insets.section),
              MCPrimaryButton(
                label: _saving ? 'Guardando…' : 'Guardar cambios',
                icon: LucideIcons.check,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Valida y persiste los cambios. Solo cambia campos editables sobre una copia
  /// del movimiento original (freezed `copyWith`); el repo manda el patch.
  Future<void> _save() async {
    setState(() => _error = null);
    final Decimal? amount = Money.parse(_amountCtrl.text);
    if (amount == null || amount <= Decimal.zero) {
      setState(() => _error = 'Ingresá un monto válido mayor a cero.');
      return;
    }
    setState(() => _saving = true);
    final String note = _noteCtrl.text.trim();
    final Transaction updated = widget.transaction.copyWith(
      type: _type,
      amount: amount,
      category: _category,
      subcategory: _subcategory,
      note: note.isEmpty ? null : note,
      date: _date,
    );
    try {
      await ref.read(transactionRepositoryProvider).update(updated);
      await HapticFeedback.mediumImpact();
      ref.invalidate(transactionsControllerProvider);
      ref.invalidate(homeControllerProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No pudimos guardar los cambios. Reintentá.';
        });
      }
    }
  }

  /// Decoración de input consistente con el design system (surface + squircle).
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

  /// Monto a texto plano sin agrupar (para el campo editable).
  static String _plainAmount(Decimal v) {
    final String s = v.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

/// Toggle Gasto/Ingreso reutilizable (compartido por add + edit). Dos pills que
/// rellenan con el color semántico al seleccionarse. Espejo del `typeToggle` de
/// iOS.
class TxTypeToggle extends StatelessWidget {
  const TxTypeToggle({super.key, required this.type, required this.onChanged});

  final TxType type;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: _pill(
            context,
            selected: type == TxType.gasto,
            label: 'Gasto',
            icon: LucideIcons.arrowUpRight,
            color: c.brandDanger,
            onTap: () => onChanged(TxType.gasto),
          ),
        ),
        const SizedBox(width: Insets.lg),
        Expanded(
          child: _pill(
            context,
            selected: type == TxType.ingreso,
            label: 'Ingreso',
            icon: LucideIcons.arrowDownLeft,
            color: c.brandSuccess,
            onTap: () => onChanged(TxType.ingreso),
          ),
        ),
      ],
    );
  }

  Widget _pill(
    BuildContext context, {
    required bool selected,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.6) : c.appSurface,
          borderRadius: BorderRadius.circular(Radii.input),
          border: Border.all(
            color: selected ? color : c.appBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? const Color(0xFF0E1312) : c.textPrimary,
            ),
            const SizedBox(width: Insets.md),
            Text(
              label,
              style: AppText.body(
                selected ? const Color(0xFF0E1312) : c.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal scrollable de chips (categoría / subcategoría / cuenta).
/// Compartida por add + edit.
class TxChipRow extends StatelessWidget {
  const TxChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.md),
        itemBuilder: (_, int i) => children[i],
      ),
    );
  }
}

/// Campo de fecha: tile que abre el `showDatePicker` de Material con el tema
/// Midnight Sage. Compartido por add + edit.
class TxDateField extends StatelessWidget {
  const TxDateField({super.key, required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        HapticFeedback.selectionClick();
        final DateTime now = DateTime.now();
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
        decoration: BoxDecoration(
          color: c.appSurfaceInset,
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 16, color: c.brandPrimary),
            const SizedBox(width: Insets.md),
            Text(_formatDate(date), style: AppText.body(c.textPrimary)),
          ],
        ),
      ),
    );
  }

  /// Fecha legible compacta (rioplatense): "5 de mayo de 2026".
  static String _formatDate(DateTime d) {
    const List<String> months = <String>[
      '',
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${d.day} de ${months[d.month]} de ${d.year}';
  }
}
