"use server";

/**
 * Server Action de Categorías. Guardamos el jsonb completo del hogar de una sola
 * vez (la UI maneja agregar/renombrar/eliminar en el cliente y persiste el set).
 * Revalidamos /categories y /dashboard (las categorías alimentan reportes/filtros).
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import { upsertCategories, type CategoryData } from "@/lib/db/categories";

/** Limpia y deduplica un listado de nombres de categoría. */
function sanitizeList(list: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of list) {
    const name = raw.trim();
    if (!name) continue;
    const key = name.toLowerCase();
    if (seen.has(key)) continue; // sin duplicados (case-insensitive)
    seen.add(key);
    out.push(name);
  }
  return out;
}

/** Persiste el set completo de categorías (gastos + ingresos) del hogar activo. */
export async function saveCategories(data: CategoryData): Promise<void> {
  const t = await getT();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionInvalid"));

  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  const clean: CategoryData = {
    gastos: sanitizeList(data.gastos ?? []),
    ingresos: sanitizeList(data.ingresos ?? []),
  };

  await upsertCategories(supabase, {
    userId: user.id,
    householdId: active.id,
    data: clean,
  });

  revalidatePath("/categories");
  revalidatePath("/dashboard");
}
