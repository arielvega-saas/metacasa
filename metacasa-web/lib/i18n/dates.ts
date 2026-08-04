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
 * Convierte `YYYY-MM-DD` (o un timestamp ISO) en una fecha a medianoche **local**.
 *
 * **Usar esto siempre que se vaya a MOSTRAR una fecha guardada.** `new Date("2026-08-10")`
 * no sirve: el string de sólo-fecha se interpreta como medianoche **UTC**, y al
 * formatearlo en un huso negativo —toda LatAm, que es el mercado de esta app— sale
 * el día anterior. Vencimientos, metas y deudas mostraban un día menos, y los
 * movimientos se agrupaban bajo "Ayer" el mismo día que se cargaban.
 *
 * La fecha de un movimiento, un vencimiento o una meta es **un día del calendario
 * del usuario**, no un instante en el tiempo. Ese es el criterio, y es el mismo que
 * aplica `toStableDate` al escribir.
 */
export function parseDayLocal(date: string): Date {
  const [y, m, d] = String(date).slice(0, 10).split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

/**
 * Hoy, a medianoche local, como `Date`.
 *
 * No usar `new Date().toISOString().slice(0, 10)` para esto: eso da el día **UTC**,
 * y en Argentina a partir de las 21 h ya devuelve mañana. Un vencimiento de mañana
 * pasaba a contarse como "hoy" con sólo que se hiciera de noche.
 */
export function todayLocal(): Date {
  const n = new Date();
  return new Date(n.getFullYear(), n.getMonth(), n.getDate());
}

/**
 * Día + mes corto, localizado. Acepta `Date` o ISO string.
 * "5 may" / "May 5" / "5 mai".
 */
export function formatDayMonth(date: Date | string, l: Locale): string {
  const d = typeof date === "string" ? parseDayLocal(date) : date;
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
