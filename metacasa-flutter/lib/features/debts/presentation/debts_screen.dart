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
import '../../../state/app_providers.dart';
import '../application/debt_format.dart';
import '../application/debts_controller.dart';
import 'add_debt_sheet.dart';
import 'debt_detail_screen.dart';

/// Pantalla de Deudas — espejo de `DebtsListView` (iOS).
///
/// Estructura:
///   1. Total: deuda total viva (monto grande serif) + pago mensual total.
///   2. Lista de deudas: acreedor, tasa anual %, meses estimados, saldo y una
///      `MCProgressBar` de avance pagado. Tap → [DebtDetailScreen].
///   3. "+ deuda" en la AppBar y un CTA en el empty-state.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<DebtsState> async = ref.watch(debtsControllerProvider);
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
        title: Text('Deudas', style: AppText.h2(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.brandPrimary),
            tooltip: 'Agregar deuda',
            onPressed: householdId == null
                ? null
                : () => _openAdd(context, ref, householdId),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () => ref.read(debtsControllerProvider.notifier).refresh(),
        child: async.when(
          loading: () => const _Skeleton(),
          error: (Object err, StackTrace _) => _ErrorState(
            onRetry: () => ref.read(debtsControllerProvider.notifier).refresh(),
          ),
          data: (DebtsState state) {
            if (state.isEmpty) {
              return _EmptyDebts(
                onAdd: householdId == null
                    ? null
                    : () => _openAdd(context, ref, householdId),
              );
            }
            return _DebtsList(
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
    final bool? saved =
        await AddDebtSheet.show(context, householdId: householdId);
    if (saved ?? false) {
      await ref.read(debtsControllerProvider.notifier).refresh();
    }
  }
}

// ─────────────────────────────── Lista ─────────────────────────────────────

/// Lista scrollable: total + filas de deuda. `AlwaysScrollableScrollPhysics`
/// para que el pull-to-refresh siempre funcione.
class _DebtsList extends StatelessWidget {
  const _DebtsList({
    required this.state,
    required this.currency,
    required this.privacy,
  });

  final DebtsState state;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120, // espacio para el FAB del asistente del shell
      ),
      children: [
        _TotalCard(
          totalBalance: state.totalBalance,
          totalMonthly: state.totalMonthly,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        ...state.debts.map((Debt d) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _DebtRow(debt: d, privacy: privacy),
            )),
      ],
    );
  }
}

// ─────────────────────────────── Total ─────────────────────────────────────

/// Card de total: la deuda total viva (monto grande serif, coral) + el pago
/// mensual total. Espejo del `totalCard` de iOS.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.totalBalance,
    required this.totalMonthly,
    required this.currency,
    required this.privacy,
  });

  final Decimal totalBalance;
  final Decimal totalMonthly;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEUDA TOTAL', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.sm),
          AmountText(
            value: totalBalance,
            currencyCode: currency,
            kind: AmountKind.gasto,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifHero(c.textPrimary),
          ),
          if (totalMonthly > Decimal.zero) ...[
            Divider(color: c.appBorder, height: Insets.section * 2),
            Row(
              children: [
                Icon(LucideIcons.calendarClock, size: 14, color: c.textMuted),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child:
                      Text('Pago mensual', style: AppText.caption(c.textMuted)),
                ),
                AmountText(
                  value: totalMonthly,
                  currencyCode: currency,
                  kind: AmountKind.gasto,
                  obscured: privacy,
                  style: AppText.body(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Fila de deuda ─────────────────────────────

/// Fila de deuda: acreedor + tasa % (• meses estimados), saldo (gasto), barra
/// de progreso pagado y "% pagado". Tap → detalle. Espejo del `DebtRow` de iOS.
class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.privacy});

  final Debt debt;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool settled = debt.status == DebtStatus.settled;
    final int? months = debt.estimatedMonthsToPayoff;

    return MCCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DebtDetailScreen(debt: debt),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.creditor,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Insets.xxs),
                    Row(
                      children: [
                        Icon(LucideIcons.percent, size: 11, color: c.textMuted),
                        const SizedBox(width: Insets.xs),
                        Text(
                          '${formatRate(debt.annualRate)}%',
                          style: AppText.caption(c.textMuted),
                        ),
                        if (months != null) ...[
                          Text('  ·  ', style: AppText.caption(c.textDim)),
                          Text(
                            '${formatMonthsDuration(months)} restantes',
                            style: AppText.caption(c.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
              AmountText(
                value: debt.currentBalance,
                currencyCode: debt.currency,
                kind: AmountKind.gasto,
                obscured: privacy,
                style: AppText.serifAmount(c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: Insets.card),
          MCProgressBar(
            percent: debt.progress,
            color: settled ? c.brandSuccess : c.brandPrimary,
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: Text('Pagado', style: AppText.caption(c.textMuted)),
              ),
              Text(
                '${(debt.progress * 100).round()}%',
                style:
                    AppText.caption(settled ? c.brandSuccess : c.brandPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Estados ───────────────────────────────────

/// Empty-state: sin deudas todavía, con CTA de alta. Scrollable para el
/// pull-to-refresh.
class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.arrowDownToLine,
            title: 'Todavía no tenés deudas',
            message:
                'Cargá tus préstamos y créditos para proyectar cuándo los terminás.',
            actionLabel: onAdd == null ? null : 'Agregar deuda',
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
            title: 'No pudimos cargar tus deudas',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton mientras carga: total + filas placeholder. Scrollable para el
/// pull-to-refresh.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

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
        _SkeletonBlock(height: 150),
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 116),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 116),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 116),
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
