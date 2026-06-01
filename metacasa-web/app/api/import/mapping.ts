/**
 * Tipos + heurística de mapeo compartidos por las rutas de importación.
 * El mapeo asocia cada campo de nuestro schema con el ÍNDICE de columna (0-based)
 * de la planilla subida, o `null` si no hay columna para ese campo.
 */

export type FieldKey = "date" | "amount" | "type" | "category" | "account" | "note";

export interface ColumnMapping {
  date: number | null;
  amount: number | null;
  type: number | null;
  category: number | null;
  account: number | null;
  note: number | null;
}

/** Cómo se determina el tipo (gasto/ingreso) de cada fila. */
export type AmountSign =
  | "negativeIsExpense" // el signo del monto define el tipo (negativo = gasto)
  | "typeColumn" // hay una columna de tipo explícita
  | "allExpense" // sin señal: tratamos todo como gasto
  | "allIncome";

export interface MappingResult {
  mapping: ColumnMapping;
  /** Formato de fecha adivinado (ej. "DD/MM/YYYY"); informativo. */
  dateFormat: string | null;
  amountSign: AmountSign;
  /** Origen del mapeo: para avisar al usuario si la IA no respondió. */
  source: "ai" | "heuristic";
  notes?: string;
}

const EMPTY_MAPPING: ColumnMapping = {
  date: null,
  amount: null,
  type: null,
  category: null,
  account: null,
  note: null,
};

/** Palabras clave por campo, en es/en/pt (sin acentos: se normalizan). */
const KEYWORDS: Record<FieldKey, string[]> = {
  date: ["fecha", "date", "data", "dia", "day", "fecha operacion", "fecha valor"],
  amount: [
    "monto",
    "importe",
    "amount",
    "valor",
    "total",
    "value",
    "debito",
    "credito",
    "debit",
    "credit",
    "cargo",
    "abono",
  ],
  type: ["tipo", "type", "movimiento", "movement", "operacion", "transaction type", "ingreso/gasto"],
  category: ["categoria", "category", "categoria", "rubro", "concepto", "concept"],
  account: ["cuenta", "account", "conta", "banco", "bank", "wallet", "billetera", "tarjeta", "card"],
  note: [
    "nota",
    "descripcion",
    "description",
    "descricao",
    "note",
    "detalle",
    "detail",
    "memo",
    "referencia",
    "reference",
    "concepto",
  ],
};

/** Normaliza un header: minúsculas, sin acentos, sin espacios extra. */
function normalize(s: string): string {
  return s
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Mapeo heurístico por nombre de header (es/en/pt), usado como FALLBACK cuando
 * la IA no está disponible — así la feature funciona igual sin IA. Para cada
 * campo elige el primer header que matchea exacto; si no, el primero que
 * contiene alguna keyword. Un mismo índice no se asigna a dos campos.
 */
export function heuristicMapping(headers: string[]): MappingResult {
  const norm = headers.map(normalize);
  const used = new Set<number>();
  const mapping: ColumnMapping = { ...EMPTY_MAPPING };

  const order: FieldKey[] = ["date", "amount", "type", "category", "account", "note"];
  for (const field of order) {
    const kws = KEYWORDS[field];
    // 1) match exacto de header.
    let idx = norm.findIndex((h, i) => !used.has(i) && kws.includes(h));
    // 2) match por inclusión de keyword.
    if (idx < 0) {
      idx = norm.findIndex(
        (h, i) => !used.has(i) && h.length > 0 && kws.some((k) => h.includes(k)),
      );
    }
    if (idx >= 0) {
      mapping[field] = idx;
      used.add(idx);
    }
  }

  return {
    mapping,
    dateFormat: null,
    amountSign: mapping.type != null ? "typeColumn" : "negativeIsExpense",
    source: "heuristic",
  };
}

/** Valida que un índice sea una columna existente (o null). */
function coerceIndex(value: unknown, colCount: number): number | null {
  if (value == null) return null;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isInteger(n) || n < 0 || n >= colCount) return null;
  return n;
}

const VALID_SIGNS: AmountSign[] = [
  "negativeIsExpense",
  "typeColumn",
  "allExpense",
  "allIncome",
];

/**
 * Parsea, de forma DEFENSIVA, el JSON que devuelve el modelo (puede venir
 * envuelto en prosa o en un bloque ```json). Devuelve `null` si no hay un
 * objeto de mapeo utilizable, para que el caller caiga a la heurística.
 */
export function parseAiMapping(text: string, colCount: number): MappingResult | null {
  if (!text) return null;

  // Aislar el primer objeto JSON balanceado del texto.
  const jsonStr = extractFirstJsonObject(text);
  if (!jsonStr) return null;

  let obj: unknown;
  try {
    obj = JSON.parse(jsonStr);
  } catch {
    return null;
  }
  if (!obj || typeof obj !== "object") return null;

  const root = obj as Record<string, unknown>;
  const m = (root.mapping ?? root) as Record<string, unknown>;
  if (!m || typeof m !== "object") return null;

  const mapping: ColumnMapping = {
    date: coerceIndex(m.date, colCount),
    amount: coerceIndex(m.amount, colCount),
    type: coerceIndex(m.type, colCount),
    category: coerceIndex(m.category, colCount),
    account: coerceIndex(m.account, colCount),
    note: coerceIndex(m.note, colCount),
  };

  // Sin fecha NI monto el mapeo es inútil → que decida la heurística.
  if (mapping.date == null && mapping.amount == null) return null;

  const rawSign = root.amountSign;
  const amountSign: AmountSign = VALID_SIGNS.includes(rawSign as AmountSign)
    ? (rawSign as AmountSign)
    : mapping.type != null
      ? "typeColumn"
      : "negativeIsExpense";

  return {
    mapping,
    dateFormat: typeof root.dateFormat === "string" ? root.dateFormat.slice(0, 40) : null,
    amountSign,
    source: "ai",
    notes: typeof root.notes === "string" ? root.notes.slice(0, 300) : undefined,
  };
}

/** Encuentra el primer objeto `{...}` balanceado dentro de un texto. */
function extractFirstJsonObject(text: string): string | null {
  const start = text.indexOf("{");
  if (start < 0) return null;
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (inStr) {
      if (esc) esc = false;
      else if (ch === "\\") esc = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') inStr = true;
    else if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}
