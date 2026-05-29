import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/goal_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Estado inmutable de la pantalla de Metas. Clase plana (sin freezed/codegen,
/// por requerimiento) con las metas del hogar separadas en activas/completadas y
/// el progreso global ya computado.
///
/// Espejo conceptual del `GoalsViewModel.goals` de iOS, enriquecido con el
/// progreso global (Σ current / Σ target) que el header de la lista muestra como
/// resumen — algo que iOS no calcula en una sola pasada, pero que pedimos acá
/// para el summary card.
class GoalsState {
  const GoalsState({
    required this.goals,
    required this.totalCurrent,
    required this.totalTarget,
  });

  /// Estado vacío (sin hogar o sin metas): lista vacía + totales en cero.
  factory GoalsState.empty() => GoalsState(
        goals: const <Goal>[],
        totalCurrent: Decimal.zero,
        totalTarget: Decimal.zero,
      );

  /// Todas las metas del hogar, ordenadas incompletas-primero (las activas/
  /// pausadas antes que las completadas), preservando dentro de cada bloque el
  /// orden del repo (prioridad desc, luego creación asc).
  final List<Goal> goals;

  /// Σ `currentAmount` de TODAS las metas (incluye completadas) — numerador del
  /// progreso global.
  final Decimal totalCurrent;

  /// Σ `targetAmount` de TODAS las metas — denominador del progreso global.
  final Decimal totalTarget;

  /// `true` si no hay ninguna meta para mostrar.
  bool get isEmpty => goals.isEmpty;

  /// Metas activas/pausadas (todo lo que no esté completado): el bloque "en
  /// curso" de la lista.
  List<Goal> get active =>
      goals.where((Goal g) => g.status != GoalStatus.completed).toList();

  /// Metas ya completadas: el bloque inferior de la lista.
  List<Goal> get completed =>
      goals.where((Goal g) => g.status == GoalStatus.completed).toList();

  /// Progreso global hacia el ahorro del hogar (0.0 – 1.0). Σ current / Σ target,
  /// clampeado a 1. Si no hay target acumulado, 0 (evita división por cero).
  double get globalProgress {
    if (totalTarget <= Decimal.zero) return 0;
    final double ratio = totalCurrent.toDouble() / totalTarget.toDouble();
    return ratio < 1 ? ratio : 1;
  }
}

/// Controller de la pantalla de Metas. `AsyncNotifier` que observa el hogar
/// activo y, ante cualquier cambio (switch de hogar), recarga las metas.
///
/// Espejo de `GoalsViewModel` de iOS: misma fuente (`fetchAll` con
/// `includeCompleted: true`, ordenado prioridad desc → creación asc), con la
/// mutación de estado en el notifier (Riverpod) en vez del `@Observable`. Las
/// escrituras (alta/edición/aporte/borrado) las hace la UI vía los repos y luego
/// llaman [refresh] para releer la verdad del backend (el trigger de DB ajusta
/// `current_amount`, así que un re-fetch es lo más simple y correcto).
class GoalsController extends AsyncNotifier<GoalsState> {
  @override
  Future<GoalsState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      // Sin hogar no hay metas (el gate cubre el flujo de alta).
      return GoalsState.empty();
    }
    return _load(householdId);
  }

  /// Fetch de todas las metas del hogar (incluidas las completadas) y armado del
  /// estado: ordena incompletas-primero y acumula los totales para el progreso
  /// global.
  Future<GoalsState> _load(String householdId) async {
    final GoalRepository repo = ref.read(goalRepositoryProvider);
    final List<Goal> all =
        await repo.fetchAll(householdId: householdId, includeCompleted: true);
    return _project(all);
  }

  /// Proyecta la lista cruda al [GoalsState]: estable-ordena incompletas-primero
  /// (sin alterar el orden relativo del repo dentro de cada bloque) y suma los
  /// totales para el progreso global.
  GoalsState _project(List<Goal> all) {
    final List<Goal> incomplete = <Goal>[];
    final List<Goal> done = <Goal>[];
    var totalCurrent = Decimal.zero;
    var totalTarget = Decimal.zero;
    for (final Goal g in all) {
      totalCurrent += g.currentAmount;
      totalTarget += g.targetAmount;
      if (g.status == GoalStatus.completed) {
        done.add(g);
      } else {
        incomplete.add(g);
      }
    }
    return GoalsState(
      goals: <Goal>[...incomplete, ...done],
      totalCurrent: totalCurrent,
      totalTarget: totalTarget,
    );
  }

  /// Crea o actualiza una meta. Decide por la presencia de `id` no vacío:
  /// distingue alta (insert) de edición (update), igual criterio que el resto de
  /// los controllers. Tras escribir, refresca para reflejar el orden/estado del
  /// backend.
  Future<void> saveGoal(Goal goal) async {
    final GoalRepository repo = ref.read(goalRepositoryProvider);
    if (goal.id.isEmpty) {
      await repo.insert(goal);
    } else {
      await repo.update(goal);
    }
    await refresh();
  }

  /// Elimina una meta (la cascada de DB borra sus aportes) y refresca.
  Future<void> deleteGoal(String id) async {
    await ref.read(goalRepositoryProvider).delete(id);
    await refresh();
  }

  /// Registra un aporte a una meta. El repo inserta el aporte y devuelve la meta
  /// YA recargada (el trigger de DB actualizó `current_amount`/`status`).
  /// Devuelve esa meta para que el detalle pueda reflejar el cambio sin re-leer,
  /// y refresca la lista para que el header/orden global queden coherentes.
  Future<Goal> contribute(
    String goalId,
    Decimal amount, {
    String? notes,
    String? transactionId,
  }) async {
    final GoalContributionResult result =
        await ref.read(goalRepositoryProvider).addContribution(
              goalId: goalId,
              amount: amount,
              notes: notes,
              transactionId: transactionId,
            );
    await refresh();
    return result.goal;
  }

  /// Fuerza una recarga (pull-to-refresh / post-mutación). Mantiene visible el
  /// dato previo mientras recomputa (`AsyncValue.guard` setea loading→data).
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData<GoalsState>(GoalsState.empty());
      return;
    }
    state = const AsyncLoading<GoalsState>().copyWithPrevious(state);
    state = await AsyncValue.guard<GoalsState>(() => _load(householdId));
  }
}

/// Provider del controller de Metas. `AsyncNotifierProvider` (no family): el
/// controller observa `currentHouseholdProvider` internamente, así que se
/// reconstruye solo cuando cambia el hogar activo.
final goalsControllerProvider =
    AsyncNotifierProvider<GoalsController, GoalsState>(GoalsController.new);
