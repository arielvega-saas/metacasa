import Foundation

/// Por qué las tools **lanzan** en vez de devolver "Error: …" como texto.
///
/// Un string que empieza con "Error:" es, para el modelo, un resultado más:
/// puede leerlo, decidir que no es importante y seguir. Lanzando, el
/// `tool_result` viaja con `is_error: true`, que es la señal que el modelo sí
/// respeta. La diferencia se pagó en producción: el asistente confirmó por
/// escrito una corrección de importe que nunca llegó a la base.
enum AIToolError: LocalizedError {
    case referenciaInvalida(String)
    case referenciaAmbigua(String, Int)
    case movimientoNoEncontrado(String)
    case escrituraNoVerificable(String)
    case escrituraNoImpactada(pedido: String, real: String)

    var errorDescription: String? {
        switch self {
        case .referenciaInvalida(let r):
            return "\"\(r)\" no identifica un movimiento. Buscá el movimiento primero y usá el id completo que devuelve la búsqueda."
        case .referenciaAmbigua(let r, let n):
            return "\"\(r)\" coincide con \(n) movimientos. Pedí el id completo antes de escribir."
        case .movimientoNoEncontrado(let r):
            return "No existe ningún movimiento con id \(r). NO informes ningún cambio: no se modificó nada."
        case .escrituraNoVerificable(let id):
            return "El movimiento \(id) no se pudo releer después de escribir, así que el cambio no está confirmado. NO informes que se guardó."
        case .escrituraNoImpactada(let pedido, let real):
            return "El cambio NO se aplicó. Se pidió \(pedido) y en la base quedó \(real). NO informes que se guardó."
        }
    }
}

/// Ejecución de las 22 tools del asistente. **Sin FoundationModels y sin gate
/// de versión: corre desde iOS 17**, que es el deployment target de la app.
///
/// Estos métodos estuvieron marcados `@available(iOS 26.0, *)` dentro de
/// `#if canImport(FoundationModels)` sin usar una sola API del framework: el
/// gate lo heredaban de los tipos de sus argumentos (`XxxTool.Arguments`, que
/// son structs `@Generable` anidados en tools de iOS 26). Ahora toman los args
/// planos de `AIToolArgs.swift` y el gate se quedó donde de verdad hace falta:
/// en la declaración de las tools y en el provider on-device.
///
/// Si algún día un handler necesita una API de iOS 26 **en su cuerpo**, ese
/// método —y sólo ese— lleva su propio `@available`; no todo el archivo.
/// ─── POR QUÉ ES UN `actor` Y NO `@MainActor` ──────────────────────────────
///
/// Estuvo marcado `@MainActor` sin ninguna razón: **no toca interfaz**. Todo lo
/// que usa (`TransactionService`, `AccountService`, `BudgetService`, …) ya son
/// `actor`, y lo demás es formateo y filtrado puro.
///
/// El costo de esa anotación de más lo pagaba la UI: las 22 tools corrían en el
/// hilo principal, incluidos los `filter`/`reduce` sobre miles de filas y el
/// formateo de cada importe. Con un pedido grande —"cargá estos trece
/// movimientos"— eso dejaba la app congelada hasta que el sistema la mataba.
///
/// Como `actor`, el trabajo va a un executor propio y **la interfaz no puede
/// bloquearse por este camino**, sin importar cuánto tarde adentro. El estado
/// mutable (`cuentaPorDefecto`) queda protegido por el aislamiento del actor,
/// así que tampoco hace falta el `@unchecked Sendable` que había antes.
actor AIToolHandler {
    private let householdId: UUID
    private let userId: UUID
    private let currency: String

    /// Cuenta por defecto, resuelta UNA vez por turno.
    ///
    /// `defaultAccountId` hace un `GET /accounts` completo. Como cada
    /// `add_transaction` la pedía, cargar trece movimientos eran trece consultas
    /// redundantes intercaladas con los trece POST: veintiséis viajes en serie
    /// donde alcanzaban catorce. El handler vive lo que dura un turno, así que
    /// cachearlo acá no puede quedar rancio.
    private var cuentaPorDefecto: UUID??

    /// Cuántas escrituras REALES ejecutó el turno.
    ///
    /// Existe porque el asistente puede **redactar** una confirmación sin haber
    /// ejecutado nada: "Actualicé el gasto a $78.972,57" sobre un registro que
    /// quedó intacto. Ningún prompt evita eso de manera confiable —un modelo
    /// chico alucina confirmaciones—, así que la app no le cree a la palabra:
    /// cuenta los efectos.
    ///
    /// Sólo suma cuando la escritura ya volvió verificada de la base, nunca al
    /// intentarla.
    private(set) var escriturasDelTurno = 0

    /// Arranca un turno nuevo. La sesión on-device se reusa varios minutos, así
    /// que el contador tiene que volver a cero acá y no al crear el handler.
    func iniciarTurno() {
        escriturasDelTurno = 0
    }

    private func registrarEscritura() {
        escriturasDelTurno += 1
    }

    /// Convierte a `Decimal` un importe que viene del modelo como `Double`.
    ///
    /// `Decimal(unDouble)` **conserva el error binario del double**: pedir
    /// 78.972,57 guardaba `78972.57000000001024` en la base. Un centésimo de
    /// millonésimo no cambia ningún total visible, pero es basura en la columna
    /// de plata: reaparece en exportaciones, en comparaciones por igualdad y en
    /// cualquier suma que se muestre con más decimales.
    ///
    /// El JSON de la API no tiene tipo decimal, así que el importe llega sí o sí
    /// como `Double`; lo que se puede hacer es cortar el error acá, en el único
    /// lugar por donde entra.
    private static func montoDecimal(_ d: Double) -> Decimal {
        var origen = Decimal(d)
        var redondeado = Decimal()
        NSDecimalRound(&redondeado, &origen, 2, .plain)
        return redondeado
    }

    init(householdId: UUID, userId: UUID, currency: String) {
        self.householdId = householdId
        self.userId = userId
        self.currency = currency
    }

    /// La cuenta a la que imputar cuando el usuario no eligió una.
    private func resolverCuentaPorDefecto() async -> UUID? {
        if let cacheada = cuentaPorDefecto { return cacheada }
        let id = await AccountService.shared.defaultAccountId(householdId: householdId)
        cuentaPorDefecto = .some(id)
        return id
    }

    // MARK: - Date helpers

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return Self.dayFmt.date(from: s)
    }

    private func monthRange(_ monthStr: String?) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        if let m = monthStr {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            if let d = fmt.date(from: m) {
                let comps = cal.dateComponents([.year, .month], from: d)
                let start = cal.date(from: comps) ?? now
                let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? now
                return (start, end)
            }
        }
        let comps = cal.dateComponents([.year, .month], from: now)
        let start = cal.date(from: comps) ?? now
        let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? now
        return (start, end)
    }

    private func fmtDate(_ d: Date) -> String {
        Self.dayFmt.string(from: d)
    }

    /// Formato CON código ISO explícito (ej. "ARS 6.000", "USD 100").
    /// Esto evita que el LLM interprete el "$" como USD (bias del training).
    /// Cuando el LLM lee tool results con código explícito, sabe la moneda exacta
    /// y la respeta en su respuesta al usuario.
    private func fmt(_ amount: Decimal, cur: String? = nil) -> String {
        let currencyCode = cur ?? currency
        let value = (amount as NSDecimalNumber).doubleValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = ","
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(currencyCode) \(formatted)"
    }


    /// Importe formateado para que lo lea una PERSONA.
    ///
    /// `fmt` está pensado para el modelo: código ISO explícito y sin separador
    /// de miles, para que no interprete el "$" como dólares (sesgo de su
    /// entrenamiento). Eso mismo, mostrado en la tarjeta de deshacer, se lee
    /// "ARS 500000" — que en una app de plata queda mal y encima es más difícil
    /// de verificar de un vistazo.
    private func paraElUsuario(_ amount: Decimal) -> String {
        Money.format(amount, currency: currency, style: .compact)
    }


    /// Ajusta la categoría que eligió el modelo al catálogo REAL del hogar.
    ///
    /// ─── EL PROBLEMA ───────────────────────────────────────────────────────
    /// El modelo escribe la categoría como texto libre. Si inventa una que no
    /// existe —"Comida hecha", "Celular", "Seguro"—, el movimiento se guarda
    /// igual pero queda **huérfano**: no aparece en el selector al editarlo, no
    /// se puede presupuestar, y en los reportes es una categoría de una sola
    /// fila. Verificado en la base del usuario: cinco movimientos así.
    ///
    /// La corrección respeta lo que el usuario quiso decir, en este orden:
    /// 1. Coincidencia exacta → se usa tal cual.
    /// 2. Coincidencia ignorando mayúsculas y acentos ("alimentacion" →
    ///    "Alimentación") → se usa la del catálogo, para no duplicar la misma
    ///    categoría escrita de dos formas.
    /// 3. No existe → **se agrega al catálogo del hogar**. El usuario la pidió;
    ///    esconderla sería peor que crearla. Y se avisa en el resultado para
    ///    que el asistente lo cuente.
    private func categoriaDelCatalogo(_ pedida: String, tipo: TxType) async -> (nombre: String, creada: Bool) {
        let blob = try? await CategoryService.shared.fetch(householdId: householdId)
        let disponibles = CategoryService.merged(custom: blob?.data, type: tipo)

        if let exacta = disponibles.first(where: { $0.name == pedida }) {
            return (exacta.name, false)
        }
        let normalizar: (String) -> String = { s in
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespaces)
        }
        let objetivo = normalizar(pedida)
        if let parecida = disponibles.first(where: { normalizar($0.name) == objetivo }) {
            return (parecida.name, false)
        }

        // No existe: se crea, así el movimiento queda utilizable en toda la app.
        var data = blob?.data ?? CategoriesData(gastos: [], ingresos: [])
        let nueva = CategoryItem(name: pedida, emoji: CategoryCatalog.emoji(for: pedida))
        if tipo == .gasto { data.gastos.append(nueva) } else { data.ingresos.append(nueva) }
        try? await CategoryService.shared.save(householdId: householdId, data: data)
        return (pedida, true)
    }

    // MARK: - 1. Query Transactions

    func queryTransactions(_ p: QueryTransactionsArgs) async throws -> String {
        let from = parseDate(p.dateFrom) ?? Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let to = parseDate(p.dateTo) ?? Date()
        // `max(1, …)` y no sólo `min(…, 50)`: el `limit` lo elige el modelo, y
        // ante un "mostrame TODAS mis transacciones" Claude emite `-1`, que es la
        // convención habitual de "sin límite". `min(-1, 50)` da `-1`, y
        // `Array.prefix(-1)` es un `_precondition` que mata la app en Release
        // ("Can't take a prefix of negative length"). El schema que se le manda
        // al modelo tampoco declara `minimum`, así que nada lo acota antes.
        let limit = max(1, min(p.limit ?? 20, 50))

        var txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: from, to: to, limit: 5000
        )

        if let cat = p.category {
            let lc = cat.lowercased()
            txs = txs.filter { $0.category.lowercased().contains(lc) }
        }
        if let t = p.type {
            let txType: TxType = t.uppercased() == "INGRESO" ? .ingreso : .gasto
            txs = txs.filter { $0.type == txType }
        }
        if let note = p.noteContains {
            let lc = note.lowercased()
            txs = txs.filter { ($0.note ?? "").lowercased().contains(lc) }
        }
        if let min = p.amountMin {
            txs = txs.filter { ($0.amount as NSDecimalNumber).doubleValue >= min }
        }
        if let max = p.amountMax {
            txs = txs.filter { ($0.amount as NSDecimalNumber).doubleValue <= max }
        }

        let totalAmount = txs.reduce(Decimal.zero) { $0 + $1.amount }
        let display = txs.prefix(limit)

        var lines: [String] = []
        lines.append("Found \(txs.count) transactions. Total: \(fmt(totalAmount)).")
        if txs.count > limit { lines.append("Showing first \(limit):") }
        lines.append("")

        for tx in display {
            let sign = tx.type == .gasto ? "-" : "+"
            let note = tx.note.flatMap { $0.isEmpty ? nil : " (\($0))" } ?? ""
            lines.append("• \(fmtDate(tx.date)): \(sign)\(fmt(tx.amount)) \(tx.category)\(note) [id:\(tx.id.uuidString)]")
        }

        return lines.joined(separator: "\n")
    }

    /// Corrige el año cuando el modelo devuelve una fecha absurda.
    ///
    /// Nace de un caso real: el usuario pegó su resumen del banco con "05/08" y
    /// "06/08" —día y mes, sin año— y el modelo completó con **2024**, el año de
    /// sus datos de entrenamiento. Los trece gastos se cargaron bien… dos años
    /// atrás. No aparecían en el mes, ni en el presupuesto, ni en los reportes,
    /// y el asistente respondió "cargué los 13 gastos" con total naturalidad.
    ///
    /// Decirle la fecha de hoy en el system prompt es necesario, pero no puede
    /// ser la única defensa: un prompt es una sugerencia, no una garantía. Acá
    /// vale la misma regla que con cualquier dato que viene del modelo — se
    /// valida antes de escribirlo en la base.
    ///
    /// La regla respeta lo que el usuario dijo (día y mes) y sólo toca el año:
    /// si la fecha cae fuera de la ventana razonable, se reubica en el año que
    /// la deje más cerca de hoy sin quedar en el futuro. Se devuelve además si
    /// hubo ajuste, para poder decírselo al usuario en vez de corregir en
    /// silencio.
    static func fechaRazonable(_ propuesta: Date?, hoy: Date = Date()) -> (fecha: Date, ajustada: Bool) {
        guard let propuesta else { return (hoy, false) }
        let cal = Calendar.current

        // Ventana aceptable: hasta 13 meses atrás (cubre "el año pasado por esta
        // época") y hasta 1 mes adelante (un gasto programado, un vencimiento).
        let piso = cal.date(byAdding: .month, value: -13, to: hoy) ?? hoy
        let techo = cal.date(byAdding: .month, value: 1, to: hoy) ?? hoy
        if propuesta >= piso && propuesta <= techo { return (propuesta, false) }

        // Fuera de rango: conservamos día y mes, y probamos el año actual; si eso
        // cae en el futuro, el anterior. Es lo que haría cualquiera al leer
        // "05/08" en un resumen de banco.
        var comps = cal.dateComponents([.month, .day, .hour, .minute], from: propuesta)
        comps.year = cal.component(.year, from: hoy)
        guard let esteAño = cal.date(from: comps) else { return (hoy, true) }
        if esteAño <= techo { return (esteAño, true) }
        comps.year = cal.component(.year, from: hoy) - 1
        return (cal.date(from: comps) ?? hoy, true)
    }

    // MARK: - 2. Add Transaction

    func addTransaction(_ p: AddTransactionArgs) async throws -> String {
        let txType: TxType = p.type.uppercased() == "INGRESO" ? .ingreso : .gasto
        let (categoria, categoriaCreada) = await categoriaDelCatalogo(p.category, tipo: txType)
        let (date, añoAjustado) = Self.fechaRazonable(parseDate(p.date))
        let amount = Self.montoDecimal(p.amount)

        let input = try NewTransactionInput.converting(
            householdId: householdId,
            userId: userId,
            accountId: await resolverCuentaPorDefecto(),
            type: txType,
            amountOriginal: amount,
            currency: currency,
            // `currency` YA es la base del hogar: el tool de IA no acepta moneda como argumento,
            // así que acá nunca hay conversión. Va por `converting` igual para que el día que se
            // agregue el argumento herede la regla en vez de reimplementarla.
            baseCurrency: currency,
            rates: [:],
            category: categoria,
            subcategory: p.subcategory,
            note: p.note,
            date: date
        )

        let created = try await TransactionService.shared.insert(input)
        registrarEscritura()
        await AssistantActionLog.shared.registrar(AccionRevertible(
            clase: .alta,
            descripcion: "\(txType == .gasto ? "Gasto" : "Ingreso") de \(paraElUsuario(amount)) en \(categoria)",
            objetivo: created
        ))
        let typeLabel = txType == .gasto ? "expense" : "income"
        var salida = "Transaction created: \(typeLabel) of \(fmt(amount)) in \(categoria) on \(fmtDate(date)). ID: \(created.id.uuidString)."
        if categoriaCreada {
            salida += " NOTE: the category \"\(categoria)\" did not exist and was ADDED to the household catalog. Tell the user."
        }
        if añoAjustado {
            // Que el modelo lo CUENTE. Corregir en silencio es tan malo como
            // guardar mal: el usuario tiene que poder decir "no, ese era del año
            // pasado" y arreglarlo.
            salida += " NOTE: the date you sent (\(p.date ?? "—")) was out of range, so the year was corrected to \(fmtDate(date)). Tell the user explicitly which date you used."
        }
        return salida
    }

    // MARK: - 3. Update Transaction

    func updateTransaction(_ p: UpdateTransactionArgs) async throws -> String {
        var tx = try await resolverTransaccion(p.transactionId)
        let antes = tx

        if let a = p.amount { tx.amount = Self.montoDecimal(a) }
        if let c = p.category { tx.category = c }
        if let s = p.subcategory { tx.subcategory = s }
        if let n = p.note { tx.note = n }
        if let d = p.date, let date = parseDate(d) {
            // Misma validación de año que al crear: una edición también puede
            // venir con el año inventado por el modelo.
            tx.date = Self.fechaRazonable(date, hoy: Date()).fecha
        }
        if let t = p.type { tx.type = t.uppercased() == "INGRESO" ? .ingreso : .gasto }

        _ = try await TransactionService.shared.update(tx)

        // Releer antes de contestar. El resultado tiene que describir **lo que
        // quedó en la base**, no lo que se pidió escribir: si el update no
        // impactó, acá se ve, y el modelo no puede anunciar un cambio
        // inexistente.
        guard let confirmada = try await TransactionService.shared.fetchOne(id: tx.id) else {
            throw AIToolError.escrituraNoVerificable(tx.id.uuidString)
        }
        guard confirmada.amount == tx.amount, confirmada.category == tx.category else {
            throw AIToolError.escrituraNoImpactada(
                pedido: "\(fmt(tx.amount)) en \(tx.category)",
                real: "\(fmt(confirmada.amount)) en \(confirmada.category)"
            )
        }

        var cambios: [String] = []
        if antes.amount != confirmada.amount {
            cambios.append("importe \(fmt(antes.amount)) → \(fmt(confirmada.amount))")
        }
        if antes.category != confirmada.category {
            cambios.append("categoría \(antes.category) → \(confirmada.category)")
        }
        if (antes.note ?? "") != (confirmada.note ?? "") {
            cambios.append("detalle → \(confirmada.note ?? "(vacío)")")
        }
        if antes.date != confirmada.date {
            cambios.append("fecha \(fmtDate(antes.date)) → \(fmtDate(confirmada.date))")
        }
        if antes.type != confirmada.type {
            cambios.append("tipo → \(confirmada.type == .ingreso ? "ingreso" : "gasto")")
        }

        let detalle = cambios.isEmpty
            ? "no cambió ningún campo (los valores enviados ya eran los guardados)"
            : cambios.joined(separator: ", ")
        registrarEscritura()
        await AssistantActionLog.shared.registrar(AccionRevertible(
            clase: .edicion,
            descripcion: "Edición de \(paraElUsuario(antes.amount)) en \(antes.category)",
            objetivo: antes
        ))
        return """
        Verificado en la base — \(detalle).
        Estado actual: \(fmt(confirmada.amount)) en \(confirmada.category) \
        el \(fmtDate(confirmada.date)) [id:\(confirmada.id.uuidString)]
        """
    }

    // MARK: - 4. Delete Transaction

    func deleteTransaction(_ p: DeleteTransactionArgs) async throws -> String {
        let tx = try await resolverTransaccion(p.transactionId)
        try await TransactionService.shared.delete(id: tx.id)

        // Igual que en el update: se verifica que de verdad ya no esté antes de
        // decir que se borró.
        if try await TransactionService.shared.fetchOne(id: tx.id) != nil {
            throw AIToolError.escrituraNoImpactada(
                pedido: "borrar \(fmt(tx.amount)) en \(tx.category)",
                real: "el movimiento sigue existiendo"
            )
        }
        registrarEscritura()
        return "Verificado en la base — borrado: \(fmt(tx.amount)) en \(tx.category) el \(fmtDate(tx.date))."
    }

    // MARK: - 5. Financial Summary

    func getFinancialSummary(_ p: GetFinancialSummaryArgs) async throws -> String {
        let range = monthRange(p.month)
        let totals = try await TransactionService.shared.totals(
            householdId: householdId, from: range.start, to: range.end
        )

        let balance = totals.ingresos - totals.gastos
        let savingsRate: Int = totals.ingresos > 0
            ? Int(((balance / totals.ingresos) as NSDecimalNumber).doubleValue * 100)
            : 0

        var lines: [String] = []
        lines.append("Financial Summary:")
        lines.append("• Income: \(fmt(totals.ingresos))")
        lines.append("• Expenses: \(fmt(totals.gastos))")
        lines.append("• Balance: \(fmt(balance))")
        lines.append("• Savings rate: \(savingsRate)%")

        if p.includeComparison == true {
            let cal = Calendar.current
            let prevStart = cal.date(byAdding: .month, value: -1, to: range.start) ?? range.start
            let prevEnd = cal.date(byAdding: .month, value: -1, to: range.end) ?? range.end
            let prev = try await TransactionService.shared.totals(
                householdId: householdId, from: prevStart, to: prevEnd
            )
            let deltaExp = totals.gastos - prev.gastos
            let deltaInc = totals.ingresos - prev.ingresos
            lines.append("")
            lines.append("vs Previous month:")
            lines.append("• Income change: \(deltaInc >= 0 ? "+" : "")\(fmt(deltaInc))")
            lines.append("• Expense change: \(deltaExp >= 0 ? "+" : "")\(fmt(deltaExp))")
        }

        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: range.start, to: range.end, limit: 5000
        )
        var byCat: [String: Decimal] = [:]
        for tx in txs where tx.type == .gasto {
            byCat[tx.category, default: 0] += tx.amount
        }
        let sorted = byCat.sorted { $0.value > $1.value }
        if !sorted.isEmpty {
            lines.append("")
            lines.append("Top categories:")
            for (i, item) in sorted.prefix(7).enumerated() {
                let pct = totals.gastos > 0
                    ? Int(((item.value / totals.gastos) as NSDecimalNumber).doubleValue * 100)
                    : 0
                lines.append("  \(i+1). \(item.key): \(fmt(item.value)) (\(pct)%)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 6. Budget Status

    func getBudgetStatus(_ p: GetBudgetStatusArgs) async throws -> String {
        let range = monthRange(p.month)
        guard let period = try await BudgetService.shared.fetchPeriod(
            householdId: householdId, containing: range.start
        ) else {
            return "No budget period found for this month. Create one in the Budget tab."
        }

        let allocs = try await BudgetService.shared.fetchAllocations(periodId: period.id)
        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: range.start, to: range.end, limit: 5000
        )

        var spent: [String: Decimal] = [:]
        for tx in txs.excludingTransfers where tx.type == .gasto {
            spent[tx.category, default: 0] += tx.amount
        }

        // El resumen sale del RPC, no de las columnas: el asistente le dice el número al usuario
        // EN TEXTO, con confianza y sin que se pueda contrastar contra la pantalla de al lado.
        // Era uno de los cuatro lectores de "listo para asignar" con criterios distintos.
        let resumen = try? await BudgetService.shared.periodSummary(periodId: period.id)

        var lines: [String] = ["Budget Status:"]
        lines.append("Total allocated: \(fmt(resumen?.totalAllocated ?? period.totalAllocated))")
        lines.append("Ready to assign: \(fmt(resumen?.readyToAssign ?? period.readyToAssign))")
        if let n = resumen?.fxMissingCount, n > 0 {
            // Sin esto el asistente afirmaría un total exacto sobre datos incompletos.
            lines.append("Note: \(n) envelope(s) in a currency with no exchange rate are NOT included.")
        }
        lines.append("")

        var overBudget: [String] = []
        var nearLimit: [String] = []

        for alloc in allocs.sorted(by: { $0.allocated > $1.allocated }) where alloc.allocated > 0 {
            let s = spent[alloc.category] ?? 0
            let remaining = alloc.allocated - s
            let pct = ((s / alloc.allocated) as NSDecimalNumber).doubleValue * 100
            let status: String
            if pct >= 100 {
                status = "OVER"
                overBudget.append(alloc.category)
            } else if pct >= 80 {
                status = "WARNING"
                nearLimit.append(alloc.category)
            } else {
                status = "OK"
            }
            lines.append("• \(alloc.category): \(fmt(s))/\(fmt(alloc.allocated)) (\(Int(pct))%) [\(status)] remaining: \(fmt(remaining))")
        }

        if !overBudget.isEmpty {
            lines.append("\nOver budget: \(overBudget.joined(separator: ", "))")
        }
        if !nearLimit.isEmpty {
            lines.append("Near limit (80%+): \(nearLimit.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 7. Net Worth

    func getNetWorth() async throws -> String {
        let accounts = try await AccountService.shared.fetchAll(householdId: householdId, includingInactive: false)
        let debts = try await DebtService.shared.fetchAll(householdId: householdId, includeSettled: false)

        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .year, value: -1, to: now) ?? now
        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: start, to: now, limit: 10000
        )

        var lines: [String] = ["Net Worth Breakdown:"]
        var totalAssets: Decimal = 0
        var totalLiabilities: Decimal = 0

        lines.append("\nAssets:")
        for acc in accounts where acc.type != .creditCard && acc.type != .loan {
            let bal = AccountBalanceService.currentBalance(
                account: acc, transactions: txs, baseCurrency: currency
            )
            totalAssets += bal
            lines.append("  • \(acc.name) (\(acc.type.rawValue)): \(fmt(bal, cur: acc.currency))")
        }

        lines.append("\nLiabilities:")
        for acc in accounts where acc.type == .creditCard || acc.type == .loan {
            let bal = AccountBalanceService.currentBalance(
                account: acc, transactions: txs, baseCurrency: currency
            )
            let owed = abs(bal)
            totalLiabilities += owed
            lines.append("  • \(acc.name): \(fmt(owed, cur: acc.currency))")
        }
        for debt in debts {
            totalLiabilities += debt.currentBalance
            lines.append("  • \(debt.creditor) (debt): \(fmt(debt.currentBalance, cur: debt.currency))")
        }

        let netWorth = totalAssets - totalLiabilities
        lines.append("\nTotal Assets: \(fmt(totalAssets))")
        lines.append("Total Liabilities: \(fmt(totalLiabilities))")
        lines.append("Net Worth: \(fmt(netWorth))")

        return lines.joined(separator: "\n")
    }

    // MARK: - 8. Health Score

    func getHealthScore() async throws -> String {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps)!
        let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart)!

        let totals = try await TransactionService.shared.totals(
            householdId: householdId, from: monthStart, to: monthEnd
        )
        let goals = try await GoalService.shared.fetchAll(householdId: householdId, includeCompleted: false)
        let debts = try await DebtService.shared.fetchAll(householdId: householdId, includeSettled: false)
        let accounts = try await AccountService.shared.fetchAll(householdId: householdId, includingInactive: false)

        let balance = totals.ingresos - totals.gastos
        let savingsRate: Double = totals.ingresos > 0
            ? ((balance / totals.ingresos) as NSDecimalNumber).doubleValue
            : 0

        let monthlyDebt = debts.reduce(Decimal.zero) { $0 + ($1.currentBalance / 24) }
        let debtRatio: Double = totals.ingresos > 0
            ? ((monthlyDebt / totals.ingresos) as NSDecimalNumber).doubleValue
            : 0

        let liquid = accounts
            .filter { $0.type != .creditCard && $0.type != .loan }
            .reduce(Decimal.zero) { $0 + $1.startingBalance }
        let monthsOfRunway: Double = totals.gastos > 0
            ? ((liquid / totals.gastos) as NSDecimalNumber).doubleValue
            : 0

        let avgGoalProgress: Double = goals.isEmpty ? 0 :
            goals.reduce(0.0) { $0 + $1.progress } / Double(goals.count)

        // Score components (each 0-20, total 0-100)
        let savingsScore = min(20, Int(savingsRate * 100))
        let debtScore = max(0, 20 - Int(debtRatio * 50))
        let emergencyScore = min(20, Int(monthsOfRunway / 6.0 * 20))
        let goalScore = Int(avgGoalProgress * 20)
        let budgetScore: Int
        if let period = try? await BudgetService.shared.fetchPeriod(householdId: householdId, containing: now) {
            let allocs = (try? await BudgetService.shared.fetchAllocations(periodId: period.id)) ?? []
            budgetScore = allocs.isEmpty ? 5 : 15
        } else {
            budgetScore = 0
        }

        let total = savingsScore + debtScore + emergencyScore + goalScore + budgetScore

        var lines: [String] = ["Financial Health Score: \(total)/100"]
        lines.append("")
        lines.append("Breakdown:")
        lines.append("  • Savings rate (\(Int(savingsRate * 100))%): \(savingsScore)/20")
        lines.append("  • Debt load (\(Int(debtRatio * 100))%): \(debtScore)/20")
        lines.append("  • Emergency fund (\(String(format: "%.1f", monthsOfRunway)) months): \(emergencyScore)/20")
        lines.append("  • Goal progress (\(Int(avgGoalProgress * 100))%): \(goalScore)/20")
        lines.append("  • Budget setup: \(budgetScore)/20")

        let grade: String
        switch total {
        case 80...: grade = "Excellent"
        case 60..<80: grade = "Good"
        case 40..<60: grade = "Needs improvement"
        default: grade = "Critical - take action"
        }
        lines.append("\nGrade: \(grade)")

        return lines.joined(separator: "\n")
    }

    // MARK: - 9. Project Scenario

    func projectScenario(_ p: ProjectScenarioArgs) async throws -> String {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let monthStart = cal.date(from: comps)!
        let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart)!
        let months = p.months ?? 3

        let totals = try await TransactionService.shared.totals(
            householdId: householdId, from: monthStart, to: monthEnd
        )

        var projectedIncome = totals.ingresos
        var projectedExpenses = totals.gastos

        if let cat = p.category, let pct = p.percentChange {
            let txs = try await TransactionService.shared.fetchForPeriod(
                householdId: householdId, from: monthStart, to: monthEnd, limit: 5000
            )
            let catSpend = txs.filter { $0.type == .gasto && $0.category.lowercased() == cat.lowercased() }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let change = catSpend * Decimal(pct / 100.0)
            projectedExpenses += change
        } else if let fixed = p.fixedAmountChange {
            let fixedDec = Decimal(fixed)
            if fixedDec > 0 {
                projectedIncome += fixedDec
            } else {
                projectedExpenses += abs(fixedDec)
            }
        }

        let currentBalance = totals.ingresos - totals.gastos
        let projectedBalance = projectedIncome - projectedExpenses
        let monthlySavingsDelta = projectedBalance - currentBalance

        var lines: [String] = ["Scenario: \(p.scenario)"]
        lines.append("")
        lines.append("Current monthly:")
        lines.append("  Income: \(fmt(totals.ingresos)), Expenses: \(fmt(totals.gastos)), Balance: \(fmt(currentBalance))")
        lines.append("")
        lines.append("Projected monthly:")
        lines.append("  Income: \(fmt(projectedIncome)), Expenses: \(fmt(projectedExpenses)), Balance: \(fmt(projectedBalance))")
        lines.append("")
        lines.append("Monthly impact: \(monthlySavingsDelta >= 0 ? "+" : "")\(fmt(monthlySavingsDelta))")
        lines.append("\(months)-month cumulative impact: \(monthlySavingsDelta >= 0 ? "+" : "")\(fmt(monthlySavingsDelta * Decimal(months)))")

        return lines.joined(separator: "\n")
    }

    // MARK: - 10. Spending Patterns

    func detectSpendingPatterns(_ p: DetectSpendingPatternsArgs) async throws -> String {
        let monthsBack = min(p.monthsBack ?? 3, 12)
        let cal = Calendar.current
        let now = Date()
        let start = cal.date(byAdding: .month, value: -monthsBack, to: now) ?? now

        var txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: start, to: now, limit: 10000
        )
        txs = txs.filter { $0.type == .gasto }

        if let cat = p.category {
            let lc = cat.lowercased()
            txs = txs.filter { $0.category.lowercased().contains(lc) }
        }

        guard !txs.isEmpty else {
            return "No expense data found for the past \(monthsBack) months."
        }

        // Monthly totals
        var monthlyTotals: [String: Decimal] = [:]
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "yyyy-MM"
        for tx in txs {
            let key = monthFmt.string(from: tx.date)
            monthlyTotals[key, default: 0] += tx.amount
        }

        // Day-of-week distribution
        var dayOfWeek: [Int: Decimal] = [:]
        for tx in txs {
            let dow = cal.component(.weekday, from: tx.date)
            dayOfWeek[dow, default: 0] += tx.amount
        }
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Category breakdown
        var byCat: [String: Decimal] = [:]
        for tx in txs { byCat[tx.category, default: 0] += tx.amount }

        var lines: [String] = ["Spending Patterns (\(monthsBack) months):"]

        lines.append("\nMonthly trend:")
        for key in monthlyTotals.keys.sorted() {
            lines.append("  \(key): \(fmt(monthlyTotals[key]!))")
        }

        let sortedMonths = monthlyTotals.keys.sorted()
        if sortedMonths.count >= 2 {
            let first = monthlyTotals[sortedMonths.first!]!
            let last = monthlyTotals[sortedMonths.last!]!
            if first > 0 {
                let growthPct = ((last - first) / first) as NSDecimalNumber
                lines.append("  Trend: \(Int(growthPct.doubleValue * 100))% change from first to last month")
            }
        }

        lines.append("\nBy day of week:")
        for dow in 1...7 {
            let total = dayOfWeek[dow] ?? 0
            lines.append("  \(dayNames[dow]): \(fmt(total))")
        }

        if p.category == nil {
            lines.append("\nTop categories:")
            for (i, item) in byCat.sorted(by: { $0.value > $1.value }).prefix(5).enumerated() {
                lines.append("  \(i+1). \(item.key): \(fmt(item.value))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 11. Savings Opportunities

    func suggestSavings(_ p: SuggestSavingsArgs) async throws -> String {
        let cal = Calendar.current
        let now = Date()
        let threeMonthsAgo = cal.date(byAdding: .month, value: -3, to: now) ?? now

        let txs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: threeMonthsAgo, to: now, limit: 10000
        )
        let expenses = txs.filter { $0.type == .gasto }

        var byCat: [String: [Decimal]] = [:]
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "yyyy-MM"
        for tx in expenses {
            let key = "\(tx.category)|\(monthFmt.string(from: tx.date))"
            byCat[tx.category, default: []].append(tx.amount)
        }

        var catAvg: [(String, Decimal)] = []
        for (cat, amounts) in byCat {
            let avg = amounts.reduce(Decimal.zero, +) / 3
            catAvg.append((cat, avg))
        }
        catAvg.sort { $0.1 > $1.1 }

        var lines: [String] = ["Savings Opportunities (based on 3-month average):"]
        lines.append("")

        let targetStr = p.targetSavings.map { fmt(Decimal($0)) } ?? "unspecified"
        lines.append("Target savings: \(targetStr)")
        lines.append("")

        var potentialSavings: Decimal = 0
        let discretionary = Set(["Ocio", "Restaurantes", "Compras", "Suscripciones", "Delivery", "Entretenimiento"])

        for (cat, avg) in catAvg where avg > 0 {
            let suggestion: Decimal
            if discretionary.contains(cat) {
                suggestion = avg * 20 / 100
                lines.append("• \(cat) (avg \(fmt(avg))/mo): reduce 20% → save \(fmt(suggestion))/mo")
            } else {
                suggestion = avg * 10 / 100
                lines.append("• \(cat) (avg \(fmt(avg))/mo): optimize 10% → save \(fmt(suggestion))/mo")
            }
            potentialSavings += suggestion
        }

        lines.append("")
        lines.append("Total potential monthly savings: \(fmt(potentialSavings))")

        if let target = p.targetSavings {
            let targetDec = Decimal(target)
            if potentialSavings >= targetDec {
                lines.append("This exceeds your target of \(fmt(targetDec)).")
            } else {
                lines.append("Gap to target: \(fmt(targetDec - potentialSavings)) — consider additional income sources.")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 12. Goals

    func getGoals(_ p: GetGoalsArgs) async throws -> String {
        let goals = try await GoalService.shared.fetchAll(
            householdId: householdId, includeCompleted: p.includeCompleted ?? false
        )

        guard !goals.isEmpty else {
            return "No active goals. Create one in More > Goals > + button."
        }

        var lines: [String] = ["Goals (\(goals.count)):"]
        for g in goals {
            let pct = Int(g.progress * 100)
            let remaining = max(0, g.targetAmount - g.currentAmount)
            var line = "• \(g.name): \(fmt(g.currentAmount, cur: g.currency))/\(fmt(g.targetAmount, cur: g.currency)) (\(pct)%)"

            if let target = g.targetDate {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: target).day ?? 0
                line += " — \(daysLeft) days left"
                if remaining > 0 && daysLeft > 0 {
                    let monthsLeft = max(1, daysLeft / 30)
                    let monthlyNeeded = remaining / Decimal(monthsLeft)
                    line += ", need \(fmt(monthlyNeeded, cur: g.currency))/mo"
                }
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 13. Accounts

    func getAccounts(_ p: GetAccountsArgs) async throws -> String {
        let accounts = try await AccountService.shared.fetchAll(
            householdId: householdId, includingInactive: p.includeInactive ?? false
        )

        guard !accounts.isEmpty else {
            return "No accounts found. Add one in More > Accounts."
        }

        var lines: [String] = ["Accounts (\(accounts.count)):"]
        for acc in accounts {
            let status = acc.isActive ? "" : " [inactive]"
            let inst = acc.institution.flatMap { $0.isEmpty ? nil : " (\($0))" } ?? ""
            lines.append("• \(acc.name)\(inst): \(acc.type.rawValue) · \(fmt(acc.startingBalance, cur: acc.currency))\(status)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 14. Bills

    func getBills(_ p: GetBillsArgs) async throws -> String {
        let days = p.daysAhead ?? 30
        let bills = try await BillService.shared.fetchUpcoming(householdId: householdId, daysAhead: days)

        guard !bills.isEmpty else {
            return "No upcoming bills in the next \(days) days."
        }

        var lines: [String] = ["Upcoming Bills (\(bills.count)):"]
        for bill in bills {
            let urgency: String
            switch bill.urgency {
            case .overdue: urgency = "OVERDUE"
            case .dueToday: urgency = "DUE TODAY"
            case .dueSoon: urgency = "Due soon"
            default: urgency = "\(bill.daysUntilDue)d"
            }
            lines.append("• \(bill.title): \(fmt(bill.amount, cur: bill.currency)) — \(fmtDate(bill.dueDate)) [\(urgency)]")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 15. Inflation Impact

    func analyzeInflation(_ p: AnalyzeInflationArgs) async throws -> String {
        let monthsBack = p.monthsBack ?? 3
        let cal = Calendar.current
        let now = Date()

        let recentStart = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let oldStart = cal.date(byAdding: .month, value: -(monthsBack + 1), to: now) ?? now
        let oldEnd = cal.date(byAdding: .month, value: -monthsBack, to: now) ?? now

        let recentTxs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: recentStart, to: now, limit: 5000
        )
        let oldTxs = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId, from: oldStart, to: oldEnd, limit: 5000
        )

        let recentExp = recentTxs.filter { $0.type == .gasto }
        let oldExp = oldTxs.filter { $0.type == .gasto }

        func aggregate(_ txs: [Transaction]) -> [String: (total: Decimal, count: Int)] {
            var result: [String: (total: Decimal, count: Int)] = [:]
            for tx in txs {
                let cat = p.category.flatMap { tx.category.lowercased().contains($0.lowercased()) ? tx.category : nil } ?? tx.category
                if p.category != nil && cat != tx.category { continue }
                let existing = result[tx.category] ?? (0, 0)
                result[tx.category] = (existing.total + tx.amount, existing.count + 1)
            }
            return result
        }

        let recent = aggregate(recentExp)
        let old = aggregate(oldExp)

        var lines: [String] = ["Inflation & Price Impact Analysis (\(monthsBack) months ago vs now):"]
        lines.append("")

        let recentTotal = recentExp.reduce(Decimal.zero) { $0 + $1.amount }
        let oldTotal = oldExp.reduce(Decimal.zero) { $0 + $1.amount }

        if oldTotal > 0 {
            let totalChange = ((recentTotal - oldTotal) / oldTotal) as NSDecimalNumber
            lines.append("Overall spending change (nominal): \(Int(totalChange.doubleValue * 100))%")
        }

        // ─── LO QUE DE VERDAD IMPORTA EN ARGENTINA ─────────────────────────
        // El cambio nominal miente: con 33,5% interanual, "gastaste 20% más"
        // puede ser gastaste 10% MENOS en términos reales. Se reexpresa el
        // período viejo a pesos de hoy con el CER oficial y se compara ahí.
        let cer = await CERService.shared.snapshot()
        let indiceCER: (Date) -> Decimal? = { cer.valor($0) }
        let mitadVieja = oldStart.addingTimeInterval(oldEnd.timeIntervalSince(oldStart) / 2)
        if oldTotal > 0,
           let viejoEnPesosDeHoy = Reexpresion.llevar(oldTotal, desde: mitadVieja, hasta: now, indice: indiceCER),
           viejoEnPesosDeHoy > 0,
           let real = Reexpresion.variacionReal(
               anterior: oldTotal, fechaAnterior: mitadVieja,
               actual: recentTotal, fechaActual: now, indice: indiceCER) {
            let pct = Int(((real as NSDecimalNumber).doubleValue * 100).rounded())
            lines.append("Same period expressed in TODAY's pesos (official CER index): \(fmt(viejoEnPesosDeHoy))")
            lines.append("REAL change (inflation removed): \(pct > 0 ? "+" : "")\(pct)%")
            lines.append(pct < 0
                ? "So in real terms the user is spending LESS than before — say this explicitly, it is the headline."
                : "So the increase is real: it is above inflation, not just prices going up.")
        } else {
            lines.append("(Could not express in today's pesos: no CER data for that date range.)")
        }
        lines.append("")

        for (cat, r) in recent.sorted(by: { $0.value.total > $1.value.total }) {
            guard let o = old[cat], o.total > 0 else { continue }
            let totalChange = ((r.total - o.total) / o.total) as NSDecimalNumber
            let avgRecent: Decimal = r.count > 0 ? r.total / Decimal(r.count) : 0
            let avgOld: Decimal = o.count > 0 ? o.total / Decimal(o.count) : 0

            var line = "• \(cat): \(Int(totalChange.doubleValue * 100))% change"

            if avgOld > 0 {
                let priceChange = ((avgRecent - avgOld) / avgOld) as NSDecimalNumber
                let qtyChange = r.count - o.count
                line += " (avg price \(Int(priceChange.doubleValue * 100))%"
                if qtyChange != 0 {
                    line += ", qty \(qtyChange > 0 ? "+" : "")\(qtyChange)"
                }
                line += ")"
            }
            lines.append(line)
        }

        lines.append("")
        lines.append("Note: the REAL change uses the BCRA's official CER index. The per-category numbers are nominal, and price changes are approximated from average transaction amounts.")

        return lines.joined(separator: "\n")
    }

    // MARK: - 16. Mark Bill Paid

    func markBillPaid(_ p: MarkBillPaidArgs) async throws -> String {
        guard let uuid = UUID(uuidString: p.billId) else {
            return "Error: billId no es un UUID válido"
        }
        do {
            try await BillService.shared.markPaid(id: uuid)
            registrarEscritura()
            return "✅ Factura marcada como pagada."
        } catch {
            return "Error al marcar la factura: \(error.localizedDescription)"
        }
    }

    // MARK: - 17. Compare Periods

    func comparePeriods(_ p: ComparePeriodsArgs) async throws -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        guard let dateA = fmt.date(from: p.periodA),
              let dateB = fmt.date(from: p.periodB) else {
            return "Error: períodos deben estar en formato yyyy-MM (ej: 2026-04)"
        }

        func rangeFor(_ d: Date) -> (Date, Date) {
            let comps = cal.dateComponents([.year, .month], from: d)
            let start = cal.date(from: comps) ?? d
            let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? d
            return (start, end)
        }

        let (startA, endA) = rangeFor(dateA)
        let (startB, endB) = rangeFor(dateB)

        async let totalsA = TransactionService.shared.totals(householdId: householdId, from: startA, to: endA)
        async let totalsB = TransactionService.shared.totals(householdId: householdId, from: startB, to: endB)
        async let txA = TransactionService.shared.fetchForPeriod(householdId: householdId, from: startA, to: endA, limit: 5000)
        async let txB = TransactionService.shared.fetchForPeriod(householdId: householdId, from: startB, to: endB, limit: 5000)

        let (tA, tB) = try await (totalsA, totalsB)
        let (allA, allB) = try await (txA, txB)

        // Compute top categories inline (no dedicated service method exists).
        func topCategories(_ txs: [Transaction]) -> [(category: String, total: Decimal)] {
            var sums: [String: Decimal] = [:]
            for t in txs where t.type == .gasto {
                sums[t.category, default: 0] += t.amount
            }
            return sums.map { ($0.key, $0.value) }
                .sorted { $0.1 > $1.1 }
                .prefix(5)
                .map { ($0.0, $0.1) }
        }
        let catsA = topCategories(allA)
        let catsB = topCategories(allB)

        let balA = tA.ingresos - tA.gastos
        let balB = tB.ingresos - tB.gastos
        let svgRateA: Int = tA.ingresos > 0 ? Int(((balA / tA.ingresos) as NSDecimalNumber).doubleValue * 100) : 0
        let svgRateB: Int = tB.ingresos > 0 ? Int(((balB / tB.ingresos) as NSDecimalNumber).doubleValue * 100) : 0

        let deltaIng = tA.ingresos - tB.ingresos
        let deltaGas = tA.gastos - tB.gastos
        let deltaBal = balA - balB

        func fmtAmount(_ d: Decimal) -> String {
            Money.format(d, currency: currency, style: .compact)
        }
        func fmtDelta(_ d: Decimal) -> String {
            let sign = d >= 0 ? "+" : ""
            return "\(sign)\(fmtAmount(d))"
        }

        var lines: [String] = []
        lines.append("\(p.periodA) vs \(p.periodB) (\(currency)):")
        lines.append("• Ingresos: \(fmtAmount(tA.ingresos)) vs \(fmtAmount(tB.ingresos)) — Δ \(fmtDelta(deltaIng))")
        lines.append("• Gastos: \(fmtAmount(tA.gastos)) vs \(fmtAmount(tB.gastos)) — Δ \(fmtDelta(deltaGas))")
        lines.append("• Balance: \(fmtAmount(balA)) vs \(fmtAmount(balB)) — Δ \(fmtDelta(deltaBal))")
        lines.append("• Savings rate: \(svgRateA)% vs \(svgRateB)%")

        if !catsA.isEmpty {
            lines.append("")
            lines.append("Top categorías \(p.periodA):")
            for (i, c) in catsA.prefix(5).enumerated() {
                lines.append("  \(i+1). \(c.category): \(fmtAmount(c.total))")
            }
        }
        if !catsB.isEmpty {
            lines.append("")
            lines.append("Top categorías \(p.periodB):")
            for (i, c) in catsB.prefix(5).enumerated() {
                lines.append("  \(i+1). \(c.category): \(fmtAmount(c.total))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 18. Set Budget Envelope

    func setBudgetEnvelope(_ p: SetBudgetEnvelopeArgs) async throws -> String {
        guard p.amount >= 0 else {
            return "Error: el monto debe ser >= 0"
        }
        let cal = Calendar.current
        let date: Date = {
            if let m = p.month {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM"
                fmt.locale = Locale(identifier: "en_US_POSIX")
                return fmt.date(from: m) ?? Date()
            }
            return Date()
        }()
        do {
            let period = try await BudgetService.shared.ensurePeriodForMonth(
                householdId: householdId, containing: date
            )
            _ = try await BudgetService.shared.upsertAllocation(
                periodId: period.id,
                category: p.category,
                subcategory: p.subcategory ?? "",
                allocated: Self.montoDecimal(p.amount),
                currency: currency
            )
            let formatted = Money.format(Self.montoDecimal(p.amount), currency: currency, style: .compact)
            let sub = (p.subcategory?.isEmpty == false) ? " > \(p.subcategory!)" : ""
            let monthFmt = DateFormatter()
            monthFmt.dateFormat = "yyyy-MM"
            monthFmt.locale = Locale(identifier: "en_US_POSIX")
            let periodLabel = monthFmt.string(from: period.periodStart)
            registrarEscritura()
            return "✅ Presupuesto seteado: \(p.category)\(sub) = \(formatted) para \(periodLabel)."
        } catch {
            return "Error al setear presupuesto: \(error.localizedDescription)"
        }
        _ = cal
    }

    // MARK: - 19. Transfer Between Accounts

    func transferBetweenAccounts(_ p: TransferBetweenAccountsArgs) async throws -> String {
        guard p.amount > 0 else {
            return "Error: el monto debe ser mayor a cero"
        }
        guard let fromId = UUID(uuidString: p.fromAccountId),
              let toId = UUID(uuidString: p.toAccountId) else {
            return "Error: account IDs deben ser UUIDs validos"
        }
        guard fromId != toId else {
            return "Error: la cuenta origen y destino no pueden ser la misma"
        }
        let amount = Self.montoDecimal(p.amount)
        let now = Date()
        let baseNote = p.note?.isEmpty == false ? p.note! : "Transferencia entre cuentas"

        // Una sola RPC atómica en vez de dos inserts sueltos.
        //
        // Antes esto hacía `insert(expense)` y después `insert(income)`: dos requests HTTP
        // independientes. Si el segundo fallaba quedaba un GASTO huérfano que le comía plata al
        // usuario sin contrapartida — y el mensaje de error lo admitía, pidiéndole que lo
        // arreglara a mano desde Movimientos.
        //
        // `create_transfer` inserta las dos piernas en un solo statement: o entran las dos o no
        // entra ninguna. Además las vincula con `transfer_group_id`, que es lo que permite que los
        // agregados las excluyan (mover plata entre cuentas propias no es ingreso ni gasto) y que
        // se puedan borrar juntas.
        struct TransferParams: Encodable {
            let p_household: UUID
            let p_from_account: UUID
            let p_to_account: UUID
            let p_amount: Decimal
            let p_date: Date
            let p_note: String
        }
        do {
            let _: UUID = try await SupabaseRPC.call(
                "create_transfer",
                params: TransferParams(
                    p_household: householdId,
                    p_from_account: fromId,
                    p_to_account: toId,
                    p_amount: amount,
                    p_date: now,
                    p_note: baseNote
                )
            )
            let formatted = Money.format(amount, currency: currency, style: .compact)
            registrarEscritura()
            return "✅ Transferencia ejecutada: \(formatted) movido entre cuentas."
        } catch {
            // Sin "puede que haya quedado a medias": la RPC es atómica, si falló no entró nada.
            return "Error en la transferencia: \(error.localizedDescription). No se creó ningún movimiento."
        }
    }

    // MARK: - 20. Categorize Transaction

    func categorizeTransaction(_ p: CategorizeTransactionArgs) async throws -> String {
        let text = p.text.lowercased()
        guard !text.isEmpty else {
            return "Error: necesito un texto descriptivo para categorizar"
        }

        // Heuristica determinista basada en keywords LATAM-friendly.
        // No requiere red — es rapida y no consume tokens del LLM.
        let patterns: [(category: String, keywords: [String], confidence: Double)] = [
            ("Alimentacion", ["super", "mercado", "verduleria", "carniceria", "panaderia", "almacen", "coto", "carrefour", "dia", "jumbo", "disco"], 0.92),
            ("Restaurantes", ["restaurante", "bar", "cafe", "rappi", "pedidos ya", "uber eats", "delivery", "pizza", "sushi"], 0.90),
            ("Transporte", ["uber", "cabify", "didi", "taxi", "subte", "colectivo", "tren", "ypf", "axion", "shell", "nafta", "combustible", "estacionamiento", "peaje"], 0.92),
            ("Servicios", ["luz", "edenor", "edesur", "metrogas", "gas", "agua", "aysa", "internet", "fibertel", "telecentro", "movistar", "claro", "personal", "telecom"], 0.94),
            ("Streaming", ["netflix", "spotify", "disney", "hbo", "amazon prime", "apple music", "youtube premium"], 0.95),
            ("Salud", ["farmacia", "farmacity", "doctor", "clinica", "hospital", "obra social", "osde", "swiss medical"], 0.92),
            ("Entretenimiento", ["cine", "teatro", "concierto", "show", "boleto"], 0.85),
            ("Hogar", ["sodimac", "easy", "ikea", "ferreteria", "mueble", "limpieza"], 0.85),
            ("Educacion", ["universidad", "curso", "udemy", "coursera", "libreria", "libro"], 0.88),
            ("Ropa", ["zara", "h&m", "indumentaria", "ropa", "calzado"], 0.85),
            ("Sueldo", ["sueldo", "salario", "haberes", "pago mensual"], 0.96),
            ("Freelance", ["freelance", "honorarios", "factura"], 0.85),
        ]

        var best: (String, Double) = ("Otro", 0.3)
        for p in patterns {
            for kw in p.keywords {
                if text.contains(kw) && p.confidence > best.1 {
                    best = (p.category, p.confidence)
                }
            }
        }

        return "Sugerencia: \(best.0) (confianza \(String(format: "%.0f", best.1 * 100))%). Si no es correcto, indicame la categoria correcta."
    }

    // MARK: - 21. Validate CFDI (Mexico)

    func validateCFDI(_ p: ValidateCFDIArgs) async throws -> String {
        let input = p.qrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            return "Error: pasame el QR text o la URL de verificacion del CFDI"
        }

        // Pattern: UUID = 8-4-4-4-12 hex (32 hex digits con dashes).
        let uuidPattern = #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#
        // RFC SAT MX: 3-4 chars iniciales + 6 digits fecha + 3 homoclave (=12-13 chars).
        let rfcPattern = #"[A-Z&Ñ]{3,4}[0-9]{6}[0-9A-Z]{3}"#

        var uuid: String?
        var rfcEmisor: String?
        var rfcReceptor: String?
        var total: String?

        // Caso 1: URL completa con query params.
        if input.contains("verificacfdi") || input.contains("?id=") || input.contains("&re=") {
            if let url = URL(string: input),
               let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                for q in comps.queryItems ?? [] {
                    switch q.name.lowercased() {
                    case "id": uuid = q.value
                    case "re": rfcEmisor = q.value
                    case "rr": rfcReceptor = q.value
                    case "tt": total = q.value
                    default: break
                    }
                }
            }
        }
        // Caso 2: QR text plano con "?re=...&rr=..." pero sin schema.
        if uuid == nil, let urlLike = input.range(of: "id=") {
            let after = input[urlLike.upperBound...]
            let parts = after.split(separator: "&")
            for part in parts {
                let kv = part.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { continue }
                let val = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                switch String(kv[0]).lowercased() {
                case "id": uuid = val
                case "re": rfcEmisor = val
                case "rr": rfcReceptor = val
                case "tt": total = val
                default: break
                }
            }
        }
        // Caso 3: solo UUID pelado.
        if uuid == nil,
           let m = input.range(of: uuidPattern, options: .regularExpression) {
            uuid = String(input[m])
        }

        guard let extractedUUID = uuid else {
            return "No detecte un UUID de CFDI valido en el input. Formato esperado: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (32 hex). El QR de una factura mexicana tiene typicamente una URL de verificacfdi.facturaelectronica.sat.gob.mx con parametros id, re, rr, tt."
        }

        // Validar formato UUID estricto.
        let uuidValid = extractedUUID.range(of: "^" + uuidPattern + "$", options: .regularExpression) != nil

        // Validar formato RFCs si los tenemos.
        var rfcEmisorValid: Bool? = nil
        if let r = rfcEmisor?.uppercased() {
            rfcEmisorValid = r.range(of: "^" + rfcPattern + "$", options: .regularExpression) != nil
            rfcEmisor = r
        }
        var rfcReceptorValid: Bool? = nil
        if let r = rfcReceptor?.uppercased() {
            rfcReceptorValid = r.range(of: "^" + rfcPattern + "$", options: .regularExpression) != nil
            rfcReceptor = r
        }

        var lines: [String] = []
        lines.append("📄 CFDI 4.0 — datos extraidos:")
        lines.append("• UUID: \(extractedUUID) \(uuidValid ? "✓" : "⚠️ formato no valido")")
        if let r = rfcEmisor {
            lines.append("• RFC Emisor: \(r) \((rfcEmisorValid ?? false) ? "✓" : "⚠️")")
        }
        if let r = rfcReceptor {
            lines.append("• RFC Receptor: \(r) \((rfcReceptorValid ?? false) ? "✓" : "⚠️")")
        }
        if let t = total {
            lines.append("• Total: $\(t) MXN")
        }

        // Si tenemos los 4 campos, ofrecemos URL de verificacion oficial.
        if let r = rfcEmisor, let rr = rfcReceptor, let t = total, uuidValid {
            let verifyURL = "https://verificacfdi.facturaelectronica.sat.gob.mx/default.aspx?id=\(extractedUUID)&re=\(r)&rr=\(rr)&tt=\(t)"
            lines.append("")
            lines.append("Para verificar estado vigente/cancelado contra SAT, abrime:")
            lines.append(verifyURL)
        } else {
            lines.append("")
            lines.append("Faltan datos (RFC emisor, RFC receptor o total) para armar la URL de verificacion oficial.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 22. Validate ARCA (Argentina)

    func validateARCA(_ p: ValidateARCAArgs) async throws -> String {
        let cae = p.cae.trimmingCharacters(in: .whitespaces)

        // El CAE de ARCA es un numero de 14 digitos (sin dashes ni espacios).
        let caePattern = "^[0-9]{14}$"
        let caeFormatValid = cae.range(of: caePattern, options: .regularExpression) != nil

        var lines: [String] = []
        lines.append("🇦🇷 ARCA — analisis de comprobante electronico:")
        lines.append("• CAE: \(cae) \(caeFormatValid ? "✓ formato valido (14 digitos)" : "⚠️ formato invalido — el CAE son 14 digitos sin dashes")")

        // Verificar fecha de vencimiento embebida en CAE — los primeros 8 chars
        // de un CAE codifican typicamente YYYYMMDD pero esto varia. Lo dejamos
        // como informativo.
        if caeFormatValid {
            let prefix = String(cae.prefix(8))
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            if let date = fmt.date(from: prefix) {
                let outFmt = DateFormatter()
                outFmt.dateStyle = .medium
                outFmt.locale = Locale(identifier: "es_AR")
                lines.append("• Posible fecha asociada al CAE: \(outFmt.string(from: date))")
            }
        }

        if let comprobante = p.comprobante {
            // Formato esperado: XXXX-XXXXXXXX (punto de venta - numero).
            let comprobantePattern = #"^[0-9]{4,5}-[0-9]{1,8}$"#
            let comprobanteValid = comprobante.range(of: comprobantePattern, options: .regularExpression) != nil
            lines.append("• Comprobante: \(comprobante) \(comprobanteValid ? "✓" : "⚠️ formato esperado: 0001-00000123")")
            if comprobanteValid {
                let parts = comprobante.split(separator: "-")
                if parts.count == 2 {
                    lines.append("  Punto de venta: \(parts[0])")
                    lines.append("  Numero: \(parts[1])")
                }
            }
        }

        if let total = p.total {
            let formatted = Money.format(Decimal(total), currency: "ARS", style: .compact)
            lines.append("• Total declarado: \(formatted)")
        }

        lines.append("")
        if caeFormatValid {
            lines.append("✅ Formato del CAE valido. La verificacion contra los Web Services de ARCA (WSFEv1/WSFEX) requiere tu Clave Fiscal + certificado digital. Para activarlo en Home Finance, andate a Ajustes → Integraciones fiscales (proximamente).")
        } else {
            lines.append("⚠️ El formato del CAE no es valido. Verifica que copiaste los 14 digitos completos del comprobante original (sin dashes, espacios ni letras).")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Resuelve la referencia a un movimiento que manda el modelo.
    ///
    /// ─── EL BUG QUE ARREGLA ────────────────────────────────────────────────
    /// Los listados devolvían el id **recortado a 8 caracteres** (`[id:b3deed5d]`)
    /// y el único "expansor" que había era esto:
    ///
    ///     private func expandUUID(_ s: String) -> String {
    ///         if s.count == 8 { return s }
    ///         return s
    ///     }
    ///
    /// —o sea, nada—. Después venía `UUID(uuidString: "b3deed5d")`, que da `nil`.
    /// Resultado: **editar y borrar movimientos desde el chat nunca funcionó**,
    /// porque el modelo jamás podía conocer otro id que el recortado. Y como el
    /// fallo se devolvía como texto normal, el asistente contestaba "Corregido"
    /// igual. Caso real: un gasto de $98.800 que quedó en $98.800 después de que
    /// el asistente confirmara que lo había cambiado a $78.972,57.
    ///
    /// Ahora los listados mandan el UUID entero, así el id sobrevive en el
    /// historial de la conversación y sirve en cualquier turno posterior. Esta
    /// función además sigue aceptando referencias cortas, que es lo que hay en
    /// las conversaciones ya empezadas.
    private func resolverTransaccion(_ ref: String) async throws -> Transaction {
        let limpio = ref.trimmingCharacters(in: .whitespacesAndNewlines)

        if let uuid = UUID(uuidString: limpio) {
            guard let tx = try await TransactionService.shared.fetchOne(id: uuid) else {
                throw AIToolError.movimientoNoEncontrado(limpio)
            }
            return tx
        }

        // Referencia corta. Menos de 6 caracteres no identifica nada: mejor
        // fallar que editar el movimiento equivocado.
        let prefijo = limpio.lowercased()
        guard prefijo.count >= 6, prefijo.allSatisfy({ $0.isHexDigit || $0 == "-" }) else {
            throw AIToolError.referenciaInvalida(limpio)
        }

        let cal = Calendar.current
        let hoy = Date()
        let candidatas = try await TransactionService.shared.fetchForPeriod(
            householdId: householdId,
            from: cal.date(byAdding: .month, value: -24, to: hoy) ?? hoy,
            to: cal.date(byAdding: .month, value: 12, to: hoy) ?? hoy,
            limit: 5000
        ).filter { $0.id.uuidString.lowercased().hasPrefix(prefijo) }

        guard candidatas.count <= 1 else {
            throw AIToolError.referenciaAmbigua(limpio, candidatas.count)
        }
        guard let tx = candidatas.first else {
            throw AIToolError.movimientoNoEncontrado(limpio)
        }
        return tx
    }
}
