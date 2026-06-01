"use server";

/**
 * Server Actions de Plantillas (atajos rápidos / quick-add).
 * Toda mutación filtra por el hogar activo y confía en RLS para autorizar.
 * En cada alta seteamos `created_by` + `household_id` explícitos (igual que iOS
 * `TemplateService.create`, que pasa `created_by: userId`).
 *
 * `applyTemplate` es la pieza central: a diferencia de iOS (que prellena el form
 * de alta), acá creamos un movimiento REAL con fecha de HOY, reutilizando el
 * mismo insert canónico que el alta individual (`createTransaction` de
 * `lib/db/transactions.ts`), de modo que la data queda 100% compatible con iOS.
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  createTemplateRow,
  updateTemplateRow,
  deleteTemplateRow,
  getTemplateRow,
} from "@/lib/db/templates";
import { createTransaction, toStableDate } from "@/lib/db/transactions";
import { TX_TYPE, type TxType } from "@/lib/constants";

/** Datos crudos del formulario de plantilla (monto ya parseado en el client). */
export interface TemplateFormInput {
  name: string;
  emoji?: string | null;
  type: TxType;
  amount: number;
  currency: string;
  category: string;
  subcategory?: string | null;
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
  return { supabase, userId: user.id, household: active };
}

/** Valida la forma del input (RLS valida pertenencia; esto valida dominio). */
async function validate(form: TemplateFormInput) {
  const t = await getT();
  if (!form.name?.trim()) throw new Error(t("templates.errors.nameRequired"));
  if (!Number.isFinite(form.amount) || form.amount <= 0) {
    throw new Error(t("errors.transactionAmountPositive"));
  }
  if (!form.category?.trim()) throw new Error(t("errors.chooseCategory"));
  if (form.type !== TX_TYPE.EXPENSE && form.type !== TX_TYPE.INCOME) {
    throw new Error(t("errors.invalidTxType"));
  }
}

/** Redondeo a 2 decimales evitando errores de coma flotante. */
function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Refresca las vistas que dependen de plantillas y/o movimientos. */
function revalidateTemplates() {
  revalidatePath("/templates");
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
}

/** Crea una plantilla nueva. `position` se autocalcula al final de la lista. */
export async function createTemplate(form: TemplateFormInput): Promise<void> {
  await validate(form);
  const { supabase, userId, household } = await requireContext();

  await createTemplateRow(supabase, {
    household_id: household.id,
    created_by: userId,
    name: form.name.trim(),
    emoji: form.emoji?.trim() || null,
    type: form.type,
    amount: round2(form.amount),
    currency: (form.currency || household.default_currency).toUpperCase(),
    category: form.category.trim(),
    subcategory: form.subcategory?.trim() || null,
    note: form.note?.trim() || null,
  });
  revalidateTemplates();
}

/** Edita una plantilla existente. RLS valida pertenencia al hogar. */
export async function updateTemplate(
  id: string,
  form: TemplateFormInput,
): Promise<void> {
  const t = await getT();
  if (!id) throw new Error(t("templates.errors.missingId"));
  await validate(form);
  const { supabase, household } = await requireContext();

  await updateTemplateRow(supabase, id, household.id, {
    name: form.name.trim(),
    emoji: form.emoji?.trim() || null,
    type: form.type,
    amount: round2(form.amount),
    currency: (form.currency || household.default_currency).toUpperCase(),
    category: form.category.trim(),
    subcategory: form.subcategory?.trim() || null,
    note: form.note?.trim() || null,
  });
  revalidateTemplates();
}

/** Elimina una plantilla (con confirmación en la UI). */
export async function deleteTemplate(id: string): Promise<void> {
  const t = await getT();
  if (!id) throw new Error(t("templates.errors.missingId"));
  const { supabase, household } = await requireContext();
  await deleteTemplateRow(supabase, id, household.id);
  revalidateTemplates();
}

/**
 * Aplica una plantilla: crea un movimiento REAL con fecha de HOY a partir de
 * ella. Reutiliza EXACTAMENTE el insert canónico (`createTransaction`), con la
 * misma forma de columnas multi-moneda que el alta individual y la importación,
 * para que la data sea idéntica a la que produce iOS:
 *
 *   - `amount`           = monto base positivo (el signo lo da `type`).
 *   - `amount_original`  = mismo monto (la plantilla guarda el monto tal cual).
 *   - `currency_original`= moneda de la plantilla.
 *   - `fx_rate_to_base`  = 1 (las plantillas se crean en la moneda base del
 *                          hogar — ver iOS `saveCurrentAsTemplate` —, así que no
 *                          hay conversión; coincide con el contrato del brief).
 *   - `date`             = HOY, estabilizada a mediodía UTC vía `toStableDate`.
 *
 * Devuelve el nombre de la plantilla aplicada (para el toast "movimiento creado").
 */
export async function applyTemplate(templateId: string): Promise<string> {
  const t = await getT();
  if (!templateId) throw new Error(t("templates.errors.missingId"));
  const { supabase, userId, household } = await requireContext();

  const tpl = await getTemplateRow(supabase, templateId, household.id);
  if (!tpl) throw new Error(t("templates.errors.notFound"));

  const type: TxType =
    tpl.type === TX_TYPE.INCOME ? TX_TYPE.INCOME : TX_TYPE.EXPENSE;
  const amount = round2(Number(tpl.amount));
  // Fecha de HOY en formato YYYY-MM-DD (la estabiliza createTransaction a UTC).
  const today = new Date().toISOString().slice(0, 10);

  await createTransaction(supabase, {
    householdId: household.id,
    userId,
    type,
    amount,
    category: tpl.category,
    // La tabla `transactions` no tiene `subcategory`; la plegamos en la nota si
    // no hay nota propia (igual que iOS, que arrastra subcategory al form pero
    // el guardado del movimiento usa category + note).
    accountId: null,
    date: toStableDate(today),
    note: tpl.note?.trim() || tpl.subcategory?.trim() || null,
    amountOriginal: amount,
    currencyOriginal: tpl.currency,
    fxRateToBase: 1,
  });

  revalidateTemplates();
  return tpl.name;
}
