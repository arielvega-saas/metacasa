import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/recurring_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';
import '../../notifications/notification_preferences.dart';
import '../../notifications/notification_service.dart';

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
  /// a `start_date`) y recarga. Espejo del `create` de iOS: tras persistir,
  /// agenda el heads-up con el `id`/`next_date` reales devueltos por la DB.
  Future<void> add(RecurringTransaction recurring) async {
    final RecurringTransaction saved =
        await ref.read(recurringRepositoryProvider).insert(recurring);
    await _scheduleHeadsUp(saved);
    await refresh();
  }

  /// Desactiva una recurrente (`active=false`) y recarga. Espejo del
  /// `deactivate` de iOS: cancela el heads-up pendiente.
  Future<void> deactivate(String id) async {
    await ref.read(recurringRepositoryProvider).deactivate(id);
    await _cancelHeadsUp(id);
    await refresh();
  }

  /// Reactiva una recurrente (`active=true`) vía `update` y recarga. iOS no
  /// tiene este flujo (solo desactiva), pero acá el toggle es bidireccional:
  /// re-agenda el heads-up al volver a activarla.
  Future<void> reactivate(RecurringTransaction recurring) async {
    final RecurringTransaction reactivated = recurring.copyWith(active: true);
    await ref.read(recurringRepositoryProvider).update(reactivated);
    await _scheduleHeadsUp(reactivated);
    await refresh();
  }

  /// Elimina una recurrente y recarga. Espejo del `delete` de iOS: cancela el
  /// heads-up local pendiente.
  Future<void> delete(String id) async {
    await ref.read(recurringRepositoryProvider).delete(id);
    await _cancelHeadsUp(id);
    await refresh();
  }

  /// Agenda (best-effort, guardado) el heads-up de una recurrente. Resuelve la
  /// moneda del hogar para formatear el monto. Inicializa el servicio
  /// perezosamente; no-opea si no está listo/permitido, el toggle `recurring`
  /// está apagado, la recurrente está inactiva o `next_date` ya pasó. Nunca lanza.
  Future<void> _scheduleHeadsUp(RecurringTransaction recurring) async {
    try {
      final NotificationService svc = ref.read(notificationServiceProvider);
      await svc.init();
      if (!svc.isReady) return;
      final Household? household =
          await ref.read(currentHouseholdProvider.future);
      await svc.scheduleRecurringHeadsUp(
        recurring,
        ref.read(notificationPreferencesProvider),
        currencyCode: household?.defaultCurrency ?? 'USD',
      );
    } catch (_) {
      // Sin notificaciones disponibles (p. ej. test/desktop): no-op.
    }
  }

  /// Cancela el heads-up de una recurrente por id (best-effort, guardado).
  Future<void> _cancelHeadsUp(String id) async {
    try {
      final NotificationService svc = ref.read(notificationServiceProvider);
      if (!svc.isReady) return;
      await svc.cancelRecurringHeadsUp(id);
    } catch (_) {
      // no-op
    }
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
