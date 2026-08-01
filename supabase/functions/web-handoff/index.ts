// web-handoff: canjea el JWT del usuario móvil por un magic link de un solo uso
// para que la web pueda iniciar sesión SIN pedir credenciales de nuevo.
// verify_jwt=true: solo usuarios autenticados llegan acá.
import { createClient } from "jsr:@supabase/supabase-js@2";

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

// Destino de la web. `WEB_APP_URL` (secret) manda si está seteado.
//
// FALLBACK TEMPORAL (2026-07-28): apunta a la PWA de Firebase porque el
// proyecto de Vercel que servía usehomefinance.com quedó SUSPENDIDO por
// facturación y el dominio devuelve HTTP 402. Mandar al usuario ahí era
// mandarlo a una página de error.
// → Cuando la web nueva esté online (migración a Netlify), volver a
//   "https://usehomefinance.com" o setear el secret WEB_APP_URL.
const DEFAULT_WEB_APP_URL = "https://metacasa-app-cf592.web.app";

// Bases que NO saben consumir `/auth/handoff?token_hash=...`. La PWA legacy es
// un SPA de Vite sin esa ruta: el catch-all le serviría el index y el token se
// quemaría sin usarse. Para esos destinos devolvemos la URL pelada — el usuario
// llega a una web que FUNCIONA y se loguea a mano, en vez de a un error.
const HANDOFF_UNSUPPORTED_HOSTS = new Set([
  "metacasa-app-cf592.web.app",
  "metacasa-app-cf592.firebaseapp.com",
]);

function supportsHandoff(base: string): boolean {
  try {
    return !HANDOFF_UNSUPPORTED_HOSTS.has(new URL(base).hostname);
  } catch {
    return true;
  }
}

Deno.serve(async (req: Request) => {
  const cors = corsHeaders(req);
  const json = (body: unknown, status = 200): Response =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) return json({ error: "missing_token" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Validar el JWT del usuario móvil y obtener su email.
    const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
    const email = userData?.user?.email;
    if (userErr || !email) return json({ error: "invalid_session" }, 401);

    const webBase = (Deno.env.get("WEB_APP_URL") ?? DEFAULT_WEB_APP_URL).replace(/\/$/, "");

    // Destino sin soporte de handoff → URL simple, sin quemar un magic link.
    if (!supportsHandoff(webBase)) {
      return json({ url: webBase, type: "plain", handoff: false });
    }

    // Generar un magic link de un solo uso (token_hash) para ese email.
    const { data, error } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
    });
    const tokenHash = data?.properties?.hashed_token;
    if (error || !tokenHash) return json({ error: "link_generation_failed" }, 500);

    const url = `${webBase}/auth/handoff?token_hash=${encodeURIComponent(tokenHash)}&type=magiclink&next=/dashboard`;

    return json({ token_hash: tokenHash, type: "magiclink", url, handoff: true });
  } catch (e) {
    return json({ error: "internal_error", detail: String(e) }, 500);
  }
});
