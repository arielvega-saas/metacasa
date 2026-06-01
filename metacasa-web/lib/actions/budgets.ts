"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
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
 */
export async function createMonthlyPeriod() {
  const t = await getT();
  const supabase = await createClient();
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth(); // 0-based
  const pad = (n: number) => String(n).padStart(2, "0");
  // Último día del mes: día 0 del mes siguiente.
  const lastDay = new Date(year, month + 1, 0).getDate();
  const periodStart = `${year}-${pad(month + 1)}-01`;
  const periodEnd = `${year}-${pad(month + 1)}-${pad(lastDay)}`;

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
