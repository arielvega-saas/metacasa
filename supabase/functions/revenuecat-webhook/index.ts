// RevenueCat webhook handler.
//
// Flujo: RevenueCat llama este endpoint con eventos de compra/renovación/
// cancelación → insertamos una row en `public.subscriptions` → el trigger
// `subscriptions_sync_entitlements` mantiene `public.user_entitlements`
// consistente automáticamente.
//
// Seguridad: autenticación por shared secret en el header `Authorization`.
// Configurar en Supabase secrets: `REVENUECAT_WEBHOOK_SECRET`.
// Configurar también: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (auto-populated
// por Supabase en edge functions del mismo proyecto).
//
// verify_jwt: false — RevenueCat no manda JWT de Supabase, usa su propio secret.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

type RCStore = "APP_STORE" | "MAC_APP_STORE" | "PLAY_STORE" | "STRIPE" | "PROMOTIONAL";

interface RCEvent {
  type: string;
  id?: string;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  entitlement_ids?: string[];
  product_id?: string;
  store?: RCStore;
  environment?: "SANDBOX" | "PRODUCTION";
  period_type?: "TRIAL" | "INTRO" | "NORMAL";
  expiration_at_ms?: number;
  purchased_at_ms?: number;
  event_timestamp_ms?: number;
  original_transaction_id?: string;
  transaction_id?: string;
  cancel_reason?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // 1. Authentication
  if (!WEBHOOK_SECRET) {
    console.error("[revenuecat-webhook] missing REVENUECAT_WEBHOOK_SECRET env");
    return jsonResponse({ error: "server misconfigured" }, 500);
  }

  const auth = req.headers.get("authorization") ?? "";
  if (auth !== `Bearer ${WEBHOOK_SECRET}`) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  // 2. Parse body
  let body: { event?: RCEvent; api_version?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid JSON" }, 400);
  }
  const event = body?.event;
  if (!event) return jsonResponse({ error: "missing event" }, 400);

  const eventType = String(event.type ?? "UNKNOWN").toUpperCase();

  // TEST events: ACK con 200 sin procesar
  if (eventType === "TEST") {
    return jsonResponse({ ok: true, test: true });
  }

  // 3. Validar user id — tiene que ser un UUID de Supabase (RevenueCatService
  // hace Purchases.logIn(userId.uuidString) al iniciar sesión en iOS).
  const userId = event.app_user_id ?? event.original_app_user_id ?? "";
  if (!isUUID(userId)) {
    return jsonResponse({ ok: true, skipped: "non-uuid app_user_id", userId });
  }

  // 4. Mapear evento → status para `public.subscriptions`
  const status = mapEventToStatus(eventType);
  if (status === null) {
    return jsonResponse({ ok: true, skipped: eventType });
  }

  const entitlementIds: string[] = event.entitlement_ids && event.entitlement_ids.length > 0
    ? event.entitlement_ids
    : ["premium"];

  const productId = event.product_id ?? "unknown";
  const store = mapStore(event.store);
  const environment = event.environment === "SANDBOX" ? "sandbox" : "production";
  const periodType = mapPeriodType(event.period_type);
  const expiresAt = event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null;
  const purchasedAt = event.purchased_at_ms ? new Date(event.purchased_at_ms).toISOString() : null;
  const eventTs = event.event_timestamp_ms ? new Date(event.event_timestamp_ms).toISOString() : new Date().toISOString();

  // CANCELLATION: usuario canceló pero el entitlement sigue activo hasta la
  // expiración real. Dejamos status=active y guardamos canceled_at para auditar.
  // EXPIRATION: termina de verdad.
  const canceledAt = (eventType === "CANCELLATION" || eventType === "EXPIRATION")
    ? eventTs
    : null;

  // Renewed_at solo para RENEWAL events.
  const renewedAt = eventType === "RENEWAL" ? eventTs : null;

  // 5. Insert en subscriptions (append-only). El trigger sincroniza
  // user_entitlements automáticamente.
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const rows = entitlementIds.map((entId) => ({
    user_id: userId,
    revenuecat_user_id: event.original_app_user_id ?? userId,
    product_id: productId,
    entitlement_id: entId,
    store,
    environment,
    status,
    period_type: periodType,
    purchased_at: purchasedAt,
    renewed_at: renewedAt,
    expires_at: expiresAt,
    canceled_at: canceledAt,
    original_transaction_id: event.original_transaction_id ?? null,
    metadata: {
      event_type: eventType,
      event_id: event.id ?? null,
      cancel_reason: event.cancel_reason ?? null,
      transaction_id: event.transaction_id ?? null,
      aliases: event.aliases ?? [],
    },
  }));

  const { error } = await supabase.from("subscriptions").insert(rows);
  if (error) {
    console.error("[revenuecat-webhook] insert error", error);
    return jsonResponse({ error: error.message }, 500);
  }

  return jsonResponse({
    ok: true,
    event_type: eventType,
    user_id: userId,
    entitlements: entitlementIds,
    status,
    expires_at: expiresAt,
  });
});

// MARK: - Helpers

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function isUUID(s: string): boolean {
  return /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(s);
}

/// Devuelve el status a escribir en `public.subscriptions` o null si el evento
/// se debe ignorar. El trigger SQL después deriva `user_entitlements.is_active`
/// en base a status IN ('active','trialing','grace_period') + expires_at futuro.
function mapEventToStatus(eventType: string): string | null {
  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "UNCANCELLATION":
    case "PRODUCT_CHANGE":
    case "NON_RENEWING_PURCHASE":
    case "SUBSCRIPTION_EXTENDED":
    case "CANCELLATION":
      // CANCELLATION: user canceled, sigue activo hasta expiration.
      return "active";
    case "TRIAL_STARTED":
      return "trialing";
    case "EXPIRATION":
      return "expired";
    case "BILLING_ISSUE":
      return "billing_issue";
    case "SUBSCRIPTION_PAUSED":
      return "paused";
    case "TRANSFER":
      // Cambio de app_user_id — skip MVP
      return null;
    default:
      return null;
  }
}

function mapStore(store?: string): string {
  const s = (store ?? "").toUpperCase();
  switch (s) {
    case "APP_STORE":
    case "MAC_APP_STORE":
      return "app_store";
    case "PLAY_STORE":
      return "play_store";
    case "STRIPE":
      return "stripe";
    case "PROMOTIONAL":
      return "promotional";
    default:
      return "app_store";
  }
}

function mapPeriodType(p?: string): string | null {
  switch ((p ?? "").toUpperCase()) {
    case "TRIAL": return "trial";
    case "INTRO": return "intro";
    case "NORMAL": return "normal";
    default: return null;
  }
}
