import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.0";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MODEL = "claude-haiku-4-5-20251001";

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
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (allowed) {
    base["Access-Control-Allow-Origin"] = allowed;
    base["Vary"] = "Origin";
  }
  return base;
}

interface AnthropicRequest {
  system?: any;
  messages: any[];
  tools?: any[];
  // Deja que el cliente OBLIGUE al modelo a usar una herramienta.
  //
  // Sin esto, pedirle "agregá un gasto de 1.000.000" y confirmar con "Si"
  // terminaba en una respuesta de texto que afirmaba la carga sin haberla
  // hecho: el modelo tiene las tools disponibles y elige no usarlas. Con
  // `{"type":"any"}` no puede responder texto — tiene que llamar a alguna.
  tool_choice?: any;
  max_tokens?: number;
  temperature?: number;
  stream?: boolean;
}

interface AnthropicResponse {
  id: string;
  type: string;
  role: string;
  content: any[];
  model: string;
  stop_reason: string;
  stop_sequence: string | null;
  usage: {
    input_tokens: number;
    output_tokens: number;
    cache_creation_input_tokens?: number;
    cache_read_input_tokens?: number;
  };
}

Deno.serve(async (req: Request) => {
  const cors = corsHeaders(req);
  const jsonResponse = (body: any, status: number): Response =>
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json", ...cors },
    });

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  if (!ANTHROPIC_API_KEY) {
    return jsonResponse(
      { error: "server misconfigured: missing ANTHROPIC_API_KEY secret" },
      500,
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "missing bearer token" }, 401);
  }
  const userJwt = authHeader.slice(7);

  const supabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: userData, error: userErr } = await supabaseClient.auth
    .getUser(userJwt);
  if (userErr || !userData.user) {
    return jsonResponse({ error: "invalid jwt" }, 401);
  }
  const userId = userData.user.id;

  let body: AnthropicRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid json body" }, 400);
  }

  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return jsonResponse({ error: "messages array required" }, 400);
  }

  const isStreaming = body.stream === true;

  // Bumped quota: voice mode con tools puede generar 5-10 calls por intercambio
  // (tool_use loop). Limites antiguos (50/d) saturaban con pocas pruebas.
  const { data: quotaData, error: quotaErr } = await supabaseClient.rpc(
    "ai_check_and_increment_quota",
    {
      p_user_id: userId,
      p_daily_limit: 1000,
      p_monthly_limit: 30000,
      p_input_tokens: 0,
      p_output_tokens: 0,
    },
  );
  if (quotaErr) {
    return jsonResponse({ error: "quota check failed", detail: quotaErr.message }, 500);
  }
  const quota = Array.isArray(quotaData) ? quotaData[0] : quotaData;
  if (!quota?.allowed) {
    return jsonResponse(
      {
        error: "rate_limit_exceeded",
        daily_used: quota?.daily_used,
        monthly_used: quota?.monthly_used,
        message: "Llegaste al límite de uso del asistente AI por hoy. Volvé a intentar mañana.",
      },
      429,
    );
  }

  const anthropicReq = {
    model: MODEL,
    max_tokens: body.max_tokens ?? 1024,
    temperature: body.temperature ?? 0.7,
    system: body.system,
    messages: body.messages,
    tools: body.tools,
    ...(body.tool_choice ? { tool_choice: body.tool_choice } : {}),
    stream: isStreaming,
  };

  // ─── STREAMING PATH ──────────────────────────────────────────────────────
  // Pass-through SSE: forward chunks del upstream directo al cliente.
  // No parseamos JSON. Tracking de usage tokens NO se hace aqui (el ultimo
  // evento message_delta tiene los tokens, pero parsear el SSE en el proxy
  // anula el beneficio del streaming — lo dejamos en el cliente si quiere).
  if (isStreaming) {
    let upstream: Response;
    try {
      upstream = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify(anthropicReq),
      });
    } catch (e) {
      return jsonResponse(
        { error: "anthropic_fetch_failed", detail: String(e) },
        502,
      );
    }

    if (!upstream.ok || !upstream.body) {
      const errBody = await upstream.text();
      return jsonResponse(
        { error: "anthropic_api_error", status: upstream.status, detail: errBody },
        502,
      );
    }

    return new Response(upstream.body, {
      status: 200,
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        ...cors,
      },
    });
  }

  // ─── NON-STREAMING PATH (original) ───────────────────────────────────────
  let anthropicResp: AnthropicResponse;
  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(anthropicReq),
    });

    if (!resp.ok) {
      const errBody = await resp.text();
      return jsonResponse(
        { error: "anthropic_api_error", status: resp.status, detail: errBody },
        502,
      );
    }
    anthropicResp = await resp.json();
  } catch (e) {
    return jsonResponse(
      { error: "anthropic_fetch_failed", detail: String(e) },
      502,
    );
  }

  await supabaseClient
    .from("ai_usage_daily")
    .update({
      input_tokens: anthropicResp.usage.input_tokens,
      output_tokens: anthropicResp.usage.output_tokens,
      cache_read_tokens: anthropicResp.usage.cache_read_input_tokens ?? 0,
      cache_write_tokens: anthropicResp.usage.cache_creation_input_tokens ?? 0,
    })
    .eq("user_id", userId)
    .eq("day", new Date().toISOString().slice(0, 10));

  return jsonResponse(anthropicResp, 200);
});
