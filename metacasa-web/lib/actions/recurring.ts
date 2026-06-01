"use server";

/**
 * Server Actions de Recurrentes (movimientos automáticos).
 * Toda mutación filtra por el hogar activo y confía en RLS para autorizar.
 * En cada alta seteamos `user_id` + `household_id` explícitos (igual que iOS).
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  createRecurring,
  updateRecurring,
  deleteRecurring,
  setRecurringActive,
  computeNextDate,
  isFrequency,
  type Frequency,
} from "@/lib/db/recurring";
import { TX_TYPE, type TxType } from "@/lib/constants";

/** Datos crudos del formulario (montos ya parseados a número en el client). */
export interface RecurringFormInput {
  type: TxType;
  amount: number;
  category: string;
  account?: string | null;
  frequency: Frequency;
  /** Fecha ISO "YYYY-MM-DD". */
  startDate: string;
  /** Fecha ISO "YYYY-MM-DD" o null si no termina. */
  endDate?: string | null;
  note?: string | null;
}

/** Refresca las vistas que muestran recurrentes. */
function revalidateRecurring() {
  revalidatePath("/recurring");
  revalidatePath("/dashboard");
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

/** Valida la forma del input (RLS valida pertenencia; esto valida dominio). */
async function validate(form: RecurringFormInput) {
  const t = await getT();
  if (!Number.isFinite(form.amount) || form.amount <= 0) {
    throw new Error(t("errors.transactionAmountPositive"));
  }
  if (!form.category?.trim()) throw new Error(t("errors.chooseCategory"));
  if (form.type !== TX_TYPE.EXPENSE && form.type !== TX_TYPE.INCOME) {
    throw new Error(t("errors.invalidTxType"));
  }
  if (!isFrequency(form.frequency)) {
    throw new Error(t("errors.invalidTxType"));
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(form.startDate)) {
    throw new Error(t("errors.transactionAmountPositive"));
  }
}

/** Redondeo a 2 decimales evitando errores de coma flotante. */
function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Crea un recurrente nuevo. `next_date` se siembra como `start_date` (iOS). */
export async function createRecurringAction(form: RecurringFormInput) {
  await validate(form);
  const { supabase, userId, householdId } = await requireContext();

  await createRecurring(supabase, {
    household_id: householdId,
    user_id: userId,
    type: form.type,
    amount: round2(form.amount),
    category: form.category.trim(),
    account: form.account?.trim() || null,
    frequency: form.frequency,
    start_date: form.startDate,
    end_date: form.endDate || null,
    next_date: form.startDate,
    note: form.note?.trim() || null,
    active: true,
  });
  revalidateRecurring();
}

/** Edita un recurrente existente. Recalcula `next_date` desde la nueva fecha. */
export async function updateRecurringAction(
  id: string,
  form: RecurringFormInput,
) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  await validate(form);
  const { supabase, householdId } = await requireContext();

  await updateRecurring(supabase, id, householdId, {
    type: form.type,
    amount: round2(form.amount),
    category: form.category.trim(),
    account: form.account?.trim() || null,
    frequency: form.frequency,
    start_date: form.startDate,
    end_date: form.endDate || null,
    next_date: computeNextDateOrStart(form.startDate, form.frequency),
    note: form.note?.trim() || null,
  });
  revalidateRecurring();
}

/**
 * `next_date` al editar: si la fecha de inicio sigue siendo futura/hoy la
 * conservamos como próxima; si ya pasó, avanzamos una vez según la frecuencia
 * (espejo del avance de iOS `Frequency.nextDate`).
 */
function computeNextDateOrStart(startDate: string, frequency: Frequency): string {
  const todayISO = new Date().toISOString().slice(0, 10);
  if (startDate >= todayISO) return startDate;
  return computeNextDate(startDate, frequency);
}

/** Activa / pausa un recurrente. */
export async function setRecurringActiveAction(id: string, active: boolean) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  const { supabase, householdId } = await requireContext();
  await setRecurringActive(supabase, id, householdId, active);
  revalidateRecurring();
}

/** Elimina un recurrente (con confirmación en la UI). */
export async function deleteRecurringAction(id: string) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  const { supabase, householdId } = await requireContext();
  await deleteRecurring(supabase, id, householdId);
  revalidateRecurring();
}
