"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import { listAccounts } from "@/lib/db/accounts";
import { getCategories } from "@/lib/db/categories";
import { bulkCreateTransactions, type TxMutationInput } from "@/lib/db/transactions";
import { parseMoney } from "@/lib/money";
import { TX_TYPE, type TxType } from "@/lib/constants";

/**
 * Una fila ya mapeada que manda el cliente (paso de preview). Todos los campos
 * vienen como strings crudos extraídos de la planilla (la columna ya resuelta
 * por el mapeo); acá los validamos y normalizamos. `accountId` es la cuenta
 * destino elegida por el usuario para ESTA fila (default = cuenta destino del
 * paso de mapeo), ya resuelta a un id real o null.
 */
export interface ParsedTxInput {
  /** Fecha cruda tal como vino en la planilla (ej. "12/03/2025", "2025-03-12"). */
  date: string;
  /** Monto crudo (puede traer signo, símbolos, separadores locales). */
  amount: string;
  /** Tipo explícito si la planilla tenía columna de tipo; si no, vacío. */
  type?: string;
  category?: string;
  note?: string;
  /** Cuenta destino ya resuelta por el cliente (id existente o null). */
  accountId?: string | null;
}

export interface ImportRequest {
  rows: ParsedTxInput[];
  /** Cómo derivar el tipo cuando no hay columna de tipo confiable. */
  amountSign?: "negativeIsExpense" | "typeColumn" | "allExpense" | "allIncome";
  /** Formato de fecha detectado, para desambiguar DD/MM vs MM/DD. */
  dateFormat?: string | null;
  /** Categoría por defecto cuando la fila no trae una válida. */
  defaultCategory?: string;
}

export interface ImportResult {
  inserted: number;
  skipped: number;
  /** Índices de fila (0-based, respecto al array recibido) que se omitieron. */
  errors: number[];
}

/** Tope defensivo de filas por importación (espeja el cap del parser). */
const MAX_ROWS = 2000;

/**
 * Importa un lote de movimientos. Valida fila por fila y OMITE las inválidas en
 * vez de fallar todo el batch. Construye el MISMO shape canónico que el alta
 * individual (`createTransaction`): `amount` magnitud positiva en moneda base,
 * `amount_original`/`currency_original`/`fx_rate_to_base` consistentes (moneda =
 * base del hogar; fx = 1, porque la planilla no trae tasas confiables), fecha
 * estabilizada a mediodía UTC dentro de `bulkCreateTransactions`. 100% compatible
 * con iOS.
 */
export async function importTransactions(req: ImportRequest): Promise<ImportResult> {
  const t = await getT();
  const supabase = await createClient();

  // 1) Sesión.
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionExpired"));

  // 2) Hogar activo. (El middleware ya bloquea Server Actions de usuarios
  //    'locked'; además RLS valida pertenencia en el INSERT.)
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  // 3) Doble verificación de pertenencia al hogar (defensa en profundidad).
  const { data: membership } = await supabase
    .from("household_members")
    .select("household_id")
    .eq("household_id", active.id)
    .eq("user_id", user.id)
    .maybeSingle();
  if (!membership) throw new Error(t("errors.noHousehold"));

  const rows = Array.isArray(req.rows) ? req.rows.slice(0, MAX_ROWS) : [];
  if (rows.length === 0) return { inserted: 0, skipped: 0, errors: [] };

  const baseCurrency = (active.default_currency || "USD").toUpperCase();

  // 4) Sets de categorías/cuentas válidas del hogar para mapear/validar.
  const [categories, accounts] = await Promise.all([
    getCategories(supabase, active.id),
    listAccounts(supabase, active.id),
  ]);
  const validCategories = new Set<string>([
    ...(categories.gastos ?? []),
    ...(categories.ingresos ?? []),
  ]);
  const validAccountIds = new Set(accounts.map((a) => a.id));
  const fallbackCategory = sanitizeCategory(req.defaultCategory) || "Otros";

  // 5) Validar + normalizar cada fila. Las inválidas se omiten (no rompen el lote).
  const inputs: TxMutationInput[] = [];
  const errors: number[] = [];

  for (let i = 0; i < rows.length; i++) {
    const raw = rows[i];

    const isoDate = parseDate(raw?.date, req.dateFormat);
    if (!isoDate) {
      errors.push(i);
      continue;
    }

    const parsed = parseSignedAmount(raw?.amount);
    if (parsed == null || parsed.magnitude <= 0) {
      errors.push(i);
      continue;
    }

    const type = resolveType(raw?.type, parsed.negative, req.amountSign);

    // Categoría: usa la de la fila si coincide con una del hogar; si no, fallback.
    const rowCategory = sanitizeCategory(raw?.category);
    const category = rowCategory && validCategories.has(rowCategory)
      ? rowCategory
      : fallbackCategory;

    // Cuenta: sólo se acepta si es un id real del hogar (evita inyección/fugas).
    const accountId =
      raw?.accountId && validAccountIds.has(raw.accountId) ? raw.accountId : null;

    inputs.push({
      householdId: active.id,
      userId: user.id,
      type,
      amount: parsed.magnitude, // magnitud positiva, ya en moneda base
      category,
      accountId,
      date: isoDate, // YYYY-MM-DD; bulkCreate lo estabiliza a mediodía UTC
      note: sanitizeNote(raw?.note),
      amountOriginal: parsed.magnitude,
      currencyOriginal: baseCurrency,
      fxRateToBase: 1,
    });
  }

  if (inputs.length === 0) {
    return { inserted: 0, skipped: rows.length, errors };
  }

  // 6) Inserción en lotes (RLS valida pertenencia por fila).
  const inserted = await bulkCreateTransactions(supabase, inputs);

  revalidatePath("/transactions");
  revalidatePath("/dashboard");

  return {
    inserted,
    skipped: rows.length - inserted,
    errors,
  };
}

// ──────────────────────────────────────────────────────────────────────────
// Helpers de parseo/normalización (puros, testeables, sin I/O).
// ──────────────────────────────────────────────────────────────────────────

/** Recorta y acota la categoría; vacío → "". */
function sanitizeCategory(c: unknown): string {
  return typeof c === "string" ? c.trim().slice(0, 80) : "";
}

/** Nota: recortada a 140 (como el form individual) o null. */
function sanitizeNote(n: unknown): string | null {
  if (typeof n !== "string") return null;
  const trimmed = n.trim().slice(0, 140);
  return trimmed || null;
}

/**
 * Parsea un monto que puede traer signo, símbolos de moneda y separadores
 * locales (US o LatAm). Reutiliza `parseMoney` para el valor numérico y detecta
 * el signo por separado (paréntesis contables o "-"). Devuelve magnitud + signo,
 * o `null` si no hay número válido.
 */
function parseSignedAmount(raw: unknown): { magnitude: number; negative: boolean } | null {
  if (typeof raw !== "string" && typeof raw !== "number") return null;
  const s = String(raw).trim();
  if (!s) return null;

  // Negativo si hay "-" o si viene entre paréntesis (formato contable).
  const negative = /^\(.*\)$/.test(s) || /-/.test(s);
  const value = parseMoney(s);
  if (!Number.isFinite(value) || value === 0) return null;
  return { magnitude: Math.abs(round2(value)), negative };
}

/**
 * Resuelve el tipo de movimiento. Prioridad:
 * 1) columna de tipo explícita (palabras es/en/pt),
 * 2) modo 'allExpense'/'allIncome',
 * 3) signo del monto (negativo = gasto) — default.
 */
function resolveType(
  typeRaw: unknown,
  negative: boolean,
  sign?: ImportRequest["amountSign"],
): TxType {
  const explicit = matchTypeWord(typeRaw);
  if (explicit) return explicit;
  if (sign === "allIncome") return TX_TYPE.INCOME;
  if (sign === "allExpense") return TX_TYPE.EXPENSE;
  // negativeIsExpense (default) y typeColumn-sin-match caen acá:
  return negative ? TX_TYPE.EXPENSE : TX_TYPE.INCOME;
}

const INCOME_WORDS = ["ingreso", "income", "receita", "credito", "credit", "abono", "haber", "deposito", "deposit"];
const EXPENSE_WORDS = ["gasto", "expense", "despesa", "debito", "debit", "cargo", "pago", "payment", "egreso", "retiro", "withdrawal"];

/** Detecta gasto/ingreso desde un texto de columna de tipo (es/en/pt). */
function matchTypeWord(raw: unknown): TxType | null {
  if (typeof raw !== "string") return null;
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

/**
 * Parsea una fecha cruda a "YYYY-MM-DD". Soporta:
 * - ISO (YYYY-MM-DD o con tiempo) → tal cual.
 * - Date de ExcelJS ya serializado a ISO por el parser.
 * - D/M/Y o M/D/Y con separadores `/ . -`, desambiguando con `dateFormat`.
 * Devuelve `null` si no logra una fecha de calendario válida.
 */
function parseDate(raw: unknown, dateFormat?: string | null): string | null {
  if (typeof raw !== "string" && typeof raw !== "number") return null;
  const s = String(raw).trim();
  if (!s) return null;

  // 1) Ya ISO (con o sin tiempo): tomar la parte de fecha y validar.
  const isoMatch = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (isoMatch) {
    return validCalendarDate(+isoMatch[1], +isoMatch[2], +isoMatch[3]);
  }

  // 2) Numérico/separado: dd?/mm?/yyyy o yyyy/mm/dd.
  const parts = s.split(/[/.\-\s]+/).filter(Boolean);
  if (parts.length < 3) return null;
  const nums = parts.slice(0, 3).map((p) => parseInt(p, 10));
  if (nums.some((n) => !Number.isFinite(n))) return null;

  let year: number, month: number, day: number;
  if (parts[0].length === 4) {
    // YYYY/MM/DD
    [year, month, day] = nums;
  } else {
    // Día y mes primero: el orden lo decide dateFormat. Default DD/MM (es/pt/LatAm).
    const monthFirst = !!dateFormat && /^M{1,2}[/.\-]?D/i.test(dateFormat.trim());
    if (monthFirst) {
      [month, day] = [nums[0], nums[1]];
    } else {
      [day, month] = [nums[0], nums[1]];
    }
    year = nums[2];
    if (year < 100) year += year >= 70 ? 1900 : 2000; // años de 2 dígitos
  }

  return validCalendarDate(year, month, day);
}

/** Valida (Y,M,D) como fecha real y la devuelve como "YYYY-MM-DD" o null. */
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
  // Confirmar que el día existe en ese mes (evita 31/02, etc.).
  const d = new Date(Date.UTC(year, month - 1, day));
  if (
    d.getUTCFullYear() !== year ||
    d.getUTCMonth() !== month - 1 ||
    d.getUTCDate() !== day
  ) {
    return null;
  }
  const mm = String(month).padStart(2, "0");
  const dd = String(day).padStart(2, "0");
  return `${year}-${mm}-${dd}`;
}

function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}
