import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../state/app_providers.dart';
import '../application/goals_controller.dart';
import 'add_contribution_sheet.dart';

/// Detalle de una meta — espejo 1:1 de `GoalDetailView` (iOS).
///
/// Estructura (de arriba a abajo):
///   1. Header card: emoji grande + badge "Completada" si corresponde.
///   2. Progress card: current/target (serif), barra, % + fecha límite y la
///      línea de ETA ("a este ritmo…") calculada igual que iOS.
///   3. Botón "Registrar aporte" (deshabilitado si la meta está completa).
///   4. Lista de aportes (más recientes primero) o estado vacío.
///   5. Botón "Eliminar meta" (con confirmación).
///
/// Mantiene la [Goal] en estado local: al registrar un aporte, la hoja devuelve
/// la meta YA recargada (el trigger de DB ajustó `current_amount`/`status`) y
/// acá actualizamos el local + recargamos los aportes, sin re-leer toda la lista.
class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.goal});

  /// Meta inicial (la fila tocada). El detalle la mantiene viva y la reemplaza
  /// con la versión recargada tras cada aporte.
  final Goal goal;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  late Goal _goal;
  List<GoalContribution> _contributions = const <GoalContribution>[];
  bool _loadingContribs = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _loadContributions();
  }

  bool get _completed => _goal.status == GoalStatus.completed;

  /// Carga los aportes de la meta (más recientes primero). Degrada a lista vacía
  /// si falla (no queremos tumbar el detalle por el historial).
  Future<void> _loadContributions() async {
    setState(() => _loadingContribs = true);
    try {
      final List<GoalContribution> list =
          await ref.read(goalRepositoryProvider).fetchContributions(_goal.id);
      if (!mounted) return;
      setState(() {
        _contributions = list;
        _loadingContribs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingContribs = false);
    }
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
          _goal.name,
          style: AppText.h2(c.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        color: c.brandPrimary,
        backgroundColor: c.appSurface,
        onRefresh: _loadContributions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Insets.screen,
            Insets.md,
            Insets.screen,
            Insets.xxl,
          ),
          children: [
            _headerCard(context),
            const SizedBox(height: Insets.section),
            _progressCard(context, privacy),
            const SizedBox(height: Insets.section),
            MCPrimaryButton(
              label: 'Registrar aporte',
              icon: LucideIcons.plusCircle,
              onPressed: _completed ? null : _openContribute,
            ),
            const SizedBox(height: Insets.section),
            _contributionsSection(context, privacy),
            const SizedBox(height: Insets.xxl),
            _deleteButton(context),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _headerCard(BuildContext context) {
    final c = context.colors;
    return MCCard(
      glow: _completed,
      child: Center(
        child: Column(
          children: [
            Text(_goal.icon ?? '🎯', style: const TextStyle(fontSize: 48)),
            if (_completed) ...[
              const SizedBox(height: Insets.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.badgeCheck, size: 18, color: c.brandSuccess),
                  const SizedBox(width: Insets.sm),
                  Text(
                    'Completada',
                    style: AppText.h2(c.brandSuccess).copyWith(fontSize: 16),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Progreso + ETA ──────────────────────────────────────────────────────────

  Widget _progressCard(BuildContext context, bool privacy) {
    final c = context.colors;
    final double progress = _goal.progress;
    final Color barColor = _completed ? c.brandSuccess : c.brandPrimary;
    final String? eta = _etaText(context);

    return MCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: AmountText(
                  value: _goal.currentAmount,
                  currencyCode: _goal.currency,
                  // Lo ahorrado = dinero que ENTRA al objetivo → sage.
                  kind: AmountKind.ingreso,
                  obscured: privacy,
                  style: AppText.serifAmount(c.brandSuccess),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text('/', style: AppText.serifTitle(c.textDim)),
              const SizedBox(width: Insets.sm),
              Flexible(
                child: AmountText(
                  value: _goal.targetAmount,
                  currencyCode: _goal.currency,
                  kind: AmountKind.neutro,
                  obscured: privacy,
                  style: AppText.serifAmount(c.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.card),
          MCProgressBar(percent: progress, color: barColor),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Text(
                '${(progress * 100).round()}% completado',
                style: AppText.caption(c.textMuted),
              ),
              const Spacer(),
              if (_goal.targetDate != null)
                Text(
                  'Hasta ${_formatDate(_goal.targetDate!)}',
                  style: AppText.caption(c.textMuted),
                ),
            ],
          ),
          // ETA: a ritmo actual, cuánto falta (solo si la meta no está completa).
          if (eta != null && !_completed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.card),
              child: Divider(height: 1, color: c.appBorder),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.clock, size: 18, color: c.brandPrimary),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESTIMACIÓN', style: AppText.label(c.textMuted)),
                      const SizedBox(height: Insets.xs),
                      Text(
                        eta,
                        style: AppText.body(c.brandPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Texto de ETA estimado según aporte promedio mensual. Port 1:1 de `etaText`
  /// del iOS:
  /// - `remaining = max(0, target − current)`; si 0, sin ETA.
  /// - Sin aportes aún: si hay `targetDate`, ritmo requerido
  ///   `monthlyNeeded = remaining * 30 / days`; si no, null.
  /// - Con aportes: `avgMonthly = totalContrib * 30 / daysSinceFirst`;
  ///   `monthsToGo = remaining / avgMonthly`. Si hay `targetDate`, compara contra
  ///   los meses restantes (on-track / off-track); si no, estima los meses.
  String? _etaText(BuildContext context) {
    final Decimal target = _goal.targetAmount;
    final Decimal current = _goal.currentAmount;
    final Decimal diff = target - current;
    final Decimal remaining = diff > Decimal.zero ? diff : Decimal.zero;
    if (remaining <= Decimal.zero) return null;

    final String locale = _locale(context);
    final DateTime now = DateTime.now();

    // Fecha del primer aporte (mínimo) — null si todavía no hay ninguno.
    DateTime? firstContrib;
    for (final GoalContribution gc in _contributions) {
      if (firstContrib == null || gc.contributedAt.isBefore(firstContrib)) {
        firstContrib = gc.contributedAt;
      }
    }

    if (firstContrib == null) {
      // Sin aportes. Con targetDate, calculamos el ritmo mensual requerido.
      final DateTime? td = _goal.targetDate;
      if (td == null) return null;
      final int days = math.max(1, td.difference(now).inDays);
      // Ritmo requerido = remaining × 30 / días. División real en Decimal
      // (vía Rational), 1:1 con el `remaining * 30 / Decimal(days)` de iOS.
      final Decimal monthlyNeeded =
          (remaining * Decimal.fromInt(30) / Decimal.fromInt(days))
              .toDecimal(scaleOnInfinitePrecision: 2);
      final String monthlyStr = Money.format(
        monthlyNeeded,
        currencyCode: _goal.currency,
        style: MoneyStyle.compact,
        locale: locale,
      );
      return 'Necesitás aportar $monthlyStr por mes ($days días restantes).';
    }

    final int daysSinceFirst = math.max(1, now.difference(firstContrib).inDays);
    var totalContrib = Decimal.zero;
    for (final GoalContribution gc in _contributions) {
      totalContrib += gc.amount;
    }
    // Promedio mensual = total × 30 / días. División real en Decimal (vía
    // Rational), 1:1 con el `totalContrib * 30 / Decimal(daysSinceFirst)` de iOS.
    final Decimal avgMonthly =
        (totalContrib * Decimal.fromInt(30) / Decimal.fromInt(daysSinceFirst))
            .toDecimal(scaleOnInfinitePrecision: 2);

    if (avgMonthly <= Decimal.zero) {
      return 'Registrá aportes para estimar cuándo llegás.';
    }

    final double monthsToGo = remaining.toDouble() / avgMonthly.toDouble();
    final int monthsCeil = monthsToGo.ceil();

    final DateTime? td = _goal.targetDate;
    if (td != null) {
      final int daysLeft = td.difference(now).inDays;
      final double monthsLeft = daysLeft / 30.0;
      if (monthsToGo <= monthsLeft) {
        return 'A este ritmo llegás en ${_plMonths(monthsCeil)}. ¡Vas bien!';
      }
      return 'A este ritmo te faltan ${_plMonths(monthsCeil)}, '
          'pero quedan $daysLeft días.';
    }

    final String avgStr = Money.format(
      avgMonthly,
      currencyCode: _goal.currency,
      style: MoneyStyle.compact,
      locale: locale,
    );
    return 'A este ritmo ($avgStr/mes) llegás en ${_plMonths(monthsCeil)}.';
  }

  // ── Aportes ─────────────────────────────────────────────────────────────────

  Widget _contributionsSection(BuildContext context, bool privacy) {
    final c = context.colors;
    if (_contributions.isEmpty && !_loadingContribs) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.card),
        child: Center(
          child: Text(
            'Aún no registraste aportes.',
            style: AppText.body(c.textMuted),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aportes', style: AppText.h2(c.textPrimary)),
        const SizedBox(height: Insets.card),
        MCCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.cardLg,
            vertical: Insets.xs,
          ),
          child: Column(
            children: [
              for (int i = 0; i < _contributions.length; i++) ...[
                _ContributionRow(
                  contribution: _contributions[i],
                  currency: _goal.currency,
                  privacy: privacy,
                ),
                if (i < _contributions.length - 1)
                  Divider(height: 1, color: c.appBorder),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Eliminar ─────────────────────────────────────────────────────────────────

  Widget _deleteButton(BuildContext context) {
    final c = context.colors;
    return Center(
      child: TextButton.icon(
        onPressed: _deleting ? null : _confirmDelete,
        icon: Icon(LucideIcons.trash2, size: 16, color: c.brandDanger),
        label: Text(
          _deleting ? 'Eliminando…' : 'Eliminar meta',
          style:
              AppText.body(c.brandDanger).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Acciones ─────────────────────────────────────────────────────────────────

  /// Abre la hoja de aporte. Si devuelve la meta recargada, la aplicamos al
  /// estado local (con detección de "recién completada" para el haptic de éxito)
  /// y recargamos los aportes.
  Future<void> _openContribute() async {
    HapticFeedback.mediumImpact();
    final Goal? updated = await AddContributionSheet.show(context, _goal);
    if (updated == null) return;
    final bool justCompleted = _goal.status != GoalStatus.completed &&
        updated.status == GoalStatus.completed;
    setState(() => _goal = updated);
    if (justCompleted) await HapticFeedback.heavyImpact();
    await _loadContributions();
  }

  /// Confirma el borrado con un diálogo (espejo del `.alert` destructivo de iOS).
  Future<void> _confirmDelete() async {
    final c = context.colors;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: c.appSurface,
        title: Text('¿Eliminar meta?', style: AppText.h2(c.textPrimary)),
        content: Text(
          'Se borran todos los aportes registrados. Esta acción no se puede '
          'deshacer.',
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
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await ref.read(goalsControllerProvider.notifier).deleteGoal(_goal.id);
      await HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos eliminar la meta.')),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Pluraliza "N mes/meses".
  static String _plMonths(int n) => n == 1 ? '1 mes' : '$n meses';

  /// Locale ICU del contexto (es_AR) para `Money.format`.
  String _locale(BuildContext context) =>
      Localizations.localeOf(context).toLanguageTag().replaceAll('-', '_');

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

/// Fila de un aporte: ícono sage, monto (ingreso/verde), fecha y nota opcional.
class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.currency,
    required this.privacy,
  });

  final GoalContribution contribution;
  final String currency;
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final String? note = contribution.notes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.lg),
      child: Row(
        children: [
          Icon(LucideIcons.arrowUpCircle, size: 22, color: c.brandSuccess),
          const SizedBox(width: Insets.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AmountText(
                  value: contribution.amount,
                  currencyCode: currency,
                  kind: AmountKind.ingreso,
                  obscured: privacy,
                  style: AppText.body(c.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  _formatDate(contribution.contributedAt),
                  style: AppText.caption(c.textMuted),
                ),
              ],
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(width: Insets.md),
            Flexible(
              child: Text(
                note,
                style: AppText.caption(c.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ],
      ),
    );
  }

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
