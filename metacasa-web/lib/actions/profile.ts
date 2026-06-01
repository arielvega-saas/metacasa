"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getT } from "@/lib/i18n/server";

/**
 * Actualiza el nombre visible del usuario en Supabase Auth
 * (`user_metadata.display_name`). Es la misma fuente que lee el dashboard.
 */
export async function updateProfileName(displayName: string) {
  const t = await getT();
  const supabase = await createClient();
  const name = displayName.trim();
  if (!name) throw new Error(t("errors.nameEmpty"));

  const { error } = await supabase.auth.updateUser({
    data: { display_name: name },
  });
  if (error) throw new Error(error.message);

  revalidatePath("/profile");
  revalidatePath("/", "layout"); // el saludo del dashboard usa display_name
}

/**
 * Actualiza nombre y moneda principal del hogar. RLS valida que el usuario
 * sea miembro con permisos (owner/admin) del hogar.
 */
export async function updateHouseholdSettings(input: {
  householdId: string;
  name: string;
  defaultCurrency: string;
}) {
  const t = await getT();
  const supabase = await createClient();
  const name = input.name.trim();
  if (!name) throw new Error(t("errors.householdNameEmpty"));

  const { error } = await supabase
    .from("households")
    .update({ name, default_currency: input.defaultCurrency })
    .eq("id", input.householdId);
  if (error) throw new Error(error.message);

  revalidatePath("/profile");
  revalidatePath("/", "layout"); // el switcher de hogares y montos usan estos datos
}

/**
 * Crea una invitación por email a un hogar. `invited_by` = usuario actual.
 * El insert lo valida RLS (solo miembros con permiso pueden invitar).
 */
export async function createInvitation(input: {
  householdId: string;
  email: string;
  role: string;
}) {
  const t = await getT();
  const supabase = await createClient();
  const email = input.email.trim().toLowerCase();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error(t("errors.invalidEmail"));
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionExpired"));

  const { error } = await supabase.from("household_invitations").insert({
    household_id: input.householdId,
    email,
    role: input.role,
    invited_by: user.id,
  });
  if (error) throw new Error(error.message);

  revalidatePath("/profile");
}

// ──────────────────────────────────────────────────────────────────────────
// Gestión de miembros (cambio de rol + baja). ADITIVO: no toca las acciones de
// arriba. Espeja iOS `HouseholdService.updateMemberRole` / `removeMember`
// (escrituras directas a `household_members` bajo RLS). Las policies ya exigen
// owner/admin para UPDATE y owner/admin-o-uno-mismo para DELETE; acá agregamos
// guards explícitos (errores claros) + protección del ÚLTIMO propietario, que
// RLS por sí sola no cubre.
// ──────────────────────────────────────────────────────────────────────────

/** Roles válidos del hogar (match con `household_members.role`). */
const MEMBER_ROLES = ["owner", "admin", "member", "viewer"] as const;
type MemberRole = (typeof MEMBER_ROLES)[number];

/**
 * Resuelve usuario actual + su rol en el hogar. Falla si no hay sesión o no es
 * miembro. Devuelve el rol del caller para los guards de permisos.
 */
async function requireMembership(householdId: string) {
  const t = await getT();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionInvalid"));

  const { data: me } = await supabase
    .from("household_members")
    .select("role")
    .eq("household_id", householdId)
    .eq("user_id", user.id)
    .maybeSingle();
  if (!me) throw new Error(t("errors.noHousehold"));
  return { supabase, userId: user.id, callerRole: me.role as string };
}

/** Cuenta cuántos propietarios tiene el hogar (para proteger al último). */
async function ownerCount(
  supabase: Awaited<ReturnType<typeof createClient>>,
  householdId: string,
): Promise<number> {
  const { count } = await supabase
    .from("household_members")
    .select("user_id", { count: "exact", head: true })
    .eq("household_id", householdId)
    .eq("role", "owner");
  return count ?? 0;
}

/**
 * Cambia el rol de un miembro del hogar. Solo owner/admin (guard + RLS). No
 * permite degradar al último propietario (dejaría el hogar sin owner).
 */
export async function updateMemberRole(input: {
  householdId: string;
  userId: string;
  role: string;
}) {
  const t = await getT();
  if (!(MEMBER_ROLES as readonly string[]).includes(input.role)) {
    throw new Error(t("profile.roleUpdateError"));
  }
  const role = input.role as MemberRole;

  const { supabase, callerRole } = await requireMembership(input.householdId);
  if (callerRole !== "owner" && callerRole !== "admin") {
    throw new Error(t("profile.roleUpdateError"));
  }

  // Proteger al último propietario: si está dejando de ser owner y es el único,
  // bloquear (el hogar quedaría sin propietario).
  if (role !== "owner") {
    const { data: target } = await supabase
      .from("household_members")
      .select("role")
      .eq("household_id", input.householdId)
      .eq("user_id", input.userId)
      .maybeSingle();
    if (target?.role === "owner" && (await ownerCount(supabase, input.householdId)) <= 1) {
      throw new Error(t("profile.lastOwnerHint"));
    }
  }

  const { error } = await supabase
    .from("household_members")
    .update({ role })
    .eq("household_id", input.householdId)
    .eq("user_id", input.userId);
  if (error) throw new Error(error.message);

  revalidatePath("/profile");
  revalidatePath("/", "layout"); // el switcher/topbar reflejan el rol del usuario
}

/**
 * Quita a un miembro del hogar. Solo owner/admin (guard + RLS). No permite
 * quitar al último propietario.
 */
export async function removeMember(input: {
  householdId: string;
  userId: string;
}) {
  const t = await getT();
  const { supabase, callerRole } = await requireMembership(input.householdId);
  if (callerRole !== "owner" && callerRole !== "admin") {
    throw new Error(t("profile.memberRemoveError"));
  }

  // Proteger al último propietario.
  const { data: target } = await supabase
    .from("household_members")
    .select("role")
    .eq("household_id", input.householdId)
    .eq("user_id", input.userId)
    .maybeSingle();
  if (target?.role === "owner" && (await ownerCount(supabase, input.householdId)) <= 1) {
    throw new Error(t("profile.lastOwnerHint"));
  }

  const { error } = await supabase
    .from("household_members")
    .delete()
    .eq("household_id", input.householdId)
    .eq("user_id", input.userId);
  if (error) throw new Error(error.message);

  revalidatePath("/profile");
  revalidatePath("/", "layout");
}
