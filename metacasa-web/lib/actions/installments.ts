"use server";

/**
 * Server Actions de Cuotas (installment plans).
 * Toda mutación filtra por el hogar activo y confía en RLS para autorizar.
 * Tras escribir, revalidamos /installments.
 *
 * Paridad con iOS (`InstallmentService.swift`):
 *  - `createPlan` inserta el plan y siembra las N filas de `installment_payments`
 *    (reparto parejo, períodos consecutivos desde start_year/start_month).
 *  - `markInstallmentPaid` SOLO marca `paid=true` + `paid_at` (igual que iOS, que
 *    llama `markPaymentPaid` con `transactionId` opcional = nil por defecto). NO
 *    crea una transacción: las cuotas no generan movimientos automáticos en
 *    ninguno de los dos clientes.
 *  - `deletePlan` borra el plan; el ledger se va por ON DELETE CASCADE.
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  createPlanRow,
  seedPayments,
  setPaymentPaid,
  deletePlanRow,
} from "@/lib/db/installments";

/** Datos de alta de un plan en cuotas. */
export interface PlanInput {
  name: string;
  totalAmount: number;
  totalInstallments: number;
  currency: string;
  startYear: number;
  startMonth: number;
  category?: string | null;
  accountId?: string | null;
  note?: string | null;
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
  return { supabase, userId: user.id, householdId: active.id };
}

/**
 * Crea un plan en cuotas y siembra su ledger de pagos. Mismo flujo que iOS:
 * insert del plan → `seedPayments` con reparto parejo del total.
 */
export async function createPlan(input: PlanInput): Promise<void> {
  const t = await getT();
  const name = input.name.trim();
  if (!name) throw new Error(t("installments.nameRequired"));
  if (!(input.totalAmount > 0)) throw new Error(t("installments.amountRequired"));
  const count = Math.trunc(input.totalInstallments);
  if (!(count >= 1)) throw new Error(t("installments.installmentsRequired"));

  const { supabase, userId, householdId } = await requireContext();

  const plan = await createPlanRow(supabase, {
    household_id: householdId,
    created_by: userId,
    name,
    total_amount: input.totalAmount,
    total_installments: count,
    currency: input.currency,
    start_year: input.startYear,
    start_month: input.startMonth,
    category: input.category?.trim() || null,
    account_id: input.accountId || null,
    note: input.note?.trim() || null,
  });

  await seedPayments(supabase, plan);

  revalidatePath("/installments");
}

/**
 * Marca una cuota como pagada. No crea transacción (paridad con iOS).
 * RLS valida pertenencia al hogar a través del plan.
 */
export async function markInstallmentPaid(paymentId: string): Promise<void> {
  const { supabase } = await requireContext();
  await setPaymentPaid(supabase, paymentId, true);
  revalidatePath("/installments");
}

/** Desmarca una cuota (vuelve a pendiente y limpia paid_at). */
export async function unmarkInstallmentPaid(paymentId: string): Promise<void> {
  const { supabase } = await requireContext();
  await setPaymentPaid(supabase, paymentId, false);
  revalidatePath("/installments");
}

/** Elimina un plan en cuotas. El ledger se borra por ON DELETE CASCADE. */
export async function deletePlan(planId: string): Promise<void> {
  const { supabase } = await requireContext();
  await deletePlanRow(supabase, planId);
  revalidatePath("/installments");
}
