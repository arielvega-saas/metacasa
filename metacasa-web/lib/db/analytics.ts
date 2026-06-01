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
    .gte("date", start.toISOString());
  if (error) throw error;

  const uniqueDays = new Set<string>();
  for (const t of data ?? []) {
    uniqueDays.add(String(t.date).slice(0, 10)); // "YYYY-MM-DD" (UTC)
  }
  return uniqueDays.size;
}
