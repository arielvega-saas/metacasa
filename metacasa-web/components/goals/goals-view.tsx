"use client";

import * as React from "react";
import { Target } from "lucide-react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { EmptyState } from "@/components/ui/empty-state";
import { GoalCard } from "@/components/goals/goal-card";
import { GoalDialog } from "@/components/goals/goal-dialog";
import { useT } from "@/components/i18n/locale-provider";
import type { Tables } from "@/lib/database.types";

type GoalTab = "active" | "completed" | "all";

interface GoalsViewProps {
  goals: Tables<"goals">[];
  defaultCurrency: string;
}

/** Vista de metas con tabs (activas / completadas / todas) y grilla de cards. */
export function GoalsView({ goals, defaultCurrency }: GoalsViewProps) {
  const t = useT();
  const [tab, setTab] = React.useState<GoalTab>("active");

  const active = goals.filter((g) => g.status === "active");
  const completed = goals.filter((g) => g.status === "completed");

  const visible =
    tab === "active" ? active : tab === "completed" ? completed : goals;

  return (
    <Tabs value={tab} onValueChange={(v) => setTab(v as GoalTab)}>
      <TabsList>
        <TabsTrigger value="active">
          {t("goals.tabActive", { n: active.length })}
        </TabsTrigger>
        <TabsTrigger value="completed">
          {t("goals.tabCompleted", { n: completed.length })}
        </TabsTrigger>
        <TabsTrigger value="all">
          {t("goals.tabAll", { n: goals.length })}
        </TabsTrigger>
      </TabsList>

      <TabsContent value={tab}>
        {visible.length === 0 ? (
          <EmptyState
            icon={Target}
            title={
              tab === "completed"
                ? t("goals.emptyCompletedTitle")
                : tab === "active"
                  ? t("goals.emptyActiveTitle")
                  : t("goals.emptyAllTitle")
            }
            description={
              tab === "completed"
                ? t("goals.emptyCompletedDescription")
                : t("goals.emptyDefaultDescription")
            }
            action={
              tab === "completed" ? undefined : (
                <GoalDialog defaultCurrency={defaultCurrency} />
              )
            }
          />
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {visible.map((goal) => (
              <GoalCard
                key={goal.id}
                goal={goal}
                defaultCurrency={defaultCurrency}
              />
            ))}
          </div>
        )}
      </TabsContent>
    </Tabs>
  );
}
