import { describe, it, expect } from "vitest";
import { computeHealthScore, computeStreak, utcDayKey } from "@/lib/health";

/** Set de días activos a partir de claves "YYYY-MM-DD". */
function days(...keys: string[]): Set<string> {
  return new Set(keys);
}

/** N días consecutivos hacia atrás desde `from` (incluido). */
function consecutive(from: string, n: number): Set<string> {
  const out = new Set<string>();
  const cursor = new Date(`${from}T00:00:00.000Z`);
  for (let i = 0; i < n; i++) {
    out.add(utcDayKey(cursor));
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return out;
}

describe("computeHealthScore", () => {
  it("queda siempre dentro de 0–100", () => {
    const cases: [number, number, number][] = [
      [0, 0, 0],
      [1_000_000, 1, 30],
      [1, 1_000_000, 30],
      [-500, 200, 10],
      [1000, 500, 90],
    ];
    for (const [income, expense, n] of cases) {
      const score = computeHealthScore(income, expense, consecutive("2026-07-27", n));
      expect(score).toBeGreaterThanOrEqual(0);
      expect(score).toBeLessThanOrEqual(100);
      expect(Number.isInteger(score)).toBe(true);
    }
  });

  it("sin ingresos sólo puntúa la consistencia (máx. 20)", () => {
    // 10 días activos → 10 × 0.67 = 6.7 → 7.
    expect(computeHealthScore(0, 500, consecutive("2026-07-27", 10))).toBe(7);
    // Sin ingresos y sin movimientos → 0.
    expect(computeHealthScore(0, 0, days())).toBe(0);
    // Aun con 30 días activos, el techo sin ingresos es 20.
    expect(computeHealthScore(0, 999, consecutive("2026-07-27", 30))).toBe(20);
  });

  it("gastar más de lo que entra anula ahorro y ratio (pero no resta)", () => {
    // rate = max(0, negativo) = 0 · ratio = 1.5 (no < 1) → sólo consistencia.
    expect(computeHealthScore(1000, 1500, consecutive("2026-07-27", 5))).toBe(3);
    expect(computeHealthScore(1000, 1500, days())).toBe(0);
  });

  it("gastar exactamente lo que entra da 0 en los bloques de ingreso", () => {
    expect(computeHealthScore(1000, 1000, days())).toBe(0);
  });

  it("ahorrar la mitad da 50 (tasa) + 15 (ratio)", () => {
    expect(computeHealthScore(1000, 500, days())).toBe(65);
  });

  it("un mes perfecto con 30 días activos llega a 100", () => {
    expect(computeHealthScore(1000, 0, consecutive("2026-07-27", 30))).toBe(100);
  });

  it("una tasa de ahorro del 20% ya topea los 50 puntos de ahorro", () => {
    // rate 0.2 × 250 = 50 (tope) + (1 − 0.8) × 30 = 6 → 56.
    expect(computeHealthScore(1000, 800, days())).toBe(56);
  });

  it("no depende del orden ni del contenido de las claves de días", () => {
    const a = computeHealthScore(1000, 500, days("2026-01-01", "2020-05-09"));
    const b = computeHealthScore(1000, 500, days("2020-05-09", "2026-01-01"));
    expect(a).toBe(b);
  });
});

describe("computeStreak", () => {
  const now = new Date("2026-07-27T15:30:00.000Z");

  it("cuenta los días consecutivos hacia atrás desde hoy", () => {
    expect(computeStreak(consecutive("2026-07-27", 4), now)).toBe(4);
  });

  it("es 0 si hoy no tuvo movimientos, aunque ayer sí", () => {
    expect(computeStreak(days("2026-07-26", "2026-07-25"), now)).toBe(0);
  });

  it("es 0 con un set vacío", () => {
    expect(computeStreak(days(), now)).toBe(0);
  });

  it("se corta en el primer día sin movimiento", () => {
    // 27, 26, (falta 25), 24 → racha de 2.
    expect(computeStreak(days("2026-07-27", "2026-07-26", "2026-07-24"), now)).toBe(2);
  });

  it("cruza el borde de mes sin romperse", () => {
    const june = new Date("2026-07-01T10:00:00.000Z");
    expect(
      computeStreak(days("2026-07-01", "2026-06-30", "2026-06-29"), june),
    ).toBe(3);
  });

  it("no muta la fecha que recibe", () => {
    const snapshot = now.getTime();
    computeStreak(consecutive("2026-07-27", 3), now);
    expect(now.getTime()).toBe(snapshot);
  });

  it("ignora la hora del día (normaliza a medianoche UTC)", () => {
    const early = new Date("2026-07-27T00:00:01.000Z");
    const late = new Date("2026-07-27T23:59:59.000Z");
    const set = consecutive("2026-07-27", 2);
    expect(computeStreak(set, early)).toBe(computeStreak(set, late));
  });
});
