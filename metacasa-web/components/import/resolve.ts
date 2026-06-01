/**
 * Resolución pura cliente: convierte filas crudas + mapeo en transacciones
 * previsualizables. Espeja la validación del server action `importTransactions`
 * para que el preview muestre EXACTAMENTE lo que se va a insertar (mismas reglas
 * de fecha, monto y tipo). No hace I/O.
 */
import { TX_TYPE, type TxType } from "@/lib/constants";
import { parseMoney } from "@/lib/money";
import type { AmountSign, ColumnMapping } from "./types";

export type RowErrorCode = "date" | "amount" | "empty" | null;

export interface ResolvedRow {
  /** Índice original en el array de filas crudas. */
  index: number;
  /** "YYYY-MM-DD" si la fecha es válida, null si no. */
  date: string | null;
  /** Magnitud positiva en moneda base, o null si inválido. */
  amount: number | null;
  type: TxType;
  category: string;
  /** Cuenta resuelta (id válido o null). */
  accountId: string | null;
  note: string | null;
  /** Código de error si la fila es inválida (no importable). */
  error: RowErrorCode;
}

export interface ResolveSettings {
  mapping: ColumnMapping;
  amountSign: AmountSign;
  dateFormat: string | null;
  defaultCategory: string;
  targetAccountId: string | null;
  validCategories: Set<string>;
  validAccountIds: Set<string>;
}

/** Resuelve todas las filas crudas a filas previsualizables. */
export function resolveRows(rows: string[][], s: ResolveSettings): ResolvedRow[] {
  const fallbackCategory = (s.defaultCategory || "Otros").trim() || "Otros";

  return rows.map((row, index) => {
    const cell = (idx: number | null): string =>
      idx != null && idx >= 0 && idx < row.length ? (row[idx] ?? "").trim() : "";

    const rawDate = cell(s.mapping.date);
    const rawAmount = cell(s.mapping.amount);

    // Fila completamente vacía en las columnas clave.
    if (!rawDate && !rawAmount) {
      return emptyResolved(index, "empty", fallbackCategory, s.targetAccountId);
    }

    const date = parseDate(rawDate, s.dateFormat);
    const parsed = parseSignedAmount(rawAmount);

    const rowCat = cell(s.mapping.category);
    const category = rowCat && s.validCategories.has(rowCat) ? rowCat : fallbackCategory;
    const accountId =
      s.targetAccountId && s.validAccountIds.has(s.targetAccountId)
        ? s.targetAccountId
        : null;
    const note = (() => {
      const n = cell(s.mapping.note);
      return n ? n.slice(0, 140) : null;
    })();

    if (!date) {
      return {
        index,
        date: null,
        amount: parsed?.magnitude ?? null,
        type: TX_TYPE.EXPENSE,
        category,
        accountId,
        note,
        error: "date",
      };
    }
    if (parsed == null || parsed.magnitude <= 0) {
      return {
        index,
        date,
        amount: null,
        type: TX_TYPE.EXPENSE,
        category,
        accountId,
        note,
        error: "amount",
      };
    }

    const type = resolveType(cell(s.mapping.type), parsed.negative, s.amountSign);
    return {
      index,
      date,
      amount: parsed.magnitude,
      type,
      category,
      accountId,
      note,
      error: null,
    };
  });
}

function emptyResolved(
  index: number,
  error: RowErrorCode,
  category: string,
  accountId: string | null,
): ResolvedRow {
  return {
    index,
    date: null,
    amount: null,
    type: TX_TYPE.EXPENSE,
    category,
    accountId,
    note: null,
    error,
  };
}

// ── Helpers de parseo (idénticos en intención al server action) ──────────────

export function parseSignedAmount(
  raw: string,
): { magnitude: number; negative: boolean } | null {
  const s = raw.trim();
  if (!s) return null;
  const negative = /^\(.*\)$/.test(s) || /-/.test(s);
  const value = parseMoney(s);
  if (!Number.isFinite(value) || value === 0) return null;
  return { magnitude: Math.abs(round2(value)), negative };
}

const INCOME_WORDS = ["ingreso", "income", "receita", "credito", "credit", "abono", "haber", "deposito", "deposit"];
const EXPENSE_WORDS = ["gasto", "expense", "despesa", "debito", "debit", "cargo", "pago", "payment", "egreso", "retiro", "withdrawal"];

export function resolveType(
  typeRaw: string,
  negative: boolean,
  sign: AmountSign,
): TxType {
  const explicit = matchTypeWord(typeRaw);
  if (explicit) return explicit;
  if (sign === "allIncome") return TX_TYPE.INCOME;
  if (sign === "allExpense") return TX_TYPE.EXPENSE;
  return negative ? TX_TYPE.EXPENSE : TX_TYPE.INCOME;
}

function matchTypeWord(raw: string): TxType | null {
  const s = raw
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
  if (!s) return null;
  if (INCOME_WORDS.some((w) => s.includes(w))) return TX_TYPE.INCOME;
  if (EXPENSE_WORDS.some((w) => s.includes(w))) return TX_TYPE.EXPENSE;
  return null;
}

export function parseDate(raw: string, dateFormat: string | null): string | null {
  const s = raw.trim();
  if (!s) return null;

  const isoMatch = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (isoMatch) return validCalendarDate(+isoMatch[1], +isoMatch[2], +isoMatch[3]);

  const parts = s.split(/[/.\-\s]+/).filter(Boolean);
  if (parts.length < 3) return null;
  const nums = parts.slice(0, 3).map((p) => parseInt(p, 10));
  if (nums.some((n) => !Number.isFinite(n))) return null;

  let year: number, month: number, day: number;
  if (parts[0].length === 4) {
    [year, month, day] = nums;
  } else {
    const monthFirst = !!dateFormat && /^M{1,2}[/.\-]?D/i.test(dateFormat.trim());
    if (monthFirst) [month, day] = [nums[0], nums[1]];
    else [day, month] = [nums[0], nums[1]];
    year = nums[2];
    if (year < 100) year += year >= 70 ? 1900 : 2000;
  }

  return validCalendarDate(year, month, day);
}

function validCalendarDate(year: number, month: number, day: number): string | null {
  if (
    !Number.isInteger(year) ||
    !Number.isInteger(month) ||
    !Number.isInteger(day) ||
    year < 1900 ||
    year > 2200 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31
  ) {
    return null;
  }
  const d = new Date(Date.UTC(year, month - 1, day));
  if (
    d.getUTCFullYear() !== year ||
    d.getUTCMonth() !== month - 1 ||
    d.getUTCDate() !== day
  ) {
    return null;
  }
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}
