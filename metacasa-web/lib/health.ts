/**
 * Salud financiera del hogar — lógica PURA (sin acceso a datos ni a React) para
 * poder testearla en aislamiento. Puerto 1:1 de iOS `HomeViewModel.healthScore`
 * / `HomeViewModel.streak`.
 *
 * Vive fuera de `app/(app)/dashboard/page.tsx` a propósito: la page es un Server
 * Component y no se puede importar desde tests.
 */

import { dayStartUtc, isIsoDay } from "./today";

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
 * Racha de días consecutivos (hacia atrás desde hoy) con al menos un movimiento.
 * Puerto de iOS `HomeViewModel.streak`.
 *
 * `today` acepta dos formas:
 *  - `"YYYY-MM-DD"` — el día del calendario del USUARIO (lo que devuelve
 *    `getToday()`, derivado de la cookie de zona horaria). **Es la forma
 *    correcta en producción.** Pasar un `Date` hace que el cursor arranque en el
 *    día UTC, y el server de Netlify corre en UTC: entre las 21:00 y las 24:00
 *    en Argentina eso arrancaba la cuenta en MAÑANA y la racha daba 0 aunque el
 *    usuario acabara de cargar un movimiento.
 *  - `Date` — sólo por compatibilidad y para tests; se interpreta en UTC.
 *
 * En ambos casos itera en UTC sobre el set de días, que es como están armadas
 * las claves (`transactions.date` se guarda a mediodía UTC vía `toStableDate`).
 */
export function computeStreak(
  activeDays: Set<string>,
  today: string | Date = new Date(),
): number {
  let count = 0;
  const cursor =
    typeof today === "string"
      ? // Día ya resuelto en la zona del usuario → medianoche UTC de ESE día.
        // Si llegara un string con otra forma, caemos al reloj (nunca NaN).
        isIsoDay(today)
        ? dayStartUtc(today)
        : new Date()
      : new Date(today);
  // Normalizamos a medianoche UTC para iterar día a día.
  cursor.setUTCHours(0, 0, 0, 0);
  while (activeDays.has(utcDayKey(cursor))) {
    count += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return count;
}
