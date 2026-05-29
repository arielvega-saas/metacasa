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
import '../../../state/app_providers.dart';
import '../application/recurring_controller.dart';
import 'add_recurring_sheet.dart';

/// Pantalla de Recurrentes — espejo de `RecurringListView` (iOS).
///
/// Estructura:
///   1. Lista de recurrentes (activas primero, inactivas atenuadas abajo): tile
///      de ícono por frecuencia, nota/categoría, "frecuencia · Próx: fecha",
///      monto coloreado por tipo (gasto coral / ingreso sage) y un switch
///      activo/inactivo (apagar → deactivate, prender → reactivate).
///   2. Swipe a la izquierda → eliminar.
///   3. "+ recurrente" en la AppBar y un CTA en el empty-state.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<RecurringState> recurringAsync =
        ref.watch(recurringControllerProvider);
    final String currency =
        ref.watch(currentHouseholdProvider).valueOrNull?.defaultCurrency ??
            'USD';
    final bool privacy = ref.watch(privacyModeProvider);
    final String? householdId =
        ref.watch(currentHouseholdProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Recurrentes', style: AppText.h2(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.brandPrimary),
            tooltip: 'Agregar recurrente',
            onPressed: householdId == null
                ? null
                : () => _openAdd(context, ref, householdId),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () =>
            ref.read(recurringControllerProvider.notifier).refresh(),
        child: recurringAsync.when(
          loading: () => const _RecurringSkeleton(),
          error: (Object err, StackTrace _) => _ErrorState(
            onRetry: () =>
                ref.read(recurringControllerProvider.notifier).refresh(),
          ),
          data: (RecurringState state) {
            if (state.isEmpty) {
              return _EmptyRecurring(
                onAdd: householdId == null
                    ? null
                    : () => _openAdd(context, ref, householdId),
              );
            }
            return _RecurringList(
              state: state,
              currency: currency,
              privacy: privacy,
            );
          },
        ),
      ),
    );
  }

  /// Abre la hoja de alta y, si guardó, refresca el controller.
  Future<void> _openAdd(
    BuildContext context,
    WidgetRef ref,
    String householdId,
  ) async {
    HapticFeedback.mediumImpact();
    final bool? saved = await AddRecurringSheet.show(context, householdId);
    if (saved ?? false) {
      await ref.read(recurringControllerProvider.notifier).refresh();
    }
  }
}

// ─────────────────────────────── Lista ─────────────────────────────────────

/// Lista scrollable de recurrentes. ListView con `AlwaysScrollableScrollPhysics`
/// para que el pull-to-refresh siempre funcione.
class _RecurringList extends ConsumerWidget {
  const _RecurringList({
    required this.state,
    required this.currency,
    required this.privacy,
  });

  final RecurringState state;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120, // espacio para el FAB del asistente del shell
      ),
      children: [
        ...state.items.map((RecurringTransaction r) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _RecurringRow(
                item: r,
                currency: currency,
                privacy: privacy,
                onToggle: (bool active) => _toggle(ref, r, active),
                onDelete: () => _delete(context, ref, r),
              ),
            )),
      ],
    );
  }

  Future<void> _toggle(
    WidgetRef ref,
    RecurringTransaction r,
    bool active,
  ) async {
    await HapticFeedback.selectionClick();
    final RecurringController ctrl =
        ref.read(recurringControllerProvider.notifier);
    if (active) {
      await ctrl.reactivate(r);
    } else {
      await ctrl.deactivate(r.id);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction r,
  ) async {
    await HapticFeedback.mediumImpact();
    await ref.read(recurringControllerProvider.notifier).delete(r.id);
  }
}

// ─────────────────────────────── Fila ──────────────────────────────────────

/// Fila de recurrente: tile de ícono por frecuencia, nota/categoría +
/// "frecuencia · Próx: fecha", monto coloreado por tipo y switch activo. Las
/// inactivas se atenúan. Swipe izquierda → eliminar. Espejo del `rowView` de iOS.
class _RecurringRow extends StatelessWidget {
  const _RecurringRow({
    required this.item,
    required this.currency,
    required this.privacy,
    required this.onToggle,
    required this.onDelete,
  });

  final RecurringTransaction item;
  final String currency;
  final bool privacy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // El título es la nota si la hay, si no la categoría (1:1 con iOS).
    final String title = (item.note != null && item.note!.isNotEmpty)
        ? item.note!
        : item.category;
    final AmountKind kind =
        item.type == TxType.gasto ? AmountKind.gasto : AmountKind.ingreso;

    final Widget card = Opacity(
      // Inactiva: atenuada para señalar que no genera movimientos.
      opacity: item.active ? 1 : 0.55,
      child: MCCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.cardLg,
          vertical: Insets.card,
        ),
        child: Row(
          children: [
            // Tile del ícono de frecuencia, tinte sage (igual recipe que iOS).
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: c.brandPrimary.withValues(alpha: 0.12),
                shape: SmoothRectangleBorder(
                  borderRadius: Radii.smooth(Radii.badge),
                ),
              ),
              child: Icon(_frequencyIcon(item.frequency),
                  size: 20, color: c.brandPrimary),
            ),
            const SizedBox(width: Insets.card),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body(c.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    _subtitle(item),
                    style: AppText.caption(c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AmountText(
                  value: item.amount,
                  currencyCode: currency,
                  kind: kind,
                  obscured: privacy,
                  style: AppText.serifAmount(c.textPrimary),
                ),
                const SizedBox(height: Insets.xs),
                // Switch compacto activo/inactivo (apagar → deactivate).
                SizedBox(
                  height: 28,
                  child: FittedBox(
                    fit: BoxFit.fitHeight,
                    child: Switch(
                      value: item.active,
                      activeColor: c.brandPrimary,
                      onChanged: onToggle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey<String>('recurring_${item.id}'),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(c),
      confirmDismiss: (_) => _confirmDelete(context, title),
      onDismissed: (_) => onDelete(),
      child: card,
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    final c = context.colors;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: c.appSurface,
        title: Text('Eliminar recurrente', style: AppText.h2(c.textPrimary)),
        content: Text(
          '¿Querés eliminar "$title"? No se puede deshacer.',
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

  Widget _deleteBackground(MidnightSageColors c) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: Insets.cardLg),
        decoration: ShapeDecoration(
          color: c.brandDanger.withValues(alpha: 0.18),
          shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Eliminar',
              style: AppText.body(c.brandDanger)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: Insets.md),
            Icon(LucideIcons.trash2, size: 18, color: c.brandDanger),
          ],
        ),
      );

  /// Subtítulo "frecuencia · Próx: fecha" (rioplatense). Port del `rowView` de
  /// iOS (frequency.label · próximo fecha).
  String _subtitle(RecurringTransaction r) {
    final String freq = _frequencyLabel(r.frequency);
    final DateTime? next = r.nextDate;
    if (next == null) return freq;
    return '$freq · Próx: ${_formatShortDate(next)}';
  }
}

// ─────────────────────────────── Estados ───────────────────────────────────

/// Empty-state: sin recurrentes todavía, con CTA de alta. Scrollable para el
/// pull-to-refresh.
class _EmptyRecurring extends StatelessWidget {
  const _EmptyRecurring({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.repeat,
            title: 'Sin recurrentes',
            message: 'Agregá tus gastos e ingresos fijos (alquiler, servicios, '
                'suscripciones, sueldo) y dejá que se repitan solos.',
            actionLabel: onAdd == null ? null : 'Agregar recurrente',
            onAction: onAdd,
          ),
        ),
      ],
    );
  }
}

/// Estado de error: EmptyState con reintento. Scrollable para el pull-to-refresh.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.cloudOff,
            title: 'No pudimos cargar tus recurrentes',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton mientras carga: filas placeholder. Scrollable para el pull-to-refresh.
class _RecurringSkeleton extends StatelessWidget {
  const _RecurringSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120,
      ),
      children: const [
        _SkeletonBlock(height: 68),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 68),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 68),
      ],
    );
  }
}

/// Bloque rectangular de skeleton (superficie con esquinas squircle).
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: ShapeDecoration(
        color: c.appSurface,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
    );
  }
}

// ─────────────────────────────── Helpers ───────────────────────────────────

/// Ícono lucide por frecuencia. Port del `Frequency.systemIcon` de iOS, mapeado
/// a equivalentes de lucide.
IconData _frequencyIcon(Frequency f) {
  switch (f) {
    case Frequency.daily:
      return LucideIcons.sun;
    case Frequency.weekly:
      return LucideIcons.calendarDays;
    case Frequency.monthly:
      return LucideIcons.calendar;
    case Frequency.yearly:
      return LucideIcons.calendarRange;
  }
}

/// Etiqueta legible de la frecuencia (es-AR). Port del `Frequency.label` de iOS.
String _frequencyLabel(Frequency f) {
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

/// Fecha corta legible (rioplatense): "5 may 2026".
String _formatShortDate(DateTime d) {
  const List<String> months = <String>[
    '',
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
  return '${d.day} ${months[d.month]} ${d.year}';
}
