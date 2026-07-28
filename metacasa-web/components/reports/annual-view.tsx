"use client";

// Vista anual: totales del año (ingreso/gasto/balance) + chart de barras
// agrupadas de los 12 meses (ingresos vs gastos) + grid de meses a 2 columnas.
// Espeja `Features/Reports/AnnualView.swift` de iOS.
import { ArrowDown, ArrowUp } from "lucide-react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Amount } from "@/components/finance/amount";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import { formatMoney } from "@/lib/money";
import { formatMonthShort } from "@/lib/i18n/dates";
import { CHART } from "./chart-tokens";
import { ChartTooltip, ChartTooltipRow } from "@/components/charts/chart-tooltip";
import type { AnnualMonthFlow } from "@/lib/db/analytics";

function CustomTooltip({ active, payload, label, currency, t }: any) {
  if (!active || !payload?.length) return null;
  const income = payload.find((p: any) => p.dataKey === "income")?.value ?? 0;
  const expense = payload.find((p: any) => p.dataKey === "expense")?.value ?? 0;
  return (
    <ChartTooltip title={label} capitalizeTitle>
      <ChartTooltipRow tone="income">
        {t("reports.legendIncome")} {formatMoney(income, currency, "compact")}
      </ChartTooltipRow>
      <ChartTooltipRow tone="expense">
        {t("reports.legendExpense")} {formatMoney(expense, currency, "compact")}
      </ChartTooltipRow>
    </ChartTooltip>
  );
}

export function AnnualView({
  flows,
  year,
  currency,
}: {
  flows: AnnualMonthFlow[];
  year: number;
  currency: string;
}) {
  const t = useT();
  const locale = useLocale();

  const totalIncome = flows.reduce((s, f) => s + f.income, 0);
  const totalExpense = flows.reduce((s, f) => s + f.expense, 0);
  const balance = totalIncome - totalExpense;

  // Etiqueta de mes localizada (UTC-safe) y capitalizada.
  const label = (m: number) => capitalize(formatMonthShort(year, m, locale));

  const chartData = flows.map((f) => ({
    label: label(f.month),
    income: f.income,
    expense: f.expense,
  }));

  return (
    <div className="space-y-5">
      {/* Totales del año (ingreso / gasto / balance). */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <Tile label={t("reports.yearIncome")}>
          <Amount value={totalIncome} currency={currency} kind="ingreso" className="text-lg font-semibold" />
        </Tile>
        <Tile label={t("reports.yearExpense")}>
          <Amount value={totalExpense} currency={currency} kind="gasto" className="text-lg font-semibold" />
        </Tile>
        <Tile label={t("reports.yearBalance")}>
          <Amount value={balance} currency={currency} kind="balance" className="text-lg font-semibold" />
        </Tile>
      </div>

      {/* Chart de barras agrupadas: 12 meses, ingresos vs gastos. */}
      <div>
        <p className="text-text-muted mb-2 text-xs font-semibold uppercase tracking-wider">
          {t("reports.annualEvolution")}
        </p>
        <div className="h-[260px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData} margin={{ top: 8, right: 8, bottom: 0, left: 8 }} barGap={2} barCategoryGap="22%">
              <CartesianGrid vertical={false} stroke={CHART.grid} />
              <XAxis
                dataKey="label"
                axisLine={false}
                tickLine={false}
                tick={{ fill: CHART.axis, fontSize: 11 }}
                interval="preserveStartEnd"
                minTickGap={8}
                dy={8}
              />
              <YAxis hide />
              <Tooltip
                cursor={{ fill: CHART.cursor }}
                content={<CustomTooltip currency={currency} t={t} />}
              />
              <Bar dataKey="income" name={t("reports.legendIncome")} fill={CHART.income} radius={[3, 3, 0, 0]} maxBarSize={18} />
              <Bar dataKey="expense" name={t("reports.legendExpense")} fill={CHART.expense} radius={[3, 3, 0, 0]} maxBarSize={18} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        {/* Leyenda (mismo lenguaje que IncomeExpenseTrend). */}
        <div className="mt-2 flex items-center justify-center gap-5 text-xs">
          <span className="text-text-muted flex items-center gap-1.5">
            <span className="bg-income size-2.5 rounded-full" /> {t("reports.legendIncome")}
          </span>
          <span className="text-text-muted flex items-center gap-1.5">
            <span className="bg-expense size-2.5 rounded-full" /> {t("reports.legendExpense")}
          </span>
        </div>
      </div>

      {/* Grid de meses a 2 columnas (paridad iOS `monthsGrid`). */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {flows.map((f) => (
          <div key={f.month} className="hairline bg-surface/40 rounded-[var(--radius-lg)] p-3">
            <p className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {label(f.month)}
            </p>
            <div className="mt-2 space-y-1">
              <div className="flex items-center gap-1.5">
                <ArrowUp className="text-income size-3 shrink-0" />
                <Amount value={f.income} currency={currency} kind="ingreso" className="text-xs font-semibold" style="compact" />
              </div>
              <div className="flex items-center gap-1.5">
                <ArrowDown className="text-expense size-3 shrink-0" />
                <Amount value={f.expense} currency={currency} kind="gasto" className="text-xs font-semibold" style="compact" />
              </div>
              <Amount value={f.income - f.expense} currency={currency} kind="balance" className="text-xs font-bold" style="compact" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function Tile({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="hairline bg-surface/40 rounded-[var(--radius-lg)] p-4">
      <p className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">{label}</p>
      <div className="mt-1.5">{children}</div>
    </div>
  );
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
