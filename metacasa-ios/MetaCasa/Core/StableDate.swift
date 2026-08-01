import Foundation

extension Date {
    /// Normaliza una fecha "de calendario" a **mediodía UTC** del mismo día local.
    ///
    /// Sin esto, iOS manda la hora local codificada como UTC y el movimiento cae en el mes
    /// equivocado. Caso real: en Argentina (UTC−3) un gasto cargado el **31-ene a las 22:00** se
    /// serializa como `2026-02-01T01:00Z`. Como el trigger `tg_fill_period` extrae el período en
    /// UTC y `envelope_balance` filtra por `t.date::date` en la sesión UTC de Supabase, ese gasto
    /// cuenta en **febrero**: descuadra el sobre de enero, no entra en los totales del Home (que
    /// arma el rango con `Calendar.current`, en local) y aparece bajo "1 de febrero" en el feed.
    /// En México (UTC−6) la franja rota va de 18:00 a medianoche — justo cuando la gente carga los
    /// gastos del día.
    ///
    /// Mediodía es lo que hace que funcione: da 12 horas de margen a cada lado, así que ningún huso
    /// del mundo (UTC−12 … UTC+14) puede correr la fecha a otro día.
    ///
    /// Es el mismo criterio que la web ya aplica en `toStableDate` (`lib/db/transactions.ts:209`);
    /// iOS había quedado afuera de ese fix.
    func stableForStorage(calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: self)
        var utc = DateComponents()
        utc.year = parts.year
        utc.month = parts.month
        utc.day = parts.day
        utc.hour = 12
        utc.timeZone = TimeZone(identifier: "UTC")

        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        // Si la construcción fallara (no debería con componentes válidos), devolver la fecha
        // original es mejor que crashear una app publicada por guardar un gasto.
        return gregorian.date(from: utc) ?? self
    }
}
