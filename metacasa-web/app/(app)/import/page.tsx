import type { Metadata } from "next";
import { Upload } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listAccounts } from "@/lib/db/accounts";
import { getCategories } from "@/lib/db/categories";
import { PageHeader } from "@/components/layout/page-header";
import { EmptyState } from "@/components/ui/empty-state";
import { ImportFlow } from "@/components/import/import-flow";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("importTools.metaTitle") };
}

/** Importación masiva de movimientos desde Excel/CSV con mapeo por IA. */
export default async function ImportPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return (
      <>
        <PageHeader
          title={t("importTools.title")}
          description={t("importTools.description")}
        />
        <EmptyState
          icon={Upload}
          title={t("importTools.noHouseholdTitle")}
          description={t("importTools.noHouseholdDescription")}
        />
      </>
    );
  }

  const [accounts, categories] = await Promise.all([
    listAccounts(supabase, active.id),
    getCategories(supabase, active.id),
  ]);

  return (
    <div>
      <PageHeader
        title={t("importTools.title")}
        description={t("importTools.description")}
      />
      <ImportFlow
        baseCurrency={active.default_currency}
        accounts={accounts.map((a) => ({ id: a.id, name: a.name }))}
        expenseCategories={categories.gastos ?? []}
        incomeCategories={categories.ingresos ?? []}
      />
    </div>
  );
}
