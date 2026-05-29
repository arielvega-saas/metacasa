import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../application/transactions_controller.dart';
import 'edit_transaction_sheet.dart' show TxChipRow;

/// Hoja de filtros avanzados de Movimientos — espejo (acotado) del
/// `TransactionFiltersSheet` de iOS. Cubre el subconjunto soportado por el port
/// Flutter: tipo, categoría, cuenta y orden. La búsqueda tiene su propia barra
/// en la lista; el rango de fechas lo cubre el período visible.
///
/// Edita una copia local de [TransactionFilters] y la empuja al controller al
/// tocar "Aplicar"; "Limpiar" resetea al default.
class TransactionFiltersSheet extends ConsumerStatefulWidget {
  const TransactionFiltersSheet({
    super.key,
    required this.categories,
    required this.accounts,
  });

  /// Catálogo de categorías disponibles (gastos ∪ ingresos).
  final List<CategoryItem> categories;

  /// Cuentas del hogar para el selector de cuenta.
  final List<Account> accounts;

  /// Presenta la hoja modal con el look del design system.
  static Future<void> show(
    BuildContext context, {
    required List<CategoryItem> categories,
    required List<Account> accounts,
  }) {
    final c = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TransactionFiltersSheet(
        categories: categories,
        accounts: accounts,
      ),
    );
  }

  @override
  ConsumerState<TransactionFiltersSheet> createState() =>
      _TransactionFiltersSheetState();
}

class _TransactionFiltersSheetState
    extends ConsumerState<TransactionFiltersSheet> {
  late TransactionFilters _draft;

  @override
  void initState() {
    super.initState();
    // Arrancamos desde los filtros vigentes del controller.
    _draft = ref.read(transactionsControllerProvider).valueOrNull?.filters ??
        const TransactionFilters();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
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
                Icon(LucideIcons.slidersHorizontal,
                    size: 20, color: c.brandPrimary),
                const SizedBox(width: Insets.md),
                Text('Filtros', style: AppText.h2(c.textPrimary)),
                const Spacer(),
                // Limpiar: vuelve al default.
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _draft = const TransactionFilters());
                  },
                  child: Text(
                    'Limpiar',
                    style: AppText.body(c.brandDanger)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.card),
            // Tipo.
            Text('TIPO', style: AppText.label(c.textMuted)),
            const SizedBox(height: Insets.md),
            TxChipRow(
              children: TxTypeFilter.values
                  .map((TxTypeFilter t) => MCChip(
                        label: t.label,
                        selected: _draft.type == t,
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(type: t),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: Insets.section),
            // Categoría.
            Text('CATEGORÍA', style: AppText.label(c.textMuted)),
            const SizedBox(height: Insets.md),
            if (widget.categories.isEmpty)
              Text('Sin categorías', style: AppText.caption(c.textDim))
            else
              TxChipRow(
                children: <Widget>[
                  MCChip(
                    label: 'Todas',
                    selected: _draft.category == null,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(clearCategory: true),
                    ),
                  ),
                  ...widget.categories.map((CategoryItem ci) => MCChip(
                        emoji: ci.emoji ?? CategoryCatalog.emojiFor(ci.name),
                        label: ci.name,
                        selected: _draft.category == ci.name,
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(category: ci.name),
                        ),
                      )),
                ],
              ),
            const SizedBox(height: Insets.section),
            // Cuenta.
            Text('CUENTA', style: AppText.label(c.textMuted)),
            const SizedBox(height: Insets.md),
            if (widget.accounts.isEmpty)
              Text('Sin cuentas', style: AppText.caption(c.textDim))
            else
              TxChipRow(
                children: <Widget>[
                  MCChip(
                    label: 'Todas',
                    selected: _draft.accountId == null,
                    onTap: () => setState(
                      () => _draft = _draft.copyWith(clearAccount: true),
                    ),
                  ),
                  ...widget.accounts.map((Account a) => MCChip(
                        label: a.name,
                        selected: _draft.accountId == a.id,
                        onTap: () => setState(
                          () => _draft = _draft.copyWith(accountId: a.id),
                        ),
                      )),
                ],
              ),
            const SizedBox(height: Insets.section),
            // Orden.
            Text('ORDENAR POR', style: AppText.label(c.textMuted)),
            const SizedBox(height: Insets.md),
            ...TxSort.values.map((TxSort s) => _SortOption(
                  label: s.label,
                  selected: _draft.sort == s,
                  onTap: () => setState(
                    () => _draft = _draft.copyWith(sort: s),
                  ),
                )),
            const SizedBox(height: Insets.section),
            MCPrimaryButton(
              label: 'Aplicar',
              icon: LucideIcons.check,
              onPressed: () {
                ref
                    .read(transactionsControllerProvider.notifier)
                    .setFilters(_draft);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Opción de orden: fila con check a la izquierda cuando está seleccionada.
class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        child: Row(
          children: [
            Icon(
              selected ? LucideIcons.check : LucideIcons.arrowUpDown,
              size: 16,
              color: selected ? c.brandPrimary : c.textMuted,
            ),
            const SizedBox(width: Insets.card),
            Text(
              label,
              style: AppText.body(selected ? c.textPrimary : c.textMuted)
                  .copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
