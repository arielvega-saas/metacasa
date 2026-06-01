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

// Paleta Midnight Sage para series (sage → champagne → coral, escalonadas).
export const PALETTE = [
  "#9fc4ad",
  "#c9b78a",
  "#e8b4a6",
  "#7fae93",
  "#b8d4c2",
  "#d8c9a0",
  "#cf9d8e",
  "#6b9a82",
  "#a9c9b6",
  "#e0cfae",
];

export function colorForIndex(i: number): string {
  return PALETTE[i % PALETTE.length];
}
