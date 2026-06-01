import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

/**
 * Callback universal de Auth: confirma email (signup), magic link, recovery y
 * OAuth. Soporta flujo PKCE (`code`) y token_hash (`token_hash` + `type`).
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const rawType = searchParams.get("type");
  const type = ALLOWED_OTP_TYPES.has(rawType ?? "")
    ? (rawType as EmailOtpType)
    : null;
  const next = sanitizeNext(searchParams.get("next"));

  const supabase = await createClient();
  let ok = false;

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    ok = !error;
  } else if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });
    ok = !error;
  }

  return NextResponse.redirect(`${origin}${ok ? next : "/login?error=auth"}`);
}

/** Allow-list de tipos de OTP que aceptamos canjear (no confiar en el query param). */
const ALLOWED_OTP_TYPES = new Set([
  "magiclink",
  "recovery",
  "email",
  "signup",
  "invite",
  "email_change",
]);

function sanitizeNext(n: string | null): string {
  if (!n || !n.startsWith("/") || n.startsWith("//")) return "/dashboard";
  return n;
}
