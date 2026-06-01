import type { Client } from "@/lib/supabase/types";
import type { Tables } from "@/lib/database.types";

export type BudgetPeriod = Tables<"budget_periods">;
export type BudgetAllocation = Tables<"budget_allocations">;

/**
 * Cota superior INCLUSIVA para filtrar transacciones por fecha en un período.
 * Las tx fecha-sólo se guardan a mediodía UTC (`YYYY-MM-DDT12:00:00.000Z`, ver
 * `toStableDate` en `db/transactions.ts`), así que un `.lte("date", period_end)`
 * con `period_end` como fecha-sólo (`YYYY-MM-DD` = medianoche UTC) EXCLUYE el
 * último día del período. Empujamos la cota al final del día (`T23:59:59.999Z`)
 * para que el último día quede incluido. Único helper compartido entre
 * `createPeriod` y `getCurrentPeriod` para que ambos coincidan exactamente.
 */
function inclusiveDateEnd(periodEnd: string): string {
  // Si ya viene con componente de hora, respetarlo; si es fecha-sólo, extender.
  return /^\d{4}-\d{2}-\d{2}$/.test(periodEnd)
    ? `${periodEnd}T23:59:59.999Z`
    : periodEnd;
}

/**
 * Suma de ingresos (en moneda base) del hogar dentro del rango `[start, end]`.
 * Usa la cota superior inclusiva compartida. Devuelve el total redondeado a la
 * representación numérica de JS (la columna es numeric en DB). Es la ÚNICA
 * fuente de verdad del `total_income` para crear y para recomputar en vivo.
 */
async function sumPeriodIncome(
  supabase: Client,
  householdId: string,
  periodStart: string,
  periodEnd: string,
): Promise<number> {
  const { data, error } = await supabase
    .from("transactions")
    .select("amount")
    .eq("household_id", householdId)
    .eq("type", "INGRESO")
    .gte("date", periodStart)
    .lte("date", inclusiveDateEnd(periodEnd));
  if (error) throw error;
  return (data ?? []).reduce((s, r) => s + Number(r.amount ?? 0), 0);
}

/** Período de presupuesto vigente hoy (si existe). */
export async function getCurrentPeriod(
  supabase: Client,
  householdId: string,
): Promise<BudgetPeriod | null> {
  const today = new Date().toISOString().slice(0, 10);
  const { data, error } = await supabase
    .from("budget_periods")
    .select("*")
    .eq("household_id", householdId)
    .lte("period_start", today)
    .gte("period_end", today)
    .order("period_start", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;

  // Recalcular ingresos y asignado EN VIVO: las columnas almacenadas quedan
  // desactualizadas si se registran ingresos después de crear el período (el
  // "ready to assign" arrancaría en 0 para siempre). La verdad para mostrar se
  // computa acá; las mutaciones igual mantienen la DB sincronizada. El rango de
  // ingresos usa el MISMO helper que `createPeriod`, así que el `total_income`
  // recomputado coincide con el que se guardó al crear el período.
  const [totalIncome, { data: allocRows }] = await Promise.all([
    sumPeriodIncome(supabase, householdId, data.period_start, data.period_end),
    supabase.from("budget_allocations").select("allocated").eq("period_id", data.id),
  ]);
  const totalAllocated = (allocRows ?? []).reduce((s, r) => s + Number(r.allocated ?? 0), 0);

  return {
    ...data,
    total_income: totalIncome,
    total_allocated: totalAllocated,
    ready_to_assign: totalIncome - totalAllocated,
  };
}

/**
 * Período de presupuesto que CONTIENE el mes `ym` (formato "YYYY-MM"), con
 * ingresos y asignado recomputados en vivo (igual que `getCurrentPeriod`).
 *
 * Espeja a iOS `BudgetService.fetchPeriod(containing:)`: busca el período cuyo
 * `[period_start, period_end]` cubre el mes pedido, ordenando por `period_start`
 * desc para quedarse con el más reciente si hubiera solapamiento. Usamos el día
 * 15 del mes como ancla — cae siempre dentro del rango de un período mensual
 * (`primer día … último día`), evitando bordes en los extremos del mes.
 *
 * NO crea períodos (la web crea sólo vía el CTA `createPeriod`). Devuelve `null`
 * si el mes pedido no tiene período aún.
 */
export async function getPeriodForMonth(
  supabase: Client,
  householdId: string,
  ym: string,
): Promise<BudgetPeriod | null> {
  if (!/^\d{4}-\d{2}$/.test(ym)) return getCurrentPeriod(supabase, householdId);
  const anchor = `${ym}-15`; // mediodía del mes, dentro de cualquier período mensual

  const { data, error } = await supabase
    .from("budget_periods")
    .select("*")
    .eq("household_id", householdId)
    .lte("period_start", anchor)
    .gte("period_end", anchor)
    .order("period_start", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;

  const [totalIncome, { data: allocRows }] = await Promise.all([
    sumPeriodIncome(supabase, householdId, data.period_start, data.period_end),
    supabase.from("budget_allocations").select("allocated").eq("period_id", data.id),
  ]);
  const totalAllocated = (allocRows ?? []).reduce((s, r) => s + Number(r.allocated ?? 0), 0);

  return {
    ...data,
    total_income: totalIncome,
    total_allocated: totalAllocated,
    ready_to_assign: totalIncome - totalAllocated,
  };
}

/** Asignaciones (envelopes) de un período. */
export async function listAllocations(
  supabase: Client,
  periodId: string,
): Promise<BudgetAllocation[]> {
  const { data, error } = await supabase
    .from("budget_allocations")
    .select("*")
    .eq("period_id", periodId)
    .order("category", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/** Saldo de un envelope (gastado vs asignado) vía RPC server-side. */
export async function envelopeBalance(
  supabase: Client,
  periodId: string,
  category: string,
  subcategory = "",
): Promise<number> {
  const { data, error } = await supabase.rpc("envelope_balance", {
    p_period_id: periodId,
    p_category: category,
    p_subcategory: subcategory,
  });
  if (error) throw error;
  return Number(data ?? 0);
}

// ── Mutaciones (agregadas para la pantalla /budgets) ──────────────────────────

/**
 * Crea un período de presupuesto y lo siembra con los ingresos reales del rango.
 * `ready_to_assign` arranca igual a `total_income` (todavía no hay nada asignado).
 * Estas columnas no las mantiene ningún trigger, así que las calculamos acá y en
 * `upsertAllocation`/`deleteAllocation`.
 */
export async function createPeriod(
  supabase: Client,
  input: {
    householdId: string;
    periodType?: BudgetPeriod["period_type"];
    periodStart: string; // ISO date YYYY-MM-DD
    periodEnd: string; // ISO date YYYY-MM-DD
  },
): Promise<BudgetPeriod> {
  // Ingresos del hogar dentro del rango del período (moneda base del hogar).
  // Cota superior INCLUSIVA compartida con `getCurrentPeriod`: antes este path
  // usaba `.lte("date", periodEnd)` con fecha-sólo y se comía el último día del
  // mes (las tx se guardan a mediodía UTC). Ahora el `total_income` guardado
  // coincide con el recomputado en vivo.
  const totalIncome = await sumPeriodIncome(
    supabase,
    input.householdId,
    input.periodStart,
    input.periodEnd,
  );

  const { data, error } = await supabase
    .from("budget_periods")
    .insert({
      household_id: input.householdId,
      period_type: input.periodType ?? "month",
      period_start: input.periodStart,
      period_end: input.periodEnd,
      total_income: totalIncome,
      total_allocated: 0,
      ready_to_assign: totalIncome,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Recalcula `total_allocated` y `ready_to_assign` del período tras tocar sobres. */
async function syncPeriodTotals(
  supabase: Client,
  periodId: string,
): Promise<void> {
  const { data: rows, error: sumError } = await supabase
    .from("budget_allocations")
    .select("allocated")
    .eq("period_id", periodId);
  if (sumError) throw sumError;

  const totalAllocated = (rows ?? []).reduce(
    (sum, r) => sum + Number(r.allocated ?? 0),
    0,
  );

  const { data: period, error: periodError } = await supabase
    .from("budget_periods")
    .select("total_income")
    .eq("id", periodId)
    .single();
  if (periodError) throw periodError;

  const { error: updError } = await supabase
    .from("budget_periods")
    .update({
      total_allocated: totalAllocated,
      ready_to_assign: Number(period.total_income ?? 0) - totalAllocated,
    })
    .eq("id", periodId);
  if (updError) throw updError;
}

/**
 * Crea o actualiza una asignación (envelope) por (period_id, category, subcategory).
 * Usa la unique constraint para hacer upsert idempotente y resincroniza el período.
 */
export async function upsertAllocation(
  supabase: Client,
  input: {
    periodId: string;
    category: string;
    subcategory?: string;
    allocated: number;
    currency: string;
  },
): Promise<BudgetAllocation> {
  const { data, error } = await supabase
    .from("budget_allocations")
    .upsert(
      {
        period_id: input.periodId,
        category: input.category,
        subcategory: input.subcategory ?? "",
        allocated: input.allocated,
        currency: input.currency,
      },
      { onConflict: "period_id,category,subcategory" },
    )
    .select("*")
    .single();
  if (error) throw error;

  await syncPeriodTotals(supabase, input.periodId);
  return data;
}

/** Elimina una asignación y resincroniza los totales del período. */
export async function deleteAllocation(
  supabase: Client,
  allocationId: string,
  periodId: string,
): Promise<void> {
  const { error } = await supabase
    .from("budget_allocations")
    .delete()
    .eq("id", allocationId);
  if (error) throw error;

  await syncPeriodTotals(supabase, periodId);
}
