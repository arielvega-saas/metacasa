import { NextResponse, type NextRequest } from "next/server";
import { completeMercadoPagoOAuth } from "@/lib/actions/wallets";

/**
 * Callback OAuth de **Mercado Pago**.
 *
 * MP vuelve acá con `?code=…&state=…` (navegación GET top-level, así que la
 * cookie `SameSite=Lax` del `state` viaja). Toda la validación real —
 * comparación del `state` contra la cookie httpOnly, canje del código vía
 * `wallet-proxy` y persistencia del token cifrado — vive en
 * `completeMercadoPagoOAuth`.
 *
 * Nunca devolvemos el detalle del error en la URL: sólo `ok` | `error`, y la
 * pantalla muestra el toast. Así no se filtra nada del código ni de la
 * respuesta de MP al historial del navegador o a los logs del proxy.
 *
 * La ruta está dentro del grupo `(app)`, o sea que el middleware ya exige
 * sesión: sin usuario logueado nunca se llega hasta acá.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const state = searchParams.get("state");

  // El usuario canceló en el consentimiento de MP, o faltan parámetros.
  if (!code || !state) {
    return NextResponse.redirect(`${origin}/wallets?connect=error`);
  }

  try {
    await completeMercadoPagoOAuth(code, state);
    return NextResponse.redirect(`${origin}/wallets?connect=ok`);
  } catch {
    return NextResponse.redirect(`${origin}/wallets?connect=error`);
  }
}
