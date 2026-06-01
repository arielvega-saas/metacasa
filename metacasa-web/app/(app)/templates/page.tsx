import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listTemplates } from "@/lib/db/templates";
import { getCategories } from "@/lib/db/categories";
import { TemplatesView } from "@/components/templates/templates-view";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("templates.title") };
}

/**
 * Pantalla de Atajos rápidos (plantillas) — server component. Resuelve el hogar
 * activo, trae las plantillas (orden por `position`) y las categorías para el
 * diálogo de alta/edición, y delega la UI al view.
 */
export default async function TemplatesPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return <p className="text-text-muted">{t("templates.needHousehold")}</p>;
  }

  const [templates, categories] = await Promise.all([
    listTemplates(supabase, active.id),
    getCategories(supabase, active.id),
  ]);

  return (
    <TemplatesView
      templates={templates}
      categories={{
        gastos: categories.gastos ?? [],
        ingresos: categories.ingresos ?? [],
      }}
      currency={active.default_currency}
    />
  );
}
