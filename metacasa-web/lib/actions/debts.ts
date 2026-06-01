"use server";

/**
 * Server Actions de Deudas. Toda mutación filtra por el hogar activo y confía en
 * RLS para autorizar. La data escrita respeta EXACTAMENTE el schema de la tabla
 * `debts` que consume iOS (`Core/DebtService.swift`). Tras escribir, revalidamos
 * /debts (lista + net worth) y /dashboard (donde se monta el net-worth card).
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  createDebt as dbCreateDebt,
  updateDebt as dbUpdateDebt,
  settleDebt as dbSettleDebt,
  deleteDebt as dbDeleteDebt,
} from "@/lib/db/debts";

/** Datos base que comparten alta y edición de deuda. */
export interface DebtInput {
  creditor: string;
  originalAmount: number;
  currentBalance: number;
  /** Tasa anual en porcentaje (ej. 45.5 = 45.5%). */
  annualRate: number;
  monthlyPayment?: number | null;
  /** ISO date (YYYY-MM-DD). */
  startDate: string;
  /** ISO date (YYYY-MM-DD) o null si no tiene vencimiento. */
  maturityDate?: string | null;
  category?: string | null;
  note?: string | null;
}

/** `true` si el string es una fecha ISO (YYYY-MM-DD) válida. */
function isValidISODate(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(s);
  return !Number.isNaN(d.getTime());
}

/** Resuelve hogar activo + usuario; lanza si falta alguno (sesión inválida). */
async function requireContext() {
  const t = await getT();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionInvalid"));
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));
  return {
    supabase,
    userId: user.id,
    householdId: active.id,
    currency: active.default_currency,
  };
}

/**
 * Valida y normaliza el input. La moneda NO la elige el usuario: como en iOS
 * (`AddDebtView.save` toma `household.defaultCurrency`), la deuda hereda la
 * moneda base del hogar. Devuelve los campos ya saneados.
 */
async function sanitize(input: DebtInput) {
  const t = await getT();

  const creditor = input.creditor.trim();
  if (!creditor) throw new Error(t("debts.errors.creditorRequired"));

  const originalAmount = Number(input.originalAmount);
  const currentBalance = Number(input.currentBalance);
  const annualRate = Number(input.annualRate);
  if (!(originalAmount > 0)) throw new Error(t("debts.errors.originalPositive"));
  if (!(currentBalance >= 0) || !Number.isFinite(currentBalance))
    throw new Error(t("debts.errors.balanceNonNegative"));
  if (!(annualRate >= 0) || !Number.isFinite(annualRate))
    throw new Error(t("debts.errors.rateNonNegative"));

  let monthlyPayment: number | null = null;
  if (input.monthlyPayment != null) {
    const mp = Number(input.monthlyPayment);
    if (mp > 0) monthlyPayment = mp;
    else if (mp < 0 || !Number.isFinite(mp))
      throw new Error(t("debts.errors.paymentNonNegative"));
  }

  if (!isValidISODate(input.startDate))
    throw new Error(t("debts.errors.invalidDate"));
  let maturityDate: string | null = null;
  if (input.maturityDate) {
    if (!isValidISODate(input.maturityDate))
      throw new Error(t("debts.errors.invalidDate"));
    if (new Date(input.maturityDate) < new Date(input.startDate))
      throw new Error(t("debts.errors.maturityBeforeStart"));
    maturityDate = input.maturityDate;
  }

  return {
    creditor,
    originalAmount,
    currentBalance,
    annualRate,
    monthlyPayment,
    startDate: input.startDate,
    maturityDate,
    category: input.category?.trim() || null,
    note: input.note?.trim() || null,
  };
}

/** Crea una deuda nueva, heredando la moneda base del hogar (paridad iOS). */
export async function createDebt(input: DebtInput): Promise<void> {
  const { supabase, userId, householdId, currency } = await requireContext();
  const v = await sanitize(input);

  await dbCreateDebt(supabase, {
    household_id: householdId,
    created_by: userId,
    creditor: v.creditor,
    original_amount: v.originalAmount,
    current_balance: v.currentBalance,
    annual_rate: v.annualRate,
    monthly_payment: v.monthlyPayment,
    currency,
    start_date: v.startDate,
    maturity_date: v.maturityDate,
    category: v.category,
    note: v.note,
    status: "active",
  });

  revalidatePath("/debts");
  revalidatePath("/dashboard");
}

/**
 * Actualiza una deuda. Espeja exactamente el `Patch` de iOS
 * `DebtService.update` (creditor, current_balance, annual_rate,
 * monthly_payment, maturity_date, category, note) y, como la web también edita
 * el monto original, lo incluimos.
 */
export async function updateDebt(debtId: string, input: DebtInput): Promise<void> {
  const { supabase } = await requireContext();
  const v = await sanitize(input);

  await dbUpdateDebt(supabase, debtId, {
    creditor: v.creditor,
    original_amount: v.originalAmount,
    current_balance: v.currentBalance,
    annual_rate: v.annualRate,
    monthly_payment: v.monthlyPayment,
    start_date: v.startDate,
    maturity_date: v.maturityDate,
    category: v.category,
    note: v.note,
  });

  revalidatePath("/debts");
  revalidatePath("/dashboard");
}

/** Marca una deuda como saldada (status='settled', saldo 0). Paridad iOS. */
export async function settleDebt(debtId: string): Promise<void> {
  const { supabase } = await requireContext();
  await dbSettleDebt(supabase, debtId);
  revalidatePath("/debts");
  revalidatePath("/dashboard");
}

/** Borra una deuda definitivamente (paridad iOS `DebtService.delete`). */
export async function deleteDebt(debtId: string): Promise<void> {
  const { supabase } = await requireContext();
  await dbDeleteDebt(supabase, debtId);
  revalidatePath("/debts");
  revalidatePath("/dashboard");
}
