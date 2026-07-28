/**
 * Salud financiera del hogar — lógica PURA (sin acceso a datos ni a React) para
 * poder testearla en aislamiento. Puerto 1:1 de iOS `HomeViewModel.healthScore`
 * / `HomeViewModel.streak`.
 *
 * Vive fuera de `app/(app)/dashboard/page.tsx` a propósito: la page es un Server
 * Component y no se puede importar desde tests.
 */

/** Clave "YYYY-MM-DD" (UTC) de un Date — alineada con las claves de `getActiveTxDays`. */
export function utcDayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/**
 * Health Score 0–100 — puerto 1:1 de iOS `HomeViewModel.healthScore`:
 *  - savings rate (ingresos−gastos)/ingresos → hasta 50 pts (rate × 250, tope 50)
 *  - gasto/ingreso < 1 → hasta 30 pts ((1−ratio) × 30)
 *  - consistencia: días con movimiento en 30d → hasta 20 pts (días × 0.67)
 *
 * Sin ingresos el score sólo puede sumar la parte de consistencia (máx. 20):
 * no hay tasa de ahorro que medir. Si el gasto supera al ingreso, los dos
 * primeros bloques aportan 0 (no restan).
 */
export function computeHealthScore(
  income: number,
  expense: number,
  activeDays: Set<string>,
): number {
  let score = 0;
  if (income > 0) {
    const rate = Math.max(0, (income - expense) / income);
    score += Math.min(50, rate * 250);
    const ratio = expense / income;
    if (ratio < 1) score += (1 - ratio) * 30;
  }
  // Días con movimiento en los últimos 30 (el set ya viene acotado a 30d).
  score += Math.min(20, activeDays.size * 0.67);
  return Math.max(0, Math.min(100, Math.round(score)));
}

/**
 * Racha de días consecutivos (hacia atrás desde `now`) con al menos un
 * movimiento. Puerto de iOS `HomeViewModel.streak`. Trabaja en UTC sobre el set
 * de días. `now` es inyectable para poder testear sin depender del reloj.
 */
export function computeStreak(
  activeDays: Set<string>,
  now: Date = new Date(),
): number {
  let count = 0;
  const cursor = new Date(now);
  // Normalizamos a medianoche UTC para iterar día a día.
  cursor.setUTCHours(0, 0, 0, 0);
  while (activeDays.has(utcDayKey(cursor))) {
    count += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return count;
}
