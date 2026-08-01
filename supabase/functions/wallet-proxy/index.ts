import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const PROVIDERS: Record<string, string> = {
  mercadopago: "https://api.mercadopago.com",
  paypal: "https://api.paypal.com",
};

// CORS allowlist — copia inline de supabase/functions/_shared/cors.ts.
const ALLOWED_ORIGINS = new Set([
  "https://usehomefinance.com",
  "https://www.usehomefinance.com",
  "https://metacasa-app-cf592.web.app",
  "https://home-finance-web.netlify.app",
  "https://metacasa-app-cf592.firebaseapp.com",
  "http://localhost:3000",
  "http://localhost:5173",
]);

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  let allowed: string | null = null;
  if (origin) {
    if (ALLOWED_ORIGINS.has(origin)) {
      allowed = origin;
    } else {
      try {
        const host = new URL(origin).hostname;
        if (host.endsWith(".vercel.app") && host.startsWith("metacasa-web")) {
          allowed = origin;
        }
      } catch { /* origen malformado → sin CORS */ }
    }
  }
  const base: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (allowed) {
    base["Access-Control-Allow-Origin"] = allowed;
    base["Vary"] = "Origin";
  }
  return base;
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  const cors = corsHeaders(req);
  const json = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  try {
    const body = await req.json();
    const { action } = body;

    // OAuth exchange: authorization_code -> access_token upstream
    if (action === "oauth_exchange") {
      const provider: string = body.provider || "mercadopago";
      if (provider === "mercadopago") {
        const clientId = Deno.env.get("MP_CLIENT_ID") || "";
        const clientSecret = Deno.env.get("MP_CLIENT_SECRET") || "";
        if (!clientId || !clientSecret) {
          return json({ error: "OAuth de Mercado Pago no configurado en el servidor" }, 503);
        }
        const tokenRes = await fetch("https://api.mercadopago.com/oauth/token", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            grant_type: "authorization_code",
            client_id: clientId,
            client_secret: clientSecret,
            code: body.code,
            redirect_uri: body.redirect_uri,
          }).toString(),
        });
        const tokenData = await tokenRes.json();
        return json(tokenData, tokenRes.status);
      }
      return json({ error: `OAuth para ${provider} no implementado aun` }, 501);
    }

    // OAuth refresh
    if (action === "oauth_refresh") {
      const provider: string = body.provider || "mercadopago";
      if (provider === "mercadopago") {
        const clientId = Deno.env.get("MP_CLIENT_ID") || "";
        const clientSecret = Deno.env.get("MP_CLIENT_SECRET") || "";
        const tokenRes = await fetch("https://api.mercadopago.com/oauth/token", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            grant_type: "refresh_token",
            client_id: clientId,
            client_secret: clientSecret,
            refresh_token: body.refresh_token,
          }).toString(),
        });
        const tokenData = await tokenRes.json();
        return json(tokenData, tokenRes.status);
      }
      return json({ error: `OAuth refresh para ${provider} no implementado` }, 501);
    }

    // Proxy wallet API calls. Cliente envia wallet_id; el server descifra token y llama upstream.
    const { provider, path, wallet_id } = body;
    const baseUrl = PROVIDERS[provider];
    if (!baseUrl) return json({ error: "Unknown provider: " + provider }, 400);
    if (!wallet_id) return json({ error: "Missing wallet_id" }, 400);

    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    if (userErr || !userData?.user) return json({ error: "Unauthorized" }, 401);
    const callerUserId = userData.user.id;

    // Validar ownership de la wallet
    const { data: wallet, error: walletErr } = await admin
      .from("connected_wallets")
      .select("id, user_id, provider")
      .eq("id", wallet_id)
      .single();
    if (walletErr || !wallet) return json({ error: "Wallet not found" }, 404);
    if (wallet.user_id !== callerUserId) return json({ error: "Forbidden" }, 403);
    if (wallet.provider !== provider) return json({ error: "Provider mismatch" }, 400);

    // Recuperar token descifrado via RPC
    const { data: tokenResult, error: tokenErr } = await admin.rpc("get_wallet_access_token", { wid: wallet_id });
    if (tokenErr || !tokenResult) return json({ error: "Token not available" }, 500);
    const token = String(tokenResult);

    const upstream = await fetch(`${baseUrl}${path}`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
    });
    const data = await upstream.json();
    return json(data, upstream.status);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    return json({ error: msg }, 500);
  }
});
