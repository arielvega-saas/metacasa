import type { Metadata } from "next";
import { Target } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listGoals } from "@/lib/db/goals";
import { PageHeader } from "@/components/layout/page-header";
import { EmptyState } from "@/components/ui/empty-state";
import { GoalsView } from "@/components/goals/goals-view";
import { GoalDialog } from "@/components/goals/goal-dialog";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("goals.title") };
}

export default async function GoalsPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return (
      <>
        <PageHeader
          title={t("goals.title")}
          description={t("goals.headerDescription")}
        />
        <EmptyState
          icon={Target}
          title={t("goals.needHouseholdTitle")}
          description={t("goals.needHouseholdDescription")}
        />
      </>
    );
  }

  const currency = active.default_currency;
  // Traemos todas las metas; el filtrado por tab (activas/completadas) es client-side.
  const goals = await listGoals(supabase, active.id);

  return (
    <>
      <PageHeader
        title={t("goals.title")}
        description={t("goals.headerDescription")}
        action={<GoalDialog defaultCurrency={currency} />}
      />
      <GoalsView goals={goals} defaultCurrency={currency} />
    </>
  );
}
