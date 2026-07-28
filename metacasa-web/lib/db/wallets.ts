import type { Client } from "@/lib/supabase/types";
import type { Tables } from "@/lib/database.types";

/**
 * Lectura de **wallets conectadas** y sus movimientos.
 *
 * REGLA DE ORO: nunca seleccionamos `access_token` ni `access_token_encrypted`.
 * El token vive cifrado (trigger `encrypt_access_token_trigger` + pgcrypto/Vault)
 * y sólo lo descifra la edge function `wallet-proxy` con service_role. Por eso
 * todas las queries listan columnas explícitas en vez de `select("*")`.
 *
 * Todas filtran por `household_id` además de confiar en RLS (defensa en profundidad).
 */

/** Columnas seguras de `connected_wallets` (sin token en ninguna de sus formas). */
const WALLET_COLUMNS =
  "id,household_id,user_id,provider,name,balance,currency,last_sync,is_active,metadata,created_at";

export type ConnectedWallet = Pick<
  Tables<"connected_wallets">,
  | "id"
  | "household_id"
  | "user_id"
  | "provider"
  | "name"
  | "balance"
  | "currency"
  | "last_sync"
  | "is_active"
  | "metadata"
  | "created_at"
>;

export type WalletMovement = Tables<"wallet_movements">;

/** Metadata que guardamos en `connected_wallets.metadata` (jsonb). Sin secretos. */
export interface WalletMetadata {
  /** id numérico público del usuario en Mercado Pago (para saber si cobra o paga). */
  mp_user_id?: string;
  /** `false` si el token es de sandbox — se muestra como aviso en la UI. */
  live_mode?: boolean;
  scope?: string;
  connected_at?: string;
  /** Vencimiento estimado del access_token (MP: 180 días). No es un secreto. */
  token_expires_at?: string;
}

/** Lee la metadata tipada de una wallet (jsonb tolerante a basura). */
export function walletMetadata(wallet: {
  metadata: Tables<"connected_wallets">["metadata"];
}): WalletMetadata {
  const m = wallet.metadata;
  if (!m || typeof m !== "object" || Array.isArray(m)) return {};
  return m as WalletMetadata;
}

/** Wallets activas del hogar, más recientes primero. */
export async function listWallets(
  supabase: Client,
  householdId: string,
): Promise<ConnectedWallet[]> {
  const { data, error } = await supabase
    .from("connected_wallets")
    .select(WALLET_COLUMNS)
    .eq("household_id", householdId)
    .eq("is_active", true)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}

/** Una wallet del hogar por id (null si no existe o no es del hogar). */
export async function getWallet(
  supabase: Client,
  householdId: string,
  walletId: string,
): Promise<ConnectedWallet | null> {
  const { data, error } = await supabase
    .from("connected_wallets")
    .select(WALLET_COLUMNS)
    .eq("id", walletId)
    .eq("household_id", householdId)
    .maybeSingle();
  if (error) throw error;
  return data ?? null;
}

export interface WalletMovementFilters {
  /** Sólo los de esta wallet. Si se omite, trae los de todo el hogar. */
  walletId?: string;
  /** `true` = sólo los que todavía NO se convirtieron en transacción. */
  onlyPending?: boolean;
  limit?: number;
}

/** Movimientos sincronizados desde las wallets, más recientes primero. */
export async function listWalletMovements(
  supabase: Client,
  householdId: string,
  filters: WalletMovementFilters = {},
): Promise<WalletMovement[]> {
  let q = supabase
    .from("wallet_movements")
    .select("*")
    .eq("household_id", householdId);

  if (filters.walletId) q = q.eq("wallet_id", filters.walletId);
  if (filters.onlyPending) q = q.is("synced_tx_id", null);

  q = q.order("date", { ascending: false });
  if (filters.limit) q = q.limit(filters.limit);

  const { data, error } = await q;
  if (error) throw error;
  return data ?? [];
}

/**
 * `external_id` ya persistidos para una wallet. Es la base del dedupe: el sync
 * sólo inserta lo que no está acá (además del índice único `(wallet_id, external_id)`).
 */
export async function existingExternalIds(
  supabase: Client,
  householdId: string,
  walletId: string,
): Promise<Set<string>> {
  const { data, error } = await supabase
    .from("wallet_movements")
    .select("external_id")
    .eq("household_id", householdId)
    .eq("wallet_id", walletId)
    .not("external_id", "is", null);
  if (error) throw error;
  return new Set((data ?? []).map((r) => String(r.external_id)));
}

/** Una sugerencia de categoría devuelta por el RPC `suggest_category`. */
export interface CategorySuggestion {
  category: string;
  subcategory: string | null;
  /** 0..0.99 — cuánta confianza tiene la regla aprendida del hogar. */
  confidence: number;
}

/**
 * Pre-categorización de descripciones usando el RPC `suggest_category`
 * (reglas que el hogar fue APRENDIENDO de sus propias transacciones).
 *
 * El RPC toma una nota por llamada, así que deduplicamos por texto y las
 * lanzamos en paralelo con un tope. Devuelve un mapa `descripción → sugerencia`
 * (sólo las que matchearon alguna regla).
 */
export async function suggestCategories(
  supabase: Client,
  householdId: string,
  notes: readonly string[],
  max = 60,
): Promise<Map<string, CategorySuggestion>> {
  const unique = Array.from(
    new Set(notes.map((n) => (n ?? "").trim()).filter((n) => n.length >= 3)),
  ).slice(0, max);
  if (unique.length === 0) return new Map();

  const results = await Promise.all(
    unique.map(async (note) => {
      const { data, error } = await supabase.rpc("suggest_category", {
        p_household: householdId,
        p_note: note,
      });
      if (error) return null;
      const top = (data ?? [])[0];
      if (!top?.category) return null;
      return [
        note,
        {
          category: top.category,
          subcategory: top.subcategory ?? null,
          confidence: Number(top.confidence ?? 0),
        },
      ] as const;
    }),
  );

  const map = new Map<string, CategorySuggestion>();
  for (const r of results) if (r) map.set(r[0], r[1]);
  return map;
}
