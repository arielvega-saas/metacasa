"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import { getToday } from "@/lib/today-server";
import { splitYm } from "@/lib/today";
import {
  createPeriod,
  upsertAllocation,
  deleteAllocation,
} from "@/lib/db/budget";

/** Refresca las vistas que dependen del presupuesto. */
function revalidateBudget() {
  revalidatePath("/budgets");
  revalidatePath("/dashboard");
}

/**
 * Crea el período de presupuesto del mes actual (envelope budgeting YNAB-style).
 * Calcula el rango [primer día, último día] del mes en curso.
 *
 * "Mes en curso" es el del CALENDARIO DEL USUARIO (cookie `mc_tz`), no el del
 * reloj del server: en Netlify corre en UTC y el 31 a las 21:05 en Argentina
 * esto creaba el período del mes SIGUIENTE, dejando huérfano el mes que el
 * usuario estaba mirando.
 */
export async function createMonthlyPeriod() {
  const t = await getT();
  const supabase = await createClient();
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  const [year, month] = splitYm(await getToday()); // month 1-12
  const pad = (n: number) => String(n).padStart(2, "0");
  // Último día del mes: día 0 del mes siguiente (en UTC, para no depender del
  // huso del proceso).
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const periodStart = `${year}-${pad(month)}-01`;
  const periodEnd = `${year}-${pad(month)}-${pad(lastDay)}`;

  await createPeriod(supabase, {
    householdId: active.id,
    periodType: "month",
    periodStart,
    periodEnd,
  });
  revalidateBudget();
}

/**
 * Crea o edita la asignación de un sobre (categoría) dentro del período.
 * RLS valida que el período pertenezca a un hogar del usuario.
 */
export async function saveAllocation(input: {
  periodId: string;
  category: string;
  allocated: number;
  currency: string;
}) {
  const t = await getT();
  if (!input.category.trim()) throw new Error(t("errors.chooseCategory"));
  if (!(input.allocated >= 0)) throw new Error(t("errors.invalidAmount"));

  const supabase = await createClient();
  await upsertAllocation(supabase, {
    periodId: input.periodId,
    category: input.category,
    allocated: input.allocated,
    currency: input.currency,
  });
  revalidateBudget();
}

/** Elimina una asignación (sobre) y resincroniza los totales del período. */
export async function removeAllocation(allocationId: string, periodId: string) {
  const supabase = await createClient();
  await deleteAllocation(supabase, allocationId, periodId);
  revalidateBudget();
}
