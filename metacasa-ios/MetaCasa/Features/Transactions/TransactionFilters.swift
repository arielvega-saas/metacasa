import Foundation

/// Estado completo de filtros para la lista de Movimientos.
///
/// Paridad con MetaCasa web (`src/App.jsx` sección history 11034-11290):
/// - Tipo (todos/gasto/ingreso)
/// - Fecha (todo/mes actual/mes anterior/mes específico/semana/día único/rango)
/// - Monto (rango min-max)
/// - Categorías (multi-select)
/// - Cuentas (multi-select, con opción "hogar" para txs sin cuenta)
/// - Búsqueda por texto (categoría, nota, subcategoría)
/// - Modo de fecha: **Real** (fecha de la transacción) vs **Registro** (mes de
///   presupuesto asignado — permite postear un gasto de fin de mes al mes
///   siguiente si ya hiciste el corte).
/// - Sort (fecha/monto, asc/desc)
struct TransactionFilters: Equatable {
    var typeFilter: TypeFilter = .all
    var dateFilter: DateFilter = .currentMonth
    var amountMin: Decimal?
    var amountMax: Decimal?
    var selectedCategories: Set<String> = []
    /// Multi-select de subcategorías concretas. Paridad con la web: permite
    /// filtrar no solo por categoría padre ("Alimentación") sino por
    /// subcategoría específica ("Supermercado", "Delivery", etc.). Se combina
    /// AND con `selectedCategories` — la transacción debe estar en alguna de
    /// las categorías seleccionadas Y tener subcategoría en este set.
    var selectedSubcategories: Set<String> = []
    var selectedAccountIds: Set<UUID> = []
    /// Si está on, las transacciones sin `accountId` (tipo "hogar") se incluyen
    /// aunque haya accounts seleccionadas. Refleja el "Todos" del web.
    var includeNoAccount: Bool = true
    var searchText: String = ""
    var dateMode: DateMode = .real
    var sort: Sort = .dateDesc

    enum TypeFilter: String, CaseIterable, Identifiable, Hashable {
        case all, gasto, ingreso
        var id: String { rawValue }
        var localizationKey: String {
            switch self {
            case .all:     return "filters.type.all"
            case .gasto:   return "tx.type.expense"
            case .ingreso: return "tx.type.income"
            }
        }
    }

    enum DateFilter: Equatable, Hashable {
        case allTime
        case currentMonth
        case lastMonth
        case specificMonth(year: Int, month: Int)
        case thisWeek
        case singleDay(Date)
        case range(from: Date, to: Date)

        /// Clave i18n para el chip que describe el filtro activo.
        var label: String {
            switch self {
            case .allTime:        return "filters.date.allTime"
            case .currentMonth:   return "filters.date.currentMonth"
            case .lastMonth:      return "filters.date.lastMonth"
            case .specificMonth:  return "filters.date.specificMonth"
            case .thisWeek:       return "filters.date.thisWeek"
            case .singleDay:      return "filters.date.singleDay"
            case .range:          return "filters.date.range"
            }
        }
    }

    enum DateMode: String, CaseIterable, Hashable {
        /// Fecha real de la transacción.
        case real
        /// Mes de registro (presupuesto asignado). Permite ver gastos por mes
        /// contable aunque la fecha real sea del mes siguiente.
        case registro
        var localizationKey: String {
            switch self {
            case .real:     return "filters.mode.real"
            case .registro: return "filters.mode.registro"
            }
        }
    }

    enum Sort: String, CaseIterable, Hashable {
        case dateDesc, dateAsc, amountDesc, amountAsc
        var localizationKey: String {
            switch self {
            case .dateDesc:   return "sort.dateDesc"
            case .dateAsc:    return "sort.dateAsc"
            case .amountDesc: return "sort.amountDesc"
            case .amountAsc:  return "sort.amountAsc"
            }
        }
        var icon: String {
            switch self {
            case .dateDesc:   return "arrow.down"
            case .dateAsc:    return "arrow.up"
            case .amountDesc: return "arrow.down.right"
            case .amountAsc:  return "arrow.up.right"
            }
        }
    }

    /// Conteo de filtros activos (para el badge del botón "Filtros").
    /// No cuenta `dateFilter == currentMonth` porque es el default — ni
    /// `dateMode == real` ni `sort == dateDesc`.
    var activeCount: Int {
        var c = 0
        if typeFilter != .all { c += 1 }
        if dateFilter != .currentMonth { c += 1 }
        if amountMin != nil || amountMax != nil { c += 1 }
        if !selectedCategories.isEmpty { c += 1 }
        if !selectedSubcategories.isEmpty { c += 1 }
        if !selectedAccountIds.isEmpty { c += 1 }
        if !searchText.isEmpty { c += 1 }
        return c
    }

    var hasAnyFilter: Bool { activeCount > 0 }

    // MARK: - Apply filters

    /// Aplica todos los filtros a una lista de transacciones y devuelve
    /// ordenadas según `sort`.
    func apply(to txs: [Transaction]) -> [Transaction] {
        var result = txs

        // 1. Tipo
        switch typeFilter {
        case .all:     break
        case .gasto:   result = result.filter { $0.type == .gasto }
        case .ingreso: result = result.filter { $0.type == .ingreso }
        }

        // 2. Rango de fechas
        if let r = resolvedDateRange() {
            result = result.filter { tx in
                let d = dateMode == .registro ? registrationDate(of: tx) : tx.date
                return d >= r.from && d <= r.to
            }
        }

        // 3. Monto
        if let min = amountMin {
            result = result.filter { $0.amount >= min }
        }
        if let max = amountMax {
            result = result.filter { $0.amount <= max }
        }

        // 4. Categorías (multi-select)
        if !selectedCategories.isEmpty {
            result = result.filter { selectedCategories.contains($0.category) }
        }

        // 4b. Subcategorías (multi-select — AND con categorías).
        // Una transacción sin subcategoría queda filtrada fuera si hay
        // subcategorías seleccionadas. Mantiene la semántica web.
        if !selectedSubcategories.isEmpty {
            result = result.filter { tx in
                guard let sub = tx.subcategory, !sub.isEmpty else { return false }
                return selectedSubcategories.contains(sub)
            }
        }

        // 5. Cuentas (multi-select con excepción "hogar")
        if !selectedAccountIds.isEmpty {
            result = result.filter { tx in
                if let aid = tx.accountId {
                    return selectedAccountIds.contains(aid)
                }
                return includeNoAccount
            }
        }

        // 6. Texto libre
        if !searchText.isEmpty {
            let q = searchText
            result = result.filter { tx in
                tx.category.localizedCaseInsensitiveContains(q) ||
                (tx.note ?? "").localizedCaseInsensitiveContains(q) ||
                (tx.subcategory ?? "").localizedCaseInsensitiveContains(q)
            }
        }

        // 7. Ordenamiento
        result.sort { a, b in
            switch sort {
            case .dateDesc:   return a.date > b.date
            case .dateAsc:    return a.date < b.date
            case .amountDesc: return a.amount > b.amount
            case .amountAsc:  return a.amount < b.amount
            }
        }
        return result
    }

    /// Computa el rango (from, to) concreto según el `dateFilter`.
    /// Devuelve nil si es `.allTime`.
    func resolvedDateRange(now: Date = Date(), calendar: Calendar = .current) -> (from: Date, to: Date)? {
        switch dateFilter {
        case .allTime:
            return nil
        case .currentMonth:
            return monthRange(for: now, cal: calendar)
        case .lastMonth:
            let d = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return monthRange(for: d, cal: calendar)
        case .specificMonth(let y, let m):
            var comps = DateComponents(); comps.year = y; comps.month = m
            guard let start = calendar.date(from: comps) else { return nil }
            return monthRange(for: start, cal: calendar)
        case .thisWeek:
            guard let weekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            ) else { return nil }
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return (weekStart, endOfDay(weekEnd, cal: calendar))
        case .singleDay(let d):
            return (calendar.startOfDay(for: d), endOfDay(d, cal: calendar))
        case .range(let from, let to):
            return (calendar.startOfDay(for: from), endOfDay(to, cal: calendar))
        }
    }

    // MARK: - Helpers

    private func monthRange(for date: Date, cal: Calendar) -> (from: Date, to: Date) {
        let comps = cal.dateComponents([.year, .month], from: date)
        let start = cal.date(from: comps) ?? date
        let end = cal.date(byAdding: DateComponents(month: 1, day: -1, hour: 23, minute: 59, second: 59), to: start) ?? date
        return (start, end)
    }

    private func endOfDay(_ date: Date, cal: Calendar) -> Date {
        cal.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }

    private func registrationDate(of tx: Transaction) -> Date {
        if let y = tx.periodYear, let m = tx.periodMonth {
            var comps = DateComponents()
            comps.year = y
            comps.month = m
            comps.day = 15
            return Calendar.current.date(from: comps) ?? tx.date
        }
        return tx.date
    }
}

/// Modo de visualización de la lista de movimientos.
enum TransactionViewMode: String, CaseIterable, Hashable {
    case list
    case calendar
    var icon: String {
        switch self {
        case .list:     return "list.bullet"
        case .calendar: return "calendar"
        }
    }
    var localizationKey: String {
        switch self {
        case .list:     return "view.list"
        case .calendar: return "view.calendar"
        }
    }
}
