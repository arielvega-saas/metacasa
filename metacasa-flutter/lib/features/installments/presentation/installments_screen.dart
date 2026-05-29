import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/installments_controller.dart';
import 'add_installment_sheet.dart';
import 'installment_detail_screen.dart';

/// Pantalla de Cuotas — espejo de `InstallmentsListView` (iOS), enriquecida con
/// un resumen de compromiso mensual + deuda remanente.
///
/// Estructura:
///   1. Resumen: cuota mensual total (lo que sale cada mes por cuotas) + total
///      restante (lo que falta pagar de todos los planes activos).
///   2. Lista de planes: descripción, "X/N cuotas", monto mensual y una
///      `MCProgressBar` de avance. Tap → [InstallmentDetailScreen].
///   3. "+ plan" en la AppBar y un CTA en el empty-state.
class InstallmentsScreen extends ConsumerWidget {
  const InstallmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<InstallmentsState> async =
        ref.watch(installmentsControllerProvider);
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
        title: Text('Cuotas', style: AppText.h2(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.brandPrimary),
            tooltip: 'Agregar plan',
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
            ref.read(installmentsControllerProvider.notifier).refresh(),
        child: async.when(
          loading: () => const _Skeleton(),
          error: (Object err, StackTrace _) => _ErrorState(
            onRetry: () =>
                ref.read(installmentsControllerProvider.notifier).refresh(),
          ),
          data: (InstallmentsState state) {
            if (state.isEmpty) {
              return _EmptyInstallments(
                onAdd: householdId == null
                    ? null
                    : () => _openAdd(context, ref, householdId),
              );
            }
            return _InstallmentsList(
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
    final bool? saved = await AddInstallmentSheet.show(context, householdId);
    if (saved ?? false) {
      await ref.read(installmentsControllerProvider.notifier).refresh();
    }
  }
}

// ─────────────────────────────── Lista ─────────────────────────────────────

/// Lista scrollable: resumen + filas de plan. `AlwaysScrollableScrollPhysics`
/// para que el pull-to-refresh siempre funcione.
class _InstallmentsList extends StatelessWidget {
  const _InstallmentsList({
    required this.state,
    required this.currency,
    required this.privacy,
  });

  final InstallmentsState state;
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
        _SummaryCard(
          totalMonthly: state.totalMonthly,
          totalRemaining: state.totalRemaining,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        ...state.plans.map((PlanProgress pp) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _PlanRow(
                progress: pp,
                currency: currency,
                privacy: privacy,
              ),
            )),
      ],
    );
  }
}

// ─────────────────────────────── Resumen ───────────────────────────────────

/// Card de resumen: la cuota mensual total (monto grande serif) + el total
/// restante. Espejo del compromiso de cuotas (no hay equivalente directo en el
/// iOS, que muestra el resumen por plan; acá lo agregamos para dar contexto).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalMonthly,
    required this.totalRemaining,
    required this.currency,
    required this.privacy,
  });

  final Decimal totalMonthly;
  final Decimal totalRemaining;
  final String currency;
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
            value: totalMonthly,
            currencyCode: currency,
            kind: AmountKind.gasto,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifDisplay(c.textPrimary),
          ),
          Divider(color: c.appBorder, height: Insets.section * 2),
          Row(
            children: [
              Icon(LucideIcons.wallet, size: 14, color: c.textMuted),
              const SizedBox(width: Insets.sm),
              Expanded(
                child:
                    Text('Total restante', style: AppText.caption(c.textMuted)),
              ),
              AmountText(
                value: totalRemaining,
                currencyCode: currency,
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

// ─────────────────────────────── Fila de plan ──────────────────────────────

/// Fila de plan: descripción + categoría, monto mensual (gasto), barra de
/// progreso y "X/N cuotas". Tap → detalle. Espejo del `PlanRow` de iOS.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.progress,
    required this.currency,
    required this.privacy,
  });

  final PlanProgress progress;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plan = progress.plan;
    final bool done = progress.isCompleted;

    return MCCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InstallmentDetailScreen(plan: plan),
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
                      plan.name,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plan.category != null && plan.category!.isNotEmpty) ...[
                      const SizedBox(height: Insets.xxs),
                      Text(
                        plan.category!,
                        style: AppText.caption(c.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    value: plan.monthlyAmount,
                    currencyCode: plan.currency,
                    kind: AmountKind.gasto,
                    obscured: privacy,
                    style: AppText.serifAmount(c.textPrimary),
                  ),
                  Text('por mes', style: AppText.caption(c.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.card),
          MCProgressBar(
            percent: progress.progress,
            color: done ? c.brandSuccess : c.brandPrimary,
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${progress.paidCount}/${progress.totalCount} cuotas',
                  style: AppText.caption(c.textMuted),
                ),
              ),
              AmountText(
                value: plan.totalAmount,
                currencyCode: plan.currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                style: AppText.caption(c.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Estados ───────────────────────────────────

/// Empty-state: sin planes todavía, con CTA de alta. Scrollable para el
/// pull-to-refresh.
class _EmptyInstallments extends StatelessWidget {
  const _EmptyInstallments({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.creditCard,
            title: 'Todavía no tenés cuotas',
            message:
                'Cargá tus compras en cuotas para seguir cuánto pagás cada mes.',
            actionLabel: onAdd == null ? null : 'Agregar plan',
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
            title: 'No pudimos cargar tus cuotas',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton mientras carga: resumen + filas placeholder. Scrollable para el
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
        _SkeletonBlock(height: 130),
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 108),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 108),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 108),
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
