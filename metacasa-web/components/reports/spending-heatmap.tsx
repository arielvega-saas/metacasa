"use client";

// Heatmap anual de gasto diario, estilo "contribution graph" de GitHub. Espeja
// `Features/Reports/SpendingHeatmapView.swift` de iOS:
//  - Grilla 7×N: filas = día de la semana (Dom=0 … Sáb=6), columnas = semanas.
//  - Una celda por día del año; la intensidad (0–4) sale de los QUINTILES
//    ADAPTATIVOS del gasto diario no nulo (NO thresholds fijos): así se ajusta
//    al volumen de gasto de cada hogar.
//  - Stats: total del año, días con gasto, promedio por día con gasto.
//  - Tap en un día → línea de detalle con la fecha + monto exacto.
//
// La data llega del server (`getDailySpend`) como [{date,total}]; acá armamos
// el calendario completo del año para que los días sin gasto rendericen como
// celdas vacías (nivel 0). El año se cambia vía `?fy=` (lo maneja el page).
import { useMemo, useState } from "react";
import { Amount } from "@/components/finance/amount";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import { formatMoney } from "@/lib/money";
import { formatWeekdayLong } from "@/lib/i18n/dates";
import type { DailySpend } from "@/lib/db/analytics";

/** Una celda del heatmap: un día concreto del año. */
interface DayCell {
  /** "YYYY-MM-DD" (UTC). */
  date: string;
  /** 0 = Dom … 6 = Sáb (semana UTC). */
  weekday: number;
  /** Día del mes 1..31. */
  dayOfMonth: number;
  /** Mes 0..11. */
  month: number;
  /** Índice de columna (semana) en la grilla. */
  weekIndex: number;
  /** Gasto del día (moneda base). */
  amount: number;
}

/** Umbrales de quintiles para el bucketing 0–4. */
interface Quintiles {
  q1: number;
  q2: number;
  q3: number;
  q4: number;
}

/**
 * Quintiles adaptativos a partir de los gastos diarios NO nulos. Port directo
 * de `computeQuintiles` (iOS): ordena los montos > 0 y toma los cortes en
 * n/5, 2n/5, 3n/5, 4n/5. Con < 5 días de datos, cae a thresholds por magnitud
 * (max/5, 2·max/5, …) — idéntico al fallback de iOS.
 */
function computeQuintiles(nonZeroSorted: number[]): Quintiles {
  const n = nonZeroSorted.length;
  if (n < 5) {
    const max = n > 0 ? nonZeroSorted[n - 1] : 0;
    return { q1: max / 5, q2: (max * 2) / 5, q3: (max * 3) / 5, q4: (max * 4) / 5 };
  }
  return {
    q1: nonZeroSorted[Math.floor(n / 5)],
    q2: nonZeroSorted[Math.floor((2 * n) / 5)],
    q3: nonZeroSorted[Math.floor((3 * n) / 5)],
    q4: nonZeroSorted[Math.floor((4 * n) / 5)],
  };
}

/**
 * Bucket 0–4 de un monto. Idéntico a `Quintiles.bucket` de iOS:
 * 0 = sin gasto; 1..4 = intensidad creciente (el último corte cae en 4).
 */
function bucketFor(amount: number, q: Quintiles): number {
  if (amount <= 0) return 0;
  if (amount < q.q1) return 1;
  if (amount < q.q2) return 2;
  if (amount < q.q3) return 3;
  return 4;
}

/**
 * Color de la celda por intensidad. Espeja `colorFor(intensity:)` de iOS:
 * 0 = superficie tenue; 1..4 = coral (gasto) a opacidad creciente.
 * Vía tokens (`--mc-expense`) para que en tema claro use la terracota oscura
 * en vez del coral pastel, que sobre blanco sería ilegible.
 */
const CELL_COLORS = [
  "var(--mc-inset)",
  "color-mix(in srgb, var(--mc-expense) 25%, transparent)",
  "color-mix(in srgb, var(--mc-expense) 45%, transparent)",
  "color-mix(in srgb, var(--mc-expense) 70%, transparent)",
  "var(--mc-expense)",
] as const;

/** Construye las celdas de TODOS los días del año, con su gasto (0 si no hay). */
function buildCells(year: number, byDate: Map<string, number>): DayCell[] {
  const cells: DayCell[] = [];
  // Recorremos el año en UTC para que el "día" coincida con el slice de la query.
  const cursor = new Date(Date.UTC(year, 0, 1));
  // Semana base: días desde el 1-ene; la columna agrupa por semana del año
  // alineada al domingo (igual criterio visual que iOS: filas Dom..Sáb).
  const jan1Weekday = cursor.getUTCDay(); // 0=Dom
  while (cursor.getUTCFullYear() === year) {
    const iso = cursor.toISOString().slice(0, 10);
    const weekday = cursor.getUTCDay();
    const dayOfYear = Math.floor(
      (cursor.getTime() - Date.UTC(year, 0, 1)) / 86_400_000,
    );
    // Columna = en qué semana (alineada a domingo) cae el día.
    const weekIndex = Math.floor((dayOfYear + jan1Weekday) / 7);
    cells.push({
      date: iso,
      weekday,
      dayOfMonth: cursor.getUTCDate(),
      month: cursor.getUTCMonth(),
      weekIndex,
      amount: byDate.get(iso) ?? 0,
    });
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return cells;
}

/** Etiqueta de mes corto, en mayúsculas, localizada (UTC-safe). */
function monthShort(year: number, month0: number, locale: string): string {
  return new Date(Date.UTC(year, month0, 1))
    .toLocaleDateString(locale === "pt" ? "pt-BR" : locale, {
      month: "short",
      timeZone: "UTC",
    })
    .toUpperCase();
}

export function SpendingHeatmap({
  dailySpend,
  year,
  currency,
}: {
  dailySpend: DailySpend[];
  year: number;
  currency: string;
}) {
  const t = useT();
  const locale = useLocale();
  const [selected, setSelected] = useState<DayCell | null>(null);

  const byDate = useMemo(() => {
    const m = new Map<string, number>();
    for (const d of dailySpend) m.set(d.date, d.total);
    return m;
  }, [dailySpend]);

  const cells = useMemo(() => buildCells(year, byDate), [year, byDate]);

  // Quintiles desde los gastos diarios > 0 (ordenados), igual que iOS.
  const quintiles = useMemo(() => {
    const nonZero = cells
      .map((c) => c.amount)
      .filter((a) => a > 0)
      .sort((a, b) => a - b);
    return computeQuintiles(nonZero);
  }, [cells]);

  // Stats del header (paridad iOS `statsHeader`): total, días con gasto y
  // promedio por día con gasto.
  const total = useMemo(() => dailySpend.reduce((s, d) => s + d.total, 0), [dailySpend]);
  const activeDays = useMemo(() => dailySpend.filter((d) => d.total > 0).length, [dailySpend]);
  const avg = activeDays > 0 ? total / activeDays : 0;

  // Semanas (columnas): ordenadas por índice. Cada una con sus 7 días.
  const weeks = useMemo(() => {
    const map = new Map<number, DayCell[]>();
    for (const c of cells) {
      const arr = map.get(c.weekIndex) ?? [];
      arr.push(c);
      map.set(c.weekIndex, arr);
    }
    return Array.from(map.entries())
      .sort((a, b) => a[0] - b[0])
      .map(([, days]) => days);
  }, [cells]);

  // Etiquetas del eje Y (día de la semana): solo L/M/V para no saturar (iOS).
  const dayLabels = ["", "L", "", "M", "", "V", ""];

  return (
    <div>
      {/* Stats */}
      <div className="mb-4 grid grid-cols-3 gap-3">
        <Stat label={t("reports.heatmapTotal")}>
          <Amount value={total} currency={currency} kind="gasto" className="text-base font-semibold" style="compact" />
        </Stat>
        <Stat label={t("reports.activeDays")}>
          <span className="font-num tnum text-base font-semibold text-foreground">{activeDays}</span>
        </Stat>
        <Stat label={t("reports.avgPerDay")}>
          <Amount value={avg} currency={currency} kind="gasto" className="text-base font-semibold" style="compact" />
        </Stat>
      </div>

      {/* Grilla: scroll horizontal en pantallas chicas (no desborda a 360px). */}
      <div className="overflow-x-auto pb-1">
        <div className="flex items-start gap-1" role="img" aria-label={t("reports.heatmapTitle")}>
          {/* Eje Y: iniciales de día. */}
          <div className="mr-1 flex flex-col gap-[3px] pt-[14px]">
            {dayLabels.map((d, i) => (
              <span
                key={i}
                className="text-text-muted flex h-[13px] w-3 items-center justify-end text-[9px] font-medium leading-none"
              >
                {d}
              </span>
            ))}
          </div>

          {/* Columnas = semanas. */}
          {weeks.map((days, wi) => {
            // Label de mes: la semana muestra el nombre si contiene el día 1–7.
            const firstWeekDay = days.find((d) => d.dayOfMonth <= 7);
            return (
              <div key={wi} className="flex flex-col gap-[3px]">
                <span className="text-text-muted h-[11px] text-[9px] font-semibold leading-none">
                  {firstWeekDay ? monthShort(year, firstWeekDay.month, locale) : ""}
                </span>
                {Array.from({ length: 7 }, (_, weekday) => {
                  const cell = days.find((d) => d.weekday === weekday);
                  if (!cell) {
                    return <span key={weekday} className="size-[13px]" />;
                  }
                  const level = bucketFor(cell.amount, quintiles);
                  const isSel = selected?.date === cell.date;
                  return (
                    <button
                      key={weekday}
                      type="button"
                      onClick={() => setSelected(cell)}
                      title={`${cell.date} · ${formatMoney(cell.amount, currency, "compact")}`}
                      aria-label={`${cell.date}: ${formatMoney(cell.amount, currency, "compact")}`}
                      className="size-[13px] rounded-[3px] outline-none transition-transform hover:scale-125 focus-visible:ring-2 focus-visible:ring-sage"
                      style={{
                        backgroundColor: CELL_COLORS[level],
                        boxShadow: isSel ? "0 0 0 2px var(--mc-sage)" : undefined,
                      }}
                    />
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>

      {/* Leyenda menos→más (paridad iOS `legend`). */}
      <div className="text-text-muted mt-3 flex items-center gap-1.5 text-[11px]">
        <span>{t("reports.heatmapLess")}</span>
        {CELL_COLORS.map((c, i) => (
          <span key={i} className="size-3 rounded-[3px]" style={{ backgroundColor: c }} />
        ))}
        <span>{t("reports.heatmapMore")}</span>
      </div>

      {/* Detalle del día tocado (línea inline, como la `selectedCard` de iOS). */}
      <div className="mt-3 min-h-[2.5rem]">
        {selected ? (
          <div className="hairline bg-surface/60 flex items-center justify-between gap-3 rounded-[var(--radius-md)] px-3 py-2.5">
            <span className="text-sm capitalize text-foreground">
              {capitalize(formatWeekdayLong(new Date(`${selected.date}T12:00:00Z`), locale))}
            </span>
            {selected.amount > 0 ? (
              <Amount value={selected.amount} currency={currency} kind="gasto" className="text-sm font-semibold" />
            ) : (
              <span className="text-text-muted text-xs">{t("reports.heatmapNoSpend")}</span>
            )}
          </div>
        ) : (
          <p className="text-text-muted text-xs">{t("reports.heatmapSelectDay")}</p>
        )}
      </div>
    </div>
  );
}

function Stat({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="hairline bg-surface/40 rounded-[var(--radius-md)] px-3 py-2.5">
      <p className="text-text-muted text-[10px] font-semibold uppercase tracking-wider">{label}</p>
      <div className="mt-1">{children}</div>
    </div>
  );
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
