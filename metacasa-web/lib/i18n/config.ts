export const LOCALES = ["es", "en", "pt"] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = "es";
export const LOCALE_COOKIE = "mc_locale";

export const LOCALE_LABEL: Record<Locale, string> = {
  es: "Español",
  en: "English",
  pt: "Português",
};

export function isLocale(v: string | undefined | null): v is Locale {
  return !!v && (LOCALES as readonly string[]).includes(v);
}
