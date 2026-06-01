"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  type HouseholdStrategy,
  type DistributionMode,
  DISTRIBUTION_MODES,
  serializeStrategy,
} from "@/lib/db/strategy";

/**
 * Persiste la estrategia Waterfall del hogar activo en `households.strategy`.
 *
 * TWIN de iOS `HouseholdService.updateStrategy` (HouseholdService.swift:123-130):
 * escribe el jsonb con las MISMAS 7 claves snake_case (vía `serializeStrategy`),
 * así que cambiar la estrategia desde la web no corrompe el jsonb para la app.
 *
 * Guard: solo owner/admin pueden editar (mismo criterio que las mutaciones de
 * hogar en `lib/actions/profile.ts`). RLS además exige membresía; acá agregamos
 * el guard explícito de rol con un error claro localizado.
 */
export async function updateStrategy(input: {
  savingsPct: number;
  investmentPct: number;
  distributionMode: DistributionMode;
  includeBillsInWaterfall: boolean;
  includeInstallmentsInWaterfall: boolean;
  includeDebtPaymentsInWaterfall: boolean;
  /** Allocations custom por cuenta (UUID → monto). Solo relevante si mode == "custom". */
  customAllocations?: Record<string, number>;
}): Promise<void> {
  const t = await getT();
  const supabase = await createClient();

  // 1) Resolver hogar activo (mismo helper que el resto de la app).
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));
  const householdId = active.id;

  // 2) Guard de rol: owner/admin. RLS ya filtra por membresía; esto da el error
  //    claro y bloquea a member/viewer antes de tocar la DB.
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionInvalid"));

  const { data: me } = await supabase
    .from("household_members")
    .select("role")
    .eq("household_id", householdId)
    .eq("user_id", user.id)
    .maybeSingle();
  if (!me) throw new Error(t("errors.noHousehold"));
  if (me.role !== "owner" && me.role !== "admin") {
    throw new Error(t("strategy.permissionError"));
  }

  // 3) Validar porcentajes (0–100 y suma ≤ 100). Si están fuera de rango se
  //    rechaza con un mensaje claro en vez de guardar basura.
  const savingsPct = Number(input.savingsPct);
  const investmentPct = Number(input.investmentPct);
  if (
    !Number.isFinite(savingsPct) ||
    !Number.isFinite(investmentPct) ||
    savingsPct < 0 ||
    savingsPct > 100 ||
    investmentPct < 0 ||
    investmentPct > 100
  ) {
    throw new Error(t("strategy.invalidPct"));
  }
  if (savingsPct + investmentPct > 100) {
    throw new Error(t("strategy.sumTooHigh"));
  }

  if (!DISTRIBUTION_MODES.includes(input.distributionMode)) {
    throw new Error(t("strategy.invalidMode"));
  }

  // 4) Sanear customAllocations (UUID → número finito ≥ 0). Solo escribimos las
  //    claves que iOS ya usa (forma byte-compatible).
  const customAllocations: Record<string, number> = {};
  for (const [key, val] of Object.entries(input.customAllocations ?? {})) {
    const num = Number(val);
    if (Number.isFinite(num) && num >= 0) customAllocations[key] = num;
  }

  const strategy: HouseholdStrategy = {
    savingsPct,
    investmentPct,
    distributionMode: input.distributionMode,
    customAllocations,
    includeBillsInWaterfall: Boolean(input.includeBillsInWaterfall),
    includeInstallmentsInWaterfall: Boolean(input.includeInstallmentsInWaterfall),
    includeDebtPaymentsInWaterfall: Boolean(input.includeDebtPaymentsInWaterfall),
  };

  // 5) Escribir el jsonb exacto. RLS revalida la membresía a nivel fila.
  const { error } = await supabase
    .from("households")
    .update({ strategy: serializeStrategy(strategy) })
    .eq("id", householdId);
  if (error) throw new Error(error.message);

  revalidatePath("/budgets");
}
