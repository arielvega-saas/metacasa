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
import '../../../state/app_providers.dart';
import '../application/debt_format.dart';
import '../application/debts_controller.dart';
import 'add_debt_sheet.dart';

/// Detalle de una deuda — espejo 1:1 de `DebtDetailView` (iOS).
///
/// Cuatro cards apiladas:
///   1. SALDO — saldo actual (grande) + original + barra de progreso pagado.
///   2. INTERÉS — tasa anual, interés mensual estimado y pago mensual.
///   3. PROYECCIÓN — payoff en N meses (a/m) + fecha estimada, y el vencimiento
///      con los días que faltan (rojo si vencido).
///   4. NOTA — si la deuda tiene nota.
///
/// Menú (⋮): Editar (abre [AddDebtSheet] en modo edición) y Saldar (si activa).
/// La edición re-sincroniza el `_debt` local desde el estado del controller; el
/// saldado vuelve atrás (la lista ya quedó refrescada por el controller).
class DebtDetailScreen extends ConsumerStatefulWidget {
  const DebtDetailScreen({super.key, required this.debt});

  /// Deuda cuyo detalle se muestra.
  final Debt debt;

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  late Debt _debt;

  @override
  void initState() {
    super.initState();
    _debt = widget.debt;
  }

  /// Re-sincroniza el `_debt` local con la versión más fresca del controller
  /// (por id). Tras una edición, el controller ya recargó; tomamos el nuevo
  /// valor para que el detalle refleje los cambios sin volver atrás.
  void _syncFromController() {
    final DebtsState? state = ref.read(debtsControllerProvider).valueOrNull;
    if (state == null) return;
    for (final Debt d in state.debts) {
      if (d.id == _debt.id) {
        setState(() => _debt = d);
        return;
      }
    }
  }

  Future<void> _edit() async {
    final bool? saved = await AddDebtSheet.show(context,
        householdId: _debt.householdId, editing: _debt);
    if (saved ?? false) _syncFromController();
  }

  Future<void> _confirmSettle() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final c = ctx.colors;
        return AlertDialog(
          backgroundColor: c.appSurface,
          title: Text('Saldar deuda', style: AppText.h2(c.textPrimary)),
          content: Text(
            'La deuda quedará marcada como saldada y su saldo en cero. '
            'Esta acción no se puede deshacer.',
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
                'Saldar',
                style: AppText.body(c.brandPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      await ref.read(debtsControllerProvider.notifier).settle(_debt.id);
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo saldar la deuda.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool privacy = ref.watch(privacyModeProvider);
    final bool active = _debt.status == DebtStatus.active;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text(
          _debt.creditor,
          style: AppText.h2(c.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<_DebtMenuAction>(
            icon: Icon(LucideIcons.moreVertical, color: c.textPrimary),
            color: c.appSurface,
            onSelected: (_DebtMenuAction action) {
              switch (action) {
                case _DebtMenuAction.edit:
                  _edit();
                case _DebtMenuAction.settle:
                  _confirmSettle();
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_DebtMenuAction>>[
              PopupMenuItem<_DebtMenuAction>(
                value: _DebtMenuAction.edit,
                child: Row(
                  children: [
                    Icon(LucideIcons.pencil, size: 18, color: c.textPrimary),
                    const SizedBox(width: Insets.md),
                    Text('Editar', style: AppText.body(c.textPrimary)),
                  ],
                ),
              ),
              if (active)
                PopupMenuItem<_DebtMenuAction>(
                  value: _DebtMenuAction.settle,
                  child: Row(
                    children: [
                      Icon(LucideIcons.checkCircle2,
                          size: 18, color: c.brandSuccess),
                      const SizedBox(width: Insets.md),
                      Text('Saldar', style: AppText.body(c.textPrimary)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.screen,
          Insets.section,
          Insets.screen,
          Insets.xxl,
        ),
        children: [
          _BalanceCard(debt: _debt, privacy: privacy),
          const SizedBox(height: Insets.section),
          _InterestCard(debt: _debt, privacy: privacy),
          const SizedBox(height: Insets.section),
          _ProjectionCard(debt: _debt),
          if (_debt.note != null && _debt.note!.isNotEmpty) ...[
            const SizedBox(height: Insets.section),
            _NoteCard(note: _debt.note!),
          ],
        ],
      ),
    );
  }
}

/// Acciones del menú del detalle.
enum _DebtMenuAction { edit, settle }

// ─────────────────────────────── Saldo ─────────────────────────────────────

/// Card de SALDO: saldo actual (grande, coral con `-`) + original + barra de
/// progreso pagado + "% pagado".
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.debt, required this.privacy});

  final Debt debt;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool settled = debt.status == DebtStatus.settled;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SALDO ACTUAL', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: debt.currentBalance,
            currencyCode: debt.currency,
            kind: AmountKind.gasto,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifHero(c.textPrimary),
          ),
          const SizedBox(height: Insets.card),
          Row(
            children: [
              Expanded(
                child: Text('Original', style: AppText.caption(c.textMuted)),
              ),
              AmountText(
                value: debt.originalAmount,
                currencyCode: debt.currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                style: AppText.body(c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: Insets.card),
          MCProgressBar(
            percent: debt.progress,
            color: settled ? c.brandSuccess : c.brandPrimary,
          ),
          const SizedBox(height: Insets.md),
          Text(
            '${(debt.progress * 100).round()}% pagado',
            style: AppText.caption(c.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Interés ───────────────────────────────────

/// Card de INTERÉS: tasa anual %, interés mensual estimado y pago mensual (si
/// está definido). La matemática vive en el modelo (`estimatedMonthlyInterest`).
class _InterestCard extends StatelessWidget {
  const _InterestCard({required this.debt, required this.privacy});

  final Debt debt;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Decimal? monthlyPayment = debt.monthlyPayment;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.percent, size: 14, color: c.textMuted),
              const SizedBox(width: Insets.sm),
              Text('INTERÉS', style: AppText.label(c.textMuted)),
            ],
          ),
          const SizedBox(height: Insets.card),
          _Row(
            label: 'Tasa anual',
            valueWidget: Text(
              '${formatRate(debt.annualRate)}%',
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: Insets.card),
          _Row(
            label: 'Interés mensual estimado',
            valueWidget: AmountText(
              value: debt.estimatedMonthlyInterest,
              currencyCode: debt.currency,
              kind: AmountKind.gasto,
              obscured: privacy,
              moneyStyle: MoneyStyle.auto,
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (monthlyPayment != null) ...[
            const SizedBox(height: Insets.card),
            _Row(
              label: 'Pago mensual',
              valueWidget: AmountText(
                value: monthlyPayment,
                currencyCode: debt.currency,
                kind: AmountKind.gasto,
                obscured: privacy,
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Proyección ────────────────────────────────

/// Card de PROYECCIÓN: payoff en N meses (a/m) + fecha estimada (hoy + N meses)
/// o un aviso si el pago no cubre el interés; más el vencimiento con los días
/// restantes (coral si vencido). Espejo del `projectionCard` de iOS.
class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final int? months = debt.estimatedMonthsToPayoff;
    final int? days = debt.daysUntilMaturity;
    final DateTime? maturity = debt.maturityDate;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendarClock, size: 14, color: c.textMuted),
              const SizedBox(width: Insets.sm),
              Text('PROYECCIÓN', style: AppText.label(c.textMuted)),
            ],
          ),
          const SizedBox(height: Insets.card),
          if (months != null) ...[
            _Row(
              label: 'Terminás en',
              valueWidget: Text(
                formatMonthsDuration(months),
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: Insets.card),
            _Row(
              label: 'Fecha estimada',
              valueWidget: Text(
                formatMonthYear(_addMonths(DateTime.now(), months)),
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ] else
            Text(
              debt.monthlyPayment == null
                  ? 'Cargá un pago mensual para proyectar cuándo la terminás.'
                  : 'El pago mensual no alcanza a cubrir el interés.',
              style: AppText.caption(c.textMuted),
            ),
          if (maturity != null) ...[
            Divider(color: c.appBorder, height: Insets.section * 2),
            _Row(
              label: 'Vencimiento',
              valueWidget: Text(
                formatLongDate(maturity),
                style: AppText.body(c.textPrimary),
              ),
            ),
            const SizedBox(height: Insets.sm),
            if (days != null)
              Text(
                days < 0 ? 'Vencida' : 'Faltan $days días',
                style: AppText.caption(days < 0 ? c.brandDanger : c.textMuted)
                    .copyWith(
                  fontWeight: days < 0 ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Suma [months] meses a [base] manejando el wrap de año. Equivale al
  /// `Calendar.date(byAdding: .month, …)` de iOS sin traer `intl`.
  static DateTime _addMonths(DateTime base, int months) {
    final int total = base.month - 1 + months;
    final int year = base.year + total ~/ 12;
    final int month = total % 12 + 1;
    return DateTime(year, month, base.day);
  }
}

// ─────────────────────────────── Nota ──────────────────────────────────────

/// Card de NOTA: el texto libre de la deuda.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTA', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          Text(note, style: AppText.body(c.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Fila genérica ─────────────────────────────

/// Fila "etiqueta … valor" de las cards de detalle.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.valueWidget});

  final String label;
  final Widget valueWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(child: Text(label, style: AppText.caption(c.textMuted))),
        const SizedBox(width: Insets.card),
        valueWidget,
      ],
    );
  }
}
