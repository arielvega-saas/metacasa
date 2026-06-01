import type { Metadata } from "next";
import { CalendarClock } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listBills } from "@/lib/db/bills";
import { getCategories } from "@/lib/db/categories";
import { PageHeader } from "@/components/layout/page-header";
import { EmptyState } from "@/components/ui/empty-state";
import { BillsView } from "@/components/bills/bills-view";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("bills.title") };
}

/**
 * Pantalla de Vencimientos (server component): resuelve el hogar activo, trae
 * TODOS los vencimientos (cualquier estado) y las categorías para el alta, y
 * delega la UI/diálogos al view (que agrupa en vencidos / próximos / pagados).
 */
export default async function BillsPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return (
      <>
        <PageHeader
          title={t("bills.title")}
          description={t("bills.headerDescription")}
        />
        <EmptyState icon={CalendarClock} title={t("bills.needHousehold")} />
      </>
    );
  }

  const [bills, categories] = await Promise.all([
    listBills(supabase, active.id),
    getCategories(supabase, active.id),
  ]);

  return (
    <BillsView
      bills={bills}
      categories={categories.gastos ?? []}
      currency={active.default_currency}
    />
  );
}
