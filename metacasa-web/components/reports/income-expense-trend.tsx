"use client";

// Tendencia ingresos vs gastos de los últimos 12 meses (líneas suaves).
// Mismo lenguaje visual que FlowsChart: sage para ingresos, coral para gastos,
// ejes #7a8782, grid sage tenue, tooltip de vidrio.
import {
  Area,
  AreaChart,
  CartesianGrid,
  Legend,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { formatMoney } from "@/lib/money";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import { formatMonthShort } from "@/lib/i18n/dates";
import type { Locale } from "@/lib/i18n/config";

interface FlowDatum {
  month: string; // YYYY-MM
  income: number;
  expense: number;
}

function monthLabel(ym: string, locale: Locale): string {
  const [y, m] = ym.split("-").map(Number);
  return formatMonthShort(y, m, locale);
}

function CustomTooltip({ active, payload, label, currency, t }: any) {
  if (!active || !payload?.length) return null;
  const income = payload.find((p: any) => p.dataKey === "income")?.value ?? 0;
  const expense = payload.find((p: any) => p.dataKey === "expense")?.value ?? 0;
  return (
    <div className="glass hairline rounded-[var(--radius-md)] px-3 py-2 text-xs shadow-xl">
      <p className="mb-1 font-medium capitalize text-foreground">{label}</p>
      <p className="text-income">
        {t("reports.legendIncome")} {formatMoney(income, currency, "compact")}
      </p>
      <p className="text-expense">
        {t("reports.legendExpense")} {formatMoney(expense, currency, "compact")}
      </p>
    </div>
  );
}

function LegendContent({ t }: { t: ReturnType<typeof useT> }) {
  return (
    <div className="mt-2 flex items-center justify-center gap-5 text-xs">
      <span className="flex items-center gap-1.5 text-text-muted">
        <span className="size-2.5 rounded-full bg-income" />{" "}
        {t("reports.legendIncome")}
      </span>
      <span className="flex items-center gap-1.5 text-text-muted">
        <span className="size-2.5 rounded-full bg-expense" />{" "}
        {t("reports.legendExpense")}
      </span>
    </div>
  );
}

export function IncomeExpenseTrend({
  data,
  locale,
  currency,
}: {
  data: FlowDatum[];
  locale?: Locale;
  currency: string;
}) {
  const t = useT();
  const providerLocale = useLocale();
  const dateLocale = locale ?? providerLocale;
  const chartData = data.map((d) => ({ ...d, label: monthLabel(d.month, dateLocale) }));

  return (
    <div className="h-[280px] w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={chartData} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
          <defs>
            <linearGradient id="rep-income" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#9fc4ad" stopOpacity={0.35} />
              <stop offset="100%" stopColor="#9fc4ad" stopOpacity={0} />
            </linearGradient>
            <linearGradient id="rep-expense" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#e8b4a6" stopOpacity={0.3} />
              <stop offset="100%" stopColor="#e8b4a6" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid vertical={false} stroke="rgba(184,212,194,0.08)" />
          <XAxis
            dataKey="label"
            axisLine={false}
            tickLine={false}
            tick={{ fill: "#7a8782", fontSize: 12 }}
            dy={8}
          />
          <YAxis hide />
          <Tooltip
            cursor={{ stroke: "rgba(255,255,255,0.12)" }}
            content={<CustomTooltip currency={currency} t={t} />}
          />
          <Legend content={<LegendContent t={t} />} />
          <Area
            type="monotone"
            dataKey="income"
            name={t("reports.legendIncome")}
            stroke="#9fc4ad"
            strokeWidth={2}
            fill="url(#rep-income)"
            dot={false}
            activeDot={{ r: 4, fill: "#9fc4ad", strokeWidth: 0 }}
          />
          <Area
            type="monotone"
            dataKey="expense"
            name={t("reports.legendExpense")}
            stroke="#e8b4a6"
            strokeWidth={2}
            fill="url(#rep-expense)"
            dot={false}
            activeDot={{ r: 4, fill: "#e8b4a6", strokeWidth: 0 }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
