import { describe, it, expect } from "vitest";
import {
  formatMoney,
  parseMoney,
  formatNumber,
  symbolFor,
  currencyLocale,
} from "@/lib/money";

/**
 * `Intl` intercala espacios duros (U+00A0/U+202F) entre símbolo y número según
 * el locale. Los normalizamos a espacio simple para que los asserts no dependan
 * de la versión de ICU del runtime.
 */
function norm(s: string): string {
  return s.replace(/[  ]/g, " ");
}

describe("currencyLocale", () => {
  it("mapea cada moneda soportada a su locale", () => {
    expect(currencyLocale("ARS")).toBe("es-AR");
    expect(currencyLocale("BRL")).toBe("pt-BR");
    expect(currencyLocale("EUR")).toBe("es-ES");
  });

  it("es case-insensitive y cae a en-US ante lo desconocido", () => {
    expect(currencyLocale("ars")).toBe("es-AR");
    expect(currencyLocale("ZZZ")).toBe("en-US");
    expect(currencyLocale(null)).toBe("en-US");
    expect(currencyLocale(undefined)).toBe("en-US");
  });
});

describe("symbolFor", () => {
  it("devuelve el símbolo del locale de la moneda", () => {
    expect(symbolFor("USD")).toBe("$");
    expect(symbolFor("BRL")).toBe("R$");
  });

  it("cae al código crudo si la moneda no es válida para Intl", () => {
    expect(symbolFor("US")).toBe("US");
  });
});

describe("formatMoney — locales", () => {
  it("USD usa punto decimal y coma de miles", () => {
    expect(norm(formatMoney(1234.5, "USD"))).toBe("$1,234.50");
  });

  it("ARS usa coma decimal y punto de miles (es-AR)", () => {
    expect(norm(formatMoney(1234.5, "ARS"))).toBe("$ 1.234,50");
  });

  it("BRL usa el formato pt-BR", () => {
    expect(norm(formatMoney(1234.56, "BRL"))).toBe("R$ 1.234,56");
  });

  it("EUR pone el símbolo al final (es-ES)", () => {
    expect(norm(formatMoney(1234.56, "EUR"))).toBe("1234,56 €");
  });

  it("sin moneda explícita asume USD", () => {
    expect(norm(formatMoney(10))).toBe("$10");
  });
});

describe("formatMoney — estilos", () => {
  it("auto: sin decimales si el monto es entero", () => {
    expect(norm(formatMoney(1234, "USD"))).toBe("$1,234");
  });

  it("auto: con decimales si el monto los tiene", () => {
    expect(norm(formatMoney(1234.05, "USD"))).toBe("$1,234.05");
  });

  it("precise: siempre 2 decimales", () => {
    expect(norm(formatMoney(1234, "USD", "precise"))).toBe("$1,234.00");
  });

  it("compact: redondea a entero", () => {
    expect(norm(formatMoney(1234.56, "USD", "compact"))).toBe("$1,235");
  });

  it("abbreviated: notación corta a partir de 10.000", () => {
    expect(norm(formatMoney(1_234_567, "USD", "abbreviated"))).toBe("$ 1.2M");
    expect(norm(formatMoney(12_000, "USD", "abbreviated"))).toBe("$ 12K");
  });

  it("abbreviated: por debajo del umbral formatea normal", () => {
    expect(norm(formatMoney(9_999, "USD", "abbreviated"))).toBe("$9,999");
  });
});

describe("formatMoney — negativos y valores raros", () => {
  it("mantiene el signo menos", () => {
    expect(norm(formatMoney(-1234.5, "USD"))).toBe("-$1,234.50");
  });

  it("formatea el cero sin decimales en auto", () => {
    expect(norm(formatMoney(0, "USD"))).toBe("$0");
  });

  it("trata NaN e Infinity como 0 en vez de romper", () => {
    expect(norm(formatMoney(Number.NaN, "USD"))).toBe("$0");
    expect(norm(formatMoney(Number.POSITIVE_INFINITY, "USD"))).toBe("$0");
  });

  it("no lanza si la moneda no es válida para Intl", () => {
    const out = norm(formatMoney(10, "US"));
    expect(out).toContain("10");
    expect(out).toContain("US");
  });
});

describe("formatNumber", () => {
  it("formatea sin símbolo de moneda", () => {
    expect(norm(formatNumber(1234.56))).toBe("1,235");
    expect(norm(formatNumber(1234.56, 2))).toBe("1,234.56");
  });

  it("cae a 0 ante valores no finitos", () => {
    expect(formatNumber(Number.NaN)).toBe("0");
  });
});

describe("parseMoney", () => {
  it("vuelve 0 con entrada vacía o sin dígitos", () => {
    expect(parseMoney("")).toBe(0);
    expect(parseMoney("abc")).toBe(0);
    expect(parseMoney("$")).toBe(0);
  });

  it("parsea formato US (coma miles, punto decimal)", () => {
    expect(parseMoney("1,234.56")).toBe(1234.56);
    expect(parseMoney("1,234,567.89")).toBe(1234567.89);
  });

  it("parsea formato LatAm (punto miles, coma decimal)", () => {
    expect(parseMoney("1.234,56")).toBe(1234.56);
    expect(parseMoney("12.345.678,90")).toBe(12345678.9);
  });

  it("trata varias comas sin punto como separadores de miles", () => {
    // Bug histórico: `String.replace(",", ".")` sólo cambiaba la PRIMERA coma,
    // así que "1,234,567" caía en 1.234.
    expect(parseMoney("1,234,567")).toBe(1234567);
  });

  it("trata varios puntos sin coma como separadores de miles", () => {
    // Bug histórico: parseFloat("1.234.567") devolvía 1.234.
    expect(parseMoney("1.234.567")).toBe(1234567);
  });

  it("toma un único separador como decimal", () => {
    expect(parseMoney("1,50")).toBe(1.5);
    expect(parseMoney("1.50")).toBe(1.5);
  });

  it("parsea negativos", () => {
    expect(parseMoney("-1.234,56")).toBe(-1234.56);
    expect(parseMoney("-1,234.56")).toBe(-1234.56);
  });

  it("ignora símbolos y espacios alrededor del número", () => {
    expect(parseMoney("$ 1,500.25")).toBe(1500.25);
    expect(parseMoney("R$ 2.500,10")).toBe(2500.1);
    expect(parseMoney("  42  ")).toBe(42);
  });

  it("hace ida y vuelta con formatMoney en formato US", () => {
    expect(parseMoney(formatMoney(9876.54, "USD", "precise"))).toBe(9876.54);
  });
});
