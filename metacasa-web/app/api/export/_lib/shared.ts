import "server-only";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold, type Household } from "@/lib/household";
import { listTransactions, type Transaction } from "@/lib/db/transactions";
import { listAccounts } from "@/lib/db/accounts";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { lookup, interpolate } from "@/lib/i18n/lookup";
import { getLocale } from "@/lib/i18n/server";
import type { Locale } from "@/lib/i18n/config";
import { TX_TYPE, type TxType } from "@/lib/constants";

/**
 * Tope defensivo de filas para una exportación. No paginamos (queremos TODO el
 * resultado del filtro), pero acotamos para no agotar memoria del server con un
 * hogar enorme. 50k movimientos cubre años de uso intensivo de un hogar real.
 */
export const EXPORT_ROW_CAP = 50_000;

export type TFn = (key: string, vars?: Record<string, string | number>) => string;

/** `t()` sincrónico para route handlers (ya resolvimos el locale antes). */
export function makeT(locale: Locale): TFn {
  const dict = getDictionary(locale);
  return (key, vars) => interpolate(lookup(dict, key) ?? key, vars);
}

/** Contexto común de toda exportación: auth + hogar activo + locale + t(). */
export interface ExportContext {
  supabase: Awaited<ReturnType<typeof createClient>>;
  household: Household;
  locale: Locale;
  t: TFn;
  currency: string;
}

/**
 * Resuelve sesión + hogar activo + locale para una exportación. Devuelve
 * `{ error }` con el status HTTP correcto si falta sesión (401) o hogar (400),
 * para que el route handler corte temprano sin filtrar datos.
 */
export async function resolveExportContext(): Promise<
  { ctx: ExportContext } | { error: { status: number; message: string } }
> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return { error: { status: 401, message: "Unauthorized" } };
  }

  const { active } = await resolveActiveHousehold(supabase);
  if (!active) {
    return { error: { status: 400, message: "No active household" } };
  }

  const locale = await getLocale();
  return {
    ctx: {
      supabase,
      household: active,
      locale,
      t: makeT(locale),
      currency: active.default_currency ?? "USD",
    },
  };
}

/** Filtros de movimientos parseados desde los query params de la URL. */
export interface ParsedTxFilters {
  type?: TxType;
  category?: string;
  accountId?: string;
  from?: string;
  to?: string;
  search?: string;
  amountMin?: number;
  amountMax?: number;
}

/** Parsea un monto de la URL a número no-negativo (o undefined si inválido). */
function parseAmount(v: string | null): number | undefined {
  if (v == null || v.trim() === "") return undefined;
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : undefined;
}

/** Normaliza el tipo de la URL a un TxType válido (o undefined). */
function parseType(v: string | null): TxType | undefined {
  if (v === TX_TYPE.INCOME || v === TX_TYPE.EXPENSE) return v;
  return undefined;
}

/**
 * Lee los MISMOS query params que usa la página de Movimientos
 * (`from`, `to`, `type`, `category`, `account`, `q`, `min`, `max`) para que la
 * exportación coincida exactamente con lo que el usuario ve en pantalla.
 */
export function parseTxFilters(params: URLSearchParams): ParsedTxFilters {
  return {
    type: parseType(params.get("type")),
    category: params.get("category")?.trim() || undefined,
    accountId: params.get("account")?.trim() || undefined,
    from: params.get("from")?.trim() || undefined,
    to: params.get("to")?.trim() || undefined,
    search: params.get("q")?.trim() || undefined,
    amountMin: parseAmount(params.get("min")),
    amountMax: parseAmount(params.get("max")),
  };
}

/**
 * Trae TODOS los movimientos que matchean el filtro (sin paginar), hasta el tope
 * defensivo. Reutiliza `listTransactions` con un `limit` alto: no tocamos la
 * función compartida y respetamos RLS + hogar activo.
 */
export async function fetchAllTransactions(
  ctx: ExportContext,
  filters: ParsedTxFilters,
): Promise<Transaction[]> {
  const { rows } = await listTransactions(ctx.supabase, {
    householdId: ctx.household.id,
    ...filters,
    limit: EXPORT_ROW_CAP,
  });
  return rows;
}

/** Mapa id→nombre de cuenta del hogar, para resolver la cuenta de cada tx. */
export async function fetchAccountNameMap(
  ctx: ExportContext,
): Promise<Map<string, string>> {
  const accounts = await listAccounts(ctx.supabase, ctx.household.id);
  const map = new Map<string, string>();
  for (const a of accounts) map.set(a.id, a.name);
  return map;
}

/**
 * Monto con signo para exportación: GASTO negativo, INGRESO (y demás) positivo.
 * Es la convención que un usuario espera en una hoja de cálculo (SUM da el neto)
 * y espeja la semántica de balance de iOS (`AccountBalanceService`).
 */
export function signedAmount(tx: Pick<Transaction, "amount" | "type">): number {
  const n = Number(tx.amount);
  return tx.type === TX_TYPE.EXPENSE ? -Math.abs(n) : Math.abs(n);
}

/** Etiqueta localizada del tipo de movimiento (Ingreso / Gasto). */
export function typeLabel(type: string, t: TFn): string {
  return type === TX_TYPE.INCOME
    ? t("exportTools.sheet.typeIncome")
    : t("exportTools.sheet.typeExpense");
}

/**
 * Sanea un trozo de nombre de archivo: ASCII seguro, sin separadores de ruta ni
 * caracteres que rompan el header `Content-Disposition`. Solo lo usamos para el
 * sufijo de período (`YYYY-MM`), pero defendemos igual.
 */
export function safeFilePart(s: string): string {
  return s.replace(/[^a-zA-Z0-9._-]/g, "").slice(0, 40) || "export";
}

/** Sufijo `YYYY-MM` del mes actual (UTC) para el nombre del archivo de movimientos. */
export function currentYearMonth(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
}
