import Foundation

/// Detector de anomalías en transacciones del usuario. Usa estadística
/// simple (z-score por categoría) para flaggear gastos inusuales.
///
/// No usa LLM — son heurísticas determinísticas que corren sobre las
/// transacciones ya cargadas. El resultado se inyecta en `FinancialContext`
/// para que la IA pueda señalarlos proactivamente ("gastaste $X en Y
/// el martes, que es 3× tu media en esa categoría").
///
/// Heurísticas aplicadas:
/// 1. **Outlier por categoría**: una tx cuyo monto > media + 2σ de esa
///    categoría en los últimos 90 días.
/// 2. **Primera vez en categoría**: una tx en una categoría que no había
///    sido usada antes en los últimos 90 días (puede ser un gasto nuevo
///    recurrente que conviene presupuestar).
/// 3. **Duplicate candidate**: dos txs idénticas (misma fecha, categoría,
///    monto) dentro de 24h — posible doble carga.
enum AnomalyDetector {

    struct Anomaly: Sendable, Equatable {
        enum Kind: String, Sendable {
            case outlier           // monto inusualmente alto vs media
            case firstInCategory   // primera tx en esta categoría en 90d
            case possibleDuplicate // posible doble carga
        }

        let kind: Kind
        let transaction: Transaction
        /// Mensaje humano en español rioplatense listo para inyectar al LLM.
        let message: String
    }

    /// Corre todas las heurísticas sobre las txs del mes actual usando
    /// como baseline las txs de los 90 días previos.
    /// Devuelve máximo 3 anomalías (las más "interesantes") para no saturar
    /// el prompt del LLM ni la UI.
    static func detect(
        currentMonthTxs: [Transaction],
        baselineTxs: [Transaction],
        currency: String
    ) -> [Anomaly] {
        var anomalies: [Anomaly] = []

        // 1. Outlier por categoría
        let byCategory90d = Dictionary(grouping: baselineTxs.filter { $0.type == .gasto }, by: \.category)
        for tx in currentMonthTxs where tx.type == .gasto {
            guard let history = byCategory90d[tx.category], history.count >= 3 else { continue }
            let amounts = history.map { (t: Transaction) -> Double in (t.amount as NSDecimalNumber).doubleValue }
            let mean = amounts.reduce(0, +) / Double(amounts.count)
            let variance = amounts.reduce(0) { $0 + pow($1 - mean, 2) } / Double(amounts.count)
            let stdev = sqrt(variance)
            guard stdev > 0 else { continue }
            let txAmount = (tx.amount as NSDecimalNumber).doubleValue
            let zScore = (txAmount - mean) / stdev
            // Threshold 2σ es ~95% percentile. Para fintech queremos notar lo atípico sin alarmismo.
            if zScore > 2.0 {
                let multiplier = txAmount / mean
                let m = String(
                    format: "%.1fx",
                    multiplier
                )
                let fmt = Money.format(tx.amount, currency: tx.currencyOriginal ?? currency)
                let categoryFmt = tx.category
                let dateStr = formatDate(tx.date)
                anomalies.append(.init(
                    kind: .outlier,
                    transaction: tx,
                    message: "El \(dateStr) hubo un gasto de \(fmt) en \(categoryFmt), que es \(m) tu media histórica en esa categoría."
                ))
            }
        }

        // 2. Primera vez en categoría (en los 90d previos no había ninguna).
        let categoriesSeenPreviously = Set(baselineTxs.filter { $0.type == .gasto }.map(\.category))
        for tx in currentMonthTxs where tx.type == .gasto {
            if !categoriesSeenPreviously.contains(tx.category) {
                let fmt = Money.format(tx.amount, currency: tx.currencyOriginal ?? currency)
                let dateStr = formatDate(tx.date)
                anomalies.append(.init(
                    kind: .firstInCategory,
                    transaction: tx,
                    message: "El \(dateStr) apareció una categoría nueva: \"\(tx.category)\" por \(fmt). Si va a ser recurrente, te conviene presupuestarla."
                ))
            }
        }

        // 3. Possible duplicate: mismo monto + categoría + fecha dentro de 24h.
        for (i, tx) in currentMonthTxs.enumerated() where tx.type == .gasto {
            for other in currentMonthTxs.dropFirst(i + 1) where other.type == .gasto {
                if tx.category == other.category
                    && tx.amount == other.amount
                    && abs(tx.date.timeIntervalSince(other.date)) < 86_400 {
                    let fmt = Money.format(tx.amount, currency: tx.currencyOriginal ?? currency)
                    let dateStr = formatDate(tx.date)
                    let lateDate = formatDate(other.date)
                    anomalies.append(.init(
                        kind: .possibleDuplicate,
                        transaction: other,
                        message: "Hay dos gastos idénticos en \(tx.category) por \(fmt) (\(dateStr) y \(lateDate)). Revisá si es una doble carga para eliminar uno."
                    ))
                    break // Con 1 match alcanza
                }
            }
        }

        // Dedup por transaction.id — priorizamos outlier > firstInCategory > duplicate.
        var seenTxIds: Set<UUID> = []
        let priorityOrder: [Anomaly.Kind] = [.outlier, .firstInCategory, .possibleDuplicate]
        var sorted = anomalies.sorted { a, b in
            let ai = priorityOrder.firstIndex(of: a.kind) ?? 99
            let bi = priorityOrder.firstIndex(of: b.kind) ?? 99
            return ai < bi
        }
        sorted.removeAll { !seenTxIds.insert($0.transaction.id).inserted }

        return Array(sorted.prefix(3))
    }

    private static func formatDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = AppLocaleStorage.effectiveLocale
        df.setLocalizedDateFormatFromTemplate("ddMMM")
        return df.string(from: d)
    }
}
