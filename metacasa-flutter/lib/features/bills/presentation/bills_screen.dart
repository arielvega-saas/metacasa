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
import '../application/bills_controller.dart';
import 'add_bill_sheet.dart';

/// Pantalla de Vencimientos — espejo de `BillsListView` (iOS).
///
/// Estructura:
///   1. Secciones por urgencia (overdue → hoy → pronto → próximos → futuros →
///      pagados → saltados), cada una con un header de color (punto + etiqueta +
///      contador).
///   2. Cada fila: punto de urgencia, título, fecha de vencimiento (coloreada),
///      monto (privacy-aware) y, en pendientes, un botón "Pagar" (también swipe
///      de izquierda a derecha → markPaid). Swipe a la izquierda → eliminar.
///   3. "+ vencimiento" en la AppBar y un CTA en el empty-state.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<BillsState> billsAsync =
        ref.watch(billsControllerProvider);
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
        title: Text('Vencimientos', style: AppText.h2(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.brandPrimary),
            tooltip: 'Agregar vencimiento',
            onPressed: householdId == null
                ? null
                : () => _openAdd(context, ref, householdId),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () => ref.read(billsControllerProvider.notifier).refresh(),
        child: billsAsync.when(
          loading: () => const _BillsSkeleton(),
          error: (Object err, StackTrace _) => _ErrorState(
            onRetry: () => ref.read(billsControllerProvider.notifier).refresh(),
          ),
          data: (BillsState state) {
            if (state.isEmpty) {
              return _EmptyBills(
                onAdd: householdId == null
                    ? null
                    : () => _openAdd(context, ref, householdId),
              );
            }
            return _BillsList(
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
    final bool? saved = await AddBillSheet.show(context, householdId);
    if (saved ?? false) {
      await ref.read(billsControllerProvider.notifier).refresh();
    }
  }
}

// ─────────────────────────────── Lista ─────────────────────────────────────

/// Lista scrollable: por cada grupo de urgencia, un header de sección + sus
/// filas. ListView con `AlwaysScrollableScrollPhysics` para que el
/// pull-to-refresh siempre funcione.
class _BillsList extends ConsumerWidget {
  const _BillsList({
    required this.state,
    required this.currency,
    required this.privacy,
  });

  final BillsState state;
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
        for (final BillGroup group in state.groups) ...[
          _SectionHeader(urgency: group.urgency, count: group.bills.length),
          const SizedBox(height: Insets.md),
          ...group.bills.map((Bill bill) => Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: _BillRow(
                  bill: bill,
                  currency: currency,
                  privacy: privacy,
                  onMarkPaid: () => _markPaid(context, ref, bill),
                  onDelete: () => _delete(context, ref, bill),
                ),
              )),
          const SizedBox(height: Insets.lg),
        ],
      ],
    );
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref, Bill bill) async {
    await HapticFeedback.mediumImpact();
    await ref.read(billsControllerProvider.notifier).markPaid(bill.id);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Bill bill) async {
    await HapticFeedback.mediumImpact();
    await ref.read(billsControllerProvider.notifier).delete(bill.id);
  }
}

/// Header de una sección de urgencia: punto + etiqueta de color + contador.
/// Espejo del `urgencyBadge` de iOS.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.urgency, required this.count});

  final BillUrgencyLevel urgency;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ({Color color, String label}) style = _urgencyStyle(c, urgency);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Insets.md),
        Text(
          style.label.toUpperCase(),
          style: AppText.label(style.color),
        ),
        const Spacer(),
        Text(
          '$count',
          style:
              AppText.caption(c.textDim).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Fila ──────────────────────────────────────

/// Fila de vencimiento: tile de ícono coloreado por urgencia, título + fecha
/// (coloreada) + texto de días, monto (gasto) y, en pendientes, botón "Pagar".
/// Envuelta en un `Dismissible`: swipe derecha → pagar (solo pendientes), swipe
/// izquierda → eliminar. Espejo de `BillRow` + swipeActions de iOS.
class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.bill,
    required this.currency,
    required this.privacy,
    required this.onMarkPaid,
    required this.onDelete,
  });

  final Bill bill;
  final String currency;
  final bool privacy;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool pending = bill.status == BillStatus.pending;
    final ({Color color, String label}) style = _urgencyStyle(c, bill.urgency);

    final Widget card = MCCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      child: Row(
        children: [
          // Tile del ícono, tinte por urgencia (igual recipe que iOS).
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: style.color.withValues(alpha: 0.15),
              shape: SmoothRectangleBorder(
                borderRadius: Radii.smooth(Radii.badge),
              ),
            ),
            child:
                Icon(_urgencyIcon(bill.urgency), size: 20, color: style.color),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.title,
                  style: AppText.body(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.xxs),
                // Fecha de vencimiento: coloreada por urgencia para los
                // pendientes (overdue/hoy/pronto resaltan), neutra si ya cerró.
                Text(
                  _formatDate(bill.dueDate),
                  style: AppText.caption(pending ? style.color : c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (pending) ...[
                  const SizedBox(height: Insets.xxs),
                  Text(
                    _daysText(bill.daysUntilDue),
                    style: AppText.caption(c.textDim),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                value: bill.amount,
                currencyCode: bill.currency,
                kind: AmountKind.gasto,
                obscured: privacy,
                style: AppText.serifAmount(c.textPrimary),
              ),
              if (pending) ...[
                const SizedBox(height: Insets.sm),
                _PayButton(onTap: onMarkPaid),
              ],
            ],
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey<String>('bill_${bill.id}'),
      // Swipe derecha (startToEnd) = pagar, solo si está pendiente.
      // Swipe izquierda (endToStart) = eliminar (siempre).
      direction:
          pending ? DismissDirection.horizontal : DismissDirection.endToStart,
      background: pending ? _payBackground(c) : const SizedBox.shrink(),
      secondaryBackground: _deleteBackground(c),
      confirmDismiss: (DismissDirection dir) async {
        if (dir == DismissDirection.startToEnd) {
          // Pagar: ejecuta la acción pero NO descarta la fila (la lista se
          // recompone sola tras el refresh, reubicando el bill en "pagados").
          onMarkPaid();
          return false;
        }
        // Eliminar: pedimos confirmación.
        return _confirmDelete(context);
      },
      onDismissed: (_) => onDelete(),
      child: card,
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final c = context.colors;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: c.appSurface,
        title: Text('Eliminar vencimiento', style: AppText.h2(c.textPrimary)),
        content: Text(
          '¿Querés eliminar "${bill.title}"? No se puede deshacer.',
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

  Widget _payBackground(MidnightSageColors c) => Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: Insets.cardLg),
        decoration: ShapeDecoration(
          color: c.brandSuccess.withValues(alpha: 0.18),
          shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle, size: 18, color: c.brandSuccess),
            const SizedBox(width: Insets.md),
            Text(
              'Pagar',
              style: AppText.body(c.brandSuccess)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );

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
}

/// Botón compacto "Pagar" (pill sage) de la fila de un vencimiento pendiente.
class _PayButton extends StatelessWidget {
  const _PayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.card, vertical: 5),
        decoration: ShapeDecoration(
          color: c.brandSuccess.withValues(alpha: 0.16),
          shape: StadiumBorder(
            side: BorderSide(color: c.brandSuccess.withValues(alpha: 0.40)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.check, size: 12, color: c.brandSuccess),
            const SizedBox(width: Insets.xs),
            Text(
              'Pagar',
              style: AppText.caption(c.brandSuccess)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Estados ───────────────────────────────────

/// Empty-state: sin vencimientos todavía, con CTA de alta. Scrollable para el
/// pull-to-refresh.
class _EmptyBills extends StatelessWidget {
  const _EmptyBills({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.calendarClock,
            title: 'Sin vencimientos',
            message:
                'Cargá tus pagos con fecha (alquiler, tarjeta, servicios) y no te '
                'pierdas ninguno.',
            actionLabel: onAdd == null ? null : 'Agregar vencimiento',
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
            title: 'No pudimos cargar tus vencimientos',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton mientras carga: header + filas placeholder. Scrollable para el
/// pull-to-refresh.
class _BillsSkeleton extends StatelessWidget {
  const _BillsSkeleton();

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
        _SkeletonBlock(height: 16, width: 120),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 72),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 72),
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 16, width: 120),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 72),
      ],
    );
  }
}

/// Bloque rectangular de skeleton (superficie con esquinas squircle).
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      width: width,
      decoration: ShapeDecoration(
        color: c.appSurface,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
      ),
    );
  }
}

// ─────────────────────────────── Helpers ───────────────────────────────────

/// Color + etiqueta de un nivel de urgencia. Port del `urgencyBadge` de iOS:
/// overdue/hoy → coral, pronto/próximos → champagne, futuros → sage, pagados →
/// sage saturado, saltados → muted.
({Color color, String label}) _urgencyStyle(
  MidnightSageColors c,
  BillUrgencyLevel urgency,
) {
  switch (urgency) {
    case BillUrgencyLevel.overdue:
      return (color: c.brandDanger, label: 'Vencidos');
    case BillUrgencyLevel.dueToday:
      return (color: c.brandDanger, label: 'Hoy');
    case BillUrgencyLevel.dueSoon:
      return (color: c.brandWarning, label: 'Pronto');
    case BillUrgencyLevel.upcoming:
      return (color: c.brandWarning, label: 'Próximos');
    case BillUrgencyLevel.future:
      return (color: c.brandPrimary, label: 'Más adelante');
    case BillUrgencyLevel.paid:
      return (color: c.brandSuccess, label: 'Pagados');
    case BillUrgencyLevel.skipped:
      return (color: c.textMuted, label: 'Saltados');
  }
}

/// Ícono lucide por urgencia. Port del `iconName` de `BillRow` (iOS), mapeado a
/// equivalentes de lucide.
IconData _urgencyIcon(BillUrgencyLevel urgency) {
  switch (urgency) {
    case BillUrgencyLevel.paid:
      return LucideIcons.checkCircle;
    case BillUrgencyLevel.overdue:
      return LucideIcons.alertTriangle;
    case BillUrgencyLevel.dueToday:
      return LucideIcons.clock;
    case BillUrgencyLevel.dueSoon:
      return LucideIcons.alarmClock;
    case BillUrgencyLevel.upcoming:
      return LucideIcons.calendar;
    case BillUrgencyLevel.future:
      return LucideIcons.calendarPlus;
    case BillUrgencyLevel.skipped:
      return LucideIcons.minusCircle;
  }
}

/// Texto de días relativos al vencimiento (rioplatense). Port del `daysText` de
/// `BillRow` (iOS).
String _daysText(int days) {
  if (days < 0) {
    final int n = -days;
    return n == 1 ? 'Venció hace 1 día' : 'Venció hace $n días';
  }
  if (days == 0) return 'Vence hoy';
  return days == 1 ? 'Vence en 1 día' : 'Vence en $days días';
}

/// Fecha legible compacta (rioplatense): "5 de mayo de 2026".
String _formatDate(DateTime d) {
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
