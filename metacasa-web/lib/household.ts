import "server-only";
import { cache } from "react";
import { cookies } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { ACTIVE_HOUSEHOLD_COOKIE } from "@/lib/constants";
import type { Client } from "@/lib/supabase/types";
import type { Tables } from "@/lib/database.types";

export type Household = Tables<"households">;

/**
 * Hogares del usuario (RLS filtra). Deduplicado por request con React `cache`:
 * el layout y la page que ambos resuelven el hogar comparten una sola query.
 */
const cachedHouseholds = cache(async (): Promise<Household[]> => {
  const supabase = await createClient();
  const { data } = await supabase
    .from("households")
    .select("*")
    .order("created_at", { ascending: true });
  return data ?? [];
});

/** Compat: acepta (e ignora) un client; usa la versión cacheada por request. */
export async function getHouseholds(_supabase?: Client): Promise<Household[]> {
  return cachedHouseholds();
}

/**
 * Resuelve el hogar activo: el de la cookie si sigue siendo válido, si no el
 * más antiguo. Espeja la selección client-side de iOS (un hogar activo a la vez).
 */
export async function resolveActiveHousehold(_supabase?: Client): Promise<{
  households: Household[];
  active: Household | null;
}> {
  const households = await cachedHouseholds();
  if (households.length === 0) return { households, active: null };

  const cookieStore = await cookies();
  const wanted = cookieStore.get(ACTIVE_HOUSEHOLD_COOKIE)?.value;
  const active = households.find((h) => h.id === wanted) ?? households[0];
  return { households, active };
}
