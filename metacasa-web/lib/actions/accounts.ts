"use server";

/**
 * Server Actions de Cuentas y Tarjetas de crédito.
 * Toda mutación filtra por el hogar activo y confía en RLS para autorizar.
 * Tras escribir, revalidamos /accounts (lista) y /dashboard (saldo total + widget).
 */

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { getT } from "@/lib/i18n/server";
import {
  createAccount as dbCreateAccount,
  updateAccount as dbUpdateAccount,
  archiveAccount as dbArchiveAccount,
  upsertCreditCard as dbUpsertCreditCard,
} from "@/lib/db/accounts";

/** Tipos de cuenta permitidos (match con el CHECK de la tabla `accounts`). */
const ACCOUNT_TYPES = [
  "checking",
  "savings",
  "cash",
  "credit_card",
  "investment",
  "loan",
  "other",
] as const;
type AccountType = (typeof ACCOUNT_TYPES)[number];

/** Datos base que comparten alta y edición de cuenta. */
export interface AccountInput {
  name: string;
  type: AccountType;
  currency: string;
  startingBalance: number;
  institution?: string | null;
  color?: string | null;
  icon?: string | null;
}

/** Detalle opcional de tarjeta de crédito (solo cuando type === 'credit_card'). */
export interface CreditCardInput {
  creditLimit: number;
  statementDay: number; // 1-31
  dueDay: number; // 1-31
}

/** Normaliza un día de mes al rango válido 1-31. */
function clampDay(day: number): number {
  if (!Number.isFinite(day)) return 1;
  return Math.min(31, Math.max(1, Math.round(day)));
}

/** Resuelve hogar activo + usuario; lanza si falta alguno (sesión inválida). */
async function requireContext() {
  const t = await getT();
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionInvalid"));
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));
  return { supabase, userId: user.id, householdId: active.id };
}

/** Crea una cuenta nueva. Si es tarjeta, persiste también su detalle (upsert). */
export async function createAccount(
  input: AccountInput,
  card?: CreditCardInput,
): Promise<void> {
  const { supabase, userId, householdId } = await requireContext();

  const account = await dbCreateAccount(supabase, {
    household_id: householdId,
    created_by: userId,
    owner_user_id: userId,
    name: input.name.trim(),
    type: input.type,
    currency: input.currency,
    starting_balance: input.startingBalance,
    institution: input.institution?.trim() || null,
    color: input.color || null,
    icon: input.icon || null,
  });

  if (input.type === "credit_card" && card) {
    await dbUpsertCreditCard(supabase, {
      account_id: account.id,
      credit_limit: card.creditLimit,
      statement_day: clampDay(card.statementDay),
      due_day: clampDay(card.dueDay),
    });
  }

  revalidatePath("/accounts");
  revalidatePath("/dashboard");
}

/** Actualiza una cuenta existente. Si es tarjeta, hace upsert de su detalle. */
export async function updateAccount(
  accountId: string,
  input: AccountInput,
  card?: CreditCardInput,
): Promise<void> {
  const { supabase } = await requireContext();

  await dbUpdateAccount(supabase, accountId, {
    name: input.name.trim(),
    type: input.type,
    currency: input.currency,
    starting_balance: input.startingBalance,
    institution: input.institution?.trim() || null,
    color: input.color || null,
    icon: input.icon || null,
  });

  if (input.type === "credit_card" && card) {
    await dbUpsertCreditCard(supabase, {
      account_id: accountId,
      credit_limit: card.creditLimit,
      statement_day: clampDay(card.statementDay),
      due_day: clampDay(card.dueDay),
    });
  }

  revalidatePath("/accounts");
  revalidatePath("/dashboard");
}

/** Archiva una cuenta (soft-delete). Conserva el historial de movimientos. */
export async function archiveAccount(accountId: string): Promise<void> {
  const { supabase } = await requireContext();
  await dbArchiveAccount(supabase, accountId);
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
}

/** Crea/actualiza solo el detalle de tarjeta de crédito de una cuenta. */
export async function upsertCreditCard(
  accountId: string,
  card: CreditCardInput,
): Promise<void> {
  const { supabase } = await requireContext();
  await dbUpsertCreditCard(supabase, {
    account_id: accountId,
    credit_limit: card.creditLimit,
    statement_day: clampDay(card.statementDay),
    due_day: clampDay(card.dueDay),
  });
  revalidatePath("/accounts");
  revalidatePath("/dashboard");
}
