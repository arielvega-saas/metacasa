import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

/**
 * Confirmación server-side del link de RECUPERACIÓN de contraseña.
 *
 * Vive en una ruta separada de `/auth/confirm` A PROPÓSITO: las apps nativas
 * (iOS Universal Links / Android App Links) reclaman SOLO `/auth/confirm` para
 * abrirse y loguear al usuario. La recuperación, en cambio, necesita la
 * pantalla web `/reset-password` (cross-device y ya pulida), así que su link NO
 * debe abrir la app — por eso usa `/auth/reset`, que las apps no reclaman.
 *
 * Mismo mecanismo que `/auth/confirm`: `token_hash` + `type=recovery` →
 * `verifyOtp()` (no depende de `code_verifier`, funciona cross-device). La
 * plantilla del dashboard (Reset Password) debe apuntar acá con
 * `{{ .SiteURL }}/auth/reset?token_hash={{ .TokenHash }}&type=recovery&next=/reset-password`.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const tokenHash = searchParams.get("token_hash");
  const type = parseRecoveryType(searchParams.get("type"));
  const next = sanitizeNext(searchParams.get("next"));

  if (tokenHash && type) {
    const supabase = await createClient();
    const { error } = await supabase.auth.verifyOtp({
      type,
      token_hash: tokenHash,
    });
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  // Link vencido/ inválido → pantalla amigable de "pedí uno nuevo".
  return NextResponse.redirect(`${origin}/reset-password?error=expired`);
}

/** Solo aceptamos `recovery` en esta ruta (no confiar en el query param). */
function parseRecoveryType(raw: string | null): EmailOtpType | null {
  return raw === "recovery" ? "recovery" : null;
}

function sanitizeNext(n: string | null): string {
  if (!n || !n.startsWith("/") || n.startsWith("//")) return "/reset-password";
  return n;
}
