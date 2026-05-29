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
import '../application/home_controller.dart';

/// Tab "Inicio" — dashboard premium, espejo de `HomeView` (iOS).
///
/// Renderiza, de arriba a abajo (orden fijo; el reordenamiento de widgets que
/// tiene iOS no se porta por ahora):
///   1. Navegador de período (‹ Mes Año ›)
///   2. Hero balance card (serif, "Disponible" + ingresos/gastos + ojo)
///   3. Stats row (Ingresos / Gastos)
///   4. Top gastos (top 5 con barra de share)
///   5. Daily budget ("Podés gastar hoy" / "Gastaste hoy")
///   6. Proyección a fin de mes
///   7. Semáforo de presupuesto (envelopes)
///   8. Metas (si hay)
///   9. Alerta de vencimientos (si hay urgentes)
///   10. Cuotas (si hay planes activos)
///
/// AppBar: large title = nombre del hogar, leading sparkles (hoja del asistente,
/// placeholder), trailing ojo (privacidad). Pull-to-refresh invalida el
/// controller. Loading → skeleton; error → EmptyState; sin datos → empty states
/// por widget.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<Household?> householdAsync =
        ref.watch(currentHouseholdProvider);
    final String householdName = householdAsync.valueOrNull?.name ?? 'Hogar';
    final bool privacy = ref.watch(privacyModeProvider);

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        // Título grande serif editorial = nombre del hogar (espejo del
        // `.navigationTitle(householdName)` con large display de iOS).
        title: Text(
          householdName,
          style: AppText.serifTitle(c.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Leading sparkles → hoja del asistente (placeholder).
        leading: IconButton(
          icon: Icon(LucideIcons.sparkles, color: c.brandPrimary),
          tooltip: 'Asistente',
          onPressed: () => _openAssistantSheet(context),
        ),
        actions: [
          // Ojo: toggle de privacidad (enmascara montos).
          IconButton(
            icon: Icon(
              privacy ? LucideIcons.eyeOff : LucideIcons.eye,
              color: privacy ? c.brandPrimary : c.textPrimary,
            ),
            tooltip: privacy ? 'Mostrar montos' : 'Ocultar montos',
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(privacyModeProvider.notifier).update((v) => !v);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () => ref.read(homeControllerProvider.notifier).refresh(),
        child: _HomeBody(privacy: privacy),
      ),
    );
  }

  /// Hoja placeholder del asistente (mismo copy que el FAB del shell).
  void _openAssistantSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.appSurface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
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
                  Icon(LucideIcons.sparkles, size: 20, color: c.brandPrimary),
                  const SizedBox(width: Insets.md),
                  Text('Asistente', style: AppText.h2(c.textPrimary)),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text(
                'El chat del asistente vivirá acá. Próximamente.',
                style: AppText.body(c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuerpo del dashboard: observa el [homeControllerProvider] y resuelve los tres
/// estados (loading / error / data). Loading muestra skeleton; error un
/// EmptyState con reintento; data renderiza los widgets en orden.
class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.privacy});

  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<HomeState> homeAsync = ref.watch(homeControllerProvider);
    final AsyncValue<Household?> householdAsync =
        ref.watch(currentHouseholdProvider);
    final String currency =
        householdAsync.valueOrNull?.defaultCurrency ?? 'USD';
    final YearMonth period = ref.watch(currentPeriodProvider);

    return homeAsync.when(
      // Skeleton tasteful (placeholders) — el RefreshIndicator necesita un
      // scrollable, así que el skeleton también scrollea.
      loading: () => const _DashboardSkeleton(),
      error: (Object err, StackTrace _) => _ErrorState(
        onRetry: () => ref.read(homeControllerProvider.notifier).refresh(),
      ),
      data: (HomeState state) => _DashboardContent(
        state: state,
        currency: currency,
        period: period,
        privacy: privacy,
      ),
    );
  }
}

/// Contenido del dashboard con datos cargados. ListView para que el
/// pull-to-refresh siempre tenga un scrollable (incluso con poco contenido).
class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.state,
    required this.currency,
    required this.period,
    required this.privacy,
  });

  final HomeState state;
  final String currency;
  final YearMonth period;
  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      // `always` para que el gesto de refresh funcione aunque el contenido no
      // llene la pantalla.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Insets.screen,
        Insets.md,
        Insets.screen,
        120, // espacio para el FAB del asistente del shell
      ),
      children: [
        _PeriodNavigator(period: period),
        const SizedBox(height: Insets.section),
        _HeroBalanceCard(
          balance: state.balance,
          ingresos: state.totalIngresos,
          gastos: state.totalGastos,
          currency: currency,
          privacy: privacy,
          onToggleEye: () {
            HapticFeedback.selectionClick();
            ref.read(privacyModeProvider.notifier).update((v) => !v);
          },
        ),
        const SizedBox(height: Insets.section),
        _StatsRow(
          ingresos: state.totalIngresos,
          gastos: state.totalGastos,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        _TopExpensesCard(
          items: state.topCategories,
          totalGastos: state.totalGastos,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        _DailyBudgetCard(
          dailyBudget: state.dailyBudget,
          todayExpenses: state.todayExpenses,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        _ProjectionCard(
          projected: state.projectedEndOfMonth,
          currency: currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        _BudgetSemaphoreCard(
          items: state.budgetSemaphore,
          currency: currency,
          privacy: privacy,
        ),
        if (state.activeGoals.isNotEmpty) ...[
          const SizedBox(height: Insets.section),
          _GoalsStrip(goals: state.activeGoals),
        ],
        if (state.urgentBillsCount > 0) ...[
          const SizedBox(height: Insets.section),
          _BillsAlertCard(
            bills: state.upcomingBills,
            urgentCount: state.urgentBillsCount,
            privacy: privacy,
          ),
        ],
        if (state.activePlans.isNotEmpty) ...[
          const SizedBox(height: Insets.section),
          _PlansStrip(
            plans: state.activePlans,
            privacy: privacy,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────── Period navigator ──────────────────────────

/// Navegador de período: ‹ Mes Año ›. Wired a [currentPeriodProvider] vía
/// next/prev. Espejo del selector de mes de la UI.
class _PeriodNavigator extends ConsumerWidget {
  const _PeriodNavigator({required this.period});

  final YearMonth period;

  /// Nombres de mes en español (rioplatense), index 1-based.
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
    final String label = '${_months[period.month]} ${period.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _arrow(
          context,
          icon: LucideIcons.chevronLeft,
          tooltip: 'Mes anterior',
          onTap: () {
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
        _arrow(
          context,
          icon: LucideIcons.chevronRight,
          tooltip: 'Mes siguiente',
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(currentPeriodProvider.notifier).nextMonth();
          },
        ),
      ],
    );
  }

  Widget _arrow(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return IconButton(
      icon: Icon(icon, color: c.textPrimary),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

// ─────────────────────────────── Hero balance ──────────────────────────────

/// Hero balance card — el monto grande "Disponible" en serif, con la fila de
/// ingresos/gastos y el toggle del ojo. Glow MCCard (resalta el foco). Espejo
/// del `HeroBalanceCard` de iOS (adaptado: usamos "Disponible" + serif hero).
class _HeroBalanceCard extends StatelessWidget {
  const _HeroBalanceCard({
    required this.balance,
    required this.ingresos,
    required this.gastos,
    required this.currency,
    required this.privacy,
    required this.onToggleEye,
  });

  final Decimal balance;
  final Decimal ingresos;
  final Decimal gastos;
  final String currency;
  final bool privacy;
  final VoidCallback onToggleEye;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Glow solo cuando el balance es positivo (foco "sano"), igual criterio que
    // `glowIfPositive` del iOS.
    final bool positive = balance >= Decimal.zero;

    return MCCard(
      glow: positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('DISPONIBLE', style: AppText.label(c.textMuted)),
              ),
              _EyeChip(privacy: privacy, onTap: onToggleEye),
            ],
          ),
          const SizedBox(height: Insets.xl),
          // Balance hero en serif, escalado al ancho (no se trunca).
          AmountText(
            value: balance,
            currencyCode: currency,
            kind: AmountKind.balance,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifHero(c.textPrimary),
          ),
          const SizedBox(height: Insets.section),
          // Fila ingresos / gastos del período.
          Row(
            children: [
              Expanded(
                child: _HeroFigure(
                  icon: LucideIcons.arrowDownLeft,
                  label: 'Ingresos',
                  value: ingresos,
                  kind: AmountKind.ingreso,
                  color: c.brandSuccess,
                  currency: currency,
                  privacy: privacy,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: c.appBorder,
                margin: const EdgeInsets.symmetric(horizontal: Insets.xl),
              ),
              Expanded(
                child: _HeroFigure(
                  icon: LucideIcons.arrowUpRight,
                  label: 'Gastos',
                  value: gastos,
                  kind: AmountKind.gasto,
                  color: c.brandDanger,
                  currency: currency,
                  privacy: privacy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una cifra del hero (Ingresos o Gastos): ícono + etiqueta + monto inline.
class _HeroFigure extends StatelessWidget {
  const _HeroFigure({
    required this.icon,
    required this.label,
    required this.value,
    required this.kind,
    required this.color,
    required this.currency,
    required this.privacy,
  });

  final IconData icon;
  final String label;
  final Decimal value;
  final AmountKind kind;
  final Color color;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: Insets.sm),
            Text(label, style: AppText.caption(c.textMuted)),
          ],
        ),
        const SizedBox(height: Insets.xs),
        AmountText(
          value: value,
          currencyCode: currency,
          kind: kind,
          obscured: privacy,
          style: AppText.serifAmount(c.textPrimary),
        ),
      ],
    );
  }
}

/// Chip del ojo (privacy toggle) usado en el hero.
class _EyeChip extends StatelessWidget {
  const _EyeChip({required this.privacy, required this.onTap});

  final bool privacy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: privacy
              ? c.brandPrimary.withValues(alpha: 0.2)
              : c.appSurfaceInset,
        ),
        child: Icon(
          privacy ? LucideIcons.eyeOff : LucideIcons.eye,
          size: 16,
          color: privacy ? c.brandPrimary : c.textPrimary,
        ),
      ),
    );
  }
}

// ─────────────────────────────── Stats row ─────────────────────────────────

/// Fila de dos tiles: Ingresos y Gastos. Espejo del `StatsRow` de iOS (sin las
/// sparklines de Swift Charts, que llegan en una ola futura).
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.ingresos,
    required this.gastos,
    required this.currency,
    required this.privacy,
  });

  final Decimal ingresos;
  final Decimal gastos;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _StatTile(
            icon: LucideIcons.arrowDownLeft,
            title: 'Ingresos',
            value: ingresos,
            kind: AmountKind.ingreso,
            color: c.brandSuccess,
            currency: currency,
            privacy: privacy,
          ),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(
          child: _StatTile(
            icon: LucideIcons.arrowUpRight,
            title: 'Gastos',
            value: gastos,
            kind: AmountKind.gasto,
            color: c.brandDanger,
            currency: currency,
            privacy: privacy,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.kind,
    required this.color,
    required this.currency,
    required this.privacy,
  });

  final IconData icon;
  final String title;
  final Decimal value;
  final AmountKind kind;
  final Color color;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      padding: const EdgeInsets.all(Insets.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppText.caption(c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          AmountText(
            value: value,
            currencyCode: currency,
            kind: kind,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifAmount(c.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Top gastos ────────────────────────────────

/// Top 5 categorías de gasto con barra de share (proporción sobre el total).
/// Espejo del `CategoryDonutCard` de iOS (lista; el donut Swift Charts llega
/// después). Empty-state si no hay gastos.
class _TopExpensesCard extends StatelessWidget {
  const _TopExpensesCard({
    required this.items,
    required this.totalGastos,
    required this.currency,
    required this.privacy,
  });

  final List<CategoryTotal> items;
  final Decimal totalGastos;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MCSectionHeader(title: 'Top gastos'),
          const SizedBox(height: Insets.card),
          if (items.isEmpty)
            _InlineEmpty(
              icon: LucideIcons.pieChart,
              message: 'Todavía no cargaste gastos este mes.',
            )
          else
            ...items.map((CategoryTotal item) {
              final double share = totalGastos > Decimal.zero
                  ? (item.total.toDouble() / totalGastos.toDouble())
                      .clamp(0.0, 1.0)
                  : 0.0;
              final int pct = (share * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.category,
                            style: AppText.body(c.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        AmountText(
                          value: item.total,
                          currencyCode: currency,
                          kind: AmountKind.gasto,
                          obscured: privacy,
                          moneyStyle: MoneyStyle.compact,
                          style: AppText.body(c.textPrimary)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '$pct%',
                            textAlign: TextAlign.right,
                            style: AppText.caption(c.textDim),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    MCProgressBar(
                      percent: share,
                      height: 6,
                      // Share de categoría = sage neutro (no es un umbral de
                      // presupuesto), así que forzamos el color de marca.
                      color: c.brandPrimary,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Daily budget ──────────────────────────────

/// Widget de presupuesto diario: "Podés gastar hoy" (positivo) y "Gastaste
/// hoy". Espejo conceptual del cálculo de daily budget de iOS.
class _DailyBudgetCard extends StatelessWidget {
  const _DailyBudgetCard({
    required this.dailyBudget,
    required this.todayExpenses,
    required this.currency,
    required this.privacy,
  });

  final Decimal dailyBudget;
  final Decimal todayExpenses;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool canSpend = dailyBudget > Decimal.zero;

    return MCCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (canSpend ? c.brandSuccess : c.brandDanger)
                  .withValues(alpha: 0.15),
            ),
            child: Icon(
              canSpend ? LucideIcons.wallet : LucideIcons.alertTriangle,
              color: canSpend ? c.brandSuccess : c.brandDanger,
              size: 22,
            ),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canSpend ? 'Podés gastar hoy' : 'Sin margen para hoy',
                  style: AppText.caption(c.textMuted),
                ),
                const SizedBox(height: Insets.xxs),
                AmountText(
                  value: dailyBudget,
                  currencyCode: currency,
                  kind: AmountKind.balance,
                  obscured: privacy,
                  fitToWidth: true,
                  style: AppText.serifAmount(c.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.card),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Gastaste hoy', style: AppText.caption(c.textMuted)),
              const SizedBox(height: Insets.xxs),
              AmountText(
                value: todayExpenses,
                currencyCode: currency,
                kind: AmountKind.gasto,
                obscured: privacy,
                moneyStyle: MoneyStyle.compact,
                style: AppText.serifAmount(c.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Proyección ────────────────────────────────

/// Proyección de balance a fin de mes. Espejo del cálculo `projectedEndOfMonth`
/// de iOS (extrapola el ritmo de gasto al total de días del mes).
class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({
    required this.projected,
    required this.currency,
    required this.privacy,
  });

  final Decimal projected;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool positive = projected >= Decimal.zero;

    return MCCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.brandPrimary.withValues(alpha: 0.15),
            ),
            child: Icon(
              positive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              color: positive ? c.brandSuccess : c.brandDanger,
              size: 22,
            ),
          ),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proyección a fin de mes',
                  style: AppText.caption(c.textMuted),
                ),
                const SizedBox(height: Insets.xxs),
                AmountText(
                  value: projected,
                  currencyCode: currency,
                  kind: AmountKind.balance,
                  obscured: privacy,
                  fitToWidth: true,
                  style: AppText.serifAmount(c.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Semáforo de presupuesto ───────────────────────

/// Semáforo de presupuesto: por cada envelope (categoría con asignación), barra
/// con color según el % usado (umbral de `budgetThreshold`). Empty-state si no
/// hay envelopes configurados.
class _BudgetSemaphoreCard extends StatelessWidget {
  const _BudgetSemaphoreCard({
    required this.items,
    required this.currency,
    required this.privacy,
  });

  final List<BudgetSemaphoreItem> items;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MCSectionHeader(title: 'Presupuesto'),
          const SizedBox(height: Insets.card),
          if (items.isEmpty)
            _InlineEmpty(
              icon: LucideIcons.wallet,
              message: 'Asigná sobres en Presupuesto para verlos acá.',
            )
          else
            // Mostramos hasta 6 envelopes (los más urgentes primero, ya
            // ordenados por el controller).
            ...items.take(6).map((BudgetSemaphoreItem item) {
              final Color barColor = c.budgetThreshold(item.rawPercentUsed);
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.category,
                            style: AppText.body(c.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        // "gastado / asignado"
                        AmountText(
                          value: item.spent,
                          currencyCode: currency,
                          kind: AmountKind.neutro,
                          obscured: privacy,
                          moneyStyle: MoneyStyle.compact,
                          style: AppText.caption(c.textPrimary)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(' / ', style: AppText.caption(c.textDim)),
                        AmountText(
                          value: item.allocated,
                          currencyCode: currency,
                          kind: AmountKind.neutro,
                          obscured: privacy,
                          moneyStyle: MoneyStyle.compact,
                          style: AppText.caption(c.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    MCProgressBar(
                      percent: item.percentUsed,
                      height: 6,
                      color: barColor,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Metas strip ───────────────────────────────

/// Strip horizontal de metas activas con anillo de progreso. Espejo del
/// `GoalsRingsRow` de iOS. Solo se renderiza si hay metas (el caller lo decide).
class _GoalsStrip extends StatelessWidget {
  const _GoalsStrip({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MCSectionHeader(
            title: 'Tus metas',
            trailing: _CountBadge(count: goals.length, color: c.brandPrimary),
          ),
          const SizedBox(height: Insets.card),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: goals.length > 8 ? 8 : goals.length,
              separatorBuilder: (_, __) => const SizedBox(width: Insets.card),
              itemBuilder: (context, i) => _GoalRing(goal: goals[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double progress = goal.progress;
    final bool done = progress >= 1.0;
    final Color ringColor = done ? c.brandSuccess : c.brandPrimary;

    return SizedBox(
      width: 84,
      child: Column(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    backgroundColor: c.appSurfaceInset,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                if (goal.icon != null && goal.icon!.isNotEmpty)
                  Text(goal.icon!, style: const TextStyle(fontSize: 20))
                else
                  Text(
                    '${(progress * 100).round()}%',
                    style: AppText.serifInline(c.textPrimary)
                        .copyWith(fontSize: 13),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            goal.name,
            style: AppText.caption(c.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Bills alert ───────────────────────────────

/// Alerta de vencimientos: solo aparece cuando hay urgentes (vencidos/hoy/≤3d).
/// Lista compacta de los próximos. Espejo del `UpcomingBillsStrip` de iOS, en
/// formato alerta.
class _BillsAlertCard extends StatelessWidget {
  const _BillsAlertCard({
    required this.bills,
    required this.urgentCount,
    required this.privacy,
  });

  final List<Bill> bills;
  final int urgentCount;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Priorizamos los urgentes; mostramos hasta 5.
    final List<Bill> shown = bills.take(5).toList();

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertTriangle, size: 18, color: c.brandWarning),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  'Vencimientos próximos',
                  style: AppText.h2(c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _CountBadge(count: urgentCount, color: c.brandWarning),
            ],
          ),
          const SizedBox(height: Insets.card),
          ...shown.map((Bill bill) => _BillRow(bill: bill, privacy: privacy)),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.privacy});

  final Bill bill;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final int days = bill.daysUntilDue;
    final Color color = switch (bill.urgency) {
      BillUrgencyLevel.overdue => c.brandDanger,
      BillUrgencyLevel.dueToday || BillUrgencyLevel.dueSoon => c.brandWarning,
      _ => c.brandPrimary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.title,
                  style: AppText.body(c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(_dayLabel(days), style: AppText.caption(color)),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          AmountText(
            value: bill.amount,
            currencyCode: bill.currency,
            kind: AmountKind.gasto,
            obscured: privacy,
            moneyStyle: MoneyStyle.compact,
            style: AppText.body(c.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Etiqueta de días (rioplatense). Espejo del `dayLabel` de iOS.
  String _dayLabel(int days) {
    if (days < 0) return 'Vencido hace ${-days}d';
    if (days == 0) return 'Vence hoy';
    if (days == 1) return 'Vence mañana';
    return 'En $days días';
  }
}

// ─────────────────────────────── Cuotas strip ──────────────────────────────

/// Strip horizontal de planes de cuotas activos. Espejo del tile de cuotas del
/// `DebtsAndPlansTiles` de iOS. Solo se renderiza si hay planes (caller decide).
class _PlansStrip extends StatelessWidget {
  const _PlansStrip({required this.plans, required this.privacy});

  final List<InstallmentPlan> plans;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MCSectionHeader(
            title: 'Cuotas',
            trailing: _CountBadge(count: plans.length, color: c.brandPrimary),
          ),
          const SizedBox(height: Insets.card),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: plans.length > 8 ? 8 : plans.length,
              separatorBuilder: (_, __) => const SizedBox(width: Insets.xl),
              itemBuilder: (context, i) =>
                  _PlanTile(plan: plans[i], privacy: privacy),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.privacy});

  final InstallmentPlan plan;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(Insets.xl),
      decoration: ShapeDecoration(
        color: c.appSurfaceInset,
        shape: SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.pill)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(LucideIcons.creditCard, size: 16, color: c.brandPrimary),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  plan.name,
                  style: AppText.caption(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AmountText(
                value: plan.monthlyAmount,
                currencyCode: plan.currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                moneyStyle: MoneyStyle.compact,
                style: AppText.serifInline(c.textPrimary),
              ),
              Text(
                '× ${plan.totalInstallments} cuotas',
                style: AppText.caption(c.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Shared bits ───────────────────────────────

/// Badge numérico (conteo) usado en headers de sección (metas, cuotas, bills).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.2),
        shape: const StadiumBorder(),
      ),
      child: Text(
        '$count',
        style: AppText.caption(color).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Empty-state inline (dentro de una card): ícono tenue + mensaje. Para los
/// widgets que existen pero no tienen datos todavía.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Text(message, style: AppText.caption(c.textMuted)),
          ),
        ],
      ),
    );
  }
}

/// Estado de error del dashboard: EmptyState con CTA de reintento.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Envuelto en un scrollable para que el pull-to-refresh siga funcionando.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.cloudOff,
            title: 'No pudimos cargar tu hogar',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Skeleton ──────────────────────────────────

/// Skeleton del dashboard mientras carga: bloques de superficie con el shape de
/// las cards. Scrollable para mantener el pull-to-refresh.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

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
        _SkeletonBlock(height: 44), // navegador
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 180), // hero
        SizedBox(height: Insets.section),
        Row(
          children: [
            Expanded(child: _SkeletonBlock(height: 96)),
            SizedBox(width: Insets.xl),
            Expanded(child: _SkeletonBlock(height: 96)),
          ],
        ),
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 220), // top gastos
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 88), // daily budget
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
