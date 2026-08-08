import { describe, expect, it } from "vitest";
import { llevar, poderDeCompra, variacionReal, type Indice } from "@/lib/reexpresion";

/**
 * PARIDAD CON iOS.
 *
 * Estos casos son los MISMOS que `ReexpresionTests.swift`, con los mismos
 * valores reales del CER del BCRA y los mismos resultados esperados hasta el
 * centavo. Es lo único que impide que las dos implementaciones se separen: un
 * número distinto en el teléfono y en la computadora rompe la confianza en toda
 * la app, no en una pantalla.
 *
 * Si tocás una de las dos implementaciones y no la otra, este archivo se pone
 * rojo.
 */

const CER: Record<string, number> = {
  "2025-08-08": 613.87,
  "2026-08-01": 815.92975500377,
  "2026-08-07": 818.90754259824,
  "2026-08-08": 819.40489603602,
};

/** Día calendario LOCAL, igual que `CERService.clave` en iOS. */
function clave(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

const indice: Indice = (d) => CER[clave(d)] ?? null;

function fecha(iso: string): Date {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d);
}

describe("reexpresión por inflación", () => {
  it("llevar a la misma fecha no cambia el monto", () => {
    const hoy = fecha("2026-08-08");
    expect(llevar(100_000, hoy, hoy, indice)).toBe(100_000);
  });

  it("un monto de hace un año vale más en pesos de hoy", () => {
    // Mismo número exacto que el test de iOS.
    const r = llevar(100_000, fecha("2025-08-08"), fecha("2026-08-08"), indice);
    expect(r).toBe(133_481.83);
  });

  it("el viaje de ida y vuelta cierra", () => {
    const ida = llevar(100_000, fecha("2025-08-08"), fecha("2026-08-08"), indice)!;
    const vuelta = llevar(ida, fecha("2026-08-08"), fecha("2025-08-08"), indice);
    expect(vuelta).toBe(100_000);
  });

  it("sin índice devuelve null y no inventa", () => {
    expect(llevar(100_000, fecha("2019-01-01"), fecha("2026-08-08"), indice)).toBeNull();
    expect(llevar(100_000, fecha("2026-08-08"), fecha("2030-01-01"), indice)).toBeNull();
  });

  it("monto cero sigue siendo cero", () => {
    expect(llevar(0, fecha("2025-08-08"), fecha("2026-08-08"), indice)).toBe(0);
  });

  it("un monto negativo conserva el signo", () => {
    const r = llevar(-100_000, fecha("2025-08-08"), fecha("2026-08-08"), indice)!;
    expect(r).toBeLessThan(0);
  });

  it("el poder de compra de un peso del año pasado", () => {
    expect(poderDeCompra(fecha("2025-08-08"), fecha("2026-08-08"), indice)).toBe(0.7492);
  });

  it("el poder de compra de hoy es uno", () => {
    const hoy = fecha("2026-08-08");
    expect(poderDeCompra(hoy, hoy, indice)).toBe(1);
  });

  it("un aumento menor a la inflación es una pérdida real", () => {
    // Sueldo: 1.000.000 hace un año → 1.250.000 hoy (+25% nominal).
    const v = variacionReal(
      1_000_000, fecha("2025-08-08"),
      1_250_000, fecha("2026-08-08"),
      indice,
    );
    expect(v).toBe(-0.0635);
  });

  it("un aumento mayor a la inflación es ganancia real", () => {
    const v = variacionReal(
      1_000_000, fecha("2025-08-08"),
      1_500_000, fecha("2026-08-08"),
      indice,
    )!;
    expect(v).toBeGreaterThan(0);
  });

  it("sin base no hay variación", () => {
    expect(
      variacionReal(0, fecha("2025-08-08"), 1_000_000, fecha("2026-08-08"), indice),
    ).toBeNull();
  });

  it("la clave del índice es el día local, sin correrse por la hora", () => {
    // En UTC, un gasto de las 22 h caería al día siguiente y usaría otro valor.
    for (const hora of [0, 6, 12, 18, 23]) {
      const d = new Date(2026, 7, 7, hora, 30);
      expect(clave(d)).toBe("2026-08-07");
    }
  });
});
