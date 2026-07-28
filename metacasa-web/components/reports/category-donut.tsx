"use client";

// Desglose de gastos por categoría del mes (donut) + leyenda con montos.
// Paleta derivada del acento sage/champagne/coral para mantener coherencia.
import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { formatMoney } from "@/lib/money";
import { colorForIndex, type CategorySlice } from "./palette";
import { ChartTooltip, ChartTooltipRow } from "@/components/charts/chart-tooltip";

export type { CategorySlice };

function CustomTooltip({ active, payload, currency, total }: any) {
  if (!active || !payload?.length) return null;
  const p = payload[0];
  const value = Number(p.value) || 0;
  const pct = total > 0 ? Math.round((value / total) * 100) : 0;
  return (
    <ChartTooltip title={p.name}>
      <ChartTooltipRow tone="muted">
        {formatMoney(value, currency, "compact")} · {pct}%
      </ChartTooltipRow>
    </ChartTooltip>
  );
}

export function CategoryDonut({
  data,
  currency,
}: {
  data: CategorySlice[];
  currency: string;
}) {
  const total = data.reduce((s, d) => s + d.total, 0);

  return (
    <div className="h-[240px] w-full">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={data}
            dataKey="total"
            nameKey="category"
            cx="50%"
            cy="50%"
            innerRadius={62}
            outerRadius={92}
            paddingAngle={data.length > 1 ? 2 : 0}
            strokeWidth={0}
          >
            {data.map((d, i) => (
              <Cell key={d.category} fill={colorForIndex(i)} />
            ))}
          </Pie>
          <Tooltip content={<CustomTooltip currency={currency} total={total} />} />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
}
