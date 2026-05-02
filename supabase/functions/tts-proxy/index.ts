import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.0";

// Edge Function: tts-proxy
//
// Proxy a TTS APIs (OpenAI o ElevenLabs). Convierte texto en audio con voz
// natural. Usado por el voice mode del asistente iOS.
//
// Providers soportados:
//   - "openai"     (default) — Voces: alloy, echo, fable, onyx, nova, shimmer
//   - "elevenlabs" — Voces por voice_id (ver dashboard ElevenLabs)
//
// Rate limit: usa la misma tabla `ai_usage_daily` que ai-proxy.
// Privacy: API keys viven solo server-side. JWT obligatorio.

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface TTSRequest {
  text: string;
  provider?: "openai" | "elevenlabs";
  // OpenAI params
  voice?: string;
  model?: string;
  speed?: number;
  format?: string;
  // ElevenLabs params
  voice_id?: string;
  el_model?: string;
  stability?: number;
  similarity_boost?: number;
  style?: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type, apikey",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return jsonError("method not allowed", 405);
  }

  // 1. Auth
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonError("missing bearer token", 401);
  }
  const userJwt = authHeader.slice(7);
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: userData, error: userErr } = await supabase.auth.getUser(userJwt);
  if (userErr || !userData.user) {
    return jsonError("invalid jwt", 401);
  }
  const userId = userData.user.id;

  // 2. Parse body
  let body: TTSRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError("invalid json body", 400);
  }

  const text = (body.text ?? "").trim();
  if (!text) {
    return jsonError("text required", 400);
  }
  const cappedText = text.length > 4000 ? text.slice(0, 4000) : text;

  // 3. Rate limit (compartido con ai-proxy).
  // Voice mode genera N llamadas TTS por intercambio (1 por oración) — los
  // límites antiguos (50/d, 1000/m) saturaban con pocas pruebas.
  // Bumped para uso real: ~200 voice exchanges/día (5 oraciones avg).
  const { data: quotaData, error: quotaErr } = await supabase.rpc(
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
    return jsonError("quota check failed: " + quotaErr.message, 500);
  }
  const quota = Array.isArray(quotaData) ? quotaData[0] : quotaData;
  if (!quota?.allowed) {
    return jsonError("rate_limit_exceeded", 429);
  }

  // 4. Route to provider
  const provider = body.provider ?? "openai";

  if (provider === "elevenlabs") {
    return await handleElevenLabs(cappedText, body);
  }
  return await handleOpenAI(cappedText, body);
});

// ── ElevenLabs ──────────────────────────────────────────────────────────────

async function handleElevenLabs(text: string, body: TTSRequest): Promise<Response> {
  if (!ELEVENLABS_API_KEY) {
    return jsonError("server misconfigured: missing ELEVENLABS_API_KEY", 500);
  }

  const voiceId = body.voice_id ?? "21m00Tcm4TlvDq8ikWAM"; // "Rachel" default
  // eleven_flash_v2_5: ~75ms latency, optimizado para conversación.
  // eleven_turbo_v2_5: balance latency/calidad.
  // eleven_multilingual_v2: max calidad, más latencia.
  const modelId = body.el_model ?? "eleven_flash_v2_5";
  // Stability bajo (0.3-0.4) = más expresividad/emoción (tipo ChatGPT).
  // Stability alto (0.7+) = más monótono/consistente.
  const stability = body.stability ?? 0.35;
  const similarityBoost = body.similarity_boost ?? 0.85;
  const style = body.style ?? 0.0;

  // output_format mp3_22050_32 (low latency) vs mp3_44100_128 (quality).
  // Para conversación uso 22050_32 — perceptualmente igual y baja TTFB.
  const outputFormat = body.format === "high" ? "mp3_44100_128" : "mp3_22050_32";

  // Usar streaming endpoint para latencia mínima (Time To First Byte).
  // El cliente recibe el primer chunk de audio en cuanto está listo,
  // no cuando todo el audio terminó de generar.
  const url = new URL(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/stream`,
  );
  url.searchParams.set("output_format", outputFormat);
  url.searchParams.set("optimize_streaming_latency", "3");

  try {
    const resp = await fetch(
      url.toString(),
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "xi-api-key": ELEVENLABS_API_KEY,
          "Accept": "audio/mpeg",
        },
        body: JSON.stringify({
          text,
          model_id: modelId,
          voice_settings: {
            stability,
            similarity_boost: similarityBoost,
            style,
            use_speaker_boost: true,
          },
        }),
      },
    );

    if (!resp.ok) {
      const errBody = await resp.text();
      return jsonError(`elevenlabs_api_error: status=${resp.status} ${errBody}`, 502);
    }

    const audioBuffer = await resp.arrayBuffer();

    return new Response(audioBuffer, {
      status: 200,
      headers: {
        "Content-Type": "audio/mpeg",
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-store",
      },
    });
  } catch (e) {
    return jsonError(`elevenlabs_fetch_failed: ${String(e)}`, 502);
  }
}

// ── OpenAI ──────────────────────────────────────────────────────────────────

async function handleOpenAI(text: string, body: TTSRequest): Promise<Response> {
  if (!OPENAI_API_KEY) {
    return jsonError("server misconfigured: missing OPENAI_API_KEY", 500);
  }

  const voice = body.voice ?? "nova";
  const model = body.model ?? "tts-1";
  const speed = body.speed ?? 1.0;
  const format = body.format ?? "mp3";

  try {
    const resp = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model,
        input: text,
        voice,
        speed,
        response_format: format,
      }),
    });

    if (!resp.ok) {
      const errBody = await resp.text();
      return jsonError(`openai_api_error: status=${resp.status} ${errBody}`, 502);
    }

    const audioBuffer = await resp.arrayBuffer();

    return new Response(audioBuffer, {
      status: 200,
      headers: {
        "Content-Type": format === "mp3" ? "audio/mpeg" : `audio/${format}`,
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-store",
      },
    });
  } catch (e) {
    return jsonError(`openai_fetch_failed: ${String(e)}`, 502);
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
