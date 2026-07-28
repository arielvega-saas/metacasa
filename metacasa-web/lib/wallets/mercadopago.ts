/**
 * Conector **Mercado Pago** — lógica PURA (sin I/O, sin `server-only`).
 *
 * Puerto de `src/services/wallets.js` de la PWA legacy (`createWalletAdapter`).
 * Acá vive todo lo que se puede testear sin red ni base: construcción de la URL
 * de autorización OAuth y el mapeo `/v1/payments/search` → nuestro modelo de
 * `wallet_movements`. El I/O (proxy, DB, cookies) vive en
 * `lib/actions/wallets.ts`; la lectura, en `lib/db/wallets.ts`.
 *
 * Nota de seguridad: acá NUNCA se toca un access_token. El cliente sólo conoce
 * `wallet_id`; el token se descifra server-side dentro de la edge function
 * `wallet-proxy` (ver `supabase/functions/wallet-proxy/index.ts`).
 */

import { TX_TYPE, type TxType } from "@/lib/constants";

/** Provider id tal como se guarda en `connected_wallets.provider`. */
export const MERCADOPAGO = "mercadopago";

/**
 * `client_id` público de la app de Mercado Pago. NO es un secreto: viaja en la
 * URL de autorización que ve el usuario. El `client_secret` vive solamente como
 * env de la edge function (`MP_CLIENT_SECRET`) y jamás llega al browser.
 * Se puede sobreescribir por entorno sin tocar código.
 */
export const MP_PUBLIC_CLIENT_ID = "2693470312497962";

/** Endpoint de autorización de Mercado Pago (flujo OAuth de marketplace). */
const MP_AUTHORIZATION_URL = "https://auth.mercadopago.com.ar/authorization";

/** Path del proxy para traer los últimos pagos de la cuenta conectada. */
export function mpPaymentsSearchPath(limit = 50): string {
  const safe = Math.min(200, Math.max(1, Math.trunc(limit) || 50));
  return `/v1/payments/search?sort=date_created&criteria=desc&limit=${safe}`;
}

/** Path del proxy para identificar al dueño de la cuenta conectada. */
export const MP_ME_PATH = "/users/me";

/** Path del proxy para resolver el nombre público de una contraparte. */
export function mpUserPath(userId: string): string {
  return `/users/${encodeURIComponent(userId)}`;
}

// ──────────────────────────────────────────────────────────────────────────
// OAuth
// ──────────────────────────────────────────────────────────────────────────

export interface MpAuthUrlParams {
  clientId: string;
  /** Debe coincidir EXACTO con la registrada en el panel de MP y con la del exchange. */
  redirectUri: string;
  /** Nonce anti-CSRF: se compara contra la cookie httpOnly al volver. */
  state: string;
}

/**
 * URL de autorización de Mercado Pago. `state` es obligatorio: sin él, un
 * tercero podría inducir al usuario a canjear SU código en la cuenta de la
 * víctima (CSRF de OAuth).
 */
export function buildMercadoPagoAuthUrl({
  clientId,
  redirectUri,
  state,
}: MpAuthUrlParams): string {
  if (!clientId) throw new Error("missing_client_id");
  if (!redirectUri) throw new Error("missing_redirect_uri");
  if (!state) throw new Error("missing_state");

  const qs = new URLSearchParams({
    client_id: clientId,
    response_type: "code",
    platform_id: "mp",
    redirect_uri: redirectUri,
    state,
  });
  return `${MP_AUTHORIZATION_URL}?${qs.toString()}`;
}

// ──────────────────────────────────────────────────────────────────────────
// Mapeo de pagos
// ──────────────────────────────────────────────────────────────────────────

/**
 * Forma (parcial y tolerante) de un pago de `/v1/payments/search`. MP agrega
 * campos seguido, así que sólo declaramos los que consumimos.
 */
export interface MpPayment {
  id?: string | number | null;
  date_created?: string | null;
  transaction_amount?: number | string | null;
  currency_id?: string | null;
  status?: string | null;
  description?: string | null;
  statement_descriptor?: string | null;
  operation_type?: string | null;
  payment_method_id?: string | null;
  collector_id?: string | number | null;
  collector?: { id?: string | number | null } | null;
  payer?: { id?: string | number | null } | null;
}

/**
 * Un movimiento listo para persistir en `wallet_movements`. `amount` es SIEMPRE
 * magnitud positiva (el signo lo da `type`), igual que en `transactions`.
 */
export interface WalletMovementDraft {
  externalId: string;
  /** ISO 8601 (timestamptz). */
  date: string;
  amount: number;
  type: TxType;
  description: string;
  currency: string;
  status: string;
  /** id MP de la contraparte. Es un id numérico público, nunca un email. */
  counterpartId: string | null;
  operationType: string | null;
  paymentMethodId: string | null;
}

/**
 * Textos de las descripciones derivadas. Se inyectan desde el diccionario i18n
 * para que un usuario en EN/PT no reciba data en español. `{name}` se
 * interpola con el nombre público de la contraparte.
 */
export interface MpDescriptionLabels {
  transferFrom: string;
  transferReceived: string;
  transferTo: string;
  transferSent: string;
  depositIn: string;
  fundingOut: string;
  yieldIn: string;
  investmentOut: string;
  fallback: string;
}

/** Defaults en español rioplatense (paridad 1:1 con la PWA legacy). */
export const DEFAULT_MP_LABELS: MpDescriptionLabels = {
  transferFrom: "Transferencia de {name}",
  transferReceived: "Transferencia recibida",
  transferTo: "Transferencia a {name}",
  transferSent: "Transferencia enviada",
  depositIn: "Depósito bancario",
  fundingOut: "Fondeo de cuenta",
  yieldIn: "Rendimiento MP",
  investmentOut: "Inversión MP",
  fallback: "Movimiento MP",
};

/** Normaliza cualquier id de MP (number | string | null) a string o null. */
function idOf(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s && s !== "null" && s !== "undefined" ? s : null;
}

/** id del cobrador del pago (`collector.id` o el legacy `collector_id`). */
export function collectorIdOf(p: MpPayment): string | null {
  return idOf(p.collector?.id) ?? idOf(p.collector_id);
}

/** id del pagador del pago. */
export function payerIdOf(p: MpPayment): string | null {
  return idOf(p.payer?.id);
}

/**
 * `true` si la plata ENTRA a la cuenta conectada (somos el cobrador).
 * Sin `mpUserId` no se puede saber → asumimos gasto, igual que la PWA.
 */
export function isIncoming(p: MpPayment, mpUserId: string | null): boolean {
  if (!mpUserId) return false;
  return collectorIdOf(p) === mpUserId;
}

/** id de la contraparte (el "otro lado" del pago), o null si somos ambos lados. */
export function counterpartIdOf(
  p: MpPayment,
  mpUserId: string | null,
): string | null {
  const other = isIncoming(p, mpUserId) ? payerIdOf(p) : collectorIdOf(p);
  if (!other || other === mpUserId) return null;
  return other;
}

/**
 * ¿La descripción que trae MP es utilizable? MP manda `null`, cadena vacía o el
 * genérico "Varios" en la mayoría de las transferencias P2P.
 */
function isUsableDescription(desc: string): boolean {
  return desc.length > 0 && desc !== "Varios" && desc !== "null";
}

function interpolateName(template: string, name: string): string {
  return template.replace("{name}", name);
}

/**
 * Descripción legible de un pago. Orden de preferencia (igual que la PWA):
 *   1. `description` / `statement_descriptor` si son útiles.
 *   2. Nombre público de la contraparte ("Transferencia de Ana").
 *   3. Genérico por `operation_type`.
 *
 * `names` mapea id de contraparte → nombre público ya resuelto (ver
 * `counterpartIdsToResolve`). Nunca contiene emails: MP devuelve
 * `first_name`/`last_name`/`nickname`.
 */
export function describePayment(
  p: MpPayment,
  mpUserId: string | null,
  names: ReadonlyMap<string, string> = new Map(),
  labels: MpDescriptionLabels = DEFAULT_MP_LABELS,
): string {
  const raw = (p.description ?? p.statement_descriptor ?? "").trim();
  if (isUsableDescription(raw)) return raw;

  const incoming = isIncoming(p, mpUserId);
  const counterpart = counterpartIdOf(p, mpUserId);

  if (counterpart) {
    const name = names.get(counterpart)?.trim();
    if (incoming) {
      return name
        ? interpolateName(labels.transferFrom, name)
        : labels.transferReceived;
    }
    return name ? interpolateName(labels.transferTo, name) : labels.transferSent;
  }

  switch (p.operation_type) {
    case "account_fund":
      return incoming ? labels.depositIn : labels.fundingOut;
    case "investment":
      return incoming ? labels.yieldIn : labels.investmentOut;
    case "money_transfer":
      return incoming ? labels.transferReceived : labels.transferSent;
    default:
      return p.operation_type?.trim() || labels.fallback;
  }
}

/**
 * Ids de contraparte que vale la pena resolver a nombre (una llamada al proxy
 * cada uno). Sólo los pagos SIN descripción propia los necesitan. Se limita el
 * fan-out: cada id es un round-trip extra por la edge function.
 */
export function counterpartIdsToResolve(
  payments: readonly MpPayment[],
  mpUserId: string | null,
  max = 15,
): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const p of payments) {
    if (out.length >= max) break;
    const raw = (p.description ?? p.statement_descriptor ?? "").trim();
    if (isUsableDescription(raw)) continue;
    const id = counterpartIdOf(p, mpUserId);
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

/** Nombre público de un usuario MP (`/users/{id}`), sin datos de contacto. */
export function mpPublicName(user: {
  first_name?: string | null;
  last_name?: string | null;
  nickname?: string | null;
}): string | null {
  const full = [user.first_name, user.last_name]
    .filter((s): s is string => !!s && s.trim().length > 0)
    .join(" ")
    .trim();
  return full || user.nickname?.trim() || null;
}

/**
 * Mapea la respuesta de `/v1/payments/search` a nuestro modelo. Descarta los
 * pagos sin `id` (no se pueden deduplicar) y los de monto no numérico.
 */
export function mapMercadoPagoPayments(
  payments: readonly MpPayment[],
  mpUserId: string | null,
  names: ReadonlyMap<string, string> = new Map(),
  labels: MpDescriptionLabels = DEFAULT_MP_LABELS,
): WalletMovementDraft[] {
  const out: WalletMovementDraft[] = [];
  for (const p of payments ?? []) {
    const externalId = idOf(p.id);
    if (!externalId) continue;

    const amount = Math.abs(Number(p.transaction_amount ?? 0));
    if (!Number.isFinite(amount)) continue;

    const incoming = isIncoming(p, mpUserId);
    out.push({
      externalId,
      date: p.date_created ?? new Date().toISOString(),
      amount,
      type: incoming ? TX_TYPE.INCOME : TX_TYPE.EXPENSE,
      description: describePayment(p, mpUserId, names, labels),
      currency: (p.currency_id ?? "ARS").toUpperCase(),
      status: p.status ?? "approved",
      counterpartId: counterpartIdOf(p, mpUserId),
      operationType: p.operation_type ?? null,
      paymentMethodId: p.payment_method_id ?? null,
    });
  }
  return out;
}

/**
 * Deduplica por `external_id` conservando la PRIMERA aparición (MP viene
 * ordenado por fecha descendente, así que la primera es la más reciente).
 * La tabla también tiene un índice único `(wallet_id, external_id)`: esto evita
 * que un mismo lote dispare el conflicto contra sí mismo.
 */
export function dedupeByExternalId(
  drafts: readonly WalletMovementDraft[],
): WalletMovementDraft[] {
  const seen = new Set<string>();
  const out: WalletMovementDraft[] = [];
  for (const d of drafts) {
    if (seen.has(d.externalId)) continue;
    seen.add(d.externalId);
    out.push(d);
  }
  return out;
}

/**
 * Movimientos que todavía NO están en la base para esa wallet. Se compara
 * contra los `external_id` ya persistidos (dedupe incremental entre syncs).
 */
export function selectNewMovements(
  drafts: readonly WalletMovementDraft[],
  existingExternalIds: ReadonlySet<string>,
): WalletMovementDraft[] {
  return dedupeByExternalId(drafts).filter(
    (d) => !existingExternalIds.has(d.externalId),
  );
}
