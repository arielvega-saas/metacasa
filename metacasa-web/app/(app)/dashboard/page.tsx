import { Suspense } from "react";
import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listAccountsWithBalance } from "@/lib/db/accounts";
import { getMonthSummary } from "@/lib/db/transactions";
import { DashboardView } from "@/components/dashboard/dashboard-view";
import { SparklinesSection } from "@/components/dashboard/sections/sparklines-section";
import { InsightsSection } from "@/components/dashboard/sections/insights-section";
import { OverviewSection } from "@/components/dashboard/sections/overview-section";
import { FlowsSection } from "@/components/dashboard/sections/flows-section";
import { RecentSection } from "@/components/dashboard/sections/recent-section";
import { BillsSection } from "@/components/dashboard/sections/bills-section";
import { GoalsSection } from "@/components/dashboard/sections/goals-section";
import {
  SparklinesSkeleton,
  InsightsSkeleton,
  OverviewSkeleton,
  FlowsChartSkeleton,
  RowsSkeleton,
  GoalsSkeleton,
} from "@/components/dashboard/sections/skeletons";
import { getT } from "@/lib/i18n/server";
import { parseFxRates, convertToBase } from "@/lib/fx";
import { getToday } from "@/lib/today-server";
import { resolveYm, splitYm } from "@/lib/today";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("dashboard.title") };
}

/**
 * Dashboard con streaming (RSC + `<Suspense>`).
 *
 * Antes esta page hacía `Promise.all` de 11 queries antes de mandar un solo
 * byte: el usuario veía el loading global hasta que la más lenta terminaba.
 * Ahora sólo esperamos las 3 rápidas que alimentan el shell (cuentas con saldo
 * + resumen del mes actual y del anterior) y el resto — flujos, movimientos,
 * vencimientos, metas, patrimonio neto, salud y sparklines — se transmite en
 * secciones async propias, cada una con su skeleton.
 *
 * Ninguna query se duplica entre secciones: lo ya fetcheado acá (cuentas, FX,
 * resumen del mes) baja por props a las secciones que lo necesitan.
 */
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

  // El mes por defecto es el del CALENDARIO DEL USUARIO (cookie `mc_tz`), no el
  // del reloj del server: en Netlify corre en UTC y el 31 a las 21:05 en
  // Argentina el dashboard abría en el mes siguiente, todo en $0 y delta -100%.
  const ym = resolveYm(sp.ym, await getToday());
  const [year, month] = splitYm(ym);
  const prev = new Date(year, month - 2, 1);

  // Queries del shell: rápidas y necesarias para pintar KPIs + card de cuentas.
  const [accounts, summary, prevSummary] = await Promise.all([
    listAccountsWithBalance(supabase, householdId),
    getMonthSummary(supabase, householdId, year, month),
    getMonthSummary(supabase, householdId, prev.getFullYear(), prev.getMonth() + 1),
  ]);

  // "Saldo total" consolida TODAS las cuentas en la moneda base del hogar usando
  // las tasas FX manuales (`households.fx_rates`), igual que el net worth de iOS
  // (`AccountBalanceService.netWorth` suma cada cuenta tras convertir con
  // `FXConverter`). Si falta la tasa de alguna moneda, esa cuenta se omite del
  // total (no la sumamos a ciegas en otra moneda) — mismo criterio que iOS
  // (`convert` devuelve nil → la cuenta no entra en el agregado).
  const fxRates = parseFxRates(active.fx_rates);

  // Mismo barrido resuelve el saldo total y los agregados de activos/pasivos que
  // consume `OverviewSection` (que sólo agrega las DEUDAS, sin releer cuentas).
  let totalBalance = 0;
  let assets = 0;
  let negativeBalances = 0;
  let accountsUnconverted = false;
  for (const a of accounts) {
    const converted = convertToBase(a.balance, a.currency || currency, currency, fxRates);
    if (converted == null) {
      accountsUnconverted = true;
      continue;
    }
    totalBalance += converted;
    if (converted >= 0) assets += converted;
    else negativeBalances += -converted; // |saldo negativo| → pasivo
  }

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
      householdId={householdId}
      sparklinesSlot={
        <Suspense fallback={<SparklinesSkeleton />}>
          <SparklinesSection householdId={householdId} currency={currency} />
        </Suspense>
      }
      insightsSlot={
        <Suspense fallback={<InsightsSkeleton />}>
          <InsightsSection householdId={householdId} currency={currency} />
        </Suspense>
      }
      overviewSlot={
        <Suspense fallback={<OverviewSkeleton />}>
          <OverviewSection
            householdId={householdId}
            currency={currency}
            fxRates={fxRates}
            assets={assets}
            negativeBalances={negativeBalances}
            accountsUnconverted={accountsUnconverted}
            summary={summary}
          />
        </Suspense>
      }
      flowsSlot={
        <Suspense fallback={<FlowsChartSkeleton />}>
          <FlowsSection householdId={householdId} currency={currency} />
        </Suspense>
      }
      recentSlot={
        <Suspense fallback={<RowsSkeleton rows={6} />}>
          <RecentSection householdId={householdId} currency={currency} />
        </Suspense>
      }
      billsSlot={
        <Suspense fallback={<RowsSkeleton rows={4} />}>
          <BillsSection householdId={householdId} currency={currency} />
        </Suspense>
      }
      goalsSlot={
        <Suspense fallback={<GoalsSkeleton />}>
          <GoalsSection householdId={householdId} />
        </Suspense>
      }
    />
  );
}
