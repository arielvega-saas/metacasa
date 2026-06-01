import type { Client } from "@/lib/supabase/types";
import type { Tables, TablesInsert, TablesUpdate } from "@/lib/database.types";

/**
 * Plantillas de transacción (atajos rápidos / "quick-add"). Espejo EXACTO de la
 * tabla `transaction_templates` que ya consume iOS (`Core/TemplateService.swift`).
 * Aplicar una plantilla crea un movimiento real HOY — la lógica vive en
 * `lib/actions/templates.ts`; acá solo el acceso a datos (CRUD), igual que el
 * resto del repo. RLS valida pertenencia al hogar en cada operación.
 */
export type TransactionTemplate = Tables<"transaction_templates">;

/**
 * Plantillas del hogar, ordenadas por `position` ascendente — IDÉNTICO a iOS
 * `TemplateService.fetchAll` (`.order("position", ascending: true)`), así ambos
 * clientes muestran los atajos en el mismo orden.
 */
export async function listTemplates(
  supabase: Client,
  householdId: string,
): Promise<TransactionTemplate[]> {
  const { data, error } = await supabase
    .from("transaction_templates")
    .select("*")
    .eq("household_id", householdId)
    .order("position", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/**
 * Crea una plantilla. `position` se calcula como el siguiente al máximo actual
 * del hogar (al final de la lista) si no viene en el input — equivalente a iOS,
 * que pasa `position: templates.count` al crear desde el form.
 */
export async function createTemplateRow(
  supabase: Client,
  input: TablesInsert<"transaction_templates">,
): Promise<TransactionTemplate> {
  let position = input.position;
  if (position == null) {
    const { data: last } = await supabase
      .from("transaction_templates")
      .select("position")
      .eq("household_id", input.household_id)
      .order("position", { ascending: false })
      .limit(1)
      .maybeSingle();
    position = (last?.position ?? -1) + 1;
  }

  const { data, error } = await supabase
    .from("transaction_templates")
    .insert({ ...input, position })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Actualiza los campos editables de una plantilla. RLS valida pertenencia. */
export async function updateTemplateRow(
  supabase: Client,
  id: string,
  householdId: string,
  patch: TablesUpdate<"transaction_templates">,
): Promise<TransactionTemplate> {
  const { data, error } = await supabase
    .from("transaction_templates")
    .update(patch)
    .eq("id", id)
    .eq("household_id", householdId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Elimina una plantilla (hard-delete, igual que iOS `TemplateService.delete`). */
export async function deleteTemplateRow(
  supabase: Client,
  id: string,
  householdId: string,
): Promise<void> {
  const { error } = await supabase
    .from("transaction_templates")
    .delete()
    .eq("id", id)
    .eq("household_id", householdId);
  if (error) throw error;
}

/** Lee una plantilla por id dentro del hogar (para aplicarla). RLS valida. */
export async function getTemplateRow(
  supabase: Client,
  id: string,
  householdId: string,
): Promise<TransactionTemplate | null> {
  const { data, error } = await supabase
    .from("transaction_templates")
    .select("*")
    .eq("id", id)
    .eq("household_id", householdId)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}
