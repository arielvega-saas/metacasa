import Foundation

/// Proyección de gasto de un envelope **al ritmo actual** del período.
///
/// Es el patrón #7 del `PLAN_NIVEL_PRO.md` (lo que hace Copilot): no alcanza con decir "gastaste el 60%",
/// hay que decir *"a este ritmo llegás al 110%"* mientras todavía se puede hacer algo. Un 60% usado el día
/// 10 y un 60% usado el día 28 son situaciones opuestas y la barra de progreso sola no las distingue.
///
/// Cálculo puro y sin dependencias de UI para poder testearlo: `now` y `calendar` se inyectan.
struct BudgetPace: Equatable, Sendable {
    /// Fracción del período ya transcurrida, 0...1.
    let fractionElapsed: Double
    /// Gasto proyectado al cierre del período si se mantiene el ritmo.
    let projectedSpend: Decimal
    /// Proyectado / asignado. 1.10 = 110%.
    let projectedPercent: Double
    /// El ritmo lleva a pasarse del presupuesto.
    var willOverspend: Bool { projectedPercent > 1 }

    /// Mínimo de período transcurrido para proyectar.
    ///
    /// Sin este piso la proyección es ruido peligroso: una compra el día 1 de un mes de 31 días proyecta
    /// 31× el gasto y dispararía una alarma roja por algo perfectamente normal.
    ///
    /// **Subido de 0,15 a 0,25 el 2026-08-04, viéndolo en pantalla.** 0,15 caía en el día 5, y ahí el
    /// alquiler —que se paga el día 1 y es un pago ÚNICO, no un ritmo— seguía proyectando 575%. La
    /// proyección lineal asume que el gasto se reparte parejo, y los gastos fijos de principio de mes
    /// rompen ese supuesto de lleno. Recién cerca del día 8 el gasto variable pesa lo suficiente como
    /// para que el ritmo diga algo. Sigue quedando el 75% del mes con la proyección activa, que es
    /// cuando todavía se puede hacer algo al respecto.
    static let minimumElapsedFraction = 0.25

    /// Tope a partir del cual el NÚMERO deja de informar.
    ///
    /// Un "llegás al 575%" no dice nada que "llegás al 210%" no diga: los dos significan "te vas a
    /// pasar por mucho". Pero el número gigante se lee como error de la app, y una alerta que parece
    /// rota entrena a ignorar toda la zona — el mismo motivo por el que no se muestran desvíos
    /// menores al 25%. Arriba del tope se avisa igual, en cualitativo.
    static let maximumMeaningfulPercent = 2.0

    /// El porcentaje proyectado es informativo (no un artefacto de un gasto fijo temprano).
    var hasMeaningfulPercent: Bool { projectedPercent <= Self.maximumMeaningfulPercent }

    /// Devuelve la proyección, o `nil` cuando proyectar no aporta o mentiría.
    ///
    /// Casos que devuelven `nil` a propósito:
    /// - `allocated <= 0`: sin presupuesto no hay contra qué proyectar.
    /// - `spent <= 0`: sin gasto el ritmo es cero y la proyección es trivialmente 0.
    /// - Período **futuro** (`now` antes del inicio): no hay ritmo todavía.
    /// - Período **terminado** (`now` después del fin): el gasto ya es un hecho, no una proyección.
    ///   Mostrar "proyectado" sobre un mes cerrado sería directamente falso.
    /// - Menos de `minimumElapsedFraction` transcurrido (ver arriba).
    static func compute(
        spent: Decimal,
        allocated: Decimal,
        periodStart: Date,
        periodEnd: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> BudgetPace? {
        guard allocated > 0, spent > 0 else { return nil }

        // `periodEnd` viene de `BudgetService.ensurePeriodForMonth` como el ÚLTIMO DÍA del mes a
        // medianoche (1-ene → 31-ene 00:00), así que el período cubre hasta el final de ese día.
        let startDay = calendar.startOfDay(for: periodStart)
        let lastDay = calendar.startOfDay(for: periodEnd)
        let today = calendar.startOfDay(for: now)

        guard let totalDays = calendar.dateComponents([.day], from: startDay, to: lastDay).day,
              totalDays >= 0 else { return nil }
        let totalDaysInclusive = totalDays + 1

        guard let daysSinceStart = calendar.dateComponents([.day], from: startDay, to: today).day
        else { return nil }

        // Fuera del período: ni proyección futura ni reescritura del pasado.
        guard daysSinceStart >= 0, daysSinceStart <= totalDays else { return nil }

        // El día en curso cuenta como transcurrido: el día 1 es 1/31, no 0/31.
        let elapsedDays = daysSinceStart + 1
        let fraction = Double(elapsedDays) / Double(totalDaysInclusive)
        guard fraction >= minimumElapsedFraction else { return nil }

        // Decimal para no perder precisión de dinero; el divisor sale de enteros, así que es exacto.
        let projected = spent * Decimal(totalDaysInclusive) / Decimal(elapsedDays)
        let percent = (projected as NSDecimalNumber).doubleValue / (allocated as NSDecimalNumber).doubleValue

        return BudgetPace(
            fractionElapsed: fraction,
            projectedSpend: projected,
            projectedPercent: percent
        )
    }
}

extension EnvelopeStatus {
    /// Nivel de semáforo del envelope. Mismo criterio que ya usaba la barra de progreso
    /// (>0,95 rojo · >0,8 ámbar), extraído para que el anillo, la barra y el texto no puedan divergir.
    enum Severity: Sendable {
        case ok, warning, critical
    }

    var severity: Severity {
        if isOverBudget || percentUsed > 0.95 { return .critical }
        if percentUsed > 0.8 { return .warning }
        return .ok
    }

    /// Proyección al ritmo actual dentro del período dado.
    func pace(periodStart: Date, periodEnd: Date, now: Date = Date(), calendar: Calendar = .current) -> BudgetPace? {
        BudgetPace.compute(
            spent: spent,
            allocated: allocated,
            periodStart: periodStart,
            periodEnd: periodEnd,
            now: now,
            calendar: calendar
        )
    }
}
