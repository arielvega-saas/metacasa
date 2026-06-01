import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import { PageHeader } from "@/components/layout/page-header";
import { ToolsView } from "@/components/tools/tools-view";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("tools.title") };
}

/**
 * Herramientas / Calculadoras financieras. Matemática 100 % client-side; el
 * server solo resuelve la moneda base del hogar para formatear los resultados.
 */
export default async function ToolsPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);
  const currency = active?.default_currency ?? "USD";

  return (
    <div>
      <PageHeader title={t("tools.title")} description={t("tools.description")} />
      <ToolsView currency={currency} />
    </div>
  );
}
