/**
 * Tipos + paleta de series para reportes. Módulo SERVER-SAFE (sin "use client"):
 * `colorForIndex` se usa tanto en server components (reports-view) como en los
 * charts client (category-donut). Exportar una función desde un módulo "use
 * client" y llamarla en el server lanza excepción (es una client reference).
 */
export interface CategorySlice {
  category: string;
  total: number;
}

/**
 * Paleta de series (sage → champagne → coral, escalonadas).
 * Vía CSS vars para que cambie sola con el tema: en oscuro son pasteles sobre
 * midnight; en claro, versiones oscurecidas (todas ≥3:1 sobre la card blanca,
 * requisito 1.4.11 porque el color identifica la categoría en la leyenda).
 * Valores concretos en `app/globals.css` (`--mc-series-1..10`).
 */
export const PALETTE = [
  "var(--mc-series-1)",
  "var(--mc-series-2)",
  "var(--mc-series-3)",
  "var(--mc-series-4)",
  "var(--mc-series-5)",
  "var(--mc-series-6)",
  "var(--mc-series-7)",
  "var(--mc-series-8)",
  "var(--mc-series-9)",
  "var(--mc-series-10)",
];

export function colorForIndex(i: number): string {
  return PALETTE[i % PALETTE.length];
}
