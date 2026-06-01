/**
 * Colores de marca para los charts de Reportes, centralizados. Recharts pinta
 * con valores concretos (no lee `var(--…)` en SVG de forma fiable cross-browser),
 * así que espejamos acá los tokens de `app/globals.css` (Midnight Sage) en un
 * único lugar — sin hex sueltos por los componentes.
 *
 * Módulo SERVER-SAFE (sin "use client"): lo importan tanto charts client como
 * el server component `reports-view` (para los puntos de leyenda).
 *
 *   --mc-sage-strong  #9fc4ad  → income / positivo
 *   --mc-expense      #e8b4a6  → gasto / negativo
 *   --mc-champagne    #d4c19c  → acento secundario / acumulado
 *   --mc-sage         #b8d4c2  → acento primario
 *   --mc-text-muted   #7a8782  → ejes / labels
 */
export const CHART = {
  income: "#9fc4ad",
  expense: "#e8b4a6",
  champagne: "#d4c19c",
  sage: "#b8d4c2",
  axis: "#7a8782",
  /** Grid sage muy tenue (igual que los charts existentes). */
  grid: "rgba(184,212,194,0.08)",
  /** Cursor de tooltip. */
  cursor: "rgba(255,255,255,0.12)",
} as const;

/** Color semántico de un health score, según su tramo (paridad iOS). */
export function healthColor(score: number): string {
  if (score >= 75) return CHART.income;
  if (score >= 55) return CHART.sage;
  if (score >= 35) return CHART.champagne;
  return CHART.expense;
}
