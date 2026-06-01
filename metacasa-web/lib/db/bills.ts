import type { Client } from "@/lib/supabase/types";
import type { Tables, TablesInsert, TablesUpdate } from "@/lib/database.types";

export type Bill = Tables<"bills">;

/**
 * Estados de vencimiento — espejo EXACTO de iOS `BillStatus`
 * (`Models/Bill.swift`): pending / paid / skipped.
 */
export const BILL_STATUSES = ["pending", "paid", "skipped"] as const;
export type BillStatus = (typeof BILL_STATUSES)[number];

/** Próximos vencimientos pendientes, ordenados por fecha. */
export async function upcomingBills(
  supabase: Client,
  householdId: string,
  limit = 5,
): Promise<Bill[]> {
  const { data, error } = await supabase
    .from("bills")
    .select("*")
    .eq("household_id", householdId)
    .eq("status", "pending")
    .order("due_date", { ascending: true })
    .limit(limit);
  if (error) throw error;
  return data ?? [];
}

/**
 * TODOS los vencimientos del hogar (cualquier estado), ordenados por fecha de
 * vencimiento. La pantalla los agrupa en vencidos / próximos / pagados. Espeja
 * iOS `BillService.fetchAll` (orden por `due_date` ascendente).
 */
export async function listBills(
  supabase: Client,
  householdId: string,
): Promise<Bill[]> {
  const { data, error } = await supabase
    .from("bills")
    .select("*")
    .eq("household_id", householdId)
    .order("due_date", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/** Crea un vencimiento. RLS valida pertenencia al hogar. */
export async function createBill(
  supabase: Client,
  input: TablesInsert<"bills">,
): Promise<Bill> {
  const { data, error } = await supabase
    .from("bills")
    .insert(input)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Actualiza un vencimiento existente. RLS valida pertenencia al hogar. */
export async function updateBill(
  supabase: Client,
  id: string,
  householdId: string,
  patch: TablesUpdate<"bills">,
): Promise<Bill> {
  const { data, error } = await supabase
    .from("bills")
    .update(patch)
    .eq("id", id)
    .eq("household_id", householdId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/**
 * Cambia el estado de un vencimiento. Espeja iOS `BillService.markPaid`, que
 * SOLO actualiza el `status` (no inserta ningún movimiento). El schema vivo de
 * `bills` no tiene `paid_at`, así que no escribimos timestamp de pago.
 */
export async function setBillStatus(
  supabase: Client,
  id: string,
  householdId: string,
  status: BillStatus,
): Promise<void> {
  const { error } = await supabase
    .from("bills")
    .update({ status })
    .eq("id", id)
    .eq("household_id", householdId);
  if (error) throw error;
}

/** Elimina un vencimiento. RLS valida pertenencia al hogar. */
export async function deleteBill(
  supabase: Client,
  id: string,
  householdId: string,
): Promise<void> {
  const { error } = await supabase
    .from("bills")
    .delete()
    .eq("id", id)
    .eq("household_id", householdId);
  if (error) throw error;
}
