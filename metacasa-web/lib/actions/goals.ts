"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import { createGoal, updateGoal, addContribution } from "@/lib/db/goals";

/** Refresca las vistas que muestran metas. */
function revalidateGoals() {
  revalidatePath("/goals");
  revalidatePath("/dashboard");
}

/** Resuelve el usuario actual o falla (lo exige RLS en goals/contribuciones). */
async function requireUser() {
  const t = await getT();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionInvalid"));
  return { supabase, user };
}

/** Crea una meta de ahorro nueva en el hogar activo. */
export async function createGoalAction(input: {
  name: string;
  targetAmount: number;
  currentAmount?: number;
  currency: string;
  targetDate?: string | null;
  icon?: string | null;
}) {
  const t = await getT();
  if (!input.name.trim()) throw new Error(t("errors.goalNameRequired"));
  if (!(input.targetAmount > 0))
    throw new Error(t("errors.goalTargetPositive"));

  const { supabase, user } = await requireUser();
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  await createGoal(supabase, {
    householdId: active.id,
    createdBy: user.id,
    name: input.name.trim(),
    targetAmount: input.targetAmount,
    currentAmount: input.currentAmount,
    currency: input.currency,
    targetDate: input.targetDate,
    icon: input.icon,
  });
  revalidateGoals();
}

/** Edita los campos de una meta existente (no toca el monto acumulado). */
export async function updateGoalAction(
  goalId: string,
  input: {
    name: string;
    targetAmount: number;
    currency: string;
    targetDate?: string | null;
    icon?: string | null;
  },
) {
  const t = await getT();
  if (!input.name.trim()) throw new Error(t("errors.goalNameRequired"));
  if (!(input.targetAmount > 0))
    throw new Error(t("errors.goalTargetPositive"));

  const supabase = await createClient();
  await updateGoal(supabase, goalId, {
    name: input.name.trim(),
    target_amount: input.targetAmount,
    currency: input.currency,
    target_date: input.targetDate ?? null,
    icon: input.icon ?? null,
  });
  revalidateGoals();
}

/**
 * Agrega una contribución a la meta. El trigger de DB suma el monto al
 * `current_amount` y autocompleta si llega al objetivo: acá no sumamos a mano.
 */
export async function addContributionAction(input: {
  goalId: string;
  amount: number;
}) {
  const t = await getT();
  if (!(input.amount > 0)) throw new Error(t("errors.contributionPositive"));

  const { supabase, user } = await requireUser();
  await addContribution(supabase, {
    goalId: input.goalId,
    amount: input.amount,
    contributedBy: user.id,
  });
  revalidateGoals();
}

/** Marca una meta como completada manualmente. */
export async function completeGoalAction(goalId: string) {
  const supabase = await createClient();
  await updateGoal(supabase, goalId, {
    status: "completed",
    completed_at: new Date().toISOString(),
  });
  revalidateGoals();
}
