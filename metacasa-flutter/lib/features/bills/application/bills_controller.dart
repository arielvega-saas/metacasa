import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/bill_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Un grupo de vencimientos del mismo [BillUrgencyLevel] (overdue / hoy / pronto
/// / próximos / futuros / pagados / saltados), ya ordenado por fecha. Espejo del
/// `grouped` computed de `BillsListView` (iOS).
class BillGroup {
  const BillGroup({required this.urgency, required this.bills});

  /// Nivel de urgencia compartido por todas las filas del grupo.
  final BillUrgencyLevel urgency;

  /// Vencimientos del grupo, ordenados por `due_date` ascendente.
  final List<Bill> bills;
}

/// Estado inmutable de la pantalla de Vencimientos. Clase plana (sin
/// freezed/codegen, por requerimiento) con la lista cruda de vencimientos y su
/// agrupación por urgencia ya computada (en el orden visual del iOS).
class BillsState {
  const BillsState({required this.bills, required this.groups});

  /// Estado vacío (sin hogar o sin vencimientos).
  factory BillsState.empty() =>
      const BillsState(bills: <Bill>[], groups: <BillGroup>[]);

  /// Todos los vencimientos cargados (this-month + upcoming, deduplicados).
  final List<Bill> bills;

  /// Vencimientos agrupados por urgencia, en el orden de presentación del iOS:
  /// overdue → hoy → pronto → próximos → futuros → pagados → saltados. Solo
  /// incluye grupos no vacíos.
  final List<BillGroup> groups;

  /// `true` si no hay ningún vencimiento para mostrar.
  bool get isEmpty => bills.isEmpty;
}

/// Controller de la pantalla de Vencimientos. `AsyncNotifier` que observa el
/// hogar activo y recarga ante cualquier cambio (switch de hogar).
///
/// Fetch: el repo expone `fetchForMonth` (todo el mes calendario, cualquier
/// estado) y `fetchUpcoming` (pendientes con `due_date <= hoy+N`, SIN cota
/// inferior → incluye los vencidos). Mezclamos ambos y deduplicamos por `id`
/// para tener un panorama completo: pendientes vencidos + del mes (pagados /
/// saltados / pendientes) + próximos. Es el equivalente práctico del
/// `fetchAll` que usa iOS, con los métodos disponibles en Flutter.
class BillsController extends AsyncNotifier<BillsState> {
  /// Días hacia adelante para traer los pendientes próximos (cubre vencimientos
  /// de hasta ~2 meses, suficiente para el panorama de la pantalla).
  static const int _upcomingWindowDays = 60;

  /// Orden de presentación de los grupos — 1:1 con el `order` de `BillsListView`.
  static const List<BillUrgencyLevel> _urgencyOrder = <BillUrgencyLevel>[
    BillUrgencyLevel.overdue,
    BillUrgencyLevel.dueToday,
    BillUrgencyLevel.dueSoon,
    BillUrgencyLevel.upcoming,
    BillUrgencyLevel.future,
    BillUrgencyLevel.paid,
    BillUrgencyLevel.skipped,
  ];

  @override
  Future<BillsState> build() async {
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) return BillsState.empty();
    return _load(householdId);
  }

  /// Fetch + agrupación. Trae el mes actual y los pendientes próximos en
  /// paralelo, deduplica por `id` y arma los grupos por urgencia.
  Future<BillsState> _load(String householdId) async {
    final BillRepository repo = ref.read(billRepositoryProvider);
    final DateTime now = DateTime.now();

    final Future<List<Bill>> monthF = repo
        .fetchForMonth(
            householdId: householdId, year: now.year, month: now.month)
        .catchError((_) => <Bill>[]);
    final Future<List<Bill>> upcomingF = repo
        .fetchUpcoming(householdId: householdId, daysAhead: _upcomingWindowDays)
        .catchError((_) => <Bill>[]);

    final List<Bill> month = await monthF;
    final List<Bill> upcoming = await upcomingF;

    // Dedup por id preservando una sola instancia por vencimiento.
    final Map<String, Bill> byId = <String, Bill>{};
    for (final Bill b in <Bill>[...month, ...upcoming]) {
      byId[b.id] = b;
    }
    final List<Bill> bills = byId.values.toList()
      ..sort((Bill a, Bill b) => a.dueDate.compareTo(b.dueDate));

    return BillsState(bills: bills, groups: _group(bills));
  }

  /// Agrupa por urgencia en el orden del iOS, descartando grupos vacíos. Cada
  /// grupo queda ordenado por `due_date` ascendente (la lista de entrada ya lo
  /// está, así que el filtrado preserva el orden).
  List<BillGroup> _group(List<Bill> bills) {
    final List<BillGroup> groups = <BillGroup>[];
    for (final BillUrgencyLevel level in _urgencyOrder) {
      final List<Bill> matches =
          bills.where((Bill b) => b.urgency == level).toList();
      if (matches.isNotEmpty) {
        groups.add(BillGroup(urgency: level, bills: matches));
      }
    }
    return groups;
  }

  /// Inserta un vencimiento (el repo inyecta `user_id`) y recarga. Espejo del
  /// `create` de iOS.
  Future<void> addBill(Bill bill) async {
    await ref.read(billRepositoryProvider).insert(bill);
    await refresh();
  }

  /// Marca un vencimiento como pagado (`status='paid'`) y recarga. Espejo del
  /// `markPaid` de iOS.
  Future<void> markPaid(String id) async {
    await ref.read(billRepositoryProvider).markPaid(id);
    await refresh();
  }

  /// Actualiza un vencimiento existente y recarga. (Se llama `updateBill` y no
  /// `update` porque `AsyncNotifier` ya define un `update` propio.)
  Future<void> updateBill(Bill bill) async {
    await ref.read(billRepositoryProvider).update(bill);
    await refresh();
  }

  /// Elimina un vencimiento y recarga. Espejo del `delete` de iOS.
  Future<void> delete(String id) async {
    await ref.read(billRepositoryProvider).delete(id);
    await refresh();
  }

  /// Fuerza una recarga (pull-to-refresh / post-mutación). Mantiene visible el
  /// dato previo mientras recomputa.
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    if (householdId == null) {
      state = AsyncData(BillsState.empty());
      return;
    }
    state = const AsyncLoading<BillsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(householdId));
  }
}

/// Provider del controller de Vencimientos. `AsyncNotifierProvider` (no family):
/// el controller observa `currentHouseholdProvider` internamente, así que se
/// reconstruye solo cuando cambia el hogar activo.
final billsControllerProvider =
    AsyncNotifierProvider<BillsController, BillsState>(BillsController.new);
