import { ArrowDownLeft, ArrowUpRight } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Amount } from "@/components/finance/amount";
import { StatSparkline } from "@/components/dashboard/stat-sparkline";
import { createClient } from "@/lib/supabase/server";
import { getDailyFlowSparklines } from "@/lib/db/dashboard-extras";
import { getT } from "@/lib/i18n/server";
import { CHART } from "@/components/reports/chart-tokens";

/** Colores del design system para los sparklines (sage = ingreso, coral = gasto).
 *  Vía tokens: en tema claro el pastel se vuelve verde/terracota oscuros. */
const SPARK_INCOME = CHART.income;
const SPARK_EXPENSE = CHART.expense;

/**
 * Tendencia de 7 días (sparklines de ingreso/gasto). Sección async propia: su
 * query barre una ventana de transacciones y no tiene por qué frenar el pintado
 * del shell + KPIs. Si no hay ningún movimiento en la ventana no renderiza nada
 * (mismo criterio que iOS `StatsRow`).
 */
export async function SparklinesSection({
  householdId,
  currency,
}: {
  householdId: string;
  currency: string;
}) {
  const supabase = await createClient();
  const [sparklines, t] = await Promise.all([
    getDailyFlowSparklines(supabase, householdId, 7),
    getT(),
  ]);

  const hasData =
    sparklines.income.some((v) => v > 0) || sparklines.expense.some((v) => v > 0);
  if (!hasData) return null;

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4">
      <Card className="p-5">
        <div className="flex items-center justify-between gap-3">
          <span className="text-text-muted flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider">
            <ArrowDownLeft className="text-income size-3.5" />
            {t("dashboard.sparklineIncome")}
          </span>
          <Amount
            value={sparklines.income.reduce((s, v) => s + v, 0)}
            currency={currency}
            kind="ingreso"
            className="text-sm font-semibold"
          />
        </div>
        <div className="mt-3">
          <StatSparkline values={sparklines.income} color={SPARK_INCOME} />
        </div>
      </Card>
      <Card className="p-5">
        <div className="flex items-center justify-between gap-3">
          <span className="text-text-muted flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider">
            <ArrowUpRight className="text-expense size-3.5" />
            {t("dashboard.sparklineExpense")}
          </span>
          <Amount
            value={sparklines.expense.reduce((s, v) => s + v, 0)}
            currency={currency}
            kind="gasto"
            className="text-sm font-semibold"
          />
        </div>
        <div className="mt-3">
          <StatSparkline values={sparklines.expense} color={SPARK_EXPENSE} />
        </div>
      </Card>
    </div>
  );
}
