import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listAccountsWithBalance } from "@/lib/db/accounts";
import {
  getMonthSummary,
  getMonthlyFlows,
  listTransactions,
} from "@/lib/db/transactions";
import { upcomingBills } from "@/lib/db/bills";
import { listGoals } from "@/lib/db/goals";
import { listDebts, debtTotals } from "@/lib/db/debts";
import {
  getDailyFlowSparklines,
  getHouseholdSplitStrategy,
  getActiveTxDays,
} from "@/lib/db/dashboard-extras";
import { DashboardView } from "@/components/dashboard/dashboard-view";
import { getT } from "@/lib/i18n/server";
import { parseFxRates, convertToBase } from "@/lib/fx";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("dashboard.title") };
}

function pad(n: number) {
  return String(n).padStart(2, "0");
}

/** Clave "YYYY-MM-DD" (UTC) de un Date — alineada con las claves de `getActiveTxDays`. */
function utcDayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/**
 * Health Score 0–100 — puerto 1:1 de iOS `HomeViewModel.healthScore`:
 *  - savings rate (ingresos−gastos)/ingresos → hasta 50 pts (rate × 250, tope 50)
 *  - gasto/ingreso < 1 → hasta 30 pts ((1−ratio) × 30)
 *  - consistencia: días con movimiento en 30d → hasta 20 pts (días × 0.67)
 */
function computeHealthScore(
  income: number,
  expense: number,
  activeDays: Set<string>,
): number {
  let score = 0;
  if (income > 0) {
    const rate = Math.max(0, (income - expense) / income);
    score += Math.min(50, rate * 250);
    const ratio = expense / income;
    if (ratio < 1) score += (1 - ratio) * 30;
  }
  // Días con movimiento en los últimos 30 (el set ya viene acotado a 30d).
  score += Math.min(20, activeDays.size * 0.67);
  return Math.max(0, Math.min(100, Math.round(score)));
}

/**
 * Racha de días consecutivos (hacia atrás desde hoy) con al menos un movimiento.
 * Puerto de iOS `HomeViewModel.streak`. Trabaja en UTC sobre el set de días.
 */
function computeStreak(activeDays: Set<string>): number {
  let count = 0;
  const cursor = new Date();
  // Normalizamos a medianoche UTC para iterar día a día.
  cursor.setUTCHours(0, 0, 0, 0);
  while (activeDays.has(utcDayKey(cursor))) {
    count += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return count;
}

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ ym?: string }>;
}) {
  const sp = await searchParams;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    const t = await getT();
    return <p className="text-text-muted">{t("dashboard.noHousehold")}</p>;
  }

  const householdId = active.id;
  const currency = active.default_currency;

  const now = new Date();
  const ym =
    sp.ym && /^\d{4}-\d{2}$/.test(sp.ym)
      ? sp.ym
      : `${now.getFullYear()}-${pad(now.getMonth() + 1)}`;
  const [year, month] = ym.split("-").map(Number);
  const prev = new Date(year, month - 2, 1);

  const [
    accounts,
    summary,
    prevSummary,
    flows,
    recent,
    bills,
    goals,
    debtList,
    sparklines,
    splitStrategy,
    activeTxDays,
  ] = await Promise.all([
    listAccountsWithBalance(supabase, householdId),
    getMonthSummary(supabase, householdId, year, month),
    getMonthSummary(supabase, householdId, prev.getFullYear(), prev.getMonth() + 1),
    getMonthlyFlows(supabase, householdId, 6),
    listTransactions(supabase, { householdId, limit: 6 }),
    upcomingBills(supabase, householdId, 4),
    listGoals(supabase, householdId, { activeOnly: true, limit: 3 }),
    listDebts(supabase, householdId, { includeSettled: false }),
    getDailyFlowSparklines(supabase, householdId, 7),
    getHouseholdSplitStrategy(supabase, householdId),
    getActiveTxDays(supabase, householdId, 30),
  ]);

  // "Saldo total" consolida TODAS las cuentas en la moneda base del hogar usando
  // las tasas FX manuales (`households.fx_rates`), igual que el net worth de iOS
  // (`AccountBalanceService.netWorth` suma cada cuenta tras convertir con
  // `FXConverter`). Antes la web descartaba las cuentas que no estaban en la
  // moneda base, subreportando el total. Si falta la tasa de alguna moneda, esa
  // cuenta se omite del total (no la sumamos a ciegas en otra moneda) — mismo
  // criterio que iOS (`convert` devuelve nil → la cuenta no entra en el agregado).
  const fxRates = parseFxRates(active.fx_rates);
  const totalBalance = accounts.reduce((sum, a) => {
    const converted = convertToBase(a.balance, a.currency || currency, currency, fxRates);
    return converted == null ? sum : sum + converted;
  }, 0);

  // Patrimonio neto (paridad iOS `AccountBalanceService.netWorth` + nuestro
  // `debtTotals`):
  //   assets      = Σ saldos de cuenta POSITIVOS consolidados a base vía FX
  //   liabilities = Σ deudas activas (debtTotals) + Σ |saldos de cuenta NEGATIVOS|
  // Si falta la tasa de alguna moneda, esa cuenta/deuda se omite y marcamos
  // `hasUnconverted` (mismo criterio que `totalBalance` / `debtTotals`).
  let assets = 0;
  let negativeBalances = 0;
  let accountsUnconverted = false;
  for (const a of accounts) {
    const converted = convertToBase(a.balance, a.currency || currency, currency, fxRates);
    if (converted == null) {
      accountsUnconverted = true;
      continue;
    }
    if (converted >= 0) assets += converted;
    else negativeBalances += -converted; // |saldo negativo| → pasivo
  }
  const debts = debtTotals(debtList, currency, fxRates);
  const liabilities = debts.totalBalance + negativeBalances;
  const netWorth = assets - liabilities;
  const netWorthUnconverted = accountsUnconverted || debts.hasUnconverted;

  // Health Score (0–100) + racha — puerto 1:1 de iOS `HomeViewModel.healthScore`
  // / `streak`: savings rate (50%), gasto-vs-ingreso (30%), consistencia 30d (20%).
  const healthScore = computeHealthScore(summary.income, summary.expense, activeTxDays);
  const streak = computeStreak(activeTxDays);

  const name =
    (user?.user_metadata?.display_name as string) ||
    user?.email?.split("@")[0] ||
    "";
  const balanceDelta =
    prevSummary.balance !== 0
      ? Math.round(
          ((summary.balance - prevSummary.balance) / Math.abs(prevSummary.balance)) * 100,
        )
      : null;

  return (
    <DashboardView
      name={name}
      ym={ym}
      currency={currency}
      totalBalance={totalBalance}
      summary={summary}
      balanceDelta={balanceDelta}
      accounts={accounts}
      flows={flows}
      recent={recent.rows}
      bills={bills}
      goals={goals}
      netWorth={{
        assets,
        liabilities,
        net: netWorth,
        hasUnconverted: netWorthUnconverted,
      }}
      sparklines={sparklines}
      savingsSplit={{
        income: summary.income,
        savingsPercent: splitStrategy.savingsPercent,
        investmentPercent: splitStrategy.investmentPercent,
        configured: splitStrategy.configured,
      }}
      health={{ score: healthScore, streak }}
      householdId={householdId}
    />
  );
}
