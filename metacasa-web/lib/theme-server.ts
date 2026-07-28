import "server-only";
import { cookies } from "next/headers";
import { cache } from "react";
import { DEFAULT_THEME, THEME_COOKIE, isTheme, type Theme } from "./theme";

/**
 * Preferencia de tema del visitante: cookie `mc_theme` si está, si no `system`.
 * Cacheado por request (igual patrón que `getLocale`).
 */
export const getTheme = cache(async (): Promise<Theme> => {
  const v = (await cookies()).get(THEME_COOKIE)?.value;
  return isTheme(v) ? v : DEFAULT_THEME;
});
