import type { Client } from "@/lib/supabase/types";

/**
 * Consultas analíticas ADICIONALES para la pantalla de Reportes (read-only).
 * No muta nada. Respeta RLS por `household_id`. Paridad con el `ReportsView`
 * de iOS (`Features/Reports/ReportsView.swift`): el health score usa, entre
 * otras señales, los "días con actividad" de los últimos 30 días.
 */

/**
 * Cantidad de días DISTINTOS con al menos una transacción en los últimos
 * `days` días (incluye hoy). Espeja el "streak bonus" del health score de iOS:
 *
 *   let daysWithTx = Set(txs.filter { $0.date >= last30 }
 *       .map { cal.startOfDay(for: $0.date) }).count
 *
 * (ver `ReportsView.swift`, `healthScore`). La fecha se agrupa por su día UTC
 * —igual que el resto de las queries de `lib/db/transactions.ts`, que anclan
 * todo en UTC— para que el bucket coincida con el slice "YYYY-MM-DD".
 */
export async function getActiveDays(
  supabase: Client,
  householdId: string,
  days = 30,
): Promise<number> {
  const now = new Date();
  // Ventana [hoy-(days-1) 00:00Z, ahora]: `days` días naturales incluyendo hoy.
  const start = new Date(
    Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() - (days - 1),
    ),
  );

  const { data, error } = await supabase
    .from("transactions")
    .select("date")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .gte("date", start.toISOString());
  if (error) throw error;

  const uniqueDays = new Set<string>();
  for (const t of data ?? []) {
    uniqueDays.add(String(t.date).slice(0, 10)); // "YYYY-MM-DD" (UTC)
  }
  return uniqueDays.size;
}

/** Una entrada de gasto diario para el heatmap anual. */
export interface DailySpend {
  /** Día en UTC, "YYYY-MM-DD". */
  date: string;
  /** Gasto total (moneda base) de ese día. */
  total: number;
}

/**
 * Gasto diario (solo `GASTO`, en moneda base `amount`) de TODO el año `year`,
 * agrupado por día UTC. Una sola query acotada al rango [1-ene, 1-ene del año
 * siguiente). Devuelve solo los días CON gasto (> 0): el heatmap rellena el
 * resto del calendario con celdas vacías. Alimenta `SpendingHeatmap`.
 *
 * Espeja `SpendingHeatmapView.swift` (iOS): ahí se filtra `tx.type == .gasto`
 * y se acumula por `startOfDay`. Acá el bucket es el slice "YYYY-MM-DD" del
 * `date` —que se guarda a mediodía UTC—, consistente con el resto de
 * `lib/db/transactions.ts` (todo anclado en UTC), así el día no se corre bajo
 * zonas negativas (GMT-3).
 */
export async function getDailySpend(
  supabase: Client,
  householdId: string,
  year: number,
): Promise<DailySpend[]> {
  // Rango UTC del año: [year-01-01, (year+1)-01-01). `lt` en el borde superior.
  const start = new Date(Date.UTC(year, 0, 1));
  const end = new Date(Date.UTC(year + 1, 0, 1));

  const { data, error } = await supabase
    .from("transactions")
    .select("amount, date")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .eq("type", "GASTO")
    .gte("date", start.toISOString())
    .lt("date", end.toISOString());
  if (error) throw error;

  const totals = new Map<string, number>();
  for (const t of data ?? []) {
    const day = String(t.date).slice(0, 10); // "YYYY-MM-DD" (UTC, tx a mediodía UTC)
    totals.set(day, (totals.get(day) ?? 0) + Number(t.amount));
  }

  return Array.from(totals.entries())
    .map(([date, total]) => ({ date, total }))
    .sort((a, b) => a.date.localeCompare(b.date));
}

/** Totales de un mes del año para la vista anual. */
export interface AnnualMonthFlow {
  /** Mes 1..12. */
  month: number;
  income: number;
  expense: number;
}

/**
 * Flujos de los 12 meses de un AÑO CALENDARIO fijo `year` (ingreso/gasto en
 * moneda base). Espeja `getMonthlyFlows` pero anclado a un año concreto en vez
 * de "los últimos N meses". Una sola query acotada al rango del año; el bucket
 * es el mes UTC del slice "YYYY-MM", igual que `getMonthlyFlows`. Siempre
 * devuelve 12 entradas (meses sin datos quedan en 0). Alimenta `AnnualView`.
 *
 * Espeja `AnnualView.swift` (iOS): `(1...12).map { … ingresos/gastos por mes }`.
 */
export async function getAnnualFlows(
  supabase: Client,
  householdId: string,
  year: number,
): Promise<AnnualMonthFlow[]> {
  const start = new Date(Date.UTC(year, 0, 1));
  const end = new Date(Date.UTC(year + 1, 0, 1));

  const { data, error } = await supabase
    .from("transactions")
    .select("amount, type, date")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .gte("date", start.toISOString())
    .lt("date", end.toISOString());
  if (error) throw error;

  // 12 buckets inicializados en 0 (meses sin movimientos quedan visibles).
  const buckets: AnnualMonthFlow[] = Array.from({ length: 12 }, (_, i) => ({
    month: i + 1,
    income: 0,
    expense: 0,
  }));

  for (const t of data ?? []) {
    const m = Number(String(t.date).slice(5, 7)); // "MM" (UTC) → 1..12
    if (m < 1 || m > 12) continue;
    const b = buckets[m - 1];
    if (t.type === "INGRESO") b.income += Number(t.amount);
    else if (t.type === "GASTO") b.expense += Number(t.amount);
    // Otros tipos futuros (transferencias) no inflan ingresos ni gastos.
  }

  return buckets;
}
