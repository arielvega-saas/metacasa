import type { Metadata } from "next";
import { Repeat } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listRecurring } from "@/lib/db/recurring";
import { listAccounts } from "@/lib/db/accounts";
import { getCategories } from "@/lib/db/categories";
import { PageHeader } from "@/components/layout/page-header";
import { EmptyState } from "@/components/ui/empty-state";
import { RecurringView } from "@/components/recurring/recurring-view";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("recurring.title") };
}

/**
 * Pantalla de Recurrentes (server component): resuelve el hogar activo, trae los
 * recurrentes (activos + pausados), las cuentas y las categorías para el alta, y
 * delega la UI/diálogos al view.
 */
export default async function RecurringPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return (
      <>
        <PageHeader
          title={t("recurring.title")}
          description={t("recurring.headerDescription")}
        />
        <EmptyState icon={Repeat} title={t("recurring.needHousehold")} />
      </>
    );
  }

  const [recurring, accounts, categories] = await Promise.all([
    listRecurring(supabase, active.id),
    listAccounts(supabase, active.id),
    getCategories(supabase, active.id),
  ]);

  return (
    <RecurringView
      recurring={recurring}
      accounts={accounts.map((a) => ({ id: a.id, name: a.name }))}
      categories={{
        gastos: categories.gastos ?? [],
        ingresos: categories.ingresos ?? [],
      }}
      currency={active.default_currency}
    />
  );
}
