import 'package:decimal/decimal.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/budget_controller.dart';
import 'envelope_editor_sheet.dart';
import 'strategy_sheet.dart';

/// Tab "Presupuesto" — hub de sobres (envelopes) zero-based. Espejo de
/// `BudgetHubView` (iOS).
///
/// De arriba a abajo:
///   1. Header card (navegador de mes + "Por asignar" en serif sobre gradiente)
///   2. Tres tiles resumen: Ingresos / Asignado / Gastado
///   3. Sección de envelopes: header + "+ categoría", lista o empty-state
///   4. Acciones: ver cascada (Waterfall) + configurar estrategia
///
/// AppBar trailing = sliders (abre la estrategia). Pull-to-refresh recomputa el
/// controller. Montos privacy-aware (ojo del shell vía `privacyModeProvider`).
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Presupuesto', style: AppText.serifTitle(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.slidersHorizontal, color: c.textPrimary),
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
        onRefresh: () => ref.read(budgetControllerProvider.notifier).refresh(),
        child: const _BudgetBody(),
      ),
    );
  }
}

/// Cuerpo: observa el [budgetControllerProvider] y resuelve loading / error /
/// data. Loading → skeleton; error → EmptyState con reintento.
class _BudgetBody extends ConsumerWidget {
  const _BudgetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BudgetState> budgetAsync =
        ref.watch(budgetControllerProvider);
    final bool privacy = ref.watch(privacyModeProvider);
    final YearMonth period = ref.watch(currentPeriodProvider);

    return budgetAsync.when(
      loading: () => const _BudgetSkeleton(),
      error: (Object err, StackTrace _) => _ErrorState(
        onRetry: () => ref.read(budgetControllerProvider.notifier).refresh(),
      ),
      data: (BudgetState state) =>
          _BudgetContent(state: state, period: period, privacy: privacy),
    );
  }
}

/// Contenido con datos cargados. ListView para que el pull-to-refresh siempre
/// tenga scrollable, aun con poco contenido.
class _BudgetContent extends ConsumerWidget {
  const _BudgetContent({
    required this.state,
    required this.period,
    required this.privacy,
  });

  final BudgetState state;
  final YearMonth period;
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
        _HeaderCard(
          period: period,
          readyToAssign: state.readyToAssign,
          currency: state.currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        _SummaryTiles(
          ingresos: state.ingresos,
          assigned: state.totalAssigned,
          spent: state.totalSpent,
          currency: state.currency,
          privacy: privacy,
        ),
        const SizedBox(height: Insets.section),
        _EnvelopesSection(state: state, privacy: privacy),
        const SizedBox(height: Insets.section),
        const _ActionsSection(),
      ],
    );
  }
}

// ─────────────────────────────── Header card ───────────────────────────────

/// Header: navegador de mes (‹ Mes Año ›) + "Por asignar" en serif sobre un
/// gradiente sage→champagne. Espejo del `headerCard` de iOS.
class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.period,
    required this.readyToAssign,
    required this.currency,
    required this.privacy,
  });

  final YearMonth period;
  final Decimal readyToAssign;
  final String currency;
  final bool privacy;

  /// Nombres de mes (es-AR), index 1-based.
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

    return Container(
      padding: const EdgeInsets.all(Insets.hero),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [
            c.brandPrimary.withValues(alpha: 0.22),
            c.brandSecondary.withValues(alpha: 0.12),
            c.appSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: _HeaderShape.border(c.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RoundChevron(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Mes anterior',
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(currentPeriodProvider.notifier).prevMonth();
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.h2(c.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('PERÍODO', style: AppText.label(c.textMuted)),
                  ],
                ),
              ),
              _RoundChevron(
                icon: LucideIcons.chevronRight,
                tooltip: 'Mes siguiente',
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(currentPeriodProvider.notifier).nextMonth();
                },
              ),
            ],
          ),
          const SizedBox(height: Insets.cardLg),
          Text('POR ASIGNAR', style: AppText.label(c.textMuted)),
          const SizedBox(height: Insets.md),
          AmountText(
            value: readyToAssign,
            currencyCode: currency,
            kind: AmountKind.balance,
            obscured: privacy,
            fitToWidth: true,
            style: AppText.serifDisplay(c.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Chevron redondo (navegador de mes) sobre superficie inset.
class _RoundChevron extends StatelessWidget {
  const _RoundChevron({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.appSurfaceInset,
          ),
          child: Icon(icon, size: 18, color: c.textPrimary),
        ),
      ),
    );
  }
}

// ─────────────────────────────── Summary tiles ─────────────────────────────

/// Tres tiles: Ingresos (glow si >0), Asignado (glow si dentro de budget),
/// Gastado (sin glow). Espejo de `summaryTiles` de iOS.
class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({
    required this.ingresos,
    required this.assigned,
    required this.spent,
    required this.currency,
    required this.privacy,
  });

  final Decimal ingresos;
  final Decimal assigned;
  final Decimal spent;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _SummaryTile(
            icon: LucideIcons.arrowDownCircle,
            title: 'Ingresos',
            value: ingresos,
            kind: AmountKind.ingreso,
            color: c.brandSuccess,
            currency: currency,
            privacy: privacy,
            glow: ingresos > Decimal.zero,
          ),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(
          child: _SummaryTile(
            icon: LucideIcons.layers,
            title: 'Asignado',
            value: assigned,
            kind: AmountKind.neutro,
            color: c.brandPrimary,
            currency: currency,
            privacy: privacy,
            // Glow si gastado está dentro de lo asignado (premia el budget).
            glow: assigned > Decimal.zero && spent <= assigned,
          ),
        ),
        const SizedBox(width: Insets.xl),
        Expanded(
          child: _SummaryTile(
            icon: LucideIcons.arrowUpCircle,
            title: 'Gastado',
            value: spent,
            kind: AmountKind.gasto,
            color: c.brandDanger,
            currency: currency,
            privacy: privacy,
            glow: false,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.kind,
    required this.color,
    required this.currency,
    required this.privacy,
    required this.glow,
  });

  final IconData icon;
  final String title;
  final Decimal value;
  final AmountKind kind;
  final Color color;
  final String currency;
  final bool privacy;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      glow: glow,
      padding: const EdgeInsets.all(Insets.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: Insets.xs),
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
            moneyStyle: MoneyStyle.compact,
            fitToWidth: true,
            style: AppText.serifInline(c.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Envelopes ─────────────────────────────────

/// Sección de envelopes: header con "+ categoría" + lista (o empty-state).
class _EnvelopesSection extends ConsumerWidget {
  const _EnvelopesSection({required this.state, required this.privacy});

  final BudgetState state;
  final bool privacy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.layers, size: 18, color: c.brandPrimary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text('Categorías', style: AppText.h2(c.textPrimary)),
            ),
            _AddCategoryButton(
              onTap: () {
                HapticFeedback.mediumImpact();
                EnvelopeEditorSheet.show(context);
              },
            ),
          ],
        ),
        const SizedBox(height: Insets.card),
        if (state.hasNoEnvelopes)
          _EnvelopesEmpty(
            onAdd: () {
              HapticFeedback.mediumImpact();
              EnvelopeEditorSheet.show(context);
            },
          )
        else
          ...state.envelopes.map(
            (BudgetEnvelope env) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.xl),
              child: _EnvelopeRow(
                envelope: env,
                currency: state.currency,
                privacy: privacy,
              ),
            ),
          ),
      ],
    );
  }
}

/// Pill "+ categoría" con gradiente sage→champagne. Espejo del botón del
/// header de envelopes de iOS.
class _AddCategoryButton extends StatelessWidget {
  const _AddCategoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.md,
        ),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            colors: [c.brandPrimary, c.brandSecondary],
          ),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plusCircle,
                size: 14, color: Color(0xFF0E1312)),
            const SizedBox(width: Insets.sm),
            Text(
              'Categoría',
              style: AppText.caption(const Color(0xFF0E1312))
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de un envelope: emoji + categoría/subcategoría + % usado, restante a la
/// derecha, barra de progreso threshold-colored, y "gastado / asignado" + badge
/// de rollover. Tap → abre el editor con la allocation existente. Espejo de
/// `envelopeRow` de iOS.
class _EnvelopeRow extends StatelessWidget {
  const _EnvelopeRow({
    required this.envelope,
    required this.currency,
    required this.privacy,
  });

  final BudgetEnvelope envelope;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final EnvelopeStatus s = envelope.status;
    final int pct = (s.percentUsed * 100).round();
    final bool over = envelope.isOverBudget;
    final Color barColor = c.budgetThreshold(envelope.rawPercentUsed);

    return MCCard(
      padding: const EdgeInsets.all(Insets.card),
      onTap: () {
        HapticFeedback.selectionClick();
        EnvelopeEditorSheet.show(context, existing: envelope.allocation);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                CategoryCatalog.emojiFor(s.category),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.category,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.subcategory.isNotEmpty)
                      Text(
                        s.subcategory,
                        style: AppText.caption(c.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '$pct% usado',
                      style:
                          AppText.caption(over ? c.brandDanger : c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Restante', style: AppText.caption(c.textMuted)),
                  AmountText(
                    value: s.remaining,
                    currencyCode: currency,
                    kind: AmountKind.balance,
                    obscured: privacy,
                    moneyStyle: MoneyStyle.compact,
                    style: AppText.serifInline(c.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          MCProgressBar(
            percent: s.percentUsed,
            height: 6,
            color: barColor,
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              AmountText(
                value: s.spent,
                currencyCode: currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                moneyStyle: MoneyStyle.compact,
                style: AppText.caption(c.textMuted),
              ),
              Text(' / ', style: AppText.caption(c.textDim)),
              AmountText(
                value: s.allocated,
                currencyCode: currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                moneyStyle: MoneyStyle.compact,
                style: AppText.caption(c.textMuted),
              ),
              const Spacer(),
              if (envelope.hasRollover)
                _RolloverBadge(mode: envelope.allocation.rolloverMode),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge sage del modo rollover (solo cuando ≠ none). Espejo del badge de
/// rollover de iOS.
class _RolloverBadge extends StatelessWidget {
  const _RolloverBadge({required this.mode});

  final RolloverMode mode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: c.brandPrimary.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.repeat, size: 11, color: c.brandPrimary),
          const SizedBox(width: Insets.xs),
          Text(_label(mode), style: AppText.caption(c.brandPrimary)),
        ],
      ),
    );
  }

  /// Etiqueta corta del rollover en el badge.
  String _label(RolloverMode mode) => switch (mode) {
        RolloverMode.none => '',
        RolloverMode.surplus => 'Sobrante',
        RolloverMode.full => 'Todo',
      };
}

/// Empty-state de envelopes: ilustración de sobres + título serif + hint + CTA.
/// Espejo del `emptyState` de iOS (sin la ilustración custom de sobres apilados,
/// reemplazada por un ícono sage grande).
class _EnvelopesEmpty extends StatelessWidget {
  const _EnvelopesEmpty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.cardLg),
        child: Column(
          children: [
            Icon(LucideIcons.layers, size: 44, color: c.brandPrimary),
            const SizedBox(height: Insets.cardLg),
            Text(
              'Todavía no tenés sobres',
              style: AppText.serifTitle(c.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Asigná un monto a cada categoría para controlar tu gasto del mes.',
              style: AppText.body(c.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.cardLg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: MCPrimaryButton(
                label: 'Crear categoría',
                icon: LucideIcons.plusCircle,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── Actions ───────────────────────────────────

/// Dos filas-acción: ver cascada (Waterfall) + configurar estrategia. Espejo
/// del `actionsSection` de iOS.
class _ActionsSection extends StatelessWidget {
  const _ActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionRow(
          icon: LucideIcons.pieChart,
          label: 'Ver cascada',
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/budget/waterfall');
          },
        ),
        const SizedBox(height: Insets.lg),
        _ActionRow(
          icon: LucideIcons.banknote,
          label: 'Configurar estrategia',
          onTap: () {
            HapticFeedback.selectionClick();
            StrategySheet.show(context);
          },
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MCCard(
      padding: const EdgeInsets.all(Insets.card),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.brandPrimary),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Text(
              label,
              style: AppText.body(c.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 18, color: c.textDim),
        ],
      ),
    );
  }
}

// ─────────────────────────────── States ────────────────────────────────────

/// Estado de error: EmptyState con reintento, dentro de un scrollable para que
/// el pull-to-refresh siga funcionando.
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
            title: 'No pudimos cargar tu presupuesto',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton del hub: bloques con el shape de las cards. Scrollable para
/// mantener el pull-to-refresh.
class _BudgetSkeleton extends StatelessWidget {
  const _BudgetSkeleton();

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
        _SkeletonBlock(height: 150), // header
        SizedBox(height: Insets.section),
        Row(
          children: [
            Expanded(child: _SkeletonBlock(height: 84)),
            SizedBox(width: Insets.xl),
            Expanded(child: _SkeletonBlock(height: 84)),
            SizedBox(width: Insets.xl),
            Expanded(child: _SkeletonBlock(height: 84)),
          ],
        ),
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 110),
        SizedBox(height: Insets.xl),
        _SkeletonBlock(height: 110),
      ],
    );
  }
}

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
        shape: _HeaderShape.plain(),
      ),
    );
  }
}

/// Shapes squircle reusadas (header + skeleton). Centralizadas para no repetir
/// el `SmoothRectangleBorder` con/ sin borde (esquinas continuous del design
/// system).
abstract final class _HeaderShape {
  static ShapeBorder border(Color borderColor) => SmoothRectangleBorder(
        borderRadius: Radii.smooth(Radii.hero),
        side: BorderSide(color: borderColor, width: 1),
      );

  static ShapeBorder plain() =>
      SmoothRectangleBorder(borderRadius: Radii.smooth(Radii.card));
}
