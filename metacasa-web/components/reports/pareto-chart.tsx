"use client";

// Pareto 80/20 del gasto por categoría: barras (monto por categoría, orden
// descendente) + línea de % acumulado sobre un eje derecho, con una línea de
// referencia en el 80%. Espeja el `paretoData` de iOS (ReportsView.swift):
// categorías ordenadas por gasto y marca de las que forman el 80%.
import {
  Bar,
  CartesianGrid,
  Cell,
  ComposedChart,
  Line,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { formatMoney } from "@/lib/money";
import { useT } from "@/components/i18n/locale-provider";
import { CHART } from "./chart-tokens";
import { ChartTooltip, ChartTooltipRow } from "@/components/charts/chart-tooltip";

export interface ParetoDatum {
  category: string;
  total: number;
  /** % acumulado (0–100) hasta esta categoría inclusive. */
  cumulative: number;
  /** True si pertenece al conjunto "pocas vitales" (acumulado ≤ 80%). */
  vital: boolean;
}

function CustomTooltip({ active, payload, currency, t }: any) {
  if (!active || !payload?.length) return null;
  const row: ParetoDatum = payload[0].payload;
  return (
    <ChartTooltip title={row.category}>
      <ChartTooltipRow tone="expense">
        {formatMoney(row.total, currency, "compact")}
      </ChartTooltipRow>
      <ChartTooltipRow tone="muted">
        {t("reports.paretoCumulative")}: {Math.round(row.cumulative)}%
      </ChartTooltipRow>
    </ChartTooltip>
  );
}

export function ParetoChart({
  data,
  currency,
}: {
  data: ParetoDatum[];
  currency: string;
}) {
  const t = useT();
  // En pantallas angostas mostramos menos categorías para que las etiquetas no
  // se amontonen; el resto sigue computado en el acumulado igual.
  const narrow = data.length > 6;

  return (
    <div className="h-[300px] w-full">
      <ResponsiveContainer width="100%" height="100%">
        <ComposedChart
          data={data}
          margin={{ top: 8, right: 12, bottom: narrow ? 28 : 8, left: 4 }}
        >
          <CartesianGrid vertical={false} stroke={CHART.grid} />
          <XAxis
            dataKey="category"
            axisLine={false}
            tickLine={false}
            tick={{ fill: CHART.axis, fontSize: 11 }}
            interval={0}
            angle={narrow ? -35 : 0}
            textAnchor={narrow ? "end" : "middle"}
            height={narrow ? 48 : 24}
            tickFormatter={(v: string) =>
              v.length > 10 ? `${v.slice(0, 9)}…` : v
            }
          />
          {/* Eje izq: montos (oculto, el tooltip ya da el valor). */}
          <YAxis yAxisId="amount" hide />
          {/* Eje der: % acumulado 0–100. */}
          <YAxis
            yAxisId="pct"
            orientation="right"
            domain={[0, 100]}
            ticks={[0, 50, 80, 100]}
            axisLine={false}
            tickLine={false}
            tick={{ fill: CHART.axis, fontSize: 11 }}
            tickFormatter={(v: number) => `${v}%`}
            width={36}
          />
          <Tooltip
            cursor={{ fill: CHART.cursorFill }}
            content={<CustomTooltip currency={currency} t={t} />}
          />
          {/* Umbral del 80% sobre el eje acumulado. */}
          <ReferenceLine
            yAxisId="pct"
            y={80}
            stroke={CHART.champagne}
            strokeDasharray="4 4"
            strokeOpacity={0.8}
            label={{
              value: t("reports.paretoThreshold"),
              position: "insideTopRight",
              fill: CHART.champagne,
              fontSize: 10,
            }}
          />
          <Bar yAxisId="amount" dataKey="total" radius={[4, 4, 0, 0]} maxBarSize={48}>
            {data.map((d) => (
              <Cell
                key={d.category}
                // Vitales en coral pleno; el resto atenuado (las "triviales").
                fill={CHART.expense}
                fillOpacity={d.vital ? 0.95 : 0.4}
              />
            ))}
          </Bar>
          <Line
            yAxisId="pct"
            type="monotone"
            dataKey="cumulative"
            stroke={CHART.sage}
            strokeWidth={2}
            dot={{ r: 3, fill: CHART.sage, strokeWidth: 0 }}
            activeDot={{ r: 5, fill: CHART.sage, strokeWidth: 0 }}
          />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );
}
