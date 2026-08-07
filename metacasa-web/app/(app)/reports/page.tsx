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
import { getActiveDays, getDailySpend, getAnnualFlows } from "@/lib/db/analytics";
import { ReportsView } from "@/components/reports/reports-view";
import { MonthSwitcher } from "@/components/dashboard/month-switcher";
import { getToday } from "@/lib/today-server";
import { resolveYm, splitYm } from "@/lib/today";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("reports.title") };
}

/** Reportes y estadísticas del hogar activo (read-only). */
export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ ym?: string; fy?: string }>;
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
  //
  // "Mes actual" = el del CALENDARIO DEL USUARIO (cookie `mc_tz`). El server de
  // Netlify corre en UTC: el 31 a las 21:05 en Argentina, reportes abría vacío
  // porque ya estaba mirando el mes siguiente.
  const sp = await searchParams;
  const today = await getToday();
  const ym = resolveYm(sp.ym, today);
  const [year, month] = splitYm(ym);

  // El AÑO de las secciones anuales (heatmap + vista anual) viene de `?fy=`,
  // un parámetro SEPARADO del `?ym=` mensual para que no se pisen. Default: año
  // actual. Se clampa al rango razonable [2000, año actual] (paridad iOS: el
  // heatmap no navega al futuro). El "año actual" también sale del día del
  // usuario: el 31/12 a las 21:05 en Argentina el clamp del server ya dejaba
  // pasar el año siguiente.
  const currentYear = Number(today.slice(0, 4));
  const fyRaw = sp.fy && /^\d{4}$/.test(sp.fy) ? Number(sp.fy) : currentYear;
  const fiscalYear = Math.min(Math.max(fyRaw, 2000), currentYear);

  // Mes anterior (para la comparación mes a mes).
  const prevDate = new Date(year, month - 2, 1);
  const prevYear = prevDate.getFullYear();
  const prevMonth = prevDate.getMonth() + 1;

  const [flows, breakdown, summary, prevSummary, activeDays, dailySpend, annualFlows] =
    await Promise.all([
      getMonthlyFlows(supabase, householdId, 12),
      getCategoryBreakdown(supabase, householdId, year, month),
      getMonthSummary(supabase, householdId, year, month),
      getMonthSummary(supabase, householdId, prevYear, prevMonth),
      getActiveDays(supabase, householdId, 30),
      getDailySpend(supabase, householdId, fiscalYear),
      getAnnualFlows(supabase, householdId, fiscalYear),
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
        action={<MonthSwitcher ym={ym} fy={fiscalYear} />}
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
        dailySpend={dailySpend}
        annualFlows={annualFlows}
        fiscalYear={fiscalYear}
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
