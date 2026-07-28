"use client";

// Tendencia de la tasa de ahorro (% del ingreso que queda sin gastar) mes a
// mes, derivada de los flujos mensuales que ya trae la página. Misma definición
// que el KPI de ahorro: rate = clamp(0, (ingreso − gasto) / ingreso) · 100.
import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useT } from "@/components/i18n/locale-provider";
import { CHART } from "./chart-tokens";
import { ChartTooltip, ChartTooltipRow } from "@/components/charts/chart-tooltip";

export interface SavingsRateDatum {
  /** Etiqueta de mes ya localizada (ej. "may"). */
  label: string;
  /** Tasa de ahorro 0–100; null si ese mes no tuvo ingresos (sin base). */
  rate: number | null;
}

function CustomTooltip({ active, payload, label, t }: any) {
  if (!active || !payload?.length) return null;
  const v = payload[0]?.value;
  return (
    <ChartTooltip title={label} capitalizeTitle>
      <ChartTooltipRow tone="muted">
        {t("reports.savingsTrendLegend")}: {v == null ? "—" : `${Math.round(v)}%`}
      </ChartTooltipRow>
    </ChartTooltip>
  );
}

export function SavingsRateTrend({ data }: { data: SavingsRateDatum[] }) {
  const t = useT();
  // Promedio sobre los meses con base (ingreso > 0).
  const valid = data.filter((d) => d.rate != null) as { rate: number }[];
  const avg =
    valid.length > 0
      ? Math.round(valid.reduce((s, d) => s + d.rate, 0) / valid.length)
      : 0;

  return (
    <div className="h-[240px] w-full">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart
          data={data}
          margin={{ top: 8, right: 8, bottom: 0, left: 8 }}
        >
          <CartesianGrid vertical={false} stroke={CHART.grid} />
          <XAxis
            dataKey="label"
            axisLine={false}
            tickLine={false}
            tick={{ fill: CHART.axis, fontSize: 12 }}
            // En 12 puntos sobre 360px, saltear etiquetas evita el amontonamiento.
            interval="preserveStartEnd"
            minTickGap={16}
            dy={8}
          />
          <YAxis
            domain={[0, 100]}
            ticks={[0, 25, 50, 75, 100]}
            axisLine={false}
            tickLine={false}
            tick={{ fill: CHART.axis, fontSize: 11 }}
            tickFormatter={(v: number) => `${v}%`}
            width={34}
          />
          <Tooltip
            cursor={{ stroke: CHART.cursor }}
            content={<CustomTooltip t={t} />}
          />
          {/* Promedio como referencia. */}
          {valid.length > 0 && (
            <ReferenceLine
              y={avg}
              stroke={CHART.champagne}
              strokeDasharray="4 4"
              strokeOpacity={0.7}
              label={{
                value: t("reports.savingsTrendAvg", { value: avg }),
                position: "insideTopLeft",
                fill: CHART.champagne,
                fontSize: 10,
              }}
            />
          )}
          <Line
            type="monotone"
            dataKey="rate"
            stroke={CHART.income}
            strokeWidth={2}
            connectNulls
            dot={{ r: 3, fill: CHART.income, strokeWidth: 0 }}
            activeDot={{ r: 5, fill: CHART.income, strokeWidth: 0 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
