import { describe, it, expect } from "vitest";
import { parseFxRates, convertToBase, canConvertAll } from "@/lib/fx";

describe("parseFxRates", () => {
  it("acepta la forma canónica de iOS (objeto con `rate`)", () => {
    const rates = parseFxRates({
      USD: { rate: 1000, updated_at: "2026-05-30T00:00:00Z", source: "manual" },
    });
    expect(rates.USD.rate).toBe(1000);
    expect(rates.USD.source).toBe("manual");
  });

  it("acepta la forma simplificada (valor numérico directo)", () => {
    expect(parseFxRates({ USD: 1000 }).USD.rate).toBe(1000);
  });

  it("acepta `rate` numérico en string dentro del objeto", () => {
    expect(parseFxRates({ USD: { rate: "1000" } }).USD.rate).toBe(1000);
  });

  it("normaliza las claves a mayúsculas", () => {
    expect(parseFxRates({ usd: 1000 }).USD.rate).toBe(1000);
  });

  it("descarta entradas no numéricas o no finitas", () => {
    const rates = parseFxRates({
      USD: 1000,
      EUR: "no es un número",
      BRL: { rate: Number.NaN },
      MXN: { nope: 1 },
      CLP: null,
    });
    expect(Object.keys(rates)).toEqual(["USD"]);
  });

  it("devuelve un mapa vacío si el JSONB es nulo o no es objeto", () => {
    expect(parseFxRates(null)).toEqual({});
    expect(parseFxRates(undefined)).toEqual({});
    expect(parseFxRates("USD")).toEqual({});
    expect(parseFxRates(42)).toEqual({});
  });
});

describe("convertToBase", () => {
  const rates = parseFxRates({
    USD: { rate: 1000 },
    EUR: 1100,
  });

  it("devuelve el monto tal cual si la moneda ya es la base", () => {
    expect(convertToBase(1234.56, "ARS", "ARS", {})).toBe(1234.56);
  });

  it("multiplica por la tasa (forma objeto)", () => {
    expect(convertToBase(10, "USD", "ARS", rates)).toBe(10_000);
  });

  it("multiplica por la tasa (forma numérica)", () => {
    expect(convertToBase(2, "EUR", "ARS", rates)).toBe(2_200);
  });

  it("es case-insensitive en `from` y `base`", () => {
    expect(convertToBase(10, "usd", "ars", rates)).toBe(10_000);
    expect(convertToBase(5, "ars", "ARS", rates)).toBe(5);
  });

  it("devuelve null si falta la tasa (no convierte a ciegas)", () => {
    expect(convertToBase(10, "BRL", "ARS", rates)).toBeNull();
    expect(convertToBase(10, "USD", "ARS", {})).toBeNull();
  });

  it("devuelve null si la tasa quedó fuera del mapa por inválida", () => {
    const broken = parseFxRates({ BRL: { rate: "x" } });
    expect(convertToBase(10, "BRL", "ARS", broken)).toBeNull();
  });

  it("conserva el signo de los montos negativos", () => {
    expect(convertToBase(-3, "USD", "ARS", rates)).toBe(-3_000);
  });
});

describe("canConvertAll", () => {
  const rates = parseFxRates({ USD: 1000 });

  it("es true si toda moneda es base o tiene tasa", () => {
    expect(canConvertAll(["ARS", "USD"], "ARS", rates)).toBe(true);
  });

  it("es false si falta alguna tasa", () => {
    expect(canConvertAll(["ARS", "USD", "BRL"], "ARS", rates)).toBe(false);
  });

  it("es true con una lista vacía", () => {
    expect(canConvertAll([], "ARS", {})).toBe(true);
  });
});
