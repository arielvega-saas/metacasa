import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/installment_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/installments_controller.dart';

/// Detalle de un plan de cuotas con el ledger mes a mes — espejo 1:1 de
/// `InstallmentDetailView` (iOS).
///
/// Tres bloques:
///   1. Cabecera: monto mensual (grande) + total del plan.
///   2. Progreso: "X/N cuotas" + `MCProgressBar` + porcentaje.
///   3. Ledger: una fila por cuota (check de pago, número + MM/YYYY, monto y
///      "marcar paga" si está pendiente).
///
/// El ledger se carga localmente (`fetchPayments`). Al marcar una cuota como
/// paga se recarga el ledger y se invalida el controller de la lista para que
/// el resumen y el progreso de la pantalla anterior queden vivos.
class InstallmentDetailScreen extends ConsumerStatefulWidget {
  const InstallmentDetailScreen({super.key, required this.plan});

  /// Plan cuyo detalle + ledger se muestran.
  final InstallmentPlan plan;

  @override
  ConsumerState<InstallmentDetailScreen> createState() =>
      _InstallmentDetailScreenState();
}

class _InstallmentDetailScreenState
    extends ConsumerState<InstallmentDetailScreen> {
  List<InstallmentPayment> _payments = <InstallmentPayment>[];
  bool _loading = true;
  bool _error = false;

  InstallmentPlan get _plan => widget.plan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final List<InstallmentPayment> rows =
          await ref.read(installmentRepositoryProvider).fetchPayments(_plan.id);
      if (!mounted) return;
      setState(() {
        _payments = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// Marca una cuota como paga, recarga el ledger e invalida la lista (para que
  /// el resumen/progreso de la pantalla anterior se actualice).
  Future<void> _markPaid(InstallmentPayment payment) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(installmentRepositoryProvider).markPaymentPaid(payment.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo marcar la cuota.')),
        );
      }
      return;
    }
    await _load();
    // El controller observa el hogar; refrescarlo recomputa paid counts.
    await ref.read(installmentsControllerProvider.notifier).refresh();
  }

  int get _paidCount =>
      _payments.where((InstallmentPayment p) => p.paid).length;

  double get _progress {
    if (_plan.totalInstallments <= 0) return 0;
    return (_paidCount / _plan.totalInstallments).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool privacy = ref.watch(privacyModeProvider);

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text(
          _plan.name,
          style: AppText.h2(c.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Insets.screen,
            Insets.section,
            Insets.screen,
            Insets.xxl,
          ),
          children: [
            _HeaderCard(plan: _plan, privacy: privacy),
            const SizedBox(height: Insets.section),
            _ProgressCard(
              paidCount: _paidCount,
              total: _plan.totalInstallments,
              progress: _progress,
            ),
            const SizedBox(height: Insets.section),
            _LedgerCard(
              loading: _loading,
              error: _error,
              payments: _payments,
              currency: _plan.currency,
              privacy: privacy,
              onMarkPaid: _markPaid,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Cabecera ──────────────────────────────────

/// Card de cabecera: monto mensual (grande, gasto) + total del plan.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.plan, required this.privacy});

  final InstallmentPlan plan;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CUOTA MENSUAL', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: plan.monthlyAmount,
            currencyCode: plan.currency,
            kind: AmountKind.gasto,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifDisplay(c.textPrimary),
          ),
          const SizedBox(height: Insets.card),
          Row(
            children: [
              Icon(LucideIcons.sigma, size: 14, color: c.textMuted),
              const SizedBox(width: Insets.sm),
              Expanded(
                child:
                    Text('Total del plan', style: AppText.caption(c.textMuted)),
              ),
              AmountText(
                value: plan.totalAmount,
                currencyCode: plan.currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Progreso ──────────────────────────────────

/// Card de progreso: "X/N cuotas" + barra + porcentaje (sage, o verde si 100%).
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.paidCount,
    required this.total,
    required this.progress,
  });

  final int paidCount;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool done = progress >= 1;
    final Color pctColor = done ? c.brandSuccess : c.brandPrimary;

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$paidCount/$total cuotas',
                  style: AppText.label(c.textMuted),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppText.caption(pctColor)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          MCProgressBar(
            percent: progress,
            color: done ? c.brandSuccess : c.brandPrimary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Ledger ────────────────────────────────────

/// Card del ledger: lista de cuotas con check de pago, número + período,
/// monto y "marcar paga" si está pendiente. Espejo del `paymentsCard` de iOS.
class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.loading,
    required this.error,
    required this.payments,
    required this.currency,
    required this.privacy,
    required this.onMarkPaid,
  });

  final bool loading;
  final bool error;
  final List<InstallmentPayment> payments;
  final String currency;
  final bool privacy;
  final ValueChanged<InstallmentPayment> onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CALENDARIO DE PAGOS', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.card),
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.xxl),
              child: Center(
                child: CircularProgressIndicator(color: c.brandPrimary),
              ),
            )
          else if (error)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.cardLg),
              child: Text(
                'No pudimos cargar el calendario de pagos.',
                style: AppText.body(c.brandDanger),
              ),
            )
          else if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.cardLg),
              child: Text(
                'Este plan todavía no tiene cuotas cargadas.',
                style: AppText.body(c.textMuted),
              ),
            )
          else
            for (int i = 0; i < payments.length; i++) ...[
              _LedgerRow(
                payment: payments[i],
                currency: currency,
                privacy: privacy,
                onMarkPaid: onMarkPaid,
              ),
              if (i != payments.length - 1)
                Divider(color: c.appBorder, height: Insets.section * 2),
            ],
        ],
      ),
    );
  }
}

/// Una fila del ledger: check, "Cuota N · MM/YYYY" (+ fecha de pago si paga),
/// monto y botón "marcar paga" cuando está pendiente.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.payment,
    required this.currency,
    required this.privacy,
    required this.onMarkPaid,
  });

  final InstallmentPayment payment;
  final String currency;
  final bool privacy;
  final ValueChanged<InstallmentPayment> onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool paid = payment.paid;
    final String period =
        '${payment.periodMonth.toString().padLeft(2, '0')}/${payment.periodYear}';

    return Row(
      children: [
        Icon(
          paid ? LucideIcons.checkCircle2 : LucideIcons.circle,
          size: 20,
          color: paid ? c.brandSuccess : c.textDim,
        ),
        const SizedBox(width: Insets.card),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cuota ${payment.installmentNumber} · $period',
                style: AppText.body(c.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              if (paid && payment.paidAt != null) ...[
                const SizedBox(height: Insets.xxs),
                Text(
                  'Pagada el ${_formatDate(payment.paidAt!)}',
                  style: AppText.caption(c.textMuted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        AmountText(
          value: payment.amount,
          currencyCode: currency,
          kind: AmountKind.gasto,
          obscured: privacy,
          style: AppText.body(c.textPrimary).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!paid) ...[
          const SizedBox(width: Insets.sm),
          IconButton(
            icon: Icon(LucideIcons.checkCircle, color: c.brandPrimary),
            tooltip: 'Marcar paga',
            visualDensity: VisualDensity.compact,
            onPressed: () => onMarkPaid(payment),
          ),
        ],
      ],
    );
  }

  /// Fecha local abreviada `dd/MM/yyyy` (sin traer `intl` solo para esto;
  /// mismo recipe que `credit_card_detail_screen`).
  static String _formatDate(DateTime date) {
    final DateTime d = date.toLocal();
    final String dd = d.day.toString().padLeft(2, '0');
    final String mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
