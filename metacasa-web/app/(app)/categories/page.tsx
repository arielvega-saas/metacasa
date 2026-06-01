import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getCategories } from "@/lib/db/categories";
import {
  CategoriesView,
  DEFAULT_CATEGORIES,
} from "@/components/categories/categories-view";
import { getT } from "@/lib/i18n/server";

export const metadata: Metadata = { title: "Categorías" };

/**
 * Pantalla de Categorías (server component): trae el jsonb del hogar. Si está
 * vacío, propone un set por defecto razonable (que el usuario puede guardar).
 */
export default async function CategoriesPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return <p className="text-text-muted">{t("categories.needHousehold")}</p>;
  }

  const stored = await getCategories(supabase, active.id);
  const hasAny =
    (stored.gastos?.length ?? 0) > 0 || (stored.ingresos?.length ?? 0) > 0;

  // Si el hogar nunca configuró categorías, arrancamos desde el set sugerido.
  const initial = hasAny
    ? {
        gastos: stored.gastos ?? [],
        ingresos: stored.ingresos ?? [],
      }
    : DEFAULT_CATEGORIES;

  return <CategoriesView initial={initial} />;
}
