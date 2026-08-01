// CORS compartido: allowlist de orígenes web conocidos.
//
// Los clientes nativos (iOS) no mandan header Origin y no necesitan CORS.
// Un origen desconocido NO recibe Access-Control-Allow-Origin → el browser
// bloquea la respuesta (endurecimiento vs el `*` anterior: un token robado
// ya no puede usarse desde cualquier página web).
//
// NOTA de deploy: el deploy vía MCP sube cada función con sus archivos, así
// que este helper se COPIA inline en cada función (no hay import compartido
// garantizado). Este archivo es la fuente canónica — si cambiás la lista,
// replicá el cambio en las 5 funciones (wallet-proxy, ai-proxy, web-handoff,
// delete-account, tts-proxy).

export const ALLOWED_ORIGINS = new Set([
  "https://usehomefinance.com",
  "https://www.usehomefinance.com",
  "https://metacasa-app-cf592.web.app",
  "https://home-finance-web.netlify.app",
  "https://metacasa-app-cf592.firebaseapp.com",
  "http://localhost:3000",
  "http://localhost:5173",
]);

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  let allowed: string | null = null;
  if (origin) {
    if (ALLOWED_ORIGINS.has(origin)) {
      allowed = origin;
    } else {
      try {
        const host = new URL(origin).hostname;
        // Previews de Vercel del proyecto web (metacasa-web-*.vercel.app).
        if (host.endsWith(".vercel.app") && host.startsWith("metacasa-web")) {
          allowed = origin;
        }
      } catch {
        // Origin malformado → sin CORS.
      }
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
