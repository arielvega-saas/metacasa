import type { Client } from "@/lib/supabase/types";
import { getStrategy, DEFAULT_STRATEGY } from "@/lib/db/strategy";

/**
 * Helpers de SOLO LECTURA para los widgets extra del dashboard (sparklines,
 * savings/investment split). NO muta nada y NO toca `lib/db/transactions.ts`
 * (puede importar de él, pero acá no hace falta). Todo filtra por hogar y
 * confía en RLS.
 *
 * Paridad iOS `HomeView` (`Features/Home/HomeView.swift`):
 *  - Sparklines: buckets diarios de los últimos `days` días (índice `days-1`
 *    = HOY), separados por tipo INGRESO / GASTO. Mismo criterio que
 *    `HomeViewModel.incomeSparkline` / `expenseSparkline` (que arman 7 slots y
 *    acumulan por `dateComponents(.day, from: tx.date, to: now)`).
 *  - Estrategia ahorro/inversión: lee `households.strategy` (JSONB,
 *    `savings_pct` / `investment_pct`), la MISMA fuente canónica que usa iOS
 *    (`Household.swift` `HouseholdStrategy`) y la pantalla de Presupuesto
 *    (`lib/db/strategy.ts`). SOLO lectura — no escribimos la estrategia desde acá.
 *    (Antes leía la tabla legacy `public.strategy` de la PWA vieja, que está
 *    vacía y NO es la fuente de verdad — daba 0% siempre y no coincidía con
 *    Presupuesto ni con la app.)
 */

/** Series diarias de ingresos y gastos para los sparklines (longitud = `days`). */
export interface DailyFlowSparklines {
  /** Σ ingresos por día. `income[days-1]` es HOY; `income[0]` es hace `days-1` días. */
  income: number[];
  /** Σ gastos por día, misma orientación que `income`. */
  expense: number[];
  /** Cantidad de días que cubre cada serie. */
  days: number;
}

/** Clave "YYYY-MM-DD" en UTC para una fecha. */
function utcDateKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/**
 * Series diarias (últimos `days` días, default 7) de ingresos y gastos en
 * MONEDA BASE del hogar (`transactions.amount`, igual que el resto del
 * dashboard). Devuelve dos arrays alineados: el último elemento es HOY.
 *
 * Implementación: una sola query acotada a la ventana, bucketeada por el slice
 * "YYYY-MM-DD" de `date` (las tx se guardan a mediodía UTC vía `toStableDate`,
 * así que el slice UTC cae en el día correcto). Los días sin movimiento quedan
 * en 0 (no se omiten) para que el sparkline tenga la longitud completa.
 */
export async function getDailyFlowSparklines(
  supabase: Client,
  householdId: string,
  days = 7,
): Promise<DailyFlowSparklines> {
  const n = Math.max(1, days);
  // Ancla en UTC: el inicio de la ventana es la medianoche UTC de hace n-1 días.
  const now = new Date();
  const todayUtc = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  const startUtc = new Date(todayUtc);
  startUtc.setUTCDate(startUtc.getUTCDate() - (n - 1));

  // Índice por clave de día → posición en el array (0 = más antiguo, n-1 = hoy).
  const indexByKey = new Map<string, number>();
  for (let i = 0; i < n; i++) {
    const d = new Date(startUtc);
    d.setUTCDate(d.getUTCDate() + i);
    indexByKey.set(utcDateKey(d), i);
  }

  const income = new Array<number>(n).fill(0);
  const expense = new Array<number>(n).fill(0);

  const { data, error } = await supabase
    .from("transactions")
    .select("amount, type, date")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .gte("date", startUtc.toISOString());
  if (error) throw error;

  for (const t of data ?? []) {
    const key = String(t.date).slice(0, 10);
    const idx = indexByKey.get(key);
    if (idx == null) continue; // fuera de ventana (p.ej. tx futura o borde)
    const amt = Number(t.amount);
    if (t.type === "INGRESO") income[idx] += amt;
    else if (t.type === "GASTO") expense[idx] += amt;
    // Otros tipos no entran al sparkline de ingreso/gasto.
  }

  return { income, expense, days: n };
}

/**
 * Días (claves "YYYY-MM-DD" UTC) con al menos un movimiento en los últimos
 * `days` días. Alimenta el Health Score (consistencia) y la racha del dashboard,
 * que iOS deriva de `recentTransactions` (`HomeViewModel.streak` /
 * `healthScore`). Devolvemos solo las fechas (no montos) para no traer payload
 * de más. SOLO lectura.
 */
export async function getActiveTxDays(
  supabase: Client,
  householdId: string,
  days = 30,
): Promise<Set<string>> {
  const n = Math.max(1, days);
  const now = new Date();
  const start = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - (n - 1)),
  );
  const { data, error } = await supabase
    .from("transactions")
    .select("date")
    .eq("household_id", householdId)
    .is("transfer_group_id", null)
    .gte("date", start.toISOString());
  if (error) throw error;
  const out = new Set<string>();
  for (const t of data ?? []) out.add(String(t.date).slice(0, 10));
  return out;
}

/** Porcentajes de ahorro/inversión configurados para el hogar (0 si no hay fila). */
export interface HouseholdSplitStrategy {
  savingsPercent: number;
  investmentPercent: number;
  /** `false` si el hogar todavía no configuró una estrategia. */
  configured: boolean;
}

/**
 * Lee la estrategia ahorro/inversión del hogar (SOLO lectura) desde la fuente
 * CANÓNICA `households.strategy` (JSONB), reusando `getStrategy` de
 * `lib/db/strategy.ts` — la misma que usan la pantalla de Presupuesto y la app
 * iOS. Así el dashboard, el presupuesto y la app muestran SIEMPRE los mismos
 * porcentajes. Aplica `savingsPct` / `investmentPct` sobre los ingresos del mes
 * (paridad iOS `SavingsInvestmentCard`).
 *
 * `configured` es `true` cuando el hogar tiene una estrategia con algún
 * porcentaje > 0 (si está todo en los defaults 10/0 lo consideramos configurado
 * igual, porque el JSONB existe; usamos "algún pct > 0" para distinguir el hogar
 * que nunca tocó nada y mostrar el estado "configurar" solo si ambos son 0).
 */
export async function getHouseholdSplitStrategy(
  supabase: Client,
  householdId: string,
): Promise<HouseholdSplitStrategy> {
  const s = await getStrategy(supabase, householdId);
  const savingsPercent = s.savingsPct;
  const investmentPercent = s.investmentPct;
  const configured = savingsPercent > 0 || investmentPercent > 0;
  return { savingsPercent, investmentPercent, configured };
}

// `DEFAULT_STRATEGY` se importa para documentar el origen de los defaults (10/0);
// `getStrategy` ya los aplica internamente cuando el hogar no tiene estrategia.
void DEFAULT_STRATEGY;
