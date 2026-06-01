import type { Client } from "@/lib/supabase/types";
import type { Tables, TablesInsert, TablesUpdate } from "@/lib/database.types";

export type RecurringTransaction = Tables<"recurring_transactions">;

/**
 * Frecuencias soportadas — espejo EXACTO de iOS `Frequency`
 * (`Models/RecurringTransaction.swift`). El orden es el de aparición en la UI.
 */
export const FREQUENCIES = ["daily", "weekly", "monthly", "yearly"] as const;
export type Frequency = (typeof FREQUENCIES)[number];

export function isFrequency(v: string | null | undefined): v is Frequency {
  return !!v && (FREQUENCIES as readonly string[]).includes(v);
}

/**
 * Calcula la próxima fecha a partir de una fecha "YYYY-MM-DD" según la frecuencia.
 * Puerto 1:1 de iOS `Frequency.nextDate(from:)`: suma 1 día / 7 días / 1 mes /
 * 1 año. Trabajamos en UTC sobre la fecha-sólo para evitar corrimientos de zona
 * (las columnas son `date`, sin hora). Devuelve "YYYY-MM-DD".
 */
export function computeNextDate(startDate: string, frequency: Frequency): string {
  const [y, m, d] = startDate.split("-").map(Number);
  const base = new Date(Date.UTC(y, (m ?? 1) - 1, d ?? 1));
  switch (frequency) {
    case "daily":
      base.setUTCDate(base.getUTCDate() + 1);
      break;
    case "weekly":
      base.setUTCDate(base.getUTCDate() + 7);
      break;
    case "monthly":
      base.setUTCMonth(base.getUTCMonth() + 1);
      break;
    case "yearly":
      base.setUTCFullYear(base.getUTCFullYear() + 1);
      break;
  }
  return base.toISOString().slice(0, 10);
}

/**
 * Lista los recurrentes del hogar. Por defecto incluye activos e inactivos
 * (la pantalla los agrupa); `activeOnly` filtra a `active=true`. Orden por
 * `next_date` ascendente, igual que iOS `RecurringService.fetchAll`.
 */
export async function listRecurring(
  supabase: Client,
  householdId: string,
  opts: { activeOnly?: boolean } = {},
): Promise<RecurringTransaction[]> {
  let q = supabase
    .from("recurring_transactions")
    .select("*")
    .eq("household_id", householdId);
  if (opts.activeOnly) q = q.eq("active", true);
  q = q
    .order("next_date", { ascending: true, nullsFirst: false })
    .order("start_date", { ascending: true });
  const { data, error } = await q;
  if (error) throw error;
  return data ?? [];
}

/**
 * Crea un recurrente. `next_date` se siembra como `start_date` (igual que iOS
 * `RecurringService.create`, que pasa `next_date: startDate`). RLS valida
 * pertenencia al hogar.
 */
export async function createRecurring(
  supabase: Client,
  input: TablesInsert<"recurring_transactions">,
): Promise<RecurringTransaction> {
  const { data, error } = await supabase
    .from("recurring_transactions")
    .insert(input)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Actualiza un recurrente existente. RLS valida pertenencia al hogar. */
export async function updateRecurring(
  supabase: Client,
  id: string,
  householdId: string,
  patch: TablesUpdate<"recurring_transactions">,
): Promise<RecurringTransaction> {
  const { data, error } = await supabase
    .from("recurring_transactions")
    .update(patch)
    .eq("id", id)
    .eq("household_id", householdId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/**
 * Activa / pausa un recurrente (`active` boolean). Espeja iOS
 * `RecurringService.deactivate` (que solo togglea `active`, sin borrar).
 */
export async function setRecurringActive(
  supabase: Client,
  id: string,
  householdId: string,
  active: boolean,
): Promise<void> {
  const { error } = await supabase
    .from("recurring_transactions")
    .update({ active })
    .eq("id", id)
    .eq("household_id", householdId);
  if (error) throw error;
}

/** Elimina un recurrente. RLS valida pertenencia al hogar. */
export async function deleteRecurring(
  supabase: Client,
  id: string,
  householdId: string,
): Promise<void> {
  const { error } = await supabase
    .from("recurring_transactions")
    .delete()
    .eq("id", id)
    .eq("household_id", householdId);
  if (error) throw error;
}
