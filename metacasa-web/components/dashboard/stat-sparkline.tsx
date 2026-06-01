"use client";

import { Area, AreaChart, ResponsiveContainer } from "recharts";

/**
 * Sparkline minimalista (sin ejes, sin tooltip) para la tendencia de 7 días de
 * ingresos / gastos en los KPIs. Paridad visual con iOS `StatsRow` (LineMark +
 * AreaMark con gradiente, interpolación suave, alto fijo ~28px).
 *
 * Es presentación pura: recibe la serie ya calculada (`values`, último = hoy) y
 * un color del design system. Si la serie es toda cero / vacía, no dibuja nada
 * (deja que el caller muestre su placeholder), igual que iOS cuando
 * `spark.contains(where: { $0 > 0 })` es falso.
 */
export function StatSparkline({
  values,
  color,
  height = 32,
}: {
  /** Serie diaria; el último elemento es HOY. */
  values: number[];
  /** Color de línea/área (hex o var CSS resuelto). */
  color: string;
  /** Alto en px del trazo. */
  height?: number;
}) {
  const hasData = values.some((v) => v > 0);
  if (!hasData) return null;

  // Recharts necesita objetos; el índice es el eje X implícito.
  const data = values.map((v, i) => ({ i, v }));
  const gradId = `spark-${color.replace(/[^a-zA-Z0-9]/g, "")}`;

  return (
    <div style={{ height }} className="w-full">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 2, right: 0, bottom: 0, left: 0 }}>
          <defs>
            <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity={0.32} />
              <stop offset="100%" stopColor={color} stopOpacity={0} />
            </linearGradient>
          </defs>
          <Area
            type="monotone"
            dataKey="v"
            stroke={color}
            strokeWidth={2}
            fill={`url(#${gradId})`}
            dot={false}
            isAnimationActive={false}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
