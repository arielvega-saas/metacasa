import Foundation

/// Racha de días consecutivos con al menos un movimiento, contando hacia atrás desde hoy.
///
/// Vive acá y no dentro de `HomeViewModel` para poder testearla: el cálculo estaba embebido en una
/// propiedad calculada del view model, sin un solo test, y **siempre devolvía 1**.
///
/// El bug: el bucle tenía un `days.remove(prev)` al final que borraba del set el día que la vuelta
/// siguiente iba a consultar. Se contaba hoy, se borraba ayer, y al comprobar ayer ya no estaba. El
/// comentario decía que era "para evitar loops sobre gaps" — justo lo contrario de lo que hacía. No
/// hay riesgo de loop infinito: el cursor baja un día por vuelta y el set es finito.
///
/// La versión de la web (`lib/health.ts:computeStreak`) siempre estuvo bien; esto es un port que
/// divergió. Es la misma forma que ya costó caro en "listo para asignar" y en el patrimonio neto:
/// la misma regla escrita dos veces termina divergiendo, y el que diverge es el que no tiene tests.
enum Streak {

    /// - Parameters:
    ///   - transactions: movimientos a considerar. **Se espera que vengan sin transferencias**:
    ///     mover plata entre cuentas propias no es un día de actividad real.
    ///   - now: inyectable para testear sin depender del reloj.
    static func consecutiveDays(
        transactions: [Transaction],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let days = Set(transactions.map { calendar.startOfDay(for: $0.date) })
        var count = 0
        var cursor = calendar.startOfDay(for: now)
        while days.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }
}
