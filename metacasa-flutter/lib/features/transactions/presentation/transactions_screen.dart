import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../../home/application/home_controller.dart';
import '../application/transactions_controller.dart';
import 'edit_transaction_sheet.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_filters_sheet.dart';

/// Tab "Movimientos" — espejo de `TransactionListView` (iOS).
///
/// De arriba a abajo:
///   1. AppBar: título + navegador de período (‹ Mes Año ›) + ojo de privacidad
///      + botón de filtros (con badge de filtros activos).
///   2. Barra de búsqueda.
///   3. Chips rápidos: Todos / Gastos / Ingresos + "Ordenar".
///   4. Summary bar: cantidad + Σ ingresos / Σ gastos de la vista filtrada.
///   5. Lista agrupada por día (header con fecha + neto del día), cada fila
///      `tap` abre el detalle, swipe → eliminar (con confirmación) / editar.
///
/// Estados: loading → spinner; sin datos del período → empty-state; filtros sin
/// match → empty-state de filtros; error → empty-state con reintento.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  /// Nombres de mes (es, 1-based) para el navegador de período.
  static const List<String> _months = <String>[
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final bool privacy = ref.watch(privacyModeProvider);
    final YearMonth period = ref.watch(currentPeriodProvider);
    // El conteo de filtros activos viaja en el estado (cada cambio de filtro
    // produce un estado nuevo), así que lo derivamos del valor observado.
    final int activeFilters = ref
            .watch(transactionsControllerProvider)
            .valueOrNull
            ?.filters
            .activeCount ??
        0;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        titleSpacing: Insets.screen,
        title: Text('Movimientos', style: AppText.serifTitle(c.textPrimary)),
        actions: [
          // Botón de filtros con badge de conteo.
          _FilterButton(
            count: activeFilters,
            onTap: () => _openFilters(context, ref),
          ),
          // Ojo de privacidad (comparte el provider global con el Home).
          IconButton(
            icon: Icon(
              privacy ? LucideIcons.eyeOff : LucideIcons.eye,
              color: privacy ? c.brandPrimary : c.textPrimary,
            ),
            tooltip: privacy ? 'Mostrar montos' : 'Ocultar montos',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(privacyModeProvider.notifier).update((bool v) => !v);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodNavigator(
            label: '${_months[period.month]} ${period.year}',
          ),
          const _SearchBar(),
          const _QuickFilters(),
          Expanded(child: _TransactionsList(privacy: privacy)),
        ],
      ),
    );
  }

  /// Abre la hoja de filtros avanzados (categoría + cuenta + tipo + orden).
  void _openFilters(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    final TransactionsState? st =
        ref.read(transactionsControllerProvider).valueOrNull;
    TransactionFiltersSheet.show(
      context,
      categories: st?.categories ?? const <CategoryItem>[],
      accounts: st?.accounts ?? const <Account>[],
    );
  }
}

// ──────────────────────────────── Period nav ───────────────────────────────

/// Navegador de período ‹ Mes Año ›. Wired a [currentPeriodProvider]; cambia el
/// mes y el controller re-fetchea solo (observa el provider).
class _PeriodNavigator extends ConsumerWidget {
  const _PeriodNavigator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        Insets.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(LucideIcons.chevronLeft, color: c.textPrimary),
            tooltip: 'Mes anterior',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(currentPeriodProvider.notifier).prevMonth();
            },
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.h2(c.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.chevronRight, color: c.textPrimary),
            tooltip: 'Mes siguiente',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(currentPeriodProvider.notifier).nextMonth();
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────── Search ──────────────────────────────────

/// Barra de búsqueda. Empuja el texto al controller (que reproyecta en memoria,
/// sin re-fetch). Espejo del `.searchable` de iOS.
class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.screen, 0, Insets.screen, Insets.md),
      child: TextField(
        controller: _ctrl,
        style: AppText.body(c.textPrimary),
        onChanged: (String v) =>
            ref.read(transactionsControllerProvider.notifier).setSearch(v),
        decoration: InputDecoration(
          hintText: 'Buscar por nota o categoría',
          hintStyle: AppText.body(c.textDim),
          prefixIcon: Icon(LucideIcons.search, size: 18, color: c.textMuted),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(LucideIcons.x, size: 16, color: c.textMuted),
                  onPressed: () {
                    _ctrl.clear();
                    ref
                        .read(transactionsControllerProvider.notifier)
                        .setSearch('');
                    setState(() {});
                  },
                ),
          filled: true,
          fillColor: c.appSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: Insets.card),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.input),
            borderSide: BorderSide(color: c.appBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.input),
            borderSide: BorderSide(color: c.appBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.input),
            borderSide: BorderSide(color: c.brandPrimary),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Quick filters ─────────────────────────────

/// Chips rápidos de tipo (Todos / Gastos / Ingresos) + menú "Ordenar".
class _QuickFilters extends ConsumerWidget {
  const _QuickFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TransactionFilters filters =
        ref.watch(transactionsControllerProvider).valueOrNull?.filters ??
            const TransactionFilters();
    final TxTypeFilter active = filters.type;
    final TxSort sort = filters.sort;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.screen),
        children: [
          for (final TxTypeFilter t in TxTypeFilter.values) ...[
            MCChip(
              label: t.label,
              selected: active == t,
              onTap: () =>
                  ref.read(transactionsControllerProvider.notifier).setType(t),
            ),
            const SizedBox(width: Insets.md),
          ],
          _SortChip(sort: sort),
        ],
      ),
    );
  }
}

/// Chip "Ordenar": abre un menú con los cuatro criterios de orden.
class _SortChip extends ConsumerWidget {
  const _SortChip({required this.sort});

  final TxSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PopupMenuButton<TxSort>(
      onSelected: (TxSort s) {
        HapticFeedback.selectionClick();
        ref.read(transactionsControllerProvider.notifier).setSort(s);
      },
      color: c.appSurface,
      itemBuilder: (_) => TxSort.values
          .map((TxSort s) => PopupMenuItem<TxSort>(
                value: s,
                child: Row(
                  children: [
                    if (s == sort)
                      Icon(LucideIcons.check, size: 16, color: c.brandPrimary)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(s.label, style: AppText.body(c.textPrimary)),
                    ),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.card,
          vertical: Insets.lg,
        ),
        decoration: ShapeDecoration(
          color: c.appSurface,
          shape: StadiumBorder(side: BorderSide(color: c.appBorder)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.arrowUpDown, size: 14, color: c.textPrimary),
            const SizedBox(width: Insets.sm),
            Text(
              'Ordenar',
              style: AppText.caption(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón de filtros del AppBar, con badge de cantidad de filtros activos.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IconButton(
      tooltip: 'Filtros',
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            LucideIcons.slidersHorizontal,
            color: count > 0 ? c.brandPrimary : c.textPrimary,
          ),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: c.brandPrimary,
                  borderRadius: BorderRadius.circular(Radii.badge),
                ),
                child: Text(
                  '$count',
                  style: AppText.caption(const Color(0xFF0E1312))
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── List body ────────────────────────────────

/// Cuerpo de la lista: resuelve los estados del controller y, en `data`, pinta
/// la summary bar + la lista agrupada por día con pull-to-refresh.
class _TransactionsList extends ConsumerWidget {
  const _TransactionsList({required this.privacy});

  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<TransactionsState> async =
        ref.watch(transactionsControllerProvider);
    final String currency =
        ref.watch(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';

    return async.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: c.brandPrimary),
      ),
      error: (Object err, StackTrace _) => _ErrorState(
        onRetry: () =>
            ref.read(transactionsControllerProvider.notifier).refresh(),
      ),
      data: (TransactionsState state) {
        if (state.isEmpty) {
          return RefreshIndicator(
            color: c.brandPrimary,
            backgroundColor: c.appSurface,
            onRefresh: () =>
                ref.read(transactionsControllerProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(
                  height: 420,
                  child: EmptyState(
                    icon: LucideIcons.inbox,
                    title: 'Sin movimientos este mes',
                    message:
                        'Cargá tu primer ingreso o gasto con el botón Agregar.',
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _SummaryBar(
              count: state.count,
              ingresos: state.totalIngresos,
              gastos: state.totalGastos,
              currency: currency,
              privacy: privacy,
            ),
            Expanded(
              child: RefreshIndicator(
                color: c.brandPrimary,
                backgroundColor: c.appSurface,
                onRefresh: () =>
                    ref.read(transactionsControllerProvider.notifier).refresh(),
                child: state.isFilteredEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 360,
                            child: EmptyState(
                              icon: LucideIcons.filter,
                              title: 'Nada coincide con los filtros',
                              message: 'Ajustá o limpiá los filtros activos.',
                              actionLabel: 'Limpiar filtros',
                              onAction: () => ref
                                  .read(transactionsControllerProvider.notifier)
                                  .clearFilters(),
                            ),
                          ),
                        ],
                      )
                    : _DayGroupedList(
                        groups: state.dayGroups,
                        currency: currency,
                        privacy: privacy,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Lista agrupada por día: por cada [DayGroup] un header (fecha + neto) y sus
/// filas. Cada fila es swipeable (eliminar/editar) y `tap` abre el detalle.
class _DayGroupedList extends ConsumerWidget {
  const _DayGroupedList({
    required this.groups,
    required this.currency,
    required this.privacy,
  });

  final List<DayGroup> groups;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: Insets.sm,
        bottom: 120, // espacio para el FAB del asistente del shell
      ),
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int i) {
        final DayGroup group = groups[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(
              day: group.day,
              net: group.net,
              currency: currency,
              privacy: privacy,
            ),
            ...group.transactions.map((Transaction t) => _SwipeableRow(
                  transaction: t,
                  currency: currency,
                  privacy: privacy,
                )),
          ],
        );
      },
    );
  }
}

/// Header de día: fecha legible + neto del día (verde/coral según signo).
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.net,
    required this.currency,
    required this.privacy,
  });

  final DateTime day;
  final Decimal net;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.card,
        Insets.screen,
        Insets.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatDay(day),
              style: AppText.label(c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Insets.md),
          // Neto del día. `balance` para que el color siga el signo.
          AmountText(
            value: net,
            currencyCode: currency,
            kind: AmountKind.balance,
            obscured: privacy,
            showSign: true,
            moneyStyle: MoneyStyle.compact,
            style: AppText.caption(c.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// "Hoy" / "Ayer" / "lun 5 de mayo" (rioplatense).
  static String _formatDay(DateTime day) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'HOY';
    if (day == yesterday) return 'AYER';
    const List<String> wd = <String>[
      '',
      'lun',
      'mar',
      'mié',
      'jue',
      'vie',
      'sáb',
      'dom',
    ];
    const List<String> mo = <String>[
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
    return '${wd[day.weekday]} ${day.day} de ${mo[day.month]}';
  }
}

/// Fila swipeable: trailing (eliminar, con confirmación) / leading (editar).
/// `tap` abre el detalle. Espejo de los `swipeActions` de iOS.
class _SwipeableRow extends ConsumerWidget {
  const _SwipeableRow({
    required this.transaction,
    required this.currency,
    required this.privacy,
  });

  final Transaction transaction;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Dismissible(
      key: ValueKey<String>(transaction.id),
      // Trailing (←): eliminar, requiere confirmación. Leading (→): editar, no
      // descarta la fila (abrimos la hoja y "cancelamos" el dismiss).
      background: _swipeBg(
        context,
        align: Alignment.centerLeft,
        color: c.brandPrimary,
        icon: LucideIcons.pencil,
        label: 'Editar',
      ),
      secondaryBackground: _swipeBg(
        context,
        align: Alignment.centerRight,
        color: c.brandDanger,
        icon: LucideIcons.trash2,
        label: 'Eliminar',
      ),
      confirmDismiss: (DismissDirection dir) async {
        if (dir == DismissDirection.startToEnd) {
          // Editar: abrimos la hoja y NO descartamos la fila.
          await _openEdit(context);
          return false;
        }
        // Eliminar: confirmación.
        return _confirmDelete(context);
      },
      onDismissed: (_) => _delete(ref),
      child: _Row(
        transaction: transaction,
        currency: currency,
        privacy: privacy,
        onTap: () => TransactionDetailSheet.show(
          context,
          transaction: transaction,
          currency: currency,
        ),
      ),
    );
  }

  Widget _swipeBg(
    BuildContext context, {
    required Alignment align,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      color: color.withValues(alpha: 0.18),
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: Insets.cardLg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Insets.md),
          Text(
            label,
            style: AppText.caption(color).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    await EditTransactionSheet.show(
      context,
      transaction: transaction,
      currency: currency,
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final c = context.colors;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.appSurface,
        title: Text('Eliminar movimiento', style: AppText.h2(c.textPrimary)),
        content: Text(
          '¿Seguro que querés eliminar este movimiento? No se puede deshacer.',
          style: AppText.body(c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppText.body(c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: AppText.body(c.brandDanger)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _delete(WidgetRef ref) async {
    await ref.read(transactionRepositoryProvider).delete(transaction.id);
    await HapticFeedback.mediumImpact();
    ref.invalidate(transactionsControllerProvider);
    ref.invalidate(homeControllerProvider);
  }
}

/// Fila de movimiento (presentación pura) — espejo de `TransactionRow` (iOS):
/// emoji de categoría en círculo tintado + título/fecha + monto coloreado.
class _Row extends StatelessWidget {
  const _Row({
    required this.transaction,
    required this.currency,
    required this.privacy,
    required this.onTap,
  });

  final Transaction transaction;
  final String currency;
  final bool privacy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool isGasto = transaction.type == TxType.gasto;
    final Color tint = isGasto ? c.brandDanger : c.brandSuccess;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        // Fondo sólido para que el Dismissible revele el background coloreado.
        color: c.appBackground,
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.screen,
          vertical: Insets.xl,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.12),
                border: Border.all(color: tint.withValues(alpha: 0.30)),
              ),
              child: Text(
                CategoryCatalog.emojiFor(transaction.category),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: AppText.body(c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(_subtitle, style: AppText.caption(c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: Insets.md),
            AmountText(
              value: transaction.amount,
              currencyCode: transaction.currencyOriginal ?? currency,
              kind: isGasto ? AmountKind.gasto : AmountKind.ingreso,
              obscured: privacy,
              moneyStyle: MoneyStyle.auto,
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  /// Título: nota si existe, si no categoría (igual que iOS `displayTitle`).
  String get _title {
    final String? note = transaction.note;
    if (note != null && note.isNotEmpty) return note;
    return transaction.category;
  }

  /// Subtítulo de la fila. Si el título es la nota, mostramos la categoría
  /// (con la subcategoría como sufijo si la hay). Si el título YA es la
  /// categoría (no había nota), mostramos solo la subcategoría para no
  /// repetir la categoría — o nada.
  String get _subtitle {
    final bool titleIsNote =
        transaction.note != null && transaction.note!.isNotEmpty;
    final String? sub = transaction.subcategory;
    final bool hasSub = sub != null && sub.isNotEmpty;

    if (titleIsNote) {
      return hasSub ? '${transaction.category} · $sub' : transaction.category;
    }
    return hasSub ? sub : transaction.category;
  }
}

// ──────────────────────────────── Summary bar ──────────────────────────────

/// Barra de resumen de la vista filtrada: cantidad de movimientos + Σ ingresos
/// (+) y Σ gastos (−). Espejo de los totales que iOS muestra arriba de la lista.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.count,
    required this.ingresos,
    required this.gastos,
    required this.currency,
    required this.privacy,
  });

  final int count;
  final Decimal ingresos;
  final Decimal gastos;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        Insets.screen,
        0,
        Insets.screen,
        Insets.sm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.card,
        vertical: Insets.lg,
      ),
      decoration: ShapeDecoration(
        color: c.appSurface,
        shape: StadiumBorder(side: BorderSide(color: c.appBorder)),
      ),
      child: Row(
        children: [
          Text(
            count == 1 ? '1 movimiento' : '$count movimientos',
            style: AppText.caption(c.textMuted),
          ),
          const Spacer(),
          Icon(LucideIcons.arrowDownLeft, size: 13, color: c.brandSuccess),
          const SizedBox(width: Insets.xs),
          AmountText(
            value: ingresos,
            currencyCode: currency,
            kind: AmountKind.ingreso,
            obscured: privacy,
            moneyStyle: MoneyStyle.compact,
            style: AppText.caption(c.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: Insets.card),
          Icon(LucideIcons.arrowUpRight, size: 13, color: c.brandDanger),
          const SizedBox(width: Insets.xs),
          AmountText(
            value: gastos,
            currencyCode: currency,
            kind: AmountKind.gasto,
            obscured: privacy,
            moneyStyle: MoneyStyle.compact,
            style: AppText.caption(c.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Error state ──────────────────────────────

/// Estado de error de la lista: empty-state con CTA de reintento.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.refreshCcw,
      title: 'No pudimos cargar los movimientos',
      message: 'Revisá tu conexión y volvé a intentar.',
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}
