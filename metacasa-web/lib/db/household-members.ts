import type { Client } from "@/lib/supabase/types";
import type { Tables } from "@/lib/database.types";

export type HouseholdMember = Tables<"household_members">;
export type HouseholdInvitation = Tables<"household_invitations">;

/**
 * Miembros del hogar activo. RLS filtra a los hogares del usuario.
 * Nota: NO leemos emails (viven en auth.users y RLS los bloquea); el
 * `display_name` se guarda en la propia fila de `household_members`.
 */
export async function listMembers(
  supabase: Client,
  householdId: string,
): Promise<HouseholdMember[]> {
  const { data, error } = await supabase
    .from("household_members")
    .select("*")
    .eq("household_id", householdId)
    .order("joined_at", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/**
 * Invitaciones pendientes del hogar (status = 'pending').
 * Las aceptadas/expiradas no se muestran en la lista de "pendientes".
 */
export async function listInvitations(
  supabase: Client,
  householdId: string,
): Promise<HouseholdInvitation[]> {
  const { data, error } = await supabase
    .from("household_invitations")
    .select("*")
    .eq("household_id", householdId)
    .eq("status", "pending")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}
