import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/recurring_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Estado inmutable de la pantalla de Recurrentes. Clase plana (sin
/// freezed/codegen, por requerimiento) con la lista de recurrentes del hogar.
class RecurringState {
  const RecurringState({required this.items});

  /// Estado vacío (sin hogar o sin recurrentes).
  factory RecurringState.empty() =>
      const RecurringState(items: <RecurringTransaction>[]);

  /// Recurrentes del hogar (activas + inactivas), ordenadas por próxima fecha.
  /// Incluimos las inactivas para que una recurrente recién desactivada siga
  /// visible (atenuada) y se pueda reactivar; las activas van primero.
  final List<RecurringTransaction> items;

  /// `true` si no hay ninguna recurrente para mostrar.
  bool get isEmpty => items.isEmpty;
}

/// Controller de la pantalla de Recurrentes. `AsyncNotifier` que observa el
/// hogar activo y recarga ante cualquier cambio (switch de hogar).
///
/// Espejo de `RecurringListView` + `RecurringService` de iOS. iOS solo trae las
/// activas; acá traemos TODAS (`includeInactive: true`) para soportar el toggle
/// activo/inactivo en la fila sin que el ítem desaparezca al apagarlo.
class RecurringController extends AsyncNotifier<RecurringState> {
  @override
  Future<RecurringState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) return RecurringState.empty();
    return _load(householdId);
  }

  /// Fetch de todas las recurrentes del hogar. Las activas se ordenan primero;
  /// dentro de cada grupo, por próxima fecha (el repo ya trae por `next_date`).
  Future<RecurringState> _load(String householdId) async {
    final List<RecurringTransaction> all = await ref
        .read(recurringRepositoryProvider)
        .fetchAll(householdId: householdId, includeInactive: true);

    // Activas arriba, inactivas abajo; orden estable por `next_date` dentro de
    // cada grupo (la lista entrante ya viene ordenada por next_date asc).
    final List<RecurringTransaction> active =
        all.where((RecurringTransaction r) => r.active).toList();
    final List<RecurringTransaction> inactive =
        all.where((RecurringTransaction r) => !r.active).toList();

    return RecurringState(
        items: <RecurringTransaction>[...active, ...inactive]);
  }

  /// Inserta una recurrente (el repo inyecta `user_id` y defaultea `next_date`
  /// a `start_date`) y recarga. Espejo del `create` de iOS.
  Future<void> add(RecurringTransaction recurring) async {
    await ref.read(recurringRepositoryProvider).insert(recurring);
    await refresh();
  }

  /// Desactiva una recurrente (`active=false`) y recarga. Espejo del
  /// `deactivate` de iOS.
  Future<void> deactivate(String id) async {
    await ref.read(recurringRepositoryProvider).deactivate(id);
    await refresh();
  }

  /// Reactiva una recurrente (`active=true`) vía `update` y recarga. iOS no
  /// tiene este flujo (solo desactiva), pero acá el toggle es bidireccional.
  Future<void> reactivate(RecurringTransaction recurring) async {
    await ref
        .read(recurringRepositoryProvider)
        .update(recurring.copyWith(active: true));
    await refresh();
  }

  /// Elimina una recurrente y recarga. Espejo del `delete` de iOS.
  Future<void> delete(String id) async {
    await ref.read(recurringRepositoryProvider).delete(id);
    await refresh();
  }

  /// Fuerza una recarga (pull-to-refresh / post-mutación). Mantiene visible el
  /// dato previo mientras recomputa.
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData(RecurringState.empty());
      return;
    }
    state = const AsyncLoading<RecurringState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(householdId));
  }
}

/// Provider del controller de Recurrentes. `AsyncNotifierProvider` (no family):
/// el controller observa `currentHouseholdProvider` internamente, así que se
/// reconstruye solo cuando cambia el hogar activo.
final recurringControllerProvider =
    AsyncNotifierProvider<RecurringController, RecurringState>(
        RecurringController.new);
