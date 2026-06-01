import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

/**
 * Handoff app móvil → web: la app abre esta URL con un token_hash de un solo
 * uso (generado por la edge function `web-handoff`). Lo canjeamos por una
 * sesión web y redirigimos al dashboard. El usuario entra SIN re-loguearse.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const tokenHash = searchParams.get("token_hash");
  // El handoff SIEMPRE usa magic link (lo genera la edge function). No confiamos
  // en el `type` del query string: lo forzamos a 'magiclink'.
  const type: EmailOtpType = "magiclink";
  const next = sanitizeNext(searchParams.get("next"));

  if (!tokenHash) {
    return NextResponse.redirect(`${origin}/login?error=handoff`);
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });

  if (error) {
    return NextResponse.redirect(`${origin}/login?error=handoff_expired`);
  }
  return NextResponse.redirect(`${origin}${next}`);
}

function sanitizeNext(n: string | null): string {
  if (!n || !n.startsWith("/") || n.startsWith("//")) return "/dashboard";
  return n;
}
