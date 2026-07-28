"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { BarChart3 } from "lucide-react";
import { formatMoney } from "@/lib/money";
import { useLocale } from "@/components/i18n/locale-provider";
import { formatMonthShort } from "@/lib/i18n/dates";
import type { Locale } from "@/lib/i18n/config";
import { ChartTooltip, ChartTooltipRow } from "@/components/charts/chart-tooltip";
import { CHART } from "@/components/reports/chart-tokens";

interface FlowDatum {
  month: string; // YYYY-MM
  income: number;
  expense: number;
}

function monthLabel(ym: string, locale: Locale): string {
  const [y, m] = ym.split("-").map(Number);
  return formatMonthShort(y, m, locale);
}

function CustomTooltip({ active, payload, label, currency, incomeLabel, expenseLabel }: any) {
  if (!active || !payload?.length) return null;
  const income = payload.find((p: any) => p.dataKey === "income")?.value ?? 0;
  const expense = payload.find((p: any) => p.dataKey === "expense")?.value ?? 0;
  return (
    <ChartTooltip title={label} capitalizeTitle>
      <ChartTooltipRow tone="income">
        {incomeLabel} {formatMoney(income, currency, "compact")}
      </ChartTooltipRow>
      <ChartTooltipRow tone="expense">
        {expenseLabel} {formatMoney(expense, currency, "compact")}
      </ChartTooltipRow>
    </ChartTooltip>
  );
}

export function FlowsChart({
  data,
  currency,
  incomeLabel,
  expenseLabel,
  emptyLabel,
}: {
  data: FlowDatum[];
  currency: string;
  incomeLabel: string;
  expenseLabel: string;
  emptyLabel: string;
}) {
  const locale = useLocale();
  const chartData = data.map((d) => ({ ...d, label: monthLabel(d.month, locale) }));

  // Estado vacío: sin datos o todos los meses en cero (evita un recuadro en blanco).
  const allZero =
    data.length === 0 ||
    data.every((d) => (d.income ?? 0) === 0 && (d.expense ?? 0) === 0);

  if (allZero) {
    return (
      <div className="flex h-[240px] w-full flex-col items-center justify-center gap-3 text-center">
        <span className="bg-inset text-text-dim flex size-12 items-center justify-center rounded-full">
          <BarChart3 className="size-6" />
        </span>
        <p className="text-text-muted max-w-xs text-sm leading-relaxed">
          {emptyLabel}
        </p>
      </div>
    );
  }

  return (
    <div className="h-[240px] w-full">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={chartData} margin={{ top: 8, right: 4, bottom: 0, left: 4 }} barGap={5}>
          <CartesianGrid vertical={false} stroke={CHART.grid} />
          <XAxis
            dataKey="label"
            axisLine={false}
            tickLine={false}
            tick={{ fill: CHART.axis, fontSize: 12 }}
            dy={8}
          />
          <YAxis hide />
          <Tooltip
            cursor={{ fill: CHART.cursorFill }}
            content={
              <CustomTooltip
                currency={currency}
                incomeLabel={incomeLabel}
                expenseLabel={expenseLabel}
              />
            }
          />
          <Bar dataKey="income" name={incomeLabel} fill={CHART.income} radius={[6, 6, 0, 0]} maxBarSize={28} />
          <Bar dataKey="expense" name={expenseLabel} fill={CHART.expense} radius={[6, 6, 0, 0]} maxBarSize={28} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
