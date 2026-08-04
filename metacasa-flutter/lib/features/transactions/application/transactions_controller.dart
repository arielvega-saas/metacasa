import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/models.dart';
import '../../../state/app_providers.dart';

/// Filtro por tipo de movimiento para la lista. Espejo del
/// `TransactionFilters.TypeFilter` de iOS (Todos / Gastos / Ingresos).
enum TxTypeFilter {
  all,
  gasto,
  ingreso;

  /// Etiqueta del chip (rioplatense).
  String get label => switch (this) {
        TxTypeFilter.all => 'Todos',
        TxTypeFilter.gasto => 'Gastos',
        TxTypeFilter.ingreso => 'Ingresos',
      };
}

/// Criterio de ordenamiento de la lista. Espejo del `TransactionFilters.Sort`
/// de iOS (fecha/monto, asc/desc).
enum TxSort {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc;

  /// Etiqueta para el menú de orden.
  String get label => switch (this) {
        TxSort.dateDesc => 'Fecha (recientes primero)',
        TxSort.dateAsc => 'Fecha (antiguos primero)',
        TxSort.amountDesc => 'Monto (mayor a menor)',
        TxSort.amountAsc => 'Monto (menor a mayor)',
      };
}

/// Estado inmutable de los filtros de la lista de Movimientos.
///
/// Clase plana (sin freezed/codegen, por requerimiento). Es un subconjunto del
/// `TransactionFilters` de iOS, alineado al alcance del port Flutter: tipo,
/// categoría, cuenta, búsqueda libre y orden. El filtrado por rango de fechas
/// que tiene iOS acá lo cubre el período visible (`fetchForPeriod`), así que no
/// se duplica.
///
/// `accountId` nulo = "Todas las cuentas". `category` nula = "Todas las
/// categorías". `search` se matchea (case-insensitive) contra nota, categoría y
/// subcategoría — mismas columnas que iOS.
class TransactionFilters {
  const TransactionFilters({
    this.type = TxTypeFilter.all,
    this.category,
    this.accountId,
    this.search = '',
    this.sort = TxSort.dateDesc,
  });

  /// Filtro por tipo (todos / gastos / ingresos).
  final TxTypeFilter type;

  /// Categoría seleccionada (nombre exacto), o null para todas.
  final String? category;

  /// Id de cuenta seleccionada, o null para todas.
  final String? accountId;

  /// Texto libre de búsqueda (nota / categoría / subcategoría).
  final String search;

  /// Criterio de ordenamiento.
  final TxSort sort;

  /// Cantidad de filtros activos (para el badge del botón "Filtros"). No cuenta
  /// `sort` (siempre presente) ni la búsqueda (tiene su propia barra/chip).
  /// Espejo del `activeCount` de iOS acotado al subconjunto soportado.
  int get activeCount {
    var count = 0;
    if (type != TxTypeFilter.all) count++;
    if (category != null) count++;
    if (accountId != null) count++;
    return count;
  }

  /// `true` si hay algún filtro (incluida la búsqueda) que altere el set base.
  bool get hasAnyFilter => activeCount > 0 || search.trim().isNotEmpty;

  /// Copia con cambios puntuales. Los flags `clearX` permiten volver un campo
  /// nullable a null (no se puede expresar con un parámetro opcional que ya
  /// usa null como "sin cambio").
  TransactionFilters copyWith({
    TxTypeFilter? type,
    String? category,
    bool clearCategory = false,
    String? accountId,
    bool clearAccount = false,
    String? search,
    TxSort? sort,
  }) {
    return TransactionFilters(
      type: type ?? this.type,
      category: clearCategory ? null : (category ?? this.category),
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      search: search ?? this.search,
      sort: sort ?? this.sort,
    );
  }

  /// Aplica todos los filtros a [txs] y devuelve la lista ya ordenada según
  /// [sort]. Port del `apply(to:)` de iOS (mismo orden de pasos y matemática).
  List<Transaction> apply(List<Transaction> txs) {
    Iterable<Transaction> result = txs;

    // 1. Tipo.
    switch (type) {
      case TxTypeFilter.all:
        break;
      case TxTypeFilter.gasto:
        result = result.where((Transaction t) => t.type == TxType.gasto);
      case TxTypeFilter.ingreso:
        result = result.where((Transaction t) => t.type == TxType.ingreso);
    }

    // 2. Categoría.
    if (category != null) {
      result = result.where((Transaction t) => t.category == category);
    }

    // 3. Cuenta.
    if (accountId != null) {
      result = result.where((Transaction t) => t.accountId == accountId);
    }

    // 4. Texto libre (nota / categoría / subcategoría), case-insensitive.
    final String query = search.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((Transaction t) {
        final String note = (t.note ?? '').toLowerCase();
        final String cat = t.category.toLowerCase();
        final String sub = (t.subcategory ?? '').toLowerCase();
        return note.contains(query) ||
            cat.contains(query) ||
            sub.contains(query);
      });
    }

    // 5. Ordenamiento.
    final List<Transaction> sorted = result.toList();
    sorted.sort((Transaction a, Transaction b) {
      switch (sort) {
        case TxSort.dateDesc:
          return b.date.compareTo(a.date);
        case TxSort.dateAsc:
          return a.date.compareTo(b.date);
        case TxSort.amountDesc:
          return b.amount.compareTo(a.amount);
        case TxSort.amountAsc:
          return a.amount.compareTo(b.amount);
      }
    });
    return sorted;
  }
}

/// Grupo de movimientos de un mismo día calendario, con sus totales ya
/// computados. Espejo del `groupedByDay` + header de día de la lista de iOS.
class DayGroup {
  const DayGroup({
    required this.day,
    required this.transactions,
    required this.ingresos,
    required this.gastos,
  });

  /// Día calendario (medianoche local) al que pertenece el grupo.
  final DateTime day;

  /// Movimientos del día, ya ordenados según el `sort` activo.
  final List<Transaction> transactions;

  /// Σ ingresos del día.
  final Decimal ingresos;

  /// Σ gastos del día.
  final Decimal gastos;

  /// Neto del día (ingresos − gastos) — lo muestra el header del día.
  Decimal get net => ingresos - gastos;
}

/// Estado de la pantalla de Movimientos: la lista cruda del período, la
/// vista filtrada/ordenada, los grupos por día y los catálogos auxiliares
/// (cuentas + categorías) que alimentan los selectores de filtros.
class TransactionsState {
  const TransactionsState({
    required this.all,
    required this.filtered,
    required this.dayGroups,
    required this.accounts,
    required this.categories,
    required this.totalIngresos,
    required this.totalGastos,
    required this.filters,
  });

  /// Estado vacío (sin hogar / sin datos).
  factory TransactionsState.empty() => TransactionsState(
        all: const <Transaction>[],
        filtered: const <Transaction>[],
        dayGroups: const <DayGroup>[],
        accounts: const <Account>[],
        categories: const <CategoryItem>[],
        totalIngresos: Decimal.zero,
        totalGastos: Decimal.zero,
        filters: const TransactionFilters(),
      );

  /// Filtros vigentes. Viajan en el estado para que la UI los observe vía el
  /// valor del provider (cada cambio de filtro produce un estado nuevo, así que
  /// los `ConsumerWidget` que dependen de chips/badge se reconstruyen).
  final TransactionFilters filters;

  /// Todos los movimientos del período (sin filtrar) — usado para saber si el
  /// vacío es "no hay nada" vs "los filtros no matchean".
  final List<Transaction> all;

  /// Movimientos tras aplicar filtros + orden.
  final List<Transaction> filtered;

  /// [filtered] agrupados por día (descendente), con totales por día.
  final List<DayGroup> dayGroups;

  /// Cuentas del hogar (para el selector de cuenta del filtro).
  final List<Account> accounts;

  /// Categorías disponibles (gastos ∪ ingresos, dedup) para el selector.
  final List<CategoryItem> categories;

  /// Σ ingresos de la vista filtrada (summary bar).
  final Decimal totalIngresos;

  /// Σ gastos de la vista filtrada (summary bar).
  final Decimal totalGastos;

  /// Cantidad de movimientos en la vista filtrada (summary bar).
  int get count => filtered.length;

  /// `true` si el período no tiene NINGÚN movimiento (empty-state general).
  bool get isEmpty => all.isEmpty;

  /// `true` si hay datos en el período pero los filtros no matchean nada
  /// (empty-state de "ajustá los filtros").
  bool get isFilteredEmpty => all.isNotEmpty && filtered.isEmpty;
}

/// Controller de la lista de Movimientos. `AsyncNotifier` que observa el hogar
/// activo + el período visible y recarga `fetchForPeriod` cuando cambia
/// cualquiera. Los filtros viven en el propio notifier (mutables vía
/// [setFilters] y helpers), y recomputan la vista en memoria sin re-fetchear.
///
/// Espejo de `TransactionListView` de iOS: misma fuente (`fetchForPeriod`),
/// mismo grouping por día, mismos catálogos auxiliares; la diferencia es que acá
/// el estado de filtros es parte del controller (Riverpod) en lugar de
/// `@State` de la vista.
class TransactionsController extends AsyncNotifier<TransactionsState> {
  /// Estado de filtros vigente. Arranca en el default (todos, sin categoría/
  /// cuenta, orden por fecha desc).
  TransactionFilters _filters = const TransactionFilters();

  /// Filtros actuales (lo lee la UI para pintar chips/estado seleccionado).
  TransactionFilters get filters => _filters;

  @override
  Future<TransactionsState> build() async {
    // Depende del hogar activo y del período visible. Observamos ambos: un
    // switch de hogar o de mes reconstruye y re-fetchea.
    final String? householdId =
        await ref.watch(currentHouseholdProvider.future).then((h) => h?.id);
    final YearMonth period = ref.watch(currentPeriodProvider);

    if (householdId == null) return TransactionsState.empty();

    return _load(
      householdId: householdId,
      year: period.year,
      month: period.month,
    );
  }

  /// Fetch del período + catálogos auxiliares, y cómputo de la vista filtrada.
  Future<TransactionsState> _load({
    required String householdId,
    required int year,
    required int month,
  }) async {
    final TransactionRepository txRepo =
        ref.read(transactionRepositoryProvider);
    final AccountRepository accountRepo = ref.read(accountRepositoryProvider);
    final CategoryRepository categoryRepo =
        ref.read(categoryRepositoryProvider);

    // Movimientos del período (fuente principal). Cuentas + categorías degradan
    // a vacío si fallan (mismo criterio que los `try?` de iOS): no queremos que
    // un catálogo secundario tumbe la lista.
    final Future<List<Transaction>> txsF = txRepo.fetchForPeriod(
      householdId: householdId,
      year: year,
      month: month,
    );
    final Future<List<Account>> accountsF =
        accountRepo.fetchAll(householdId).catchError((_) => <Account>[]);
    final Future<CategoriesBlob?> blobF =
        categoryRepo.fetch(householdId).catchError((_) => null);

    final List<Transaction> txs = await txsF;
    final List<Account> accounts = await accountsF;
    final CategoriesBlob? blob = await blobF;

    final List<CategoryItem> categories = _availableCategories(blob?.data);

    return _project(txs: txs, accounts: accounts, categories: categories);
  }

  /// Construye el [TransactionsState] a partir de la lista cruda + catálogos,
  /// aplicando los filtros vigentes. Se reutiliza tanto en el load inicial como
  /// al cambiar filtros (sin re-fetch).
  TransactionsState _project({
    required List<Transaction> txs,
    required List<Account> accounts,
    required List<CategoryItem> categories,
  }) {
    final List<Transaction> filtered = _filters.apply(txs);
    final List<DayGroup> groups = _groupByDay(filtered);

    var ingresos = Decimal.zero;
    var gastos = Decimal.zero;
    for (final Transaction t in filtered.excludingTransfers) {
      switch (t.type) {
        case TxType.ingreso:
          ingresos += t.amount;
        case TxType.gasto:
          gastos += t.amount;
      }
    }

    return TransactionsState(
      all: txs,
      filtered: filtered,
      dayGroups: groups,
      accounts: accounts,
      categories: categories,
      totalIngresos: ingresos,
      totalGastos: gastos,
      filters: _filters,
    );
  }

  /// Agrupa por día calendario (medianoche local), orden descendente de día, y
  /// computa ingresos/gastos por grupo. Asume que [txs] ya viene ordenada por
  /// el `sort` activo, así que conserva ese orden dentro de cada día.
  List<DayGroup> _groupByDay(List<Transaction> txs) {
    final Map<DateTime, List<Transaction>> byDay =
        <DateTime, List<Transaction>>{};
    for (final Transaction t in txs) {
      final DateTime day = DateTime(t.date.year, t.date.month, t.date.day);
      (byDay[day] ??= <Transaction>[]).add(t);
    }

    final List<DateTime> days = byDay.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));

    return days.map((DateTime day) {
      final List<Transaction> dayTxs = byDay[day]!;
      var ingresos = Decimal.zero;
      var gastos = Decimal.zero;
      for (final Transaction t in dayTxs.excludingTransfers) {
        switch (t.type) {
          case TxType.ingreso:
            ingresos += t.amount;
          case TxType.gasto:
            gastos += t.amount;
        }
      }
      return DayGroup(
        day: day,
        transactions: dayTxs,
        ingresos: ingresos,
        gastos: gastos,
      );
    }).toList();
  }

  /// Une categorías de gastos + ingresos (mergeadas con los defaults) y dedup
  /// por nombre, preservando orden. Espejo del `availableCategories` de la lista
  /// de iOS (que hace `merged(.gasto) + merged(.ingreso)` y dedup).
  List<CategoryItem> _availableCategories(CategoriesData? data) {
    final List<CategoryItem> all = <CategoryItem>[
      ..._merged(data, TxType.gasto),
      ..._merged(data, TxType.ingreso),
    ];
    final Set<String> seen = <String>{};
    return all
        .where((CategoryItem c) => seen.add(c.name))
        .toList(growable: false);
  }

  /// Cambia el set completo de filtros y reproyecta la vista sin re-fetch.
  void setFilters(TransactionFilters filters) {
    _filters = filters;
    _reproject();
  }

  /// Atajo: setea el filtro por tipo (chips Todos/Gastos/Ingresos).
  void setType(TxTypeFilter type) => setFilters(_filters.copyWith(type: type));

  /// Atajo: setea el texto de búsqueda (barra de search).
  void setSearch(String search) =>
      setFilters(_filters.copyWith(search: search));

  /// Atajo: setea el criterio de orden (menú "Ordenar").
  void setSort(TxSort sort) => setFilters(_filters.copyWith(sort: sort));

  /// Resetea filtros al default y reproyecta (botón "Limpiar").
  void clearFilters() => setFilters(const TransactionFilters());

  /// Recalcula la vista filtrada sobre la lista YA cargada (sin red). No-op si
  /// todavía no hay datos cargados (estado loading/error).
  void _reproject() {
    final TransactionsState? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData<TransactionsState>(_project(
      txs: current.all,
      accounts: current.accounts,
      categories: current.categories,
    ));
  }

  /// Fuerza recarga desde el backend (pull-to-refresh). Mantiene visible el
  /// dato previo mientras recomputa.
  Future<void> refresh() async {
    final String? householdId =
        await ref.read(currentHouseholdProvider.future).then((h) => h?.id);
    final YearMonth period = ref.read(currentPeriodProvider);
    if (householdId == null) {
      state = AsyncData<TransactionsState>(TransactionsState.empty());
      return;
    }
    state = const AsyncLoading<TransactionsState>().copyWithPrevious(state);
    state = await AsyncValue.guard<TransactionsState>(() => _load(
          householdId: householdId,
          year: period.year,
          month: period.month,
        ));
  }

  /// Combina defaults + custom para [type], priorizando la custom ante choque de
  /// nombre. Port 1:1 del `CategoryService.merged` de iOS (orden: primero los
  /// defaults — pisados por su versión custom si existe —, luego los custom
  /// nuevos).
  static List<CategoryItem> _merged(CategoriesData? data, TxType type) {
    final List<String> defaults = type == TxType.gasto
        ? CategoryCatalog.defaultGastos
        : CategoryCatalog.defaultIngresos;
    final List<CategoryItem> defaultItems = defaults
        .map((String name) =>
            CategoryItem(name: name, emoji: CategoryCatalog.emojiFor(name)))
        .toList();

    final List<CategoryItem> customItems = type == TxType.gasto
        ? (data?.gastos ?? const <CategoryItem>[])
        : (data?.ingresos ?? const <CategoryItem>[]);

    final Map<String, CategoryItem> customByName = <String, CategoryItem>{
      for (final CategoryItem c in customItems) c.name: c,
    };
    final Set<String> defaultNames =
        defaultItems.map((CategoryItem c) => c.name).toSet();

    final List<CategoryItem> result = <CategoryItem>[];
    for (final CategoryItem item in defaultItems) {
      result.add(customByName[item.name] ?? item);
    }
    for (final CategoryItem item in customItems) {
      if (!defaultNames.contains(item.name)) result.add(item);
    }
    return result;
  }

  /// Helper público: categorías mergeadas para un [type] dado. Lo usa el
  /// formulario de alta/edición para poblar la grilla según Gasto/Ingreso.
  static List<CategoryItem> mergedCategories(
          CategoriesData? data, TxType type) =>
      _merged(data, type);
}

/// Provider del controller de Movimientos. Observa hogar + período internamente.
final transactionsControllerProvider =
    AsyncNotifierProvider<TransactionsController, TransactionsState>(
        TransactionsController.new);
