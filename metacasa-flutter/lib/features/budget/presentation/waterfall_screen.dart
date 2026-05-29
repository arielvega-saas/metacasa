import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/finance/waterfall_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/waterfall_controller.dart';
import 'strategy_sheet.dart';

/// Pantalla del presupuesto **Waterfall** (cascada) multi-persona. Espejo de
/// `WaterfallBudgetView` (iOS).
///
/// De arriba a abajo:
///   1. Income card: ingreso total del mes + desglose por cuenta
///   2. Deductions card: fijos / bills / cuotas / deudas / compartido (solo los
///      incluidos por la estrategia) + ahorro % / inversión %
///   3. Remainder card (resaltada con borde sage)
///   4. Distribution card: reparto del remanente por cuenta personal
///
/// La matemática la corre el `WaterfallCalculator` (port 1:1 de iOS) sobre los
/// inputs del [waterfallControllerProvider]. AppBar trailing = engranaje (abre
/// la estrategia). Pull-to-refresh recarga los inputs. Montos privacy-aware.
class WaterfallScreen extends ConsumerWidget {
  const WaterfallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Cascada', style: AppText.serifTitle(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.sliders, color: c.textPrimary),
            tooltip: 'Estrategia',
            onPressed: () {
              HapticFeedback.selectionClick();
              StrategySheet.show(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () =>
            ref.read(waterfallControllerProvider.notifier).refresh(),
        child: const _WaterfallBody(),
      ),
    );
  }
}

class _WaterfallBody extends ConsumerWidget {
  const _WaterfallBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WaterfallInputs> async =
        ref.watch(waterfallControllerProvider);
    final bool privacy = ref.watch(privacyModeProvider);

    return async.when(
      loading: () => const _WaterfallSkeleton(),
      error: (Object err, StackTrace _) => _ErrorState(
        onRetry: () => ref.read(waterfallControllerProvider.notifier).refresh(),
      ),
      data: (WaterfallInputs inputs) =>
          _WaterfallContent(inputs: inputs, privacy: privacy),
    );
  }
}

class _WaterfallContent extends StatelessWidget {
  const _WaterfallContent({required this.inputs, required this.privacy});

  final WaterfallInputs inputs;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final WaterfallResult r = inputs.calculate();
    final String currency = inputs.currency;
    final HouseholdStrategy strategy = inputs.strategy;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120,
      ),
      children: [
        _IncomeCard(
          total: r.totalIncome,
          byAccount: inputs.incomeByAccount,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.card),
        _DeductionsCard(
          result: r,
          strategy: strategy,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.card),
        _RemainderCard(
          remainder: r.remainder,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.card),
        _DistributionCard(
          distribution: r.distribution,
          mode: strategy.distributionMode,
          currency: currency,
          privacy: privacy,
        ),
      ],
    );
  }
}

// ─────────────────────────────── Income card ───────────────────────────────

/// Card de ingresos: total grande sage + desglose por cuenta (hasta 5). Espejo
/// del `incomeCard` de iOS.
class _IncomeCard extends StatelessWidget {
  const _IncomeCard({
    required this.total,
    required this.byAccount,
    required this.currency,
    required this.privacy,
  });

  final Decimal total;
  final List<AccountIncome> byAccount;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final List<AccountIncome> shown = byAccount.take(5).toList();

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.arrowDownCircle,
                  size: 16, color: c.brandSuccess),
              const SizedBox(width: Insets.md),
              Text('INGRESOS', style: AppText.label(c.textMuted)),
            ],
          ),
          const SizedBox(height: Insets.md),
          AmountText(
            value: total,
            currencyCode: currency,
            kind: AmountKind.ingreso,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifDisplay(c.textPrimary),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: Insets.card),
            Divider(color: c.appBorder, height: 1),
            const SizedBox(height: Insets.md),
            ...shown.map(
              (AccountIncome e) => Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: Row(
                  children: [
                    Icon(_accountIcon(e.account.type),
                        size: 16, color: c.textMuted),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        e.account.name,
                        style: AppText.caption(c.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AmountText(
                      value: e.amount,
                      currencyCode: e.account.currency,
                      kind: AmountKind.ingreso,
                      obscured: privacy,
                      moneyStyle: MoneyStyle.compact,
                      style: AppText.caption(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────── Deductions ────────────────────────────────

/// Card de deducciones de la cascada: fijos / bills / cuotas / deudas /
/// compartido (solo los incluidos por la estrategia), separador, y ahorro % /
/// inversión %. Espejo del `cascadeCard` de iOS.
class _DeductionsCard extends StatelessWidget {
  const _DeductionsCard({
    required this.result,
    required this.strategy,
    required this.currency,
    required this.privacy,
  });

  final WaterfallResult result;
  final HouseholdStrategy strategy;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.arrowDownToLine,
                  size: 16, color: c.brandWarning),
              const SizedBox(width: Insets.md),
              Text('DEDUCCIONES', style: AppText.label(c.textMuted)),
            ],
          ),
          const SizedBox(height: Insets.card),
          _DeductionRow(
            icon: LucideIcons.repeat,
            label: 'Gastos fijos',
            amount: result.fixedDeduction,
            currency: currency,
            privacy: privacy,
          ),
          if (strategy.includeBillsInWaterfall)
            _DeductionRow(
              icon: LucideIcons.calendarClock,
              label: 'Vencimientos',
              amount: result.billsDeduction,
              currency: currency,
              privacy: privacy,
            ),
          if (strategy.includeInstallmentsInWaterfall)
            _DeductionRow(
              icon: LucideIcons.creditCard,
              label: 'Cuotas',
              amount: result.installmentsDeduction,
              currency: currency,
              privacy: privacy,
            ),
          if (strategy.includeDebtPaymentsInWaterfall)
            _DeductionRow(
              icon: LucideIcons.arrowDownToLine,
              label: 'Deudas',
              amount: result.debtPaymentsDeduction,
              currency: currency,
              privacy: privacy,
            ),
          _DeductionRow(
            icon: LucideIcons.users,
            label: 'Compartido',
            amount: result.sharedBudgetsDeduction,
            currency: currency,
            privacy: privacy,
          ),
          const SizedBox(height: Insets.sm),
          Divider(color: c.appBorder, height: 1),
          const SizedBox(height: Insets.sm),
          _DeductionRow(
            icon: LucideIcons.banknote,
            label: 'Ahorro',
            detail: '${_pctInt(strategy.savingsPct)}%',
            amount: result.savingsAllocation,
            currency: currency,
            privacy: privacy,
            isSavings: true,
          ),
          _DeductionRow(
            icon: LucideIcons.trendingUp,
            label: 'Inversión',
            detail: '${_pctInt(strategy.investmentPct)}%',
            amount: result.investmentAllocation,
            currency: currency,
            privacy: privacy,
            isSavings: true,
          ),
        ],
      ),
    );
  }
}

/// Una fila de deducción: ícono (coral gasto / sage ahorro) + label (+ detalle)
/// + monto. Espejo del `deductionRow` de iOS.
class _DeductionRow extends StatelessWidget {
  const _DeductionRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
    required this.privacy,
    this.detail,
    this.isSavings = false,
  });

  final IconData icon;
  final String label;
  final Decimal amount;
  final String currency;
  final bool privacy;
  final String? detail;
  final bool isSavings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color iconColor = isSavings ? c.brandSuccess : c.brandDanger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(c.textPrimary)),
                if (detail != null)
                  Text(detail!, style: AppText.caption(c.textMuted)),
              ],
            ),
          ),
          AmountText(
            value: amount,
            currencyCode: currency,
            // Ahorro/inversión se muestran como ingreso (sage), las deducciones
            // como gasto (coral con signo), igual que iOS.
            kind: isSavings ? AmountKind.ingreso : AmountKind.gasto,
            obscured: privacy,
            moneyStyle: MoneyStyle.compact,
            style: AppText.body(c.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Remainder ─────────────────────────────────

/// Card del remanente, resaltada con borde sage. Espejo del `remainderCard` de
/// iOS.
class _RemainderCard extends StatelessWidget {
  const _RemainderCard({
    required this.remainder,
    required this.currency,
    required this.privacy,
  });

  final Decimal remainder;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      glow: remainder >= Decimal.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.equal, size: 16, color: c.brandPrimary),
              const SizedBox(width: Insets.md),
              Text('REMANENTE', style: AppText.label(c.textMuted)),
            ],
          ),
          const SizedBox(height: Insets.md),
          AmountText(
            value: remainder,
            currencyCode: currency,
            kind: AmountKind.balance,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifDisplay(c.textPrimary),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Lo que queda para repartir entre las cuentas personales.',
            style: AppText.caption(c.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Distribution ──────────────────────────────

/// Card de distribución del remanente por cuenta personal. Si no hay cuentas
/// personales, muestra un hint. Espejo del `distributionCard` de iOS.
class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.distribution,
    required this.mode,
    required this.currency,
    required this.privacy,
  });

  final List<AccountAllocation> distribution;
  final DistributionMode mode;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.gitBranch, size: 16, color: c.brandPrimary),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text('DISTRIBUCIÓN', style: AppText.label(c.textMuted)),
              ),
              _ModeBadge(mode: mode),
            ],
          ),
          const SizedBox(height: Insets.card),
          if (distribution.isEmpty)
            Text(
              'Marcá alguna cuenta como personal para repartir el remanente.',
              style: AppText.caption(c.textMuted),
            )
          else
            ...distribution.map(
              (AccountAllocation alloc) => Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: Row(
                  children: [
                    Icon(_accountIcon(alloc.account.type),
                        size: 18, color: c.textMuted),
                    const SizedBox(width: Insets.card),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alloc.account.name,
                            style: AppText.body(c.textPrimary)
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (mode == DistributionMode.proportional &&
                              alloc.incomeSource > Decimal.zero)
                            Text(
                              'Aporta ${Money.format(alloc.incomeSource, currencyCode: currency, locale: 'es_AR')}',
                              style: AppText.caption(c.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    AmountText(
                      value: alloc.amount,
                      currencyCode: alloc.account.currency,
                      kind: AmountKind.balance,
                      obscured: privacy,
                      moneyStyle: MoneyStyle.compact,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Badge sage con el modo de distribución (Equitativa / Proporcional /
/// Personalizada).
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final DistributionMode mode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 3),
      decoration: ShapeDecoration(
        color: c.brandPrimary.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Text(
        mode.label,
        style: AppText.caption(c.brandPrimary)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────── Helpers ───────────────────────────────────

/// Entero del porcentaje (truncado, como `Int(pct)` de iOS) para los detalles
/// de ahorro/inversión.
int _pctInt(Decimal pct) => pct.toDouble().truncate();

/// Ícono lucide por tipo de cuenta (equivalente del `systemIcon` de iOS).
IconData _accountIcon(AccountType type) => switch (type) {
      AccountType.checking => LucideIcons.landmark,
      AccountType.savings => LucideIcons.piggyBank,
      AccountType.cash => LucideIcons.wallet,
      AccountType.creditCard => LucideIcons.creditCard,
      AccountType.investment => LucideIcons.trendingUp,
      AccountType.loan => LucideIcons.arrowDownToLine,
      AccountType.other => LucideIcons.coins,
    };

// ─────────────────────────────── States ────────────────────────────────────

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
            title: 'No pudimos cargar la cascada',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

class _WaterfallSkeleton extends StatelessWidget {
  const _WaterfallSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120,
      ),
      children: [
        for (final double h in const <double>[140, 220, 120, 160]) ...[
          Container(
            height: h,
            decoration: ShapeDecoration(
              color: c.appSurface,
              shape:
                  SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card)),
            ),
          ),
          const SizedBox(height: Insets.card),
        ],
      ],
    );
  }
}
