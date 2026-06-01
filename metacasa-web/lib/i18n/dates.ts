import type { Locale } from "./config";

/**
 * Mapa de locale de la app → tag BCP-47 para la API nativa `Intl`.
 * Usamos `pt-BR` para portugués (es el mercado real) y dejamos `es`/`en`
 * genéricos. La API `Intl` es intrínsecamente correcta por idioma: no hay
 * "de" hardcodeado ni nombres de mes en español fijos.
 */
const INTL: Record<Locale, string> = { es: "es", en: "en", pt: "pt-BR" };

/** Devuelve el tag BCP-47 para `Intl` a partir del locale de la app. */
export function intlLocale(l: Locale): string {
  return INTL[l] ?? "es";
}

/**
 * Mes + año largo, localizado. Espera `month1to12` (1 = enero).
 * "mayo de 2026" / "May 2026" / "maio de 2026".
 */
export function formatMonthYear(
  year: number,
  month1to12: number,
  l: Locale,
): string {
  return new Date(year, month1to12 - 1, 1).toLocaleDateString(intlLocale(l), {
    month: "long",
    year: "numeric",
  });
}

/**
 * Mes corto, localizado. Espera `month1to12` (1 = enero).
 * "may" / "May" / "mai".
 */
export function formatMonthShort(
  year: number,
  month1to12: number,
  l: Locale,
): string {
  return new Date(year, month1to12 - 1, 1).toLocaleDateString(intlLocale(l), {
    month: "short",
  });
}

/**
 * Día + mes corto, localizado. Acepta `Date` o ISO string.
 * "5 may" / "May 5" / "5 mai".
 */
export function formatDayMonth(date: Date | string, l: Locale): string {
  const d = typeof date === "string" ? new Date(date) : date;
  return d.toLocaleDateString(intlLocale(l), { day: "numeric", month: "short" });
}

/**
 * Día de la semana + día + mes largo, localizado. Acepta `Date`.
 * "lunes, 5 de mayo" / "Monday, May 5" / "segunda-feira, 5 de maio".
 */
export function formatWeekdayLong(date: Date, l: Locale): string {
  return date.toLocaleDateString(intlLocale(l), {
    weekday: "long",
    day: "numeric",
    month: "long",
  });
}
