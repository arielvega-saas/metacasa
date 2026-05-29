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
import '../application/goals_controller.dart';
import 'add_goal_sheet.dart';
import 'goal_detail_screen.dart';

/// Pantalla de Metas — espejo de `GoalsView` (iOS), enriquecida con un summary
/// card de progreso global del ahorro del hogar.
///
/// Estructura:
///   1. Summary card: progreso global (Σ current / Σ target) con barra y un
///      gradiente sage→champagne. Solo si hay metas con objetivo.
///   2. Lista de metas ordenadas incompletas-primero: emoji, nombre, fecha
///      límite, `MCProgressBar`, current/target y %.
///   3. "+ meta" en la AppBar y un CTA en el empty-state.
///
/// Tap en una meta → [GoalDetailScreen]. Montos privacy-aware (modo ojo).
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final AsyncValue<GoalsState> goalsAsync =
        ref.watch(goalsControllerProvider);
    final bool privacy = ref.watch(privacyModeProvider);
    final String? householdId =
        ref.watch(currentHouseholdProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: c.appBackground,
      appBar: AppBar(
        backgroundColor: c.appBackground,
        title: Text('Metas', style: AppText.h2(c.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.plus, color: c.brandPrimary),
            tooltip: 'Agregar meta',
            onPressed:
                householdId == null ? null : () => _openAdd(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: () => ref.read(goalsControllerProvider.notifier).refresh(),
        child: goalsAsync.when(
          loading: () => const _GoalsSkeleton(),
          error: (Object err, StackTrace _) => _ErrorState(
            onRetry: () => ref.read(goalsControllerProvider.notifier).refresh(),
          ),
          data: (GoalsState state) {
            if (state.isEmpty) {
              return _EmptyGoals(
                onAdd:
                    householdId == null ? null : () => _openAdd(context, ref),
              );
            }
            return _GoalsList(state: state, privacy: privacy);
          },
        ),
      ),
    );
  }

  /// Abre la hoja de alta. El controller ya refresca al guardar (saveGoal →
  /// refresh), así que acá solo presentamos.
  Future<void> _openAdd(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await AddGoalSheet.show(context);
  }
}

// ─────────────────────────────── Lista ─────────────────────────────────────

/// Lista scrollable: summary card de progreso global + filas de meta. ListView
/// con `AlwaysScrollableScrollPhysics` para que el pull-to-refresh siempre ande.
class _GoalsList extends StatelessWidget {
  const _GoalsList({required this.state, required this.privacy});

  final GoalsState state;
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
        // Summary solo si hay un objetivo acumulado contra el cual medir.
        if (state.totalTarget > Decimal.zero) ...[
          _GlobalProgressCard(state: state, privacy: privacy),
          const SizedBox(height: Insets.section),
        ],
        // Las metas ya vienen ordenadas incompletas-primero desde el controller.
        ...state.goals.map((Goal g) => Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: _GoalRow(goal: g, privacy: privacy),
            )),
      ],
    );
  }
}

// ─────────────────────────── Progreso global ───────────────────────────────

/// Summary card: progreso global del ahorro del hogar (Σ current / Σ target),
/// con barra y un gradiente sage→champagne de fondo. Espejo conceptual del
/// resumen que el header de la lista muestra.
class _GlobalProgressCard extends StatelessWidget {
  const _GlobalProgressCard({required this.state, required this.privacy});

  final GoalsState state;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final double progress = state.globalProgress;
    final String currency = _currencyFor(state);

    return Container(
      padding: const EdgeInsets.all(Insets.cardLg),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [
            c.brandPrimary.withValues(alpha: 0.16),
            c.brandSecondary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: SmoothRectangleBorder(
          borderRadius: Radii.smooth(Radii.card),
          side: BorderSide(color: c.brandPrimary.withValues(alpha: 0.30)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.target, size: 16, color: c.brandPrimary),
              const SizedBox(width: Insets.md),
              Expanded(
                child:
                    Text('AHORRO TOTAL', style: AppText.label(c.textPrimary)),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppText.h2(c.brandPrimary),
              ),
            ],
          ),
          const SizedBox(height: Insets.card),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: AmountText(
                  value: state.totalCurrent,
                  currencyCode: currency,
                  kind: AmountKind.neutro,
                  obscured: privacy,
                  style: AppText.serifTitle(c.textPrimary),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text('/', style: AppText.serifInline(c.textDim)),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: AmountText(
                  value: state.totalTarget,
                  currencyCode: currency,
                  kind: AmountKind.neutro,
                  obscured: privacy,
                  style: AppText.serifInline(c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.card),
          MCProgressBar(percent: progress, color: c.brandPrimary),
          const SizedBox(height: Insets.md),
          Text(
            _subtitle(),
            style: AppText.caption(c.textMuted),
          ),
        ],
      ),
    );
  }

  /// Subtítulo: cuántas metas en curso y cuántas completadas.
  String _subtitle() {
    final int active = state.active.length;
    final int done = state.completed.length;
    final String activeText =
        active == 1 ? '1 meta en curso' : '$active metas en curso';
    if (done == 0) return activeText;
    final String doneText = done == 1 ? '1 completada' : '$done completadas';
    return '$activeText · $doneText';
  }

  /// Moneda para los totales: la de la primera meta (todas comparten la moneda
  /// del hogar en el modelo de datos actual). Cae a USD si no hay metas.
  static String _currencyFor(GoalsState state) =>
      state.goals.isNotEmpty ? state.goals.first.currency : 'USD';
}

// ─────────────────────────────── Fila de meta ──────────────────────────────

/// Fila de meta: emoji, nombre + fecha límite, barra de progreso, current/target
/// y %. Espejo del `GoalRow` de iOS, con el `MCProgressBar` del design system.
/// Tap → detalle.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.privacy});

  final Goal goal;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool completed = goal.status == GoalStatus.completed;
    final double progress = goal.progress;
    final Color barColor = completed ? c.brandSuccess : c.brandPrimary;

    return MCCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.cardLg,
        vertical: Insets.card,
      ),
      onTap: () => _openDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.icon ?? '🎯', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: Insets.card),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: AppText.body(c.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (goal.targetDate != null) ...[
                      const SizedBox(height: Insets.xxs),
                      Text(
                        'Para ${_formatDate(goal.targetDate!)}',
                        style: AppText.caption(c.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
              if (completed)
                Icon(LucideIcons.badgeCheck, size: 22, color: c.brandSuccess),
            ],
          ),
          const SizedBox(height: Insets.card),
          MCProgressBar(percent: progress, color: barColor),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              AmountText(
                value: goal.currentAmount,
                currencyCode: goal.currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                style: AppText.caption(c.textMuted)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              Text(' / ', style: AppText.caption(c.textDim)),
              AmountText(
                value: goal.targetAmount,
                currencyCode: goal.currency,
                kind: AmountKind.neutro,
                obscured: privacy,
                style: AppText.caption(c.textMuted),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: AppText.caption(barColor)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GoalDetailScreen(goal: goal),
      ),
    );
  }

  /// Fecha legible corta (dd MMM yyyy) — formato manual, sin dependencia de
  /// `initializeDateFormatting`.
  static String _formatDate(DateTime d) {
    const List<String> months = <String>[
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────── Estados ───────────────────────────────────

/// Empty-state: sin metas todavía, con CTA de alta. Scrollable para el
/// pull-to-refresh.
class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 480,
          child: EmptyState(
            icon: LucideIcons.target,
            title: 'Todavía no tenés metas',
            message:
                'Creá una meta de ahorro y registrá aportes para verla crecer.',
            actionLabel: onAdd == null ? null : 'Crear meta',
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
            title: 'No pudimos cargar tus metas',
            message: 'Revisá tu conexión y volvé a intentar.',
            actionLabel: 'Reintentar',
            onAction: onRetry,
          ),
        ),
      ],
    );
  }
}

/// Skeleton mientras carga: summary + filas placeholder. Scrollable para el
/// pull-to-refresh.
class _GoalsSkeleton extends StatelessWidget {
  const _GoalsSkeleton();

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
        _SkeletonBlock(height: 150), // summary
        SizedBox(height: Insets.section),
        _SkeletonBlock(height: 110),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 110),
        SizedBox(height: Insets.md),
        _SkeletonBlock(height: 110),
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
