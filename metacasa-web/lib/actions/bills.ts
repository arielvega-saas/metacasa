"use server";

/**
 * Server Actions de Vencimientos (bills).
 * Toda mutación filtra por el hogar activo y confía en RLS para autorizar.
 * En cada alta seteamos `user_id`, `household_id`, `currency` y el trío FX
 * (`amount_original`, `currency_original`, `fx_rate_to_base`). Sin conversión,
 * `amount` = `amount_original`, `currency_original` = `currency`, `fx` = 1.
 *
 * Paridad iOS (`BillService.markPaid`): "marcar pagado" SOLO cambia el `status`
 * a `paid` — NO inserta ningún movimiento. El schema vivo de `bills` no tiene
 * `paid_at`, así que tampoco escribimos timestamp.
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  createBill,
  updateBill,
  deleteBill,
  setBillStatus,
  type BillStatus,
} from "@/lib/db/bills";

/** Datos crudos del formulario (monto ya parseado a número en el client). */
export interface BillFormInput {
  title: string;
  amount: number;
  category: string;
  /** Fecha ISO "YYYY-MM-DD". */
  dueDate: string;
  currency: string;
  /** Días de aviso previo (default 3, igual que el schema). */
  reminderDays?: number;
  /** Tipo de recurrencia (texto libre, opcional). */
  recurrenceType?: string | null;
}

/** Refresca las vistas que muestran vencimientos. */
function revalidateBills() {
  revalidatePath("/bills");
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
  return {
    supabase,
    userId: user.id,
    householdId: active.id,
    baseCurrency: active.default_currency as string,
  };
}

/** Redondeo a 2 decimales evitando errores de coma flotante. */
function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Normaliza días de aviso al rango 0-60 (default 3). */
function clampReminder(days?: number): number {
  if (!Number.isFinite(days)) return 3;
  return Math.min(60, Math.max(0, Math.round(days as number)));
}

/** Valida la forma del input. */
async function validate(form: BillFormInput) {
  const t = await getT();
  if (!form.title?.trim()) throw new Error(t("errors.nameEmpty"));
  if (!Number.isFinite(form.amount) || form.amount <= 0) {
    throw new Error(t("errors.transactionAmountPositive"));
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(form.dueDate)) {
    throw new Error(t("errors.transactionAmountPositive"));
  }
}

/** Crea un vencimiento nuevo. */
export async function createBillAction(form: BillFormInput) {
  await validate(form);
  const { supabase, userId, householdId, baseCurrency } = await requireContext();

  const currency = (form.currency || baseCurrency).toUpperCase();
  const amount = round2(form.amount);

  await createBill(supabase, {
    household_id: householdId,
    user_id: userId,
    title: form.title.trim(),
    amount,
    category: form.category?.trim() || "",
    due_date: form.dueDate,
    status: "pending",
    currency,
    reminder_days: clampReminder(form.reminderDays),
    recurrence_type: form.recurrenceType?.trim() || null,
    // Trío FX: sin conversión, el monto base coincide con el original.
    amount_original: amount,
    currency_original: currency,
    fx_rate_to_base: 1,
  });
  revalidateBills();
}

/** Edita un vencimiento existente. */
export async function updateBillAction(id: string, form: BillFormInput) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  await validate(form);
  const { supabase, householdId, baseCurrency } = await requireContext();

  const currency = (form.currency || baseCurrency).toUpperCase();
  const amount = round2(form.amount);

  await updateBill(supabase, id, householdId, {
    title: form.title.trim(),
    amount,
    category: form.category?.trim() || "",
    due_date: form.dueDate,
    currency,
    reminder_days: clampReminder(form.reminderDays),
    recurrence_type: form.recurrenceType?.trim() || null,
    amount_original: amount,
    currency_original: currency,
    fx_rate_to_base: 1,
  });
  revalidateBills();
}

/**
 * Cambia el estado de un vencimiento (marcar pagado / pendiente). Espeja iOS:
 * solo actualiza `status`, no crea movimiento ni escribe `paid_at`.
 */
export async function setBillStatusAction(id: string, status: BillStatus) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  const { supabase, householdId } = await requireContext();
  await setBillStatus(supabase, id, householdId, status);
  revalidateBills();
}

/** Elimina un vencimiento (con confirmación en la UI). */
export async function deleteBillAction(id: string) {
  const t = await getT();
  if (!id) throw new Error(t("errors.missingTxId"));
  const { supabase, householdId } = await requireContext();
  await deleteBill(supabase, id, householdId);
  revalidateBills();
}
