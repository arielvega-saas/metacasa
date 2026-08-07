import { parseFxRates } from "@/lib/fx";
import { saldoDeCuenta, type MovimientoParaSaldo } from "@/lib/db/account-balance";
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
 * Cuenta a la que se imputa un movimiento cuando nadie eligió una.
 *
 * Paridad con iOS (`AccountService.defaultAccountId`): la primera cuenta activa
 * por `display_order`. iOS además prefiere la última usada, que guarda en
 * `UserDefaults` — la web no tiene ese estado, así que cae al mismo fallback.
 *
 * Importa porque una transacción sin `account_id` **no mueve ningún saldo**:
 * queda "del hogar" y las cuentas siguen mostrando el número viejo. El asistente
 * cargaba todo así, con lo cual los movimientos que registraba por chat no se
 * veían reflejados en ninguna cuenta.
 *
 * Devuelve `null` si el hogar todavía no tiene cuentas: es válido: el movimiento
 * se guarda sin imputar, igual que si se cargara a mano en ese estado.
 */
export async function defaultAccountId(
  supabase: Client,
  householdId: string,
): Promise<string | null> {
  const cuentas = await listAccounts(supabase, householdId);
  return cuentas[0]?.id ?? null;
}

/**
 * Cuentas con su saldo, **en la moneda de cada cuenta**.
 *
 * La regla vive en `lib/db/account-balance.ts` (`saldoDeCuenta`), que explica
 * por qué no se puede sumar `starting_balance` con `amount` a secas. Resumen:
 * el primero está en la moneda de la cuenta y el segundo en la moneda base del
 * hogar, así que una cuenta en USD dentro de un hogar en ARS salía multiplicada
 * por la cotización.
 *
 * El comentario anterior afirmaba que el saldo quedaba "en moneda base, igual
 * que iOS". Las dos mitades eran falsas: `starting_balance` nunca estuvo en
 * base, y la UI ya pintaba el resultado con `account.currency`.
 *
 * Las tx sin `account_id` no afectan saldos de cuenta (quedan "del hogar"),
 * igual que en iOS, que filtra por `accountId`.
 */
export async function listAccountsWithBalance(
  supabase: Client,
  householdId: string,
): Promise<AccountWithBalance[]> {
  const accounts = await listAccounts(supabase, householdId);

  // Moneda base y tasas se leen acá adentro para que la función siga siendo
  // autosuficiente: la llaman cinco pantallas y ninguna debería tener que
  // saber que el saldo necesita FX.
  const { data: hogar } = await supabase
    .from("households")
    .select("default_currency, fx_rates")
    .eq("id", householdId)
    .maybeSingle();
  const base = hogar?.default_currency ?? "ARS";
  const rates = parseFxRates(hogar?.fx_rates);

  const { data: txs } = await supabase
    .from("transactions")
    .select("account_id, amount, type, amount_original, currency_original")
    .eq("household_id", householdId)
    .not("account_id", "is", null);

  const porCuenta = new Map<string, MovimientoParaSaldo[]>();
  for (const t of txs ?? []) {
    if (!t.account_id) continue;
    const lista = porCuenta.get(t.account_id) ?? [];
    lista.push(t);
    porCuenta.set(t.account_id, lista);
  }

  return accounts.map((a) => {
    // El saldo queda en la moneda de LA CUENTA. Antes se sumaba
    // `starting_balance` (moneda de la cuenta) con `amount` (moneda base): una
    // caja de ahorro en USD dentro de un hogar en ARS mostraba el saldo
    // multiplicado por la cotización.
    const { balance } = saldoDeCuenta(
      Number(a.starting_balance),
      a.currency ?? base,
      base,
      porCuenta.get(a.id) ?? [],
      rates,
    );
    return { ...a, balance };
  });
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
