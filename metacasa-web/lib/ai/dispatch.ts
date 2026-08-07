import "server-only";

import type { Client } from "@/lib/supabase/types";
import { TX_TYPE, type TxType } from "@/lib/constants";
import { formatMoney } from "@/lib/money";
import { getCategories } from "@/lib/db/categories";
import { listAccountsWithBalance, defaultAccountId } from "@/lib/db/accounts";
import {
  listTransactions,
  createTransaction,
  updateTransaction,
  deleteTransaction,
  type TxFilters,
  type TxMutationInput,
} from "@/lib/db/transactions";
import { getFilteredTotals } from "@/lib/db/transfer-exclusion";
import { isKnownTool, type ToolName } from "@/lib/ai/tools";

/**
 * Ejecuta las tools que pide el modelo contra la base, con RLS.
 *
 * ─── REGLA DE SEGURIDAD CENTRAL ────────────────────────────────────────────
 * El `householdId` y el `userId` vienen SIEMPRE del `ToolContext` que arma el
 * route handler a partir de la sesión (`auth.getUser` + `resolveActiveHousehold`).
 * NUNCA de `input`. Si el modelo (o algo inyectado en la conversación) manda un
 * `householdId`, `household_id` o `userId`, se ignora: acá no se leen esas
 * claves en ningún lado. Además cada mutación filtra por `household_id` explícito
 * y RLS valida pertenencia del lado de Postgres (defensa en profundidad).
 *
 * Las tools nunca lanzan: un error se devuelve como `tool_result` con
 * `isError`, para que el modelo pueda explicárselo al usuario en vez de tumbar
 * el turno entero.
 */

/** Identidad y hogar resueltos server-side. Único origen de verdad del scope. */
export interface ToolContext {
  /** Hogar activo del usuario (cookie + RLS). Jamás sale del modelo. */
  householdId: string;
  /** Usuario autenticado. Jamás sale del modelo. */
  userId: string;
  /** Moneda base del hogar: en ella se expresan los montos de las tools. */
  currency: string;
  /**
   * El día de calendario del usuario (`YYYY-MM-DD`), mandado por el browser y
   * validado en el route. Es el default de fecha de las altas. No se calcula
   * acá porque el server corre en UTC: con su reloj, todo lo que se cargara
   * después de las 21 en Argentina quedaba fechado mañana.
   */
  today: string;
}

/** Resultado de una tool, listo para volver como bloque `tool_result`. */
export interface ToolOutcome {
  /** Texto que ve el modelo. */
  content: string;
  /** `true` → se manda `is_error` en el bloque. */
  isError?: boolean;
  /** `true` si escribió en la base (el route revalida las páginas). */
  mutated?: boolean;
}

const MAX_QUERY_LIMIT = 50;
const DEFAULT_QUERY_LIMIT = 20;

// ──────────────────────────────────────────────────────────────────────────
// Lectura defensiva del input del modelo (viene como JSON arbitrario).
// ──────────────────────────────────────────────────────────────────────────

function asRecord(input: unknown): Record<string, unknown> {
  return input && typeof input === "object" && !Array.isArray(input)
    ? (input as Record<string, unknown>)
    : {};
}

/** String no vacío, trimmeado y acotado. `undefined` si no vino o vino vacío. */
function optString(rec: Record<string, unknown>, key: string, max = 200): string | undefined {
  const v = rec[key];
  if (typeof v !== "string") return undefined;
  const trimmed = v.trim();
  return trimmed ? trimmed.slice(0, max) : undefined;
}

/** Número finito. Acepta también el string numérico que a veces emite el modelo. */
function optNumber(rec: Record<string, unknown>, key: string): number | undefined {
  const v = rec[key];
  const n = typeof v === "number" ? v : typeof v === "string" ? Number(v.trim()) : NaN;
  return Number.isFinite(n) ? n : undefined;
}

/**
 * Normaliza el tipo de movimiento. Acepta los valores canónicos (GASTO/INGRESO)
 * y los equivalentes en inglés que el modelo a veces produce, porque las
 * descripciones de las tools están en inglés.
 */
function parseTxType(raw: string | undefined): TxType | undefined {
  if (!raw) return undefined;
  const v = raw.trim().toUpperCase();
  if (v === "GASTO" || v === "EXPENSE") return TX_TYPE.EXPENSE;
  if (v === "INGRESO" || v === "INCOME") return TX_TYPE.INCOME;
  return undefined;
}

/** Fecha `YYYY-MM-DD` válida (y real: descarta 2026-02-31). */
function parseIsoDate(raw: string | undefined): string | undefined {
  if (!raw || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) return undefined;
  const [y, m, d] = raw.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  const ok = dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d;
  return ok ? raw : undefined;
}


/** UUID v4-ish. Filtra basura antes de mandarla a Postgres (evita 22P02). */
function isUuid(v: string | undefined): v is string {
  return !!v && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
}

function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/**
 * Ajusta la categoría a la grafía que ya usa el hogar cuando hay un match
 * insensible a mayúsculas y acentos ("alimentacion" → "Alimentación"). Sin
 * esto, el asistente iría creando variantes de la misma categoría y los
 * reportes se fragmentarían. Si no matchea nada, se respeta lo que dijo el
 * modelo (la columna es texto libre, igual que en iOS).
 */
async function normalizeCategory(
  supabase: Client,
  householdId: string,
  category: string,
): Promise<string> {
  const fold = (s: string) =>
    s
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "") // marcas de acento combinantes
      .toLowerCase()
      .trim();

  try {
    const cats = await getCategories(supabase, householdId);
    const all = [...(cats.gastos ?? []), ...(cats.ingresos ?? [])];
    const target = fold(category);
    return all.find((c) => fold(c) === target) ?? category;
  } catch {
    return category;
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Dispatcher
// ──────────────────────────────────────────────────────────────────────────

/**
 * Ejecuta una tool por nombre. `input` es el JSON crudo del bloque `tool_use`:
 * se valida acá, no se confía en él.
 */
export async function dispatchTool(
  supabase: Client,
  name: string,
  input: unknown,
  ctx: ToolContext,
): Promise<ToolOutcome> {
  if (!isKnownTool(name)) {
    return { content: `Unknown tool "${name}".`, isError: true };
  }

  const rec = asRecord(input);
  const tool: ToolName = name;

  try {
    switch (tool) {
      case "query_transactions":
        return await runQueryTransactions(supabase, rec, ctx);
      case "add_transaction":
        return await runAddTransaction(supabase, rec, ctx);
      case "update_transaction":
        return await runUpdateTransaction(supabase, rec, ctx);
      case "delete_transaction":
        return await runDeleteTransaction(supabase, rec, ctx);
      case "get_accounts":
        return await runGetAccounts(supabase, ctx);
    }
  } catch {
    // Nunca propagamos el error crudo de Postgres al modelo (puede traer
    // detalles del schema). Mensaje corto y accionable.
    return {
      content: `The "${tool}" operation could not be completed. Tell the user it failed and suggest trying again in a moment.`,
      isError: true,
    };
  }
}

// ── query_transactions ────────────────────────────────────────────────────

async function runQueryTransactions(
  supabase: Client,
  rec: Record<string, unknown>,
  ctx: ToolContext,
): Promise<ToolOutcome> {
  const rawLimit = optNumber(rec, "limit");
  const limit = Math.min(
    Math.max(Math.trunc(rawLimit ?? DEFAULT_QUERY_LIMIT) || DEFAULT_QUERY_LIMIT, 1),
    MAX_QUERY_LIMIT,
  );

  // La cota inclusiva del último día la aplica `applyTxFilters` —el filtro que
  // comparten la lista y su agregado— vía `inclusiveDateEnd`. Acá se pasa la
  // fecha tal cual: compensar de nuevo sería otra copia de la misma regla, y las
  // copias divergen.
  const filters: TxFilters = {
    householdId: ctx.householdId, // ← server-side, nunca del modelo
    from: parseIsoDate(optString(rec, "dateFrom")),
    to: parseIsoDate(optString(rec, "dateTo")),
    type: parseTxType(optString(rec, "type")),
    category: optString(rec, "category"),
    search: optString(rec, "noteContains"),
    amountMin: optNumber(rec, "amountMin"),
    amountMax: optNumber(rec, "amountMax"),
  };

  // Dos consultas con EL MISMO filtro y propósitos distintos:
  //  - la lista es una muestra acotada (`limit`), para que el modelo pueda citar
  //    movimientos concretos y sus ids;
  //  - los totales se agregan en Postgres sobre el filtro COMPLETO y sin las
  //    piernas de transferencia.
  // Sumar las filas de la página era responder "gasté $340.000 en julio" cuando
  // esas eran las 20 primeras de 86, y encima contando la plata que el usuario
  // sólo movió entre cuentas propias.
  const [{ rows, count }, totals] = await Promise.all([
    listTransactions(supabase, { ...filters, limit }),
    getFilteredTotals(supabase, filters),
  ]);

  if (rows.length === 0) {
    return { content: "No transactions matched those filters." };
  }

  const lines = rows.map((r) => {
    const note = r.note ? ` · ${r.note}` : "";
    return `- ${String(r.date).slice(0, 10)} · ${r.type} · ${r.category} · ${formatMoney(
      Number(r.amount),
      ctx.currency,
    )}${note} · id=${r.id}`;
  });

  const header =
    count > rows.length
      ? `Showing ${rows.length} of ${count} matching transactions (amounts in ${ctx.currency}):`
      : `${rows.length} matching transaction(s) (amounts in ${ctx.currency}):`;

  const totalsLine =
    `Totals over the FULL filter (every matching movement, not just the ones listed above) — ` +
    `income: ${formatMoney(totals.income, ctx.currency)}, expenses: ${formatMoney(
      totals.expense,
      ctx.currency,
    )}. Transfers between the household's own accounts are excluded: that money never left the ` +
    `household. Use these totals when answering "how much did I spend/earn"; never add up the ` +
    `listed rows yourself.`;

  return { content: [header, ...lines, "", totalsLine].join("\n") };
}

// ── add_transaction ───────────────────────────────────────────────────────

async function runAddTransaction(
  supabase: Client,
  rec: Record<string, unknown>,
  ctx: ToolContext,
): Promise<ToolOutcome> {
  const type = parseTxType(optString(rec, "type"));
  if (!type) {
    return { content: "Invalid 'type'. Use 'GASTO' (expense) or 'INGRESO' (income).", isError: true };
  }

  const amount = optNumber(rec, "amount");
  if (amount === undefined || amount <= 0) {
    return { content: "Invalid 'amount'. It must be a positive number.", isError: true };
  }

  const rawCategory = optString(rec, "category", 80);
  if (!rawCategory) {
    return { content: "Missing 'category'. Ask the user which category to use.", isError: true };
  }
  const category = await normalizeCategory(supabase, ctx.householdId, rawCategory);

  const rawDate = optString(rec, "date");
  if (rawDate && !parseIsoDate(rawDate)) {
    return { content: "Invalid 'date'. Use yyyy-MM-dd.", isError: true };
  }
  const date = parseIsoDate(rawDate) ?? ctx.today;

  // Multi-moneda: las tools operan en la moneda BASE del hogar (paridad con
  // iOS, que tampoco expone moneda en add_transaction) → fx = 1.
  const amountBase = round2(amount);
  const payload: TxMutationInput = {
    householdId: ctx.householdId, // ← server-side, nunca del modelo
    userId: ctx.userId, // ← server-side, nunca del modelo
    type,
    amount: amountBase,
    category,
    // Sin cuenta, el movimiento no mueve ningún saldo: queda "del hogar" y las
    // cuentas siguen mostrando el número viejo. Es la misma cuenta por defecto
    // que usa iOS cuando el asistente carga un gasto (`AIToolHandler`).
    accountId: await defaultAccountId(supabase, ctx.householdId),
    date,
    note: optString(rec, "note", 500) ?? null,
    amountOriginal: amountBase,
    currencyOriginal: ctx.currency,
    fxRateToBase: 1,
  };

  const created = await createTransaction(supabase, payload);

  return {
    mutated: true,
    content: `Created ${type} of ${formatMoney(amountBase, ctx.currency)} in "${category}" dated ${date}${
      payload.note ? ` (note: ${payload.note})` : ""
    }. id=${created.id}. Confirm this to the user in one short line.`,
  };
}

// ── update_transaction ────────────────────────────────────────────────────

async function runUpdateTransaction(
  supabase: Client,
  rec: Record<string, unknown>,
  ctx: ToolContext,
): Promise<ToolOutcome> {
  const id = optString(rec, "transactionId", 64);
  if (!isUuid(id)) {
    return {
      content: "Invalid 'transactionId'. Use query_transactions first to get the real UUID.",
      isError: true,
    };
  }

  // Se lee la fila existente para hacer un merge real: `updateTransaction`
  // reescribe todas las columnas, así que sin esto un update parcial borraría
  // los campos no enviados.
  const { data: existing, error } = await supabase
    .from("transactions")
    .select("*")
    .eq("id", id)
    .eq("household_id", ctx.householdId) // ← scope server-side
    .maybeSingle();
  if (error) throw error;
  if (!existing) {
    return { content: "That transaction does not exist in this household.", isError: true };
  }
  if (existing.transfer_group_id) {
    return {
      content:
        "That movement is one leg of a transfer between accounts. Editing a single leg would leave account balances inconsistent — tell the user to edit it from the Transactions screen.",
      isError: true,
    };
  }

  const newType = parseTxType(optString(rec, "type"));
  if (optString(rec, "type") && !newType) {
    return { content: "Invalid 'type'. Use 'GASTO' or 'INGRESO'.", isError: true };
  }

  const newAmount = optNumber(rec, "amount");
  if (newAmount !== undefined && newAmount <= 0) {
    return { content: "Invalid 'amount'. It must be a positive number.", isError: true };
  }

  const rawDate = optString(rec, "date");
  if (rawDate && !parseIsoDate(rawDate)) {
    return { content: "Invalid 'date'. Use yyyy-MM-dd.", isError: true };
  }

  const rawCategory = optString(rec, "category", 80);
  const category = rawCategory
    ? await normalizeCategory(supabase, ctx.householdId, rawCategory)
    : existing.category;

  // Se conserva la moneda y la tasa originales de la fila: el monto que edita
  // el asistente es el de la moneda en que se cargó, y el `amount` base se
  // recalcula con esa misma tasa (no se re-inventa el FX).
  const fxRate = Number(existing.fx_rate_to_base) > 0 ? Number(existing.fx_rate_to_base) : 1;
  const currencyOriginal = existing.currency_original ?? ctx.currency;
  const amountOriginal = round2(
    newAmount ?? Number(existing.amount_original ?? existing.amount),
  );

  const noteRaw = rec["note"];
  const note =
    typeof noteRaw === "string" ? (noteRaw.trim().slice(0, 500) || null) : existing.note;

  const payload: TxMutationInput = {
    householdId: ctx.householdId, // ← server-side, nunca del modelo
    userId: existing.user_id,
    type: (newType ?? (existing.type as TxType)) as TxType,
    amount: round2(amountOriginal * fxRate),
    category,
    accountId: existing.account_id,
    date: parseIsoDate(rawDate) ?? String(existing.date),
    note,
    amountOriginal,
    currencyOriginal,
    fxRateToBase: fxRate,
  };

  const updated = await updateTransaction(supabase, id, payload);

  return {
    mutated: true,
    content: `Updated transaction ${updated.id}: ${payload.type} · ${
      payload.category
    } · ${formatMoney(payload.amount, ctx.currency)} · ${String(payload.date).slice(
      0,
      10,
    )}. Confirm this to the user in one short line.`,
  };
}

// ── delete_transaction ────────────────────────────────────────────────────

async function runDeleteTransaction(
  supabase: Client,
  rec: Record<string, unknown>,
  ctx: ToolContext,
): Promise<ToolOutcome> {
  const id = optString(rec, "transactionId", 64);
  if (!isUuid(id)) {
    return {
      content: "Invalid 'transactionId'. Use query_transactions first to get the real UUID.",
      isError: true,
    };
  }

  // Se lee antes de borrar para (a) poder describir qué se borró y (b) frenar
  // el borrado de una pierna suelta de transferencia.
  const { data: existing, error } = await supabase
    .from("transactions")
    .select("id, type, amount, category, date, transfer_group_id")
    .eq("id", id)
    .eq("household_id", ctx.householdId) // ← scope server-side
    .maybeSingle();
  if (error) throw error;
  if (!existing) {
    return { content: "That transaction does not exist in this household.", isError: true };
  }
  if (existing.transfer_group_id) {
    return {
      content:
        "That movement is one leg of a transfer between accounts. Deleting a single leg would leave account balances inconsistent — tell the user to delete it from the Transactions screen.",
      isError: true,
    };
  }

  await deleteTransaction(supabase, id, ctx.householdId);

  return {
    mutated: true,
    content: `Deleted the ${existing.type} of ${formatMoney(
      Number(existing.amount),
      ctx.currency,
    )} in "${existing.category}" dated ${String(existing.date).slice(
      0,
      10,
    )}. Confirm this to the user in one short line.`,
  };
}

// ── get_accounts ──────────────────────────────────────────────────────────

async function runGetAccounts(supabase: Client, ctx: ToolContext): Promise<ToolOutcome> {
  const accounts = await listAccountsWithBalance(supabase, ctx.householdId);
  if (accounts.length === 0) {
    return { content: "This household has no accounts yet." };
  }

  const lines = accounts.map(
    (a) =>
      `- ${a.name} · ${a.type} · ${formatMoney(a.balance, a.currency || ctx.currency)} · id=${a.id}`,
  );
  return { content: [`${accounts.length} active account(s):`, ...lines].join("\n") };
}
