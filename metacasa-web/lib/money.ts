/**
 * Formateo y parseo de dinero — multi-moneda, locale-aware.
 * Espeja la lógica de iOS `Core/Money.swift` para consistencia total.
 */

const LOCALE_BY_CURRENCY: Record<string, string> = {
  ARS: "es-AR",
  USD: "en-US",
  EUR: "es-ES",
  BRL: "pt-BR",
  MXN: "es-MX",
  CLP: "es-CL",
  COP: "es-CO",
  PEN: "es-PE",
  UYU: "es-UY",
  GBP: "en-GB",
  CAD: "en-CA",
};

export type MoneyStyle = "auto" | "precise" | "compact" | "abbreviated";

export function currencyLocale(currency?: string | null): string {
  return LOCALE_BY_CURRENCY[(currency ?? "USD").toUpperCase()] ?? "en-US";
}

/** Símbolo de la moneda según locale (ej. "US$", "$", "R$"). */
export function symbolFor(currency: string, locale?: string): string {
  const cur = (currency || "USD").toUpperCase();
  try {
    const parts = new Intl.NumberFormat(locale ?? currencyLocale(cur), {
      style: "currency",
      currency: cur,
      maximumFractionDigits: 0,
    }).formatToParts(0);
    return parts.find((p) => p.type === "currency")?.value ?? cur;
  } catch {
    return cur;
  }
}

/**
 * Formatea un monto con el símbolo de la moneda.
 * - "auto": 2 decimales solo si el monto los tiene.
 * - "precise": siempre 2 decimales.
 * - "compact": sin decimales.
 * - "abbreviated": notación compacta (1,2 M) para montos grandes.
 */
export function formatMoney(
  amount: number,
  currency: string = "USD",
  style: MoneyStyle = "auto",
): string {
  const cur = (currency || "USD").toUpperCase();
  const locale = currencyLocale(cur);
  const n = Number.isFinite(amount) ? amount : 0;

  if (style === "abbreviated" && Math.abs(n) >= 10_000) {
    const fmt = new Intl.NumberFormat(locale, {
      notation: "compact",
      maximumFractionDigits: 1,
    });
    return `${symbolFor(cur, locale)} ${fmt.format(n)}`;
  }

  const hasFraction = Math.abs(n % 1) > 0.0001;
  const fractionDigits =
    style === "precise" ? 2 : style === "compact" ? 0 : hasFraction ? 2 : 0;

  try {
    return new Intl.NumberFormat(locale, {
      style: "currency",
      currency: cur,
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
    }).format(n);
  } catch {
    // Moneda no reconocida por Intl → formateo numérico + símbolo crudo.
    return `${symbolFor(cur, locale)} ${new Intl.NumberFormat(locale, {
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
    }).format(n)}`;
  }
}

/** Formatea solo el número (sin símbolo de moneda). */
export function formatNumber(amount: number, fractionDigits = 0): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  }).format(Number.isFinite(amount) ? amount : 0);
}

/** Parsea input del usuario (formato US "1,234.56" o LatAm "1.234,56") a número. */
export function parseMoney(input: string): number {
  if (!input) return 0;
  let s = input.replace(/[^\d.,-]/g, "").trim();
  if (!s) return 0;

  const lastComma = s.lastIndexOf(",");
  const lastDot = s.lastIndexOf(".");

  if (lastComma > lastDot) {
    // Coma como separador decimal (LatAm).
    s = s.replace(/\./g, "").replace(",", ".");
  } else {
    // Punto como separador decimal (US) o sin decimales.
    s = s.replace(/,/g, "");
  }

  const value = parseFloat(s);
  return Number.isFinite(value) ? value : 0;
}
