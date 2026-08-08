import type { Client } from "@/lib/supabase/types";
import type { Tables } from "@/lib/database.types";

export type BudgetPeriod = Tables<"budget_periods">;
export type BudgetAllocation = Tables<"budget_allocations">;


/**
 * Totales del período según la **definición canónica del servidor**
 * (`public.budget_period_summary`).
 *
 * Antes esto se calculaba acá con un `sumPeriodIncome` local, y era la QUINTA implementación de
 * la misma regla (iOS, el card del Home, el hub de Presupuesto, el asistente de IA y ésta). Las
 * cinco divergían en cosas que cuestan plata:
 *
 *  - **Contaba las transferencias como ingreso.** Mover $500.000 de la caja de ahorro a la cuenta
 *    corriente le sumaba $500.000 al "listo para asignar" — plata que no existe.
 *  - **No convertía monedas al sumar lo asignado.** Un sobre en dólares en un hogar en pesos se
 *    sumaba como si fuera pesos, o sea dividido por la cotización.
 *  - **Ignoraba los sobres sin cotización**, que el RPC cuenta aparte (`fx_missing_count`) en vez
 *    de asumir un 1 silencioso.
 *
 * El RPC no puede driftear porque no guarda nada: se calcula sobre las tasas de HOY, que el job
 * diario reescribe. Ver `supabase/migrations/20260803170000_budget_period_summary.sql`.
 */
async function periodSummary(
  supabase: Client,
  periodId: string,
): Promise<{ total_income: number; total_allocated: number; ready_to_assign: number }> {
  const { data, error } = await supabase.rpc("budget_period_summary", { p_period_id: periodId });
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  return {
    total_income: Number(row?.total_income ?? 0),
    total_allocated: Number(row?.total_allocated ?? 0),
    ready_to_assign: Number(row?.ready_to_assign ?? 0),
  };
}

/**
 * Período de presupuesto vigente hoy (si existe).
 *
 * `today` se pasa desde afuera (`getToday()`, que resuelve el día del usuario a
 * partir de la cookie de zona horaria). Calcularlo acá con el reloj del server
 * sería mirar el día UTC: en Netlify las funciones corren con `TZ=UTC`, así que
 * el último día del mes, después de las 21 en Argentina, el período vigente ya
 * habría "terminado" para el usuario que todavía lo está viviendo.
 */
export async function getCurrentPeriod(
  supabase: Client,
  householdId: string,
  today: string = new Date().toISOString().slice(0, 10),
): Promise<BudgetPeriod | null> {
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
  return { ...data, ...(await periodSummary(supabase, data.id)) };
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
  today?: string,
): Promise<BudgetPeriod | null> {
  // Sólo se llega acá con un `ym` inválido, que hoy no pasa desde las páginas
  // (siempre mandan uno válido). Se propaga `today` igual para que el fallback
  // no vuelva al reloj UTC del server el día que alguien sí lo alcance.
  if (!/^\d{4}-\d{2}$/.test(ym)) return getCurrentPeriod(supabase, householdId, today);
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

  return { ...data, ...(await periodSummary(supabase, data.id)) };
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
  // Sin cálculo local: `tg_budget_periods_zz_totals` siembra `total_income`,
  // `total_allocated` y `ready_to_assign` en el INSERT, con la misma definición que usa el resto
  // de la app (sin transferencias, con conversión de moneda y con el arrastre ya aplicado por el
  // trigger de rollover, que corre antes). Calcularlo acá era garantizar una sexta verdad.
  const { data, error } = await supabase
    .from("budget_periods")
    .insert({
      household_id: input.householdId,
      period_type: input.periodType ?? "month",
      period_start: input.periodStart,
      period_end: input.periodEnd,
    })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

// `syncPeriodTotals` se eliminó: `tg_budget_allocations_totals` recalcula el período en cada
// INSERT/UPDATE/DELETE de sobres, con conversión de moneda incluida. La versión de acá sumaba
// `allocated` en crudo, así que en un hogar multi-moneda escribía un total MAL sobre lo que el
// trigger había dejado bien — el último en escribir ganaba, y era éste.

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

}
