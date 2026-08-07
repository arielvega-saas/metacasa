import "server-only";
import { cookies } from "next/headers";
import { cache } from "react";
import { TZ_COOKIE, todayFromTimeZoneCookie, monthOf } from "./today";

/**
 * El día de calendario del usuario (`YYYY-MM-DD`) para ESTE request.
 *
 * Lee la cookie `mc_tz` (zona IANA que escribe `TimezoneCookie` en el browser) y
 * la resuelve contra el reloj del server. Sin cookie o con cookie inválida cae
 * al día UTC, que es el comportamiento anterior al fix: nunca rompe.
 *
 * Cacheado por request con `cache()` — mismo patrón que `getLocale` / `getTheme`,
 * así varias secciones del dashboard comparten una sola lectura y un solo "hoy"
 * (no puede pasar que dos partes de la misma página caigan en días distintos).
 */
export const getToday = cache(async (): Promise<string> => {
  const tz = (await cookies()).get(TZ_COOKIE)?.value;
  return todayFromTimeZoneCookie(tz);
});

/** El mes actual del usuario (`YYYY-MM`) — default de dashboard/reportes/presupuesto. */
export async function getCurrentYm(): Promise<string> {
  return monthOf(await getToday());
}
