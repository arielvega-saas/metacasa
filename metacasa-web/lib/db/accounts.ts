import type { Client } from "@/lib/supabase/types";
import type { Tables, TablesInsert, TablesUpdate } from "@/lib/database.types";

export type Account = Tables<"accounts">;
export type AccountWithBalance = Account & { balance: number };
export type CreditCard = Tables<"credit_cards">;

/** Cuentas activas del hogar, ordenadas por display_order. */
export async function listAccounts(
  supabase: Client,
  householdId: string,
): Promise<Account[]> {
  const { data, error } = await supabase
    .from("accounts")
    .select("*")
    .eq("household_id", householdId)
    .eq("is_active", true)
    .order("display_order", { ascending: true });
  if (error) throw error;
  return data ?? [];
}

/**
 * Cuentas con saldo calculado, IDÉNTICO a iOS `AccountBalanceService.currentBalance`:
 *
 *   balance = starting_balance + Σ (type === "GASTO" ? -amount : +amount)
 *
 * sobre las transacciones cuyo `account_id` apunta a la cuenta.
 *
 * DEFINICIÓN CANÓNICA (paridad con iOS): siempre se suma el monto en MONEDA BASE
 * del hogar (`transactions.amount`), nunca `amount_original`. iOS jamás mira
 * `amount_original` para el balance: opera sobre `tx.amount` y `tx.type` (ver
 * `Core/AccountBalanceService.swift`, `currentBalance`). La versión anterior de
 * la web mezclaba `amount_original` (cuando la moneda de la tx coincidía con la
 * de la cuenta) con `amount` en el resto, divergiendo del balance que muestra la
 * app para la misma data. Ahora ambos clientes producen el mismo número.
 *
 * Nota: como `amount` está en moneda base, el balance resultante también está en
 * moneda base — exactamente como en iOS. Las tx sin `account_id` no afectan
 * saldos de cuenta (quedan "del hogar"), igual que en iOS (filtra por accountId).
 */
export async function listAccountsWithBalance(
  supabase: Client,
  householdId: string,
): Promise<AccountWithBalance[]> {
  const accounts = await listAccounts(supabase, householdId);

  const { data: txs } = await supabase
    .from("transactions")
    .select("account_id, amount, type")
    .eq("household_id", householdId)
    .not("account_id", "is", null);

  const delta = new Map<string, number>();
  for (const t of txs ?? []) {
    if (!t.account_id) continue;
    // Paridad iOS: GASTO resta, todo lo demás (INGRESO) suma. Siempre `amount` base.
    const sign = t.type === "GASTO" ? -1 : 1;
    delta.set(t.account_id, (delta.get(t.account_id) ?? 0) + sign * Number(t.amount));
  }

  return accounts.map((a) => ({
    ...a,
    balance: Number(a.starting_balance) + (delta.get(a.id) ?? 0),
  }));
}

/**
 * Detalle de tarjeta de crédito de una cuenta (1:1 por `account_id`).
 * Devuelve `null` si la cuenta no tiene tarjeta asociada.
 */
export async function getCreditCard(
  supabase: Client,
  accountId: string,
): Promise<CreditCard | null> {
  const { data, error } = await supabase
    .from("credit_cards")
    .select("*")
    .eq("account_id", accountId)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}

/**
 * Tarjetas de crédito de todas las cuentas pasadas, indexadas por `account_id`.
 * Una sola query (la usa la pantalla de cuentas para hidratar las cards).
 */
export async function listCreditCards(
  supabase: Client,
  accountIds: string[],
): Promise<Record<string, CreditCard>> {
  if (accountIds.length === 0) return {};
  const { data, error } = await supabase
    .from("credit_cards")
    .select("*")
    .in("account_id", accountIds);
  if (error) throw error;
  const map: Record<string, CreditCard> = {};
  for (const cc of data ?? []) map[cc.account_id] = cc;
  return map;
}

/**
 * Crea una cuenta nueva en el hogar. El saldo inicial va a `starting_balance`.
 * `display_order` se calcula como el siguiente al máximo actual del hogar.
 */
export async function createAccount(
  supabase: Client,
  input: TablesInsert<"accounts">,
): Promise<Account> {
  // Próximo orden de aparición (al final de la lista existente del hogar).
  const { data: last } = await supabase
    .from("accounts")
    .select("display_order")
    .eq("household_id", input.household_id ?? "")
    .order("display_order", { ascending: false })
    .limit(1)
    .maybeSingle();
  const nextOrder = (last?.display_order ?? -1) + 1;

  const { data, error } = await supabase
    .from("accounts")
    .insert({ ...input, display_order: input.display_order ?? nextOrder })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Actualiza los campos editables de una cuenta (RLS valida pertenencia). */
export async function updateAccount(
  supabase: Client,
  accountId: string,
  patch: TablesUpdate<"accounts">,
): Promise<Account> {
  const { data, error } = await supabase
    .from("accounts")
    .update(patch)
    .eq("id", accountId)
    .select("*")
    .single();
  if (error) throw error;
  return data;
}

/** Archiva una cuenta (soft-delete: `is_active=false`). Nunca borramos historial. */
export async function archiveAccount(
  supabase: Client,
  accountId: string,
): Promise<void> {
  const { error } = await supabase
    .from("accounts")
    .update({ is_active: false })
    .eq("id", accountId);
  if (error) throw error;
}

/**
 * Crea/actualiza el detalle de tarjeta de crédito de una cuenta (upsert por
 * `account_id`, que es la PK 1:1). Se llama cuando la cuenta es `credit_card`.
 */
export async function upsertCreditCard(
  supabase: Client,
  input: TablesInsert<"credit_cards">,
): Promise<CreditCard> {
  const { data, error } = await supabase
    .from("credit_cards")
    .upsert(input, { onConflict: "account_id" })
    .select("*")
    .single();
  if (error) throw error;
  return data;
}
