import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

/**
 * Confirmación server-side de links de email (recovery, signup, magic link,
 * cambio de email). Es el endpoint recomendado por Supabase para SSR.
 *
 * Soporta DOS formatos de link, por orden de preferencia:
 *  1. `token_hash` + `type`  → `verifyOtp()`. NO necesita `code_verifier`, así
 *     que funciona en CUALQUIER dispositivo (pedís el reset en la compu y abrís
 *     el mail en el teléfono → funciona). Es el flujo correcto para links de
 *     email. La plantilla del dashboard debe apuntar acá con `{{ .TokenHash }}`.
 *  2. `code` (PKCE) → `exchangeCodeForSession()`. Fallback por si la plantilla
 *     todavía manda `{{ .ConfirmationURL }}`. Solo funciona en el MISMO browser
 *     que pidió el link (depende de la cookie `code_verifier`).
 *
 * En éxito redirige a `next` (con la sesión ya seteada por cookies). En fallo,
 * si es un flujo de recovery manda a `/reset-password?error=expired` (pantalla
 * amigable de "link vencido, pedí uno nuevo"); para el resto, `/login?error=auth`.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const type = parseOtpType(searchParams.get("type"));
  const next = sanitizeNext(searchParams.get("next"));

  const supabase = await createClient();
  let ok = false;

  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });
    ok = !error;
  } else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    ok = !error;
  }

  if (ok) {
    return NextResponse.redirect(`${origin}${next}`);
  }
  return NextResponse.redirect(`${origin}${failureRedirect(type, next)}`);
}

/** Tipos de OTP que aceptamos canjear (no confiar ciegamente en el query param). */
const ALLOWED_OTP_TYPES = new Set<string>([
  "recovery",
  "magiclink",
  "email",
  "signup",
  "invite",
  "email_change",
]);

function parseOtpType(raw: string | null): EmailOtpType | null {
  return raw && ALLOWED_OTP_TYPES.has(raw) ? (raw as EmailOtpType) : null;
}

function sanitizeNext(n: string | null): string {
  if (!n || !n.startsWith("/") || n.startsWith("//")) return "/dashboard";
  return n;
}

/**
 * Adónde mandar cuando la verificación falla. Para recovery (o cuando el destino
 * es la pantalla de nueva contraseña) mostramos el estado de "link vencido" en
 * esa misma pantalla, con acción de reenvío — nunca el login pelado.
 */
function failureRedirect(type: EmailOtpType | null, next: string): string {
  if (type === "recovery" || next.startsWith("/reset-password")) {
    return "/reset-password?error=expired";
  }
  return "/login?error=auth";
}
