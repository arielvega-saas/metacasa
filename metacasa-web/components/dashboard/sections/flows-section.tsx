import { FlowsChart } from "@/components/dashboard/flows-chart";
import { createClient } from "@/lib/supabase/server";
import { getMonthlyFlows } from "@/lib/db/transactions";
import { getT } from "@/lib/i18n/server";

/**
 * Gráfico de flujos de los últimos 6 meses. Sección async: `getMonthlyFlows`
 * agrega media docena de meses de movimientos, así que se transmite aparte
 * mientras el shell ya pintó el encabezado de la card.
 */
export async function FlowsSection({
  householdId,
  currency,
}: {
  householdId: string;
  currency: string;
}) {
  const supabase = await createClient();
  const [flows, t] = await Promise.all([
    getMonthlyFlows(supabase, householdId, 6),
    getT(),
  ]);

  return (
    <FlowsChart
      data={flows}
      currency={currency}
      incomeLabel={t("dashboard.flowsIncome")}
      expenseLabel={t("dashboard.flowsExpense")}
      emptyLabel={t("dashboard.flowsEmpty")}
    />
  );
}
