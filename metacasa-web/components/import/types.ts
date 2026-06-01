/** Tipos compartidos del flujo de importación (cliente). */

export type FieldKey = "date" | "amount" | "type" | "category" | "account" | "note";

export interface ColumnMapping {
  date: number | null;
  amount: number | null;
  type: number | null;
  category: number | null;
  account: number | null;
  note: number | null;
}

export type AmountSign =
  | "negativeIsExpense"
  | "typeColumn"
  | "allExpense"
  | "allIncome";

/** Respuesta de /api/import/parse. */
export interface ParseResponse {
  headers: string[];
  rows: string[][];
  rowCount: number;
  truncated: boolean;
  maxRows: number;
}

/** Respuesta de /api/import/map (mapeo IA o heurístico). */
export interface MapResponse {
  mapping: ColumnMapping;
  dateFormat: string | null;
  amountSign: AmountSign;
  source: "ai" | "heuristic";
  notes?: string;
  /** Presente cuando la IA falló y se devolvió la heurística. */
  aiError?: "rateLimit" | "unavailable";
}

export interface AccountOption {
  id: string;
  name: string;
}
