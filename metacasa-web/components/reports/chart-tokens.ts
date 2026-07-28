/**
 * Colores de marca para los charts de Reportes, centralizados.
 *
 * Apuntan a CSS custom properties (`var(--mc-…)`) en vez de hex: así los charts
 * cambian solos entre tema oscuro y claro sin re-render ni JS. Recharts los
 * escribe como atributos de presentación SVG (`fill`, `stroke`, `stopColor`),
 * que el navegador parsea como CSS y resuelven `var()` sin problema — es el
 * mismo patrón que usan los charts de shadcn/ui.
 *
 * Módulo SERVER-SAFE (sin "use client"): lo importan tanto charts client como
 * el server component `reports-view` (para los puntos de leyenda).
 *
 * ⚠️ Como son `var()` y no hex, NO se pueden concatenar sufijos de alfa
 * (`${color}2e`). Para opacidad usar `color-mix(in srgb, ${color} X%, transparent)`.
 *
 *   --mc-sage-strong  oscuro #9fc4ad / claro #1b6e45  → income / positivo
 *   --mc-expense      oscuro #e8b4a6 / claro #a9452e  → gasto / negativo
 *   --mc-champagne    oscuro #d4c19c / claro #7a5e1f  → acento secundario
 *   --mc-sage         oscuro #b8d4c2 / claro #2c6b4e  → acento primario
 *   --mc-text-muted   oscuro #7a8782 / claro #3f4e47  → ejes / labels (AA en ambos)
 */
export const CHART = {
  income: "var(--mc-sage-strong)",
  expense: "var(--mc-expense)",
  champagne: "var(--mc-champagne)",
  sage: "var(--mc-sage)",
  axis: "var(--mc-text-muted)",
  /** Grid tenue (sage en oscuro, verde-carbón en claro). */
  grid: "var(--mc-chart-grid)",
  /** Cursor de tooltip (stroke, para charts de línea/área). */
  cursor: "var(--mc-chart-cursor)",
  /** Cursor de tooltip (fill, para charts de barras). */
  cursorFill: "var(--mc-chart-cursor-fill)",
} as const;

/** Color semántico de un health score, según su tramo (paridad iOS). */
export function healthColor(score: number): string {
  if (score >= 75) return CHART.income;
  if (score >= 55) return CHART.sage;
  if (score >= 35) return CHART.champagne;
  return CHART.expense;
}
