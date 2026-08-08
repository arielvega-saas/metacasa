"use client";

// Comparación mes actual vs mes anterior: ingresos, gastos y balance, con su
// variación absoluta y en %. Espeja `CompareMonthsView` de iOS: para GASTOS
// bajar es mejora (verde) y subir es empeoramiento (rojo); para ingresos y
// balance, al revés. Vista de barras divergentes (un par por métrica).
import { ArrowDownRight, ArrowUpRight, Minus } from "lucide-react";
import {
  Bar,
  BarChart,
  Cell,
  ResponsiveContainer,
  XAxis,
  YAxis,
} from "recharts";
import { Amount } from "@/components/finance/amount";
import { useT } from "@/components/i18n/locale-provider";
import { CHART } from "./chart-tokens";

type Kind = "ingreso" | "gasto" | "balance";

export interface MonthComparisonData {
  /** Etiqueta del mes actual (ej. "Mayo"). */
  currentLabel: string;
  /** Etiqueta del mes anterior. */
  previousLabel: string;
  current: { income: number; expense: number; balance: number };
  previous: { income: number; expense: number; balance: number };
  /**
   * Variación del GASTO descontando la inflación (CER oficial del BCRA).
   * `null` si no hay índice para esas fechas — se prefiere no mostrar nada
   * antes que un número sin respaldo.
   *
   * Es el dato que le falta a toda comparación mes a mes en Argentina: con
   * 33,5% interanual, "gastaste 20% más" puede ser gastaste MENOS en términos
   * reales.
   */
  realExpenseChange?: number | null;
}

interface Row {
  key: Kind;
  labelKey: string;
  cur: number;
  prev: number;
}

/** % de variación; null si no hay base previa (evita dividir por 0). */
function pctDelta(cur: number, prev: number): number | null {
  if (prev === 0) return null;
  return ((cur - prev) / Math.abs(prev)) * 100;
}

/** ¿La variación es una mejora? Para gasto, bajar; para el resto, subir. */
function isImprovement(kind: Kind, delta: number): boolean {
  return kind === "gasto" ? delta < 0 : delta > 0;
}

function MetricRow({
  row,
  currency,
  t,
}: {
  row: Row;
  currency: string;
  t: ReturnType<typeof useT>;
}) {
  const delta = row.cur - row.prev;
  const pct = pctDelta(row.cur, row.prev);
  const improvement = delta === 0 ? null : isImprovement(row.key, delta);
  const deltaColor =
    improvement === null
      ? "text-text-muted"
      : improvement
        ? "text-income"
        : "text-expense";

  // Barras divergentes: el mes con mayor magnitud marca la escala (100%).
  const max = Math.max(Math.abs(row.cur), Math.abs(row.prev), 1);
  const chartData = [
    { name: "prev", value: row.prev },
    { name: "cur", value: row.cur },
  ];
  const barColor =
    row.key === "ingreso"
      ? CHART.income
      : row.key === "gasto"
        ? CHART.expense
        : row.cur < 0
          ? CHART.expense
          : CHART.income;

  const DeltaIcon =
    delta === 0 ? Minus : delta > 0 ? ArrowUpRight : ArrowDownRight;

  return (
    <div className="space-y-2 py-3 first:pt-0 last:pb-0">
      <div className="flex items-center justify-between gap-3">
        <span className="text-sm font-medium text-foreground">
          {t(row.labelKey)}
        </span>
        <span className={`flex items-center gap-1 text-xs font-semibold ${deltaColor}`}>
          <DeltaIcon className="size-3.5" />
          {pct === null
            ? t("reports.momNoChange")
            : `${pct > 0 ? "+" : ""}${Math.round(pct)}%`}
        </span>
      </div>
      <div className="grid grid-cols-[1fr_auto] items-center gap-3">
        {/* Mini barras divergentes prev vs actual. */}
        <div className="h-[44px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={chartData}
              layout="vertical"
              margin={{ top: 2, right: 4, bottom: 2, left: 4 }}
              barCategoryGap={4}
            >
              <XAxis type="number" domain={[0, max]} hide />
              <YAxis type="category" dataKey="name" hide />
              <Bar dataKey="value" radius={3} maxBarSize={14} isAnimationActive={false}>
                {chartData.map((d) => (
                  <Cell
                    key={d.name}
                    fill={barColor}
                    fillOpacity={d.name === "cur" ? 0.95 : 0.4}
                  />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="text-right">
          <Amount
            value={row.cur}
            currency={currency}
            kind={row.key as Kind}
            className="text-sm font-semibold"
          />
          <p className="text-text-dim text-[11px]">{t("reports.momVsPrev")}</p>
        </div>
      </div>
    </div>
  );
}

export function MonthComparison({
  data,
  currency,
}: {
  data: MonthComparisonData;
  currency: string;
}) {
  const t = useT();
  const rows: Row[] = [
    {
      key: "ingreso",
      labelKey: "reports.momIncome",
      cur: data.current.income,
      prev: data.previous.income,
    },
    {
      key: "gasto",
      labelKey: "reports.momExpense",
      cur: data.current.expense,
      prev: data.previous.expense,
    },
    {
      key: "balance",
      labelKey: "reports.momBalance",
      cur: data.current.balance,
      prev: data.previous.balance,
    },
  ];

  return (
    <div>
      {/* Encabezado: qué mes vs qué mes, con puntos de color por columna. */}
      <div className="text-text-muted mb-1 flex items-center justify-end gap-4 text-[11px]">
        <span className="flex items-center gap-1.5">
          <span className="bg-text-dim size-2 rounded-full" />
          {data.previousLabel}
        </span>
        <span className="flex items-center gap-1.5">
          <span className="bg-sage size-2 rounded-full" />
          {data.currentLabel}
        </span>
      </div>
      <div className="divide-border divide-y">
        {rows.map((row) => (
          <MetricRow key={row.key} row={row} currency={currency} t={t} />
        ))}
      </div>
      {/*
        La variación REAL del gasto. Va abajo de todo y con su propia
        aclaración: un porcentaje sin decir "descontando inflación" al lado de
        los nominales se lee como uno más y engaña.
      */}
      {typeof data.realExpenseChange === "number" ? (
        <div className="border-border mt-3 border-t pt-3">
          <div className="flex items-baseline justify-between gap-3">
            <span className="text-text-muted text-[11px]">
              {t("reports.realChangeLabel")}
            </span>
            <span
              className={
                data.realExpenseChange < 0
                  ? "text-sage text-sm font-semibold tabular-nums"
                  : "text-amber text-sm font-semibold tabular-nums"
              }
            >
              {data.realExpenseChange > 0 ? "+" : ""}
              {Math.round(data.realExpenseChange * 100)}%
            </span>
          </div>
          <p className="text-text-dim mt-1 text-[11px]">
            {data.realExpenseChange < 0
              ? t("reports.realChangeBetter")
              : t("reports.realChangeWorse")}
          </p>
        </div>
      ) : null}
    </div>
  );
}
