import "server-only";
import { cookies, headers } from "next/headers";
import { cache } from "react";
import { LOCALE_COOKIE, DEFAULT_LOCALE, isLocale, type Locale } from "./config";
import { getDictionary } from "./dictionaries";
import { lookup, interpolate } from "./lookup";

/** Locale activo: cookie `mc_locale` si está; si no, Accept-Language; si no, ES. */
export const getLocale = cache(async (): Promise<Locale> => {
  const cookieVal = (await cookies()).get(LOCALE_COOKIE)?.value;
  if (isLocale(cookieVal)) return cookieVal;
  const al = (await headers()).get("accept-language") ?? "";
  const first = al.split(",")[0]?.trim().split("-")[0]?.toLowerCase();
  return isLocale(first) ? first : DEFAULT_LOCALE;
});

export type TFn = (key: string, vars?: Record<string, string | number>) => string;

/** `t()` para Server Components: `const t = await getT(); t("nav.home")`. */
export async function getT(): Promise<TFn> {
  const dict = getDictionary(await getLocale());
  return (key, vars) => interpolate(lookup(dict, key) ?? key, vars);
}
