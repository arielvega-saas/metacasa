import { Target } from "lucide-react";
import { AnimatedProgressBar } from "@/components/motion/animated-progress-bar";
import { createClient } from "@/lib/supabase/server";
import { listGoals } from "@/lib/db/goals";
import { getT } from "@/lib/i18n/server";

/**
 * Metas activas del hogar con su barra de progreso. Sección async propia; las
 * barras crecen desde 0 cuando entran en viewport (`AnimatedProgressBar`).
 */
export async function GoalsSection({
  householdId,
  limit = 3,
}: {
  householdId: string;
  limit?: number;
}) {
  const supabase = await createClient();
  const [goals, t] = await Promise.all([
    listGoals(supabase, householdId, { activeOnly: true, limit }),
    getT(),
  ]);

  if (goals.length === 0) {
    return (
      <p className="text-text-dim py-2 text-sm">{t("dashboard.goalsEmpty")}</p>
    );
  }

  return (
    <div className="space-y-3.5">
      {goals.map((g) => {
        const target = Number(g.target_amount);
        const pct =
          target > 0
            ? Math.min(100, Math.round((Number(g.current_amount) / target) * 100))
            : 0;
        return (
          <div key={g.id}>
            <div className="mb-1.5 flex items-center justify-between text-sm">
              <span className="flex items-center gap-1.5 font-medium">
                <Target className="text-primary size-3.5" />
                {g.name}
              </span>
              <span className="text-text-muted tnum text-xs">{pct}%</span>
            </div>
            <AnimatedProgressBar
              value={pct}
              label={t("goals.progressAria", { pct, name: g.name })}
            />
          </div>
        );
      })}
    </div>
  );
}
