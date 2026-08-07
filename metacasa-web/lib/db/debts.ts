import type { Client } from "@/lib/supabase/types";
import type { Tables, TablesInsert, TablesUpdate } from "@/lib/database.types";
import { convertToBase, type FXRateMap } from "@/lib/fx";
import { parseDayLocal } from "@/lib/i18n/dates";

export type Debt = Tables<"debts">;

/**
 * Lista las deudas del hogar. Paridad con iOS `DebtService.fetchAll`
 * (`Core/DebtService.swift`): ordena por `created_at` descendente y, por
 * defecto, incluye también las saldadas (`status = 'settled'`). RLS filtra por
 * pertenencia al hogar.
 */
export async function listDebts(
  supabase: Client,
  householdId: string,
  opts: { includeSettled?: boolean } = {},
): Promise<Debt[]> {
  const includeSettled = opts.includeSettled ?? true;
  let q = supabase.from("debts").select("*").eq("household_id", householdId);
  if (!includeSettled) q = q.eq("status", "active");
  const { data, error } = await q.order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}

/**
 * Progreso pagado (0–1) de una deuda. Puerto directo de iOS `Debt.progress`
 * (`Models/Debt.swift`): `(original - current) / original`, acotado a [0,1].
 */
export function debtProgress(debt: Debt): number {
  const original = Number(debt.original_amount);
  if (!(original > 0)) return 0;
  const paid = original - Number(debt.current_balance);
  const ratio = paid / original;
  return Math.min(Math.max(0, ratio), 1);
}

/**
 * Interés mensual estimado sobre el saldo actual. Puerto de iOS
 * `Debt.estimatedMonthlyInterest`: `current_balance * annual_rate / 100 / 12`.
 */
export function estimatedMonthlyInterest(debt: Debt): number {
  return (Number(debt.current_balance) * Number(debt.annual_rate)) / 100 / 12;
}

/**
 * Meses estimados hasta saldo cero asumiendo `monthly_payment` constante y
 * aplicando interés mensual. Puerto 1:1 de iOS `Debt.estimatedMonthsToPayoff`:
 * devuelve `null` si no hay pago, si el pago no cubre el interés (nunca termina)
 * o si supera 600 meses.
 */
export function estimatedMonthsToPayoff(debt: Debt): number | null {
  const pay = debt.monthly_payment != null ? Number(debt.monthly_payment) : 0;
  if (!(pay > 0)) return null;
  const start = Number(debt.current_balance);
  let balance = start;
  const monthlyRate = Number(debt.annual_rate) / 100 / 12;
  let months = 0;
  while (balance > 0 && months < 600) {
    const interest = balance * monthlyRate;
    balance += interest - pay;
    months += 1;
    if (balance >= start && interest >= pay) {
      // El pago no cubre el interés — nunca se salda.
      return null;
    }
  }
  return months < 600 ? months : null;
}

/**
 * Días restantes hasta el vencimiento (puede ser negativo si ya venció).
 * Puerto de iOS `Debt.daysUntilMaturity`. `null` si no hay fecha de vencimiento.
 */
export function daysUntilMaturity(debt: Debt, now: Date = new Date()): number | null {
  if (!debt.maturity_date) return null;
  // `parseDayLocal` y no `new Date(str)`: un "2026-08-06" se interpreta como
  // medianoche UTC, y leer después `getFullYear/getMonth/getDate` en hora local
  // lo corre un día para atrás en todo huso negativo — o sea, toda LatAm. Una
  // deuda que vence HOY aparecía en rojo con el badge "Vencida" el día entero.
  // El helper ya existía y se usa cuatro líneas más abajo en `debt-card` para
  // mostrar la misma fecha: era la misma regla escrita dos veces, con distinto
  // resultado.
  const due = parseDayLocal(debt.maturity_date);
  const MS_PER_DAY = 24 * 60 * 60 * 1000;
  // Comparamos a medianoche local para contar días de calendario.
  const a = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const b = new Date(due.getFullYear(), due.getMonth(), due.getDate());
  return Math.round((b.getTime() - a.getTime()) / MS_PER_DAY);
}

/** Total de deuda activa, consolidado a moneda base vía FX (paridad iOS). */
export interface DebtTotals {
  /** Σ `current_balance` de las deudas activas, en moneda base. */
  totalBalance: number;
  /** Σ `monthly_payment` de las deudas activas, en moneda base. */
  monthlyCommitment: number;
  /** `true` si alguna deuda activa quedó fuera por faltar su tasa FX. */
  hasUnconverted: boolean;
}

/**
 * Totales de deuda ACTIVA, consolidados a `base` con las tasas del hogar.
 * Paridad con iOS `DebtsListView.totalCard` (suma solo `status == .active`) y
 * con el criterio del dashboard: si falta la tasa de una moneda, esa deuda se
 * omite del agregado (no se suma a ciegas) y se marca `hasUnconverted`.
 */
export function debtTotals(
  debts: Debt[],
  base: string,
  rates: FXRateMap,
): DebtTotals {
  let totalBalance = 0;
  let monthlyCommitment = 0;
  let hasUnconverted = false;
  for (const d of debts) {
    if (d.status === "settled") continue;
    const cur = d.currency || base;
    const bal = convertToBase(Number(d.current_balance), cur, base, rates);
    if (bal == null) {
      hasUnconverted = true;
      continue;
    }
    totalBalance += bal;
    if (d.monthly_payment != null) {
      const pay = convertToBase(Number(d.monthly_payment), cur, base, rates);
      if (pay != null) monthlyCommitment += pay;
    }
  }
  return { totalBalance, monthlyCommitment, hasUnconverted };
}

/** Inserta una deuda nueva. RLS valida pertenencia al hogar. */
export async function createDebt(
  supabase: Client,
  input: TablesInsert<"debts">,
): Promise<Debt> {
  const { data, error } = await supabase
    .from("debts")
    .insert(input)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Actualiza los campos editables de una deuda. */
export async function updateDebt(
  supabase: Client,
  debtId: string,
  patch: TablesUpdate<"debts">,
): Promise<Debt> {
  const { data, error } = await supabase
    .from("debts")
    .update(patch)
    .eq("id", debtId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/**
 * Marca una deuda como saldada (paridad iOS `DebtService.settle`): `status =
 * 'settled'` y `current_balance = 0`. No borra historial.
 */
export async function settleDebt(supabase: Client, debtId: string): Promise<void> {
  const { error } = await supabase
    .from("debts")
    .update({ status: "settled", current_balance: 0 })
    .eq("id", debtId);
  if (error) throw error;
}

/** Borra una deuda (paridad iOS `DebtService.delete`). */
export async function deleteDebt(supabase: Client, debtId: string): Promise<void> {
  const { error } = await supabase.from("debts").delete().eq("id", debtId);
  if (error) throw error;
}
