import type { Client } from "@/lib/supabase/types";
import type { Tables } from "@/lib/database.types";
import type { TxType } from "@/lib/constants";
import { inclusiveDateEnd } from "@/lib/db/date-range";

export type Transaction = Tables<"transactions">;

export interface TxFilters {
  householdId: string;
  from?: string;
  to?: string;
  type?: TxType;
  category?: string;
  accountId?: string;
  search?: string;
  /** Monto mínimo (sobre el `amount` base, valor absoluto). */
  amountMin?: number;
  /** Monto máximo (sobre el `amount` base, valor absoluto). */
  amountMax?: number;
  limit?: number;
  offset?: number;
}

/**
 * Escapa los comodines de `LIKE` (`%`, `_`) y el escape (`\`) en el término de
 * búsqueda, para que el usuario no pueda inyectar wildcards y el match sea
 * literal sobre la nota. PostgREST `.ilike` interpreta `%`/`_` como patrón.
 */
function escapeLike(term: string): string {
  return term.replace(/[\\%_]/g, (c) => `\\${c}`);
}

/**
 * Cadena de filtros de PostgREST, reducida a lo que usa este módulo. Tipar el
 * mínimo estructural (en vez de arrastrar los genéricos de
 * `PostgrestFilterBuilder`) permite aplicar los MISMOS filtros a consultas con
 * `select` distinto: la lista (`*` + count) y el agregado que le calcula los
 * totales (`amount, type`).
 */
interface TxFilterChain {
  gte(column: string, value: unknown): this;
  lte(column: string, value: unknown): this;
  eq(column: string, value: unknown): this;
  ilike(column: string, pattern: string): this;
}

/**
 * Aplica los filtros de `TxFilters` a una consulta ya scopeada al hogar.
 *
 * Existe —y se exporta— porque la lista y su total tienen que mirar EXACTAMENTE
 * el mismo conjunto: si el filtro se escribe dos veces, algún día uno de los dos
 * gana un `.eq(...)` que el otro no tiene y el pie de la pantalla contradice a
 * la lista que tiene justo arriba. Misma lección que `inclusiveDateEnd`, un
 * nivel más arriba: la regla tiene un nombre y un solo lugar.
 */
export function applyTxFilters<Q extends TxFilterChain>(q: Q, f: TxFilters): Q {
  let out = q;
  if (f.from) out = out.gte("date", f.from);
  // `inclusiveDateEnd` y no `f.to` crudo: las tx se guardan a mediodía UTC, así
  // que comparar contra la medianoche del último día lo excluía entero.
  if (f.to) out = out.lte("date", inclusiveDateEnd(f.to));
  if (f.type) out = out.eq("type", f.type);
  if (f.category) out = out.eq("category", f.category);
  if (f.accountId) out = out.eq("account_id", f.accountId);
  if (f.search) out = out.ilike("note", `%${escapeLike(f.search)}%`);
  // Filtro por monto sobre el `amount` base. Los montos se guardan como magnitud
  // positiva (el signo lo da `type`), así que comparamos directo contra `amount`.
  if (f.amountMin != null && Number.isFinite(f.amountMin)) {
    out = out.gte("amount", f.amountMin);
  }
  if (f.amountMax != null && Number.isFinite(f.amountMax)) {
    out = out.lte("amount", f.amountMax);
  }
  return out;
}

/** Lista transacciones con filtros avanzados + total count para paginar. */
export async function listTransactions(
  supabase: Client,
  f: TxFilters,
): Promise<{ rows: Transaction[]; count: number }> {
  let q = applyTxFilters(
    supabase.from("transactions").select("*", { count: "exact" }).eq("household_id", f.householdId),
    f,
  );

  q = q.order("date", { ascending: false });

  const offset = f.offset ?? 0;
  if (f.limit) q = q.range(offset, offset + f.limit - 1);

  const { data, error, count } = await q;
  if (error) throw error;
  return { rows: data ?? [], count: count ?? 0 };
}

/** Resumen ingresos/gastos/balance de un mes (year, month 1-12). */
export async function getMonthSummary(
  supabase: Client,
  householdId: string,
  year: number,
  month: number,
): Promise<{ income: number; expense: number; balance: number; count: number }> {
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month, 1));

  const { data, error } = await supabase
    .from("transactions")
    .select("amount, type")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .gte("date", start.toISOString())
    .lt("date", end.toISOString());
  if (error) throw error;

  let income = 0;
  let expense = 0;
  for (const t of data ?? []) {
    if (t.type === "INGRESO") income += Number(t.amount);
    else if (t.type === "GASTO") expense += Number(t.amount);
    // Otros tipos futuros no se cuentan como ingreso ni gasto.
  }
  return { income, expense, balance: income - expense, count: (data ?? []).length };
}

/** Flujos mensuales (ingreso/gasto) de los últimos N meses para el gráfico. */
export async function getMonthlyFlows(
  supabase: Client,
  householdId: string,
  months = 6,
): Promise<{ month: string; income: number; expense: number }[]> {
  // Anclamos TODO en UTC: las claves de bucket se derivan del año/mes UTC, igual
  // que el lookup (`t.date` slice "YYYY-MM"), que también es UTC. Antes el bucket
  // se armaba con un `Date` en hora LOCAL: bajo GMT-3 la "ventana" se corría y un
  // mes en el borde podía quedar fuera del rango o mapear a una clave distinta de
  // la del slice. Con ambos lados en UTC, las llaves coinciden siempre.
  const now = new Date();
  const startUtc = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - (months - 1), 1),
  );

  const { data, error } = await supabase
    .from("transactions")
    .select("amount, type, date")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .gte("date", startUtc.toISOString());
  if (error) throw error;

  const buckets = new Map<string, { income: number; expense: number }>();
  for (let i = 0; i < months; i++) {
    const d = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - (months - 1) + i, 1),
    );
    buckets.set(utcMonthKey(d), { income: 0, expense: 0 });
  }

  for (const t of data ?? []) {
    const key = String(t.date).slice(0, 7); // YYYY-MM (UTC, las tx se guardan a mediodía UTC)
    const b = buckets.get(key);
    if (!b) continue;
    if (t.type === "INGRESO") b.income += Number(t.amount);
    else if (t.type === "GASTO") b.expense += Number(t.amount);
    // Otros tipos futuros (p.ej. transferencias) no inflan ingresos ni gastos.
  }

  return Array.from(buckets.entries()).map(([month, v]) => ({ month, ...v }));
}

/** Gasto por categoría de un mes (top-down). */
export async function getCategoryBreakdown(
  supabase: Client,
  householdId: string,
  year: number,
  month: number,
): Promise<{ category: string; total: number }[]> {
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month, 1));

  const { data, error } = await supabase
    .from("transactions")
    .select("amount, category, type")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .eq("type", "GASTO")
    .gte("date", start.toISOString())
    .lt("date", end.toISOString());
  if (error) throw error;

  const totals = new Map<string, number>();
  for (const t of data ?? []) {
    const cat = t.category || "Otros";
    totals.set(cat, (totals.get(cat) ?? 0) + Number(t.amount));
  }

  return Array.from(totals.entries())
    .map(([category, total]) => ({ category, total }))
    .sort((a, b) => b.total - a.total);
}

/** Clave "YYYY-MM" derivada del año/mes UTC (consistente con el slice de `date`). */
function utcMonthKey(d: Date) {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

// ──────────────────────────────────────────────────────────────────────────
// Mutaciones (create / update / delete). Las usa la pantalla de Movimientos.
// El dashboard NO depende de estas; solo de las queries de arriba.
// ──────────────────────────────────────────────────────────────────────────

/**
 * Payload normalizado para crear/editar un movimiento. Los campos multi-moneda
 * ya vienen calculados por la server action (amount en moneda base del hogar).
 */
export interface TxMutationInput {
  householdId: string;
  userId: string;
  type: TxType;
  /** Monto en moneda BASE del hogar (amount_original * fx_rate_to_base). */
  amount: number;
  category: string;
  accountId?: string | null;
  /** Fecha ISO (YYYY-MM-DD o timestamp). */
  date: string;
  note?: string | null;
  /** Monto tal cual lo cargó el usuario, en currencyOriginal. */
  amountOriginal: number;
  currencyOriginal: string;
  /** Tasa a base (1 si la moneda coincide con la base). */
  fxRateToBase: number;
}

/**
 * Normaliza una fecha "YYYY-MM-DD" a mediodía UTC. Evita el off-by-one por zona
 * horaria: una fecha-sólo se guarda como medianoche UTC y, al mostrarse en
 * GMT-3 (Argentina) u otra zona negativa, se corría al día anterior ("Ayer").
 * Mediodía UTC mantiene el día correcto en cualquier zona de UTC-11 a UTC+11.
 *
 * Exportada para que la importación masiva use EXACTAMENTE la misma
 * estabilización de fecha que el alta individual (una sola fuente de verdad).
 */
export function toStableDate(date: string): string {
  return /^\d{4}-\d{2}-\d{2}$/.test(date) ? `${date}T12:00:00.000Z` : date;
}

/** Deriva period_year / period_month desde la fecha (para reportes). */
function periodFromDate(date: string): { period_year: number; period_month: number } {
  const d = new Date(toStableDate(date));
  return { period_year: d.getUTCFullYear(), period_month: d.getUTCMonth() + 1 };
}

/** Crea un movimiento. RLS valida pertenencia al hogar. */
export async function createTransaction(
  supabase: Client,
  input: TxMutationInput,
): Promise<Transaction> {
  const { period_year, period_month } = periodFromDate(input.date);
  const { data, error } = await supabase
    .from("transactions")
    .insert({
      household_id: input.householdId,
      user_id: input.userId,
      type: input.type,
      amount: input.amount,
      category: input.category,
      account_id: input.accountId ?? null,
      date: toStableDate(input.date),
      note: input.note?.trim() || null,
      amount_original: input.amountOriginal,
      currency_original: input.currencyOriginal,
      fx_rate_to_base: input.fxRateToBase,
      period_year,
      period_month,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Actualiza un movimiento existente. RLS valida pertenencia al hogar. */
export async function updateTransaction(
  supabase: Client,
  id: string,
  input: TxMutationInput,
): Promise<Transaction> {
  const { period_year, period_month } = periodFromDate(input.date);
  const { data, error } = await supabase
    .from("transactions")
    .update({
      type: input.type,
      amount: input.amount,
      category: input.category,
      account_id: input.accountId ?? null,
      date: toStableDate(input.date),
      note: input.note?.trim() || null,
      amount_original: input.amountOriginal,
      currency_original: input.currencyOriginal,
      fx_rate_to_base: input.fxRateToBase,
      period_year,
      period_month,
    })
    .eq("id", id)
    .eq("household_id", input.householdId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Elimina un movimiento. RLS valida pertenencia al hogar. */
export async function deleteTransaction(
  supabase: Client,
  id: string,
  householdId: string,
): Promise<void> {
  const { error } = await supabase
    .from("transactions")
    .delete()
    .eq("id", id)
    .eq("household_id", householdId);
  if (error) throw error;
}

/**
 * Inserción masiva de movimientos (importación Excel/CSV). Reutiliza EXACTAMENTE
 * la misma forma de columnas y la misma estabilización de fecha/período que
 * `createTransaction`, así la data queda 100% compatible con iOS. Inserta en
 * lotes para no mandar un único INSERT gigante; RLS valida pertenencia al hogar
 * en cada fila. Devuelve cuántas filas se insertaron.
 *
 * No filtra ni valida dominio: eso es responsabilidad de quien arma los
 * `TxMutationInput` (la server action `importTransactions`). Acá sólo mapeamos
 * 1:1 al shape de la tabla, igual que el alta individual.
 */
export async function bulkCreateTransactions(
  supabase: Client,
  inputs: TxMutationInput[],
  batchSize = 200,
): Promise<number> {
  if (inputs.length === 0) return 0;

  const toRow = (input: TxMutationInput) => {
    const { period_year, period_month } = periodFromDate(input.date);
    return {
      household_id: input.householdId,
      user_id: input.userId,
      type: input.type,
      amount: input.amount,
      category: input.category,
      account_id: input.accountId ?? null,
      date: toStableDate(input.date),
      note: input.note?.trim() || null,
      amount_original: input.amountOriginal,
      currency_original: input.currencyOriginal,
      fx_rate_to_base: input.fxRateToBase,
      period_year,
      period_month,
    };
  };

  let inserted = 0;
  for (let i = 0; i < inputs.length; i += batchSize) {
    const chunk = inputs.slice(i, i + batchSize).map(toRow);
    const { data, error } = await supabase
      .from("transactions")
      .insert(chunk)
      .select("id");
    if (error) throw error;
    inserted += data?.length ?? 0;
  }
  return inserted;
}

/** Campos que la edición en lote puede tocar. Deliberadamente NO incluye dinero. */
export type BulkEditableFields = {
  category?: string;
  account_id?: string | null;
};

export interface BulkUpdateResult {
  /** Filas efectivamente modificadas. */
  updated: number;
  /** Seleccionadas que se saltearon por ser piernas de una transferencia. */
  skippedTransfers: number;
}

/**
 * Edición en lote de movimientos. Sólo toca categoría y cuenta: **ningún campo de
 * dinero, moneda o fecha**. Cambiar montos en masa no tiene caso de uso real y sí
 * tiene forma de desastre silencioso, así que no está.
 *
 * Las **transferencias quedan afuera**. Una transferencia son dos filas atadas por
 * `transfer_group_id`, y las dos piernas son el mecanismo: recategorizar una, o
 * mandarla a otra cuenta, deja el par describiendo un movimiento de dinero que no
 * ocurrió y descuadra los saldos por cuenta. Se saltean y se devuelve cuántas
 * fueron, para que la UI lo diga en vez de fingir que se aplicó a todas.
 *
 * RLS valida pertenencia al hogar, y además se filtra por `household_id` explícito
 * (defensa en profundidad, igual que el resto del módulo).
 */
export async function bulkUpdateTransactions(
  supabase: Client,
  ids: string[],
  householdId: string,
  fields: BulkEditableFields,
  batchSize = 200,
): Promise<BulkUpdateResult> {
  if (ids.length === 0 || Object.keys(fields).length === 0) {
    return { updated: 0, skippedTransfers: 0 };
  }

  // Cuáles de las seleccionadas son transferencias. Se pregunta antes de escribir:
  // el UPDATE no puede distinguirlas si no se las excluye por id.
  const { data: transfers, error: transferError } = await supabase
    .from("transactions")
    .select("id")
    .in("id", ids)
    .eq("household_id", householdId)
    .not("transfer_group_id", "is", null);
  if (transferError) throw transferError;

  const transferIds = new Set((transfers ?? []).map((r) => r.id));
  const editable = ids.filter((id) => !transferIds.has(id));
  if (editable.length === 0) {
    return { updated: 0, skippedTransfers: transferIds.size };
  }

  let updated = 0;
  for (let i = 0; i < editable.length; i += batchSize) {
    const chunk = editable.slice(i, i + batchSize);
    const { data, error } = await supabase
      .from("transactions")
      .update(fields)
      .in("id", chunk)
      .eq("household_id", householdId)
      .select("id");
    if (error) throw error;
    updated += data?.length ?? 0;
  }

  return { updated, skippedTransfers: transferIds.size };
}
