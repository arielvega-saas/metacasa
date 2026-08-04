"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  createTransaction,
  updateTransaction,
  deleteTransaction,
  bulkUpdateTransactions,
  type TxMutationInput,
  type BulkUpdateResult,
} from "@/lib/db/transactions";
import { TX_TYPE, type TxType } from "@/lib/constants";

/**
 * Datos crudos que manda el formulario (client). Montos como strings porque
 * vienen de inputs; acá se normalizan y se resuelve la moneda base del hogar.
 */
export interface TxFormInput {
  type: TxType;
  /** Monto tal cual lo escribió el usuario (en la moneda elegida). */
  amount: number;
  category: string;
  accountId?: string | null;
  /** Fecha ISO (YYYY-MM-DD). */
  date: string;
  note?: string | null;
  /** Moneda del movimiento. Si coincide con la base, fxRate se ignora. */
  currency: string;
  /** Tasa manual a moneda base (solo si currency != base). Default 1. */
  fxRate?: number;
}

/** Resuelve hogar activo + usuario y arma el input multi-moneda para la DB. */
async function buildContext(form: TxFormInput) {
  const t = await getT();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionExpired"));

  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  // Validaciones de dominio mínimas (RLS valida pertenencia; esto valida forma).
  if (!Number.isFinite(form.amount) || form.amount <= 0) {
    throw new Error(t("errors.transactionAmountPositive"));
  }
  if (!form.category?.trim()) {
    throw new Error(t("errors.chooseCategory"));
  }
  if (form.type !== TX_TYPE.EXPENSE && form.type !== TX_TYPE.INCOME) {
    throw new Error(t("errors.invalidTxType"));
  }

  const base = active.default_currency;
  const currency = (form.currency || base).toUpperCase();
  const sameCurrency = currency === base.toUpperCase();
  // Si la moneda coincide con la base: fx=1 y amount = amount_original.
  // Si difiere: amount (base) = amount_original * fx_rate_to_base.
  const fxRate = sameCurrency ? 1 : Number(form.fxRate) > 0 ? Number(form.fxRate) : 1;
  const amountOriginal = round2(form.amount);
  const amountBase = round2(amountOriginal * fxRate);

  const payload: TxMutationInput = {
    householdId: active.id,
    userId: user.id,
    type: form.type,
    amount: amountBase,
    category: form.category.trim(),
    accountId: form.accountId || null,
    date: form.date,
    note: form.note ?? null,
    amountOriginal,
    currencyOriginal: sameCurrency ? base : currency,
    fxRateToBase: fxRate,
  };

  return { supabase, payload };
}

/** Crea un movimiento nuevo. */
export async function createTransactionAction(form: TxFormInput) {
  const { supabase, payload } = await buildContext(form);
  await createTransaction(supabase, payload);
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
}

/** Edita un movimiento existente. */
export async function updateTransactionAction(id: string, form: TxFormInput) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  const { supabase, payload } = await buildContext(form);
  await updateTransaction(supabase, id, payload);
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
}

/** Elimina un movimiento (con confirmación en la UI). */
export async function deleteTransactionAction(id: string) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  const supabase = await createClient();
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));
  await deleteTransaction(supabase, id, active.id);
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
}

/**
 * Recategoriza varios movimientos de una. Es el verbo que sólo tiene sentido en la
 * compu: recategorizar 40 movimientos del súper después de importar un resumen.
 */
export async function bulkRecategorizeAction(
  ids: string[],
  category: string,
): Promise<BulkUpdateResult> {
  const t = await getT();
  const clean = category.trim();
  if (!clean) throw new Error(t("errors.missingCategory"));
  return runBulk(ids, { category: clean });
}

/** Mueve varios movimientos a otra cuenta. `null` los deja sin cuenta. */
export async function bulkSetAccountAction(
  ids: string[],
  accountId: string | null,
): Promise<BulkUpdateResult> {
  return runBulk(ids, { account_id: accountId });
}

/** Tronco común de las acciones en lote: resuelve hogar, escribe y revalida. */
async function runBulk(
  ids: string[],
  fields: Parameters<typeof bulkUpdateTransactions>[3],
): Promise<BulkUpdateResult> {
  const t = await getT();
  if (!ids.length) throw new Error(t("errors.missingTxId"));
  const supabase = await createClient();
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  const result = await bulkUpdateTransactions(supabase, ids, active.id, fields);
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  return result;
}

/** Redondeo a 2 decimales evitando errores de coma flotante. */
function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}
