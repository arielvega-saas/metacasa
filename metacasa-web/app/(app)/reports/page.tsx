import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT, getLocale } from "@/lib/i18n/server";
import { PageHeader } from "@/components/layout/page-header";
import {
  getCategoryBreakdown,
  getMonthlyFlows,
  getMonthSummary,
} from "@/lib/db/transactions";
import { getActiveDays } from "@/lib/db/analytics";
import { ReportsView } from "@/components/reports/reports-view";
import { MonthSwitcher } from "@/components/dashboard/month-switcher";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("reports.title") };
}

function pad(n: number) {
  return String(n).padStart(2, "0");
}

/** Reportes y estadísticas del hogar activo (read-only). */
export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ ym?: string }>;
}) {
  const supabase = await createClient();
  const t = await getT();
  const locale = await getLocale();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return <p className="text-text-muted">{t("reports.noHousehold")}</p>;
  }

  const householdId = active.id;
  const currency = active.default_currency;

  // El mes a mostrar viene de `?ym=` (mismo patrón que el dashboard); si no
  // está o es inválido, usamos el mes actual. Antes se forzaba `new Date()`
  // siempre, así que un usuario en un mes sin datos veía todo vacío y no podía
  // navegar a meses anteriores.
  const sp = await searchParams;
  const now = new Date();
  const ym =
    sp.ym && /^\d{4}-\d{2}$/.test(sp.ym)
      ? sp.ym
      : `${now.getFullYear()}-${pad(now.getMonth() + 1)}`;
  const [year, month] = ym.split("-").map(Number);

  // Mes anterior (para la comparación mes a mes).
  const prevDate = new Date(year, month - 2, 1);
  const prevYear = prevDate.getFullYear();
  const prevMonth = prevDate.getMonth() + 1;

  const [flows, breakdown, summary, prevSummary, activeDays] =
    await Promise.all([
      getMonthlyFlows(supabase, householdId, 12),
      getCategoryBreakdown(supabase, householdId, year, month),
      getMonthSummary(supabase, householdId, year, month),
      getMonthSummary(supabase, householdId, prevYear, prevMonth),
      getActiveDays(supabase, householdId, 30),
    ]);

  // ── Health score (paridad iOS: ReportsView.swift → healthScore) ──────────
  // El score del mes actual usa el resumen del mes (ingreso/gasto) + la
  // constancia (días con actividad en los últimos 30, transversal al mes).
  const health = computeHealthScore(
    summary.income,
    summary.expense,
    activeDays,
  );

  return (
    <div>
      <PageHeader
        title={t("reports.title")}
        description={t("reports.description")}
        action={<MonthSwitcher ym={ym} />}
      />
      <ReportsView
        ym={ym}
        locale={locale}
        currency={currency}
        flows={flows}
        breakdown={breakdown}
        summary={summary}
        prevSummary={prevSummary}
        health={health}
      />
    </div>
  );
}

/**
 * Score de salud financiera 0–100. Port DIRECTO de la fórmula de iOS
 * (`Features/Reports/ReportsView.swift`, propiedad `healthScore`):
 *
 *   savings (≤50): si ingreso>0 → min(50, max(0,(ing−gas)/ing) · 250)   // 20% = 50
 *   ratio   (≤30): si ingreso>0 y gasto/ingreso<1 → (1 − ratio) · 30
 *   activity(≤20): min(20, díasConTx(30) · 0.67)                          // 30 días = 20
 *
 * Devuelve el total clampeado + el desglose por factor para mostrarlo.
 */
function computeHealthScore(
  income: number,
  expense: number,
  activeDays: number,
) {
  let savings = 0;
  let ratio = 0;
  if (income > 0) {
    const rate = Math.max(0, (income - expense) / income);
    savings = Math.min(50, rate * 250);
    const r = expense / income;
    if (r < 1) ratio = (1 - r) * 30;
  }
  const activity = Math.min(20, activeDays * 0.67);
  const total = Math.max(0, Math.min(100, Math.round(savings + ratio + activity)));
  return {
    score: total,
    factors: [
      { key: "savings" as const, value: Math.round(savings), max: 50 },
      { key: "ratio" as const, value: Math.round(ratio), max: 30 },
      { key: "activity" as const, value: Math.round(activity), max: 20 },
    ],
  };
}
