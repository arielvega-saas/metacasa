"use server";

/**
 * Server Actions de **Wallets LatAm** (Mercado Pago).
 *
 * Puerto de `src/services/wallets.js` + los handlers de `src/App.jsx` de la PWA
 * legacy. Diferencias importantes con el original:
 *
 *  - Cero credenciales en el cliente: la anon key sale de env (`NEXT_PUBLIC_*`),
 *    nunca hardcodeada, y todo el flujo corre en el servidor.
 *  - OAuth con `state` anti-CSRF en cookie httpOnly (la PWA no tenía `state`).
 *  - El `access_token` se escribe en `connected_wallets.access_token` y el
 *    trigger `encrypt_access_token_trigger` lo cifra a `access_token_encrypted`
 *    y ANULA el plaintext en el mismo BEFORE INSERT/UPDATE. O sea: el token
 *    nunca queda en reposo en claro y jamás vuelve a salir de la base (sólo la
 *    edge function `wallet-proxy`, con service_role, lo descifra vía
 *    `get_wallet_access_token`).
 *  - Nunca se loguea token, email ni monto.
 */

import { randomBytes, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold, type Household } from "@/lib/household";
import { getAccessState } from "@/lib/access";
import { getT } from "@/lib/i18n/server";
import { SITE_URL } from "@/lib/site";
import { TX_TYPE } from "@/lib/constants";
import { parseFxRates, convertToBase } from "@/lib/fx";
import { getCategories } from "@/lib/db/categories";
import { createTransaction } from "@/lib/db/transactions";
import {
  getWallet,
  existingExternalIds,
  suggestCategories,
  walletMetadata,
  type WalletMetadata,
} from "@/lib/db/wallets";
import {
  MERCADOPAGO,
  MP_ME_PATH,
  MP_PUBLIC_CLIENT_ID,
  DEFAULT_MP_LABELS,
  buildMercadoPagoAuthUrl,
  counterpartIdsToResolve,
  mapMercadoPagoPayments,
  mpPaymentsSearchPath,
  mpPublicName,
  mpUserPath,
  selectNewMovements,
  type MpDescriptionLabels,
  type MpPayment,
} from "@/lib/wallets/mercadopago";
import type { Client } from "@/lib/supabase/types";
import type { Json } from "@/lib/database.types";

/** Cookie httpOnly con el nonce de OAuth. Vive 10 minutos. */
const OAUTH_STATE_COOKIE = "mc_wallet_oauth_state";
const OAUTH_STATE_TTL_SECONDS = 600;

/** Tope de pagos que traemos por sync (la API de MP pagina por `limit`). */
const SYNC_PAGE_SIZE = 50;

/** Tope defensivo de movimientos por importación manual. */
const MAX_IMPORT = 200;

// ──────────────────────────────────────────────────────────────────────────
// Contexto y accesos
// ──────────────────────────────────────────────────────────────────────────

/**
 * Sesión + hogar activo + gate Premium. Las wallets son una feature Premium:
 * el layout ya redirige a `/locked` al navegar y el middleware bloquea las
 * Server Actions de un usuario `locked`, pero lo re-chequeamos acá (defensa en
 * profundidad: una action no ejecuta el layout).
 */
async function requireWalletContext(): Promise<{
  supabase: Client;
  userId: string;
  household: Household;
}> {
  const t = await getT();
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error(t("errors.sessionExpired"));

  const access = await getAccessState();
  if (access.state === "locked") throw new Error(t("wallets.premiumRequired"));

  const { active } = await resolveActiveHousehold(supabase);
  if (!active) throw new Error(t("errors.noHousehold"));

  return { supabase, userId: user.id, household: active };
}

/** `client_id` público de la app MP. Overrideable por entorno; no es secreto. */
function mercadoPagoClientId(): string {
  return (
    process.env.MP_OAUTH_CLIENT_ID ||
    process.env.NEXT_PUBLIC_MP_OAUTH_CLIENT_ID ||
    MP_PUBLIC_CLIENT_ID
  );
}

/**
 * Redirect URI del flujo OAuth. TIENE que ser idéntica en los 3 lugares:
 * la registrada en el panel de desarrolladores de MP, la de la URL de
 * autorización y la del `oauth_exchange`. Por eso es una función pura y
 * determinística en vez de derivarse del request.
 */
function mercadoPagoRedirectUri(): string {
  const base = (
    process.env.MP_OAUTH_REDIRECT_URI ||
    `${process.env.NEXT_PUBLIC_APP_URL || SITE_URL}/wallets/callback`
  ).trim();
  return base.replace(/\/+$/, "");
}

// ──────────────────────────────────────────────────────────────────────────
// Proxy autenticado (edge function `wallet-proxy`)
// ──────────────────────────────────────────────────────────────────────────

interface ProxyResponse {
  ok: boolean;
  status: number;
  data: unknown;
}

/**
 * Llama a la edge function `wallet-proxy` con el JWT del usuario. Nunca manda
 * ni recibe el access_token de la wallet: para el proxy autenticado sólo viaja
 * `wallet_id` y el server descifra el token puertas adentro.
 */
async function walletProxy(
  supabase: Client,
  body: Record<string, unknown>,
): Promise<ProxyResponse> {
  const t = await getT();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!supabaseUrl || !anonKey) throw new Error(t("wallets.errors.notConfigured"));

  const {
    data: { session },
  } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error(t("errors.sessionExpired"));

  const res = await fetch(`${supabaseUrl}/functions/v1/wallet-proxy`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${session.access_token}`,
      apikey: anonKey,
    },
    body: JSON.stringify(body),
    cache: "no-store",
  });

  let data: unknown = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }
  return { ok: res.ok, status: res.status, data };
}

/** GET a la API del provider a través del proxy (autenticado por `wallet_id`). */
async function proxyGet(
  supabase: Client,
  walletId: string,
  path: string,
): Promise<ProxyResponse> {
  return walletProxy(supabase, { provider: MERCADOPAGO, path, wallet_id: walletId });
}

// ──────────────────────────────────────────────────────────────────────────
// OAuth
// ──────────────────────────────────────────────────────────────────────────

/**
 * Arranca el flujo OAuth de Mercado Pago.
 *
 * Genera un `state` aleatorio de 256 bits, lo guarda en una cookie httpOnly y
 * lo incluye en la URL de autorización. Al volver, `completeMercadoPagoOAuth`
 * exige que coincidan: sin eso, un atacante podría hacer que la víctima canjee
 * un `code` de OTRA cuenta (CSRF de OAuth) y terminar viendo movimientos ajenos
 * dentro de su hogar.
 */
export async function startMercadoPagoOAuth(): Promise<{ url: string }> {
  await requireWalletContext();

  const state = randomBytes(32).toString("hex");
  const jar = await cookies();
  jar.set(OAUTH_STATE_COOKIE, state, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    // `lax` alcanza y es necesario: MP vuelve con una navegación GET top-level.
    sameSite: "lax",
    path: "/",
    maxAge: OAUTH_STATE_TTL_SECONDS,
  });

  return {
    url: buildMercadoPagoAuthUrl({
      clientId: mercadoPagoClientId(),
      redirectUri: mercadoPagoRedirectUri(),
      state,
    }),
  };
}

/** Compara dos strings en tiempo constante (evita oráculo de timing sobre el state). */
function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a, "utf8");
  const bufB = Buffer.from(b, "utf8");
  if (bufA.length !== bufB.length || bufA.length === 0) return false;
  return timingSafeEqual(bufA, bufB);
}

/** Respuesta del `oauth_token` de Mercado Pago (los campos que usamos). */
interface MpTokenResponse {
  access_token?: string;
  refresh_token?: string;
  user_id?: string | number;
  live_mode?: boolean;
  scope?: string;
  expires_in?: number;
  error?: string;
  message?: string;
}

/**
 * Completa el flujo OAuth: valida el `state`, canjea el `code` por un token vía
 * `wallet-proxy` (el `client_secret` vive sólo en la edge function) y persiste
 * la wallet.
 *
 * El `access_token` se escribe en la columna `access_token`: el trigger de la
 * base lo cifra en `access_token_encrypted` y deja `access_token = NULL` antes
 * de guardar la fila. No se persiste el `refresh_token`: hoy no hay columna
 * cifrada para él y guardarlo en `metadata` (jsonb legible por el cliente) sería
 * exponer una credencial. Ver notas de la feature.
 */
export async function completeMercadoPagoOAuth(
  code: string,
  state: string,
): Promise<{ walletId: string }> {
  const t = await getT();
  const { supabase, userId, household } = await requireWalletContext();

  // 1) Anti-CSRF: el `state` tiene que coincidir con la cookie httpOnly.
  const jar = await cookies();
  const expected = jar.get(OAUTH_STATE_COOKIE)?.value ?? "";
  // Se consume siempre (un solo uso), coincida o no.
  jar.delete(OAUTH_STATE_COOKIE);
  if (!expected || !state || !safeEqual(expected, state)) {
    throw new Error(t("wallets.errors.invalidState"));
  }
  if (!code || code.length > 512) throw new Error(t("wallets.errors.oauthFailed"));

  // 2) Canje del código. El secret jamás sale de la edge function.
  const res = await walletProxy(supabase, {
    action: "oauth_exchange",
    provider: MERCADOPAGO,
    code,
    redirect_uri: mercadoPagoRedirectUri(),
  });
  const token = (res.data ?? {}) as MpTokenResponse;
  if (!res.ok || !token.access_token) {
    // No propagamos el cuerpo de MP: puede traer detalles de la credencial.
    throw new Error(t("wallets.errors.oauthFailed"));
  }

  const mpUserId = token.user_id != null ? String(token.user_id) : undefined;
  const metadata: WalletMetadata = {
    ...(mpUserId ? { mp_user_id: mpUserId } : {}),
    live_mode: token.live_mode !== false,
    ...(token.scope ? { scope: token.scope } : {}),
    connected_at: new Date().toISOString(),
    ...(token.expires_in
      ? {
          token_expires_at: new Date(
            Date.now() + Number(token.expires_in) * 1000,
          ).toISOString(),
        }
      : {}),
  };

  // 3) ¿Ya existía esta misma cuenta MP en el hogar? Reconectar = actualizar,
  //    no duplicar (si no, se sincronizarían los mismos pagos dos veces).
  const { data: existingRows } = await supabase
    .from("connected_wallets")
    .select("id,metadata")
    .eq("household_id", household.id)
    .eq("provider", MERCADOPAGO);

  const match = mpUserId
    ? (existingRows ?? []).find(
        (w) => walletMetadata(w).mp_user_id === mpUserId,
      )
    : undefined;

  if (match) {
    const { error } = await supabase
      .from("connected_wallets")
      .update({
        // El trigger lo cifra y anula el plaintext en el mismo UPDATE.
        access_token: token.access_token,
        is_active: true,
        metadata: { ...walletMetadata(match), ...metadata } as unknown as Json,
      })
      .eq("id", match.id)
      .eq("household_id", household.id);
    if (error) throw new Error(t("wallets.errors.saveFailed"));
    revalidatePath("/wallets");
    return { walletId: match.id };
  }

  const { data: inserted, error } = await supabase
    .from("connected_wallets")
    .insert({
      household_id: household.id,
      user_id: userId,
      provider: MERCADOPAGO,
      name: "Mercado Pago",
      // Plaintext sólo en tránsito: el trigger BEFORE INSERT lo cifra y lo anula.
      access_token: token.access_token,
      currency: "ARS",
      is_active: true,
      metadata: metadata as unknown as Json,
    })
    .select("id")
    .single();
  if (error || !inserted) throw new Error(t("wallets.errors.saveFailed"));

  revalidatePath("/wallets");
  return { walletId: inserted.id };
}

// ──────────────────────────────────────────────────────────────────────────
// Sincronización
// ──────────────────────────────────────────────────────────────────────────

/** Etiquetas de descripción localizadas (las guarda la base como dato). */
async function descriptionLabels(): Promise<MpDescriptionLabels> {
  const t = await getT();
  const pick = (key: string, fallback: string) => {
    const v = t(`wallets.mp.${key}`);
    return v === `wallets.mp.${key}` ? fallback : v;
  };
  return {
    transferFrom: pick("transferFrom", DEFAULT_MP_LABELS.transferFrom),
    transferReceived: pick("transferReceived", DEFAULT_MP_LABELS.transferReceived),
    transferTo: pick("transferTo", DEFAULT_MP_LABELS.transferTo),
    transferSent: pick("transferSent", DEFAULT_MP_LABELS.transferSent),
    depositIn: pick("depositIn", DEFAULT_MP_LABELS.depositIn),
    fundingOut: pick("fundingOut", DEFAULT_MP_LABELS.fundingOut),
    yieldIn: pick("yieldIn", DEFAULT_MP_LABELS.yieldIn),
    investmentOut: pick("investmentOut", DEFAULT_MP_LABELS.investmentOut),
    fallback: pick("fallback", DEFAULT_MP_LABELS.fallback),
  };
}

export interface SyncWalletResult {
  /** Pagos que devolvió MP en esta pasada. */
  fetched: number;
  /** Movimientos nuevos guardados (los repetidos se descartan por external_id). */
  created: number;
}

/**
 * Sincroniza los últimos pagos de una wallet a `wallet_movements`.
 *
 * NO crea transacciones: el usuario elige después cuáles importar
 * (`importWalletMovements`). Dedupe por `external_id` contra lo ya guardado,
 * más el índice único `(wallet_id, external_id)` como red de seguridad.
 */
export async function syncWallet(walletId: string): Promise<SyncWalletResult> {
  const t = await getT();
  const { supabase, userId, household } = await requireWalletContext();

  const wallet = await getWallet(supabase, household.id, walletId);
  if (!wallet) throw new Error(t("wallets.errors.notFound"));
  if (wallet.provider !== MERCADOPAGO) {
    throw new Error(t("wallets.errors.providerUnsupported"));
  }

  // 1) Identidad de la cuenta conectada: define qué pago es ingreso y qué gasto.
  const meta = walletMetadata(wallet);
  let mpUserId = meta.mp_user_id ?? null;
  if (!mpUserId) {
    const me = await proxyGet(supabase, walletId, MP_ME_PATH);
    if (me.ok) {
      const id = (me.data as { id?: string | number } | null)?.id;
      if (id != null) {
        mpUserId = String(id);
        await supabase
          .from("connected_wallets")
          .update({
            metadata: { ...meta, mp_user_id: mpUserId } as unknown as Json,
          })
          .eq("id", walletId)
          .eq("household_id", household.id);
      }
    } else if (me.status === 401 || me.status === 403) {
      throw new Error(t("wallets.errors.reconnect"));
    }
  }

  // 2) Últimos pagos.
  const search = await proxyGet(
    supabase,
    walletId,
    mpPaymentsSearchPath(SYNC_PAGE_SIZE),
  );
  if (!search.ok) {
    throw new Error(
      search.status === 401 || search.status === 403
        ? t("wallets.errors.reconnect")
        : t("wallets.errors.syncFailed"),
    );
  }
  const payments = ((search.data as { results?: MpPayment[] } | null)?.results ??
    []) as MpPayment[];

  // 3) Nombres de contraparte para las transferencias sin descripción propia.
  const names = new Map<string, string>();
  const idsToResolve = counterpartIdsToResolve(payments, mpUserId);
  if (idsToResolve.length > 0) {
    const resolved = await Promise.all(
      idsToResolve.map(async (id) => {
        const r = await proxyGet(supabase, walletId, mpUserPath(id));
        if (!r.ok) return null;
        const name = mpPublicName(
          (r.data ?? {}) as {
            first_name?: string | null;
            last_name?: string | null;
            nickname?: string | null;
          },
        );
        return name ? ([id, name] as const) : null;
      }),
    );
    for (const r of resolved) if (r) names.set(r[0], r[1]);
  }

  // 4) Mapear + deduplicar contra lo ya persistido.
  const labels = await descriptionLabels();
  const drafts = mapMercadoPagoPayments(payments, mpUserId, names, labels);
  const known = await existingExternalIds(supabase, household.id, walletId);
  const fresh = selectNewMovements(drafts, known);

  if (fresh.length > 0) {
    const { error } = await supabase.from("wallet_movements").upsert(
      fresh.map((d) => ({
        wallet_id: walletId,
        household_id: household.id,
        user_id: userId,
        external_id: d.externalId,
        date: d.date,
        amount: d.amount,
        type: d.type,
        description: d.description,
        currency: d.currency,
        status: d.status,
        // Metadata mínima y sin datos personales: ni emails ni el payload crudo.
        metadata: {
          operation_type: d.operationType,
          payment_method_id: d.paymentMethodId,
          counterpart_id: d.counterpartId,
        } as unknown as Json,
      })),
      { onConflict: "wallet_id,external_id", ignoreDuplicates: true },
    );
    if (error) throw new Error(t("wallets.errors.syncFailed"));
  }

  await supabase
    .from("connected_wallets")
    .update({ last_sync: new Date().toISOString() })
    .eq("id", walletId)
    .eq("household_id", household.id);

  revalidatePath("/wallets");
  return { fetched: payments.length, created: fresh.length };
}

// ──────────────────────────────────────────────────────────────────────────
// Importación a transacciones
// ──────────────────────────────────────────────────────────────────────────

export interface ImportMovementsResult {
  imported: number;
  /** Omitidos por falta de cotización a la moneda base del hogar. */
  skippedNoRate: number;
}

/** Categoría de respaldo cuando el hogar no tiene una regla aprendida. */
function fallbackCategory(list: string[] | undefined, preferred = "Otros"): string {
  const options = list ?? [];
  return options.includes(preferred) ? preferred : (options[0] ?? preferred);
}

/**
 * Convierte los movimientos elegidos en transacciones reales usando el insert
 * canónico (`createTransaction`), y marca `synced_tx_id` para que no se puedan
 * re-importar.
 *
 * Pre-categoriza con el RPC `suggest_category` (reglas que el hogar aprendió de
 * sus propias transacciones). Si la sugerencia no existe entre las categorías
 * del hogar, cae al fallback.
 *
 * Multi-moneda: si el movimiento viene en otra moneda que la base del hogar y
 * NO hay cotización cargada, se OMITE en vez de inventar una tasa (que
 * corrompería los reportes). Se informa en `skippedNoRate`.
 */
export async function importWalletMovements(
  walletId: string,
  movementIds: string[],
  options?: { accountId?: string | null },
): Promise<ImportMovementsResult> {
  const t = await getT();
  const { supabase, userId, household } = await requireWalletContext();

  const ids = Array.from(new Set(movementIds ?? [])).slice(0, MAX_IMPORT);
  if (ids.length === 0) return { imported: 0, skippedNoRate: 0 };

  const wallet = await getWallet(supabase, household.id, walletId);
  if (!wallet) throw new Error(t("wallets.errors.notFound"));

  // Sólo los pendientes de ESTE hogar y ESTA wallet (RLS + filtro explícito).
  const { data: movements, error: readErr } = await supabase
    .from("wallet_movements")
    .select("*")
    .in("id", ids)
    .eq("wallet_id", walletId)
    .eq("household_id", household.id)
    .is("synced_tx_id", null);
  if (readErr) throw new Error(t("wallets.errors.importFailed"));
  if (!movements || movements.length === 0) {
    return { imported: 0, skippedNoRate: 0 };
  }

  // Cuenta destino: sólo se acepta si es una cuenta real del hogar.
  let accountId: string | null = null;
  if (options?.accountId) {
    const { data: account } = await supabase
      .from("accounts")
      .select("id")
      .eq("id", options.accountId)
      .eq("household_id", household.id)
      .maybeSingle();
    accountId = account?.id ?? null;
  }

  const base = (household.default_currency || "USD").toUpperCase();
  const rates = parseFxRates(household.fx_rates);

  const categories = await getCategories(supabase, household.id);
  const validExpense = new Set(categories.gastos ?? []);
  const validIncome = new Set(categories.ingresos ?? []);
  const suggestions = await suggestCategories(
    supabase,
    household.id,
    movements.map((m) => m.description ?? ""),
  );

  let imported = 0;
  let skippedNoRate = 0;

  for (const m of movements) {
    const currency = (m.currency || base).toUpperCase();
    const original = Math.abs(Number(m.amount));
    if (!Number.isFinite(original) || original <= 0) continue;

    const amountBase = convertToBase(original, currency, base, rates);
    if (amountBase == null) {
      skippedNoRate++;
      continue;
    }

    const type = m.type === TX_TYPE.INCOME ? TX_TYPE.INCOME : TX_TYPE.EXPENSE;
    const valid = type === TX_TYPE.INCOME ? validIncome : validExpense;
    const suggested = suggestions.get((m.description ?? "").trim())?.category;
    const category =
      suggested && valid.has(suggested)
        ? suggested
        : fallbackCategory(
            type === TX_TYPE.INCOME ? categories.ingresos : categories.gastos,
          );

    const tx = await createTransaction(supabase, {
      householdId: household.id,
      userId,
      type,
      amount: amountBase,
      category,
      accountId,
      date: m.date,
      note: m.description ?? null,
      amountOriginal: original,
      currencyOriginal: currency,
      fxRateToBase: original === 0 ? 1 : amountBase / original,
    });

    const { error: linkErr } = await supabase
      .from("wallet_movements")
      .update({ synced_tx_id: tx.id, status: "imported" })
      .eq("id", m.id)
      .eq("household_id", household.id);
    if (linkErr) throw new Error(t("wallets.errors.importFailed"));

    imported++;
  }

  revalidatePath("/wallets");
  revalidatePath("/transactions");
  revalidatePath("/dashboard");
  return { imported, skippedNoRate };
}

// ──────────────────────────────────────────────────────────────────────────
// Desconexión
// ──────────────────────────────────────────────────────────────────────────

/**
 * Desconecta una wallet: la marca inactiva y BORRA el token cifrado (la
 * credencial deja de existir en reposo). Los movimientos ya sincronizados y las
 * transacciones importadas se conservan — son historial financiero del hogar.
 */
export async function disconnectWallet(walletId: string): Promise<void> {
  const t = await getT();
  const { supabase, household } = await requireWalletContext();

  const wallet = await getWallet(supabase, household.id, walletId);
  if (!wallet) throw new Error(t("wallets.errors.notFound"));

  const { error } = await supabase
    .from("connected_wallets")
    .update({
      is_active: false,
      access_token: null,
      access_token_encrypted: null,
      last_sync: null,
    })
    .eq("id", walletId)
    .eq("household_id", household.id);
  if (error) throw new Error(t("wallets.errors.disconnectFailed"));

  revalidatePath("/wallets");
}
