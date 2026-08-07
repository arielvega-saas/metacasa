/**
 * Cotas de rango de fechas para consultar `transactions`.
 *
 * ─── EL PROBLEMA ───────────────────────────────────────────────────────────
 * `transactions.date` es `timestamptz`, pero conceptualmente guarda un **día de
 * calendario**. Para que ese día no se corra según el huso, `toStableDate`
 * escribe siempre el mediodía UTC: `2026-08-01T12:00:00.000Z`.
 *
 * Un filtro "hasta el 1 de agosto" se escribe naturalmente como
 * `.lte("date", "2026-08-01")`, y PostgREST lo interpreta como
 * `2026-08-01T00:00:00Z`. El mediodía es POSTERIOR a la medianoche, así que
 * **el último día del rango queda afuera entero**.
 *
 * Medido sobre la base real: filtrar "hasta 2026-08-01" devolvía 60 movimientos
 * cuando eran 86. Las 26 del día 1 desaparecían — y con ellas el sueldo del mes.
 *
 * ─── POR QUÉ VIVE ACÁ ──────────────────────────────────────────────────────
 * Esta corrección ya existía dentro de `db/budget.ts` y funcionaba, pero era
 * privada de ese archivo: la lista de movimientos y la exportación repetían el
 * `.lte(...)` crudo y seguían perdiendo el último día. Una regla implementada
 * dos veces diverge siempre; ésta tiene un nombre y un solo lugar.
 *
 * Si agregás una consulta con cota superior de fecha, pasala por acá.
 */

/**
 * Cota superior **inclusiva** para un `.lte("date", …)`.
 *
 * Una fecha-sólo (`YYYY-MM-DD`) se extiende al final de ese día en UTC. Si ya
 * viene con componente horario, se respeta tal cual: el llamador fue explícito.
 */
export function inclusiveDateEnd(end: string): string {
  return /^\d{4}-\d{2}-\d{2}$/.test(end) ? `${end}T23:59:59.999Z` : end;
}
