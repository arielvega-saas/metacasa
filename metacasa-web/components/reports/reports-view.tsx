import {
  ArrowDownLeft,
  ArrowUpRight,
  BarChart3,
  GitCompareArrows,
  HeartPulse,
  LineChart as LineChartIcon,
  PiggyBank,
  Scale,
  TrendingUp,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { KpiCard } from "@/components/dashboard/kpi-card";
import { SectionHeader } from "@/components/finance/section-header";
import { Amount } from "@/components/finance/amount";
import { EmptyState } from "@/components/ui/empty-state";
import { IncomeExpenseTrend } from "@/components/reports/income-expense-trend";
import { CategoryDonut } from "@/components/reports/category-donut";
import { ParetoChart, type ParetoDatum } from "@/components/reports/pareto-chart";
import {
  MonthComparison,
  type MonthComparisonData,
} from "@/components/reports/month-comparison";
import {
  SavingsRateTrend,
  type SavingsRateDatum,
} from "@/components/reports/savings-rate-trend";
import { HealthScore, type HealthScoreData } from "@/components/reports/health-score";
import { ExportMenu } from "@/components/export/export-menu";
import { colorForIndex, type CategorySlice } from "@/components/reports/palette";
import { formatMoney } from "@/lib/money";
import { getT } from "@/lib/i18n/server";
import { formatMonthYear, formatMonthShort } from "@/lib/i18n/dates";
import type { Locale } from "@/lib/i18n/config";

interface Summary {
  income: number;
  expense: number;
  balance: number;
}

export interface ReportsData {
  ym: string;
  locale: Locale;
  currency: string;
  flows: { month: string; income: number; expense: number }[];
  breakdown: CategorySlice[];
  summary: Summary;
  /** Resumen del mes anterior, para la comparación mes a mes. */
  prevSummary: Summary;
  /** Score de salud financiera + desglose, calculado en el server (page.tsx). */
  health: HealthScoreData;
}

/** Presentación de Reportes (read-only). Recibe todo por props. */
export async function ReportsView({
  ym,
  locale,
  currency,
  flows,
  breakdown,
  summary,
  prevSummary,
  health,
}: ReportsData) {
  const t = await getT();
  const [year, month] = ym.split("-").map(Number);
  const monthLongRaw = formatMonthYear(year, month, locale);
  const monthLong =
    monthLongRaw.charAt(0).toUpperCase() + monthLongRaw.slice(1);

  const expenseTotal = breakdown.reduce((s, d) => s + d.total, 0);
  // Tasa de ahorro: cuánto del ingreso queda sin gastar (clamp 0–100).
  const savingsRate =
    summary.income > 0
      ? Math.max(0, Math.round((summary.balance / summary.income) * 100))
      : 0;

  // Top categorías con porcentaje sobre el gasto total del mes.
  const topCategories = breakdown.slice(0, 6).map((d, i) => ({
    ...d,
    pct: expenseTotal > 0 ? Math.round((d.total / expenseTotal) * 100) : 0,
    color: colorForIndex(i),
  }));

  // ── Pareto 80/20: categorías por gasto (desc) con % acumulado y marca de las
  // "pocas vitales" (acumulado ≤ 80%). Paridad con iOS `paretoData`.
  const paretoData: ParetoDatum[] = [];
  if (expenseTotal > 0) {
    let cum = 0;
    let crossed = false; // la primera que cruza el 80% se incluye en las vitales
    for (const d of breakdown) {
      cum += d.total;
      const cumulative = (cum / expenseTotal) * 100;
      const vital = !crossed;
      if (cumulative >= 80) crossed = true;
      paretoData.push({ category: d.category, total: d.total, cumulative, vital });
    }
  }
  const vitalCount = paretoData.filter((d) => d.vital).length;

  // ── Tendencia de tasa de ahorro: derivada de los flujos mensuales ya
  // traídos. rate = clamp(0, (ing − gas)/ing)·100; null si el mes no tuvo
  // ingresos (sin base de cálculo).
  const savingsTrend: SavingsRateDatum[] = flows.map((f) => {
    const [fy, fm] = f.month.split("-").map(Number);
    const rate =
      f.income > 0
        ? Math.max(0, Math.round(((f.income - f.expense) / f.income) * 100))
        : null;
    return { label: formatMonthShort(fy, fm, locale), rate };
  });
  const hasSavingsTrend = savingsTrend.some((d) => d.rate != null);

  // ── Comparación mes a mes: mes actual vs anterior.
  const prevDate = new Date(year, month - 2, 1);
  const monthComparison: MonthComparisonData = {
    currentLabel: capitalize(formatMonthShort(year, month, locale)),
    previousLabel: capitalize(
      formatMonthShort(prevDate.getFullYear(), prevDate.getMonth() + 1, locale),
    ),
    current: summary,
    previous: prevSummary,
  };
  const hasMonthComparison =
    summary.income > 0 ||
    summary.expense > 0 ||
    prevSummary.income > 0 ||
    prevSummary.expense > 0;

  // Exportación del reporte del mes seleccionado (PDF + Excel), localizada.
  const reportExportOptions = [
    {
      key: "pdf",
      href: `/api/export/report?ym=${ym}`,
      label: t("exportTools.actions.exportReportPdf"),
    },
    {
      key: "xlsx",
      href: `/api/export/report?ym=${ym}&format=xlsx`,
      label: t("exportTools.actions.exportReportExcel"),
    },
  ];

  return (
    <div className="space-y-6">
      {/* Acciones del reporte: exportar a PDF / Excel el mes seleccionado. */}
      <div className="flex items-center justify-end">
        <ExportMenu
          label={t("exportTools.actions.export")}
          options={reportExportOptions}
        />
      </div>

      {/* KPIs del mes actual */}
      <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <KpiCard
          label={t("reports.kpiIncome")}
          value={summary.income}
          currency={currency}
          kind="ingreso"
          icon={ArrowDownLeft}
          hint={t("common.thisMonth")}
        />
        <KpiCard
          label={t("reports.kpiExpense")}
          value={summary.expense}
          currency={currency}
          kind="gasto"
          icon={ArrowUpRight}
          hint={t("common.thisMonth")}
        />
        <KpiCard
          label={t("reports.kpiSavings")}
          value={summary.balance}
          currency={currency}
          kind="balance"
          icon={Scale}
          highlight
          hint={t("reports.kpiSavingsHint")}
        />
        {/* Tasa de ahorro: % en vez de monto, por eso no usa KpiCard. */}
        <Card className="p-5">
          <div className="flex items-center justify-between">
            <span className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {t("reports.savingsRate")}
            </span>
            <PiggyBank className="text-text-muted size-4" />
          </div>
          <div className="mt-2.5 text-[26px] leading-none sm:text-[28px]">
            <span className="font-num tnum text-foreground">{savingsRate}%</span>
          </div>
          <p className="text-text-dim mt-1.5 text-xs">{t("reports.savingsRateHint")}</p>
        </Card>
      </div>

      {/* Tendencia 12 meses */}
      <Card className="p-5">
        <SectionHeader
          title={t("reports.trendTitle")}
          subtitle={t("reports.trendSubtitle")}
        />
        <IncomeExpenseTrend data={flows} locale={locale} currency={currency} />
      </Card>

      {/* Desglose por categoría: donut + leyenda y top categorías */}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <SectionHeader title={t("reports.byCategoryTitle")} subtitle={monthLong} />
          {breakdown.length === 0 ? (
            <EmptyState
              icon={TrendingUp}
              title={t("reports.byCategoryEmptyTitle")}
              description={t("reports.byCategoryEmptyDesc")}
            />
          ) : (
            <div className="grid items-center gap-4 sm:grid-cols-[minmax(0,200px)_1fr]">
              <CategoryDonut data={breakdown} currency={currency} />
              {/* Leyenda con montos */}
              <ul className="space-y-2.5">
                {topCategories.map((c) => (
                  <li
                    key={c.category}
                    className="flex items-center justify-between gap-3 text-sm"
                  >
                    <span className="flex min-w-0 items-center gap-2">
                      <span
                        className="size-2.5 shrink-0 rounded-full"
                        style={{ backgroundColor: c.color }}
                      />
                      <span className="truncate text-foreground">
                        {c.category}
                      </span>
                    </span>
                    <span className="flex shrink-0 items-baseline gap-2">
                      <span className="text-text-dim text-xs tnum">{c.pct}%</span>
                      <Amount
                        value={c.total}
                        currency={currency}
                        kind="gasto"
                        className="text-sm font-semibold"
                      />
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Card>

        {/* Top categorías como ranking con barra de progreso */}
        <Card className="p-5">
          <SectionHeader
            title={t("reports.topCategoriesTitle")}
            subtitle={t("reports.topCategoriesSubtitle", {
              total: formatMoney(expenseTotal, currency, "compact"),
            })}
          />
          {topCategories.length === 0 ? (
            <EmptyState
              icon={ArrowUpRight}
              title={t("reports.topCategoriesEmptyTitle")}
              description={t("reports.topCategoriesEmptyDesc")}
            />
          ) : (
            <div className="space-y-4">
              {topCategories.map((c) => (
                <div key={c.category}>
                  <div className="mb-1.5 flex items-center justify-between gap-3 text-sm">
                    <span className="truncate font-medium text-foreground">
                      {c.category}
                    </span>
                    <span className="flex shrink-0 items-baseline gap-2">
                      <span className="text-text-dim text-xs tnum">{c.pct}%</span>
                      <Amount
                        value={c.total}
                        currency={currency}
                        kind="gasto"
                        className="text-sm font-semibold"
                      />
                    </span>
                  </div>
                  <div className="bg-inset h-2 overflow-hidden rounded-full">
                    <div
                      className="h-full rounded-full"
                      style={{ width: `${c.pct}%`, backgroundColor: c.color }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>

      {/* ─────────────────────────────────────────────────────────────────
          Análisis avanzados (additivos): salud financiera + comparación mes a
          mes, Pareto 80/20 y tendencia de la tasa de ahorro.
          ───────────────────────────────────────────────────────────────── */}
      <div className="grid gap-4 lg:grid-cols-2">
        {/* Salud financiera (score 0–100 + desglose). */}
        <Card className="p-5">
          <SectionHeader
            title={t("reports.healthScore")}
            subtitle={t("reports.healthScoreSubtitle")}
          />
          {summary.income === 0 && summary.expense === 0 ? (
            <EmptyState
              icon={HeartPulse}
              title={t("reports.healthEmptyTitle")}
              description={t("reports.healthEmptyDesc")}
            />
          ) : (
            <HealthScore data={health} />
          )}
        </Card>

        {/* Comparación mes vs mes anterior. */}
        <Card className="p-5">
          <SectionHeader
            title={t("reports.momTitle")}
            subtitle={t("reports.momSubtitle", {
              current: monthComparison.currentLabel,
              previous: monthComparison.previousLabel,
            })}
          />
          {hasMonthComparison ? (
            <MonthComparison data={monthComparison} currency={currency} />
          ) : (
            <EmptyState
              icon={GitCompareArrows}
              title={t("reports.momEmptyTitle")}
              description={t("reports.momEmptyDesc")}
            />
          )}
        </Card>
      </div>

      {/* Pareto 80/20 del gasto por categoría. */}
      <Card className="p-5">
        <SectionHeader
          title={t("reports.paretoTitle")}
          subtitle={t("reports.paretoSubtitle")}
        />
        {paretoData.length === 0 ? (
          <EmptyState
            icon={BarChart3}
            title={t("reports.paretoEmptyTitle")}
            description={t("reports.paretoEmptyDesc")}
          />
        ) : (
          <>
            <ParetoChart data={paretoData} currency={currency} />
            <div className="mt-3 flex flex-wrap items-center justify-between gap-2">
              <p className="text-text-muted text-xs">
                {vitalCount === 1
                  ? t("reports.paretoInsightOne")
                  : t("reports.paretoInsight", { count: vitalCount })}
              </p>
              <div className="text-text-dim flex items-center gap-3 text-[11px]">
                <span className="flex items-center gap-1.5">
                  <span className="bg-expense size-2 rounded-full" />
                  {t("reports.paretoVital")}
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="bg-expense/40 size-2 rounded-full" />
                  {t("reports.paretoTrivial")}
                </span>
              </div>
            </div>
          </>
        )}
      </Card>

      {/* Tendencia de la tasa de ahorro. */}
      <Card className="p-5">
        <SectionHeader
          title={t("reports.savingsTrendTitle")}
          subtitle={t("reports.savingsTrendSubtitle")}
        />
        {hasSavingsTrend ? (
          <SavingsRateTrend data={savingsTrend} />
        ) : (
          <EmptyState
            icon={LineChartIcon}
            title={t("reports.savingsTrendEmptyTitle")}
            description={t("reports.savingsTrendEmptyDesc")}
          />
        )}
      </Card>
    </div>
  );
}

/** Capitaliza la primera letra (los meses cortos vienen en minúscula en es/pt). */
function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
