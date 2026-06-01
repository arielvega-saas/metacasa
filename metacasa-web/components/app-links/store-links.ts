/**
 * Enlaces a las tiendas de Home Finance.
 *
 * iOS: app LIVE en la App Store (id confirmado vía iTunes API — app "Home
 * Finance", dev ARIEL JOSUE VEGA GUERRERO).
 * Android: la app está en PRUEBA CERRADA (closed testing), sin ficha pública en
 * Google Play todavía → no hay link de descarga; mostramos "próximamente".
 */
export const STORE_LINKS = {
  // App Store ID real 6769792040 (confirmado vía iTunes API).
  ios: "https://apps.apple.com/app/id6769792040",
  // Sin ficha pública aún (closed testing). Cuando salga: play.google.com/store/apps/details?id=com.metacasa.app
  android: null as string | null,
} as const;

export type DetectedPlatform = "ios" | "android" | "other";

/** Detección de plataforma por user-agent (best-effort, solo cliente). */
export function detectPlatform(ua: string): DetectedPlatform {
  const s = ua.toLowerCase();
  // iPadOS 13+ se presenta como Mac con touch; lo cubrimos con maxTouchPoints en el caller.
  if (/iphone|ipad|ipod/.test(s)) return "ios";
  if (/android/.test(s)) return "android";
  return "other";
}
