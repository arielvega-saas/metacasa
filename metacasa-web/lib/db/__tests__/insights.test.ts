import { describe, expect, it } from "vitest";
import {
  insightCopy,
  normalizeSpendingInsights,
  type SpendingInsight,
} from "@/lib/db/insights";

/** Helper: fila cruda tal como la devuelve el RPC `spending_insights`. */
function row(over: Record<string, unknown> = {}) {
  return {
    category: "Delivery",
    actual: 45000,
    promedio: 18000,
    delta_pct: 150,
    direccion: "subio",
    ...over,
  } as never;
}

describe("normalizeSpendingInsights", () => {
  it("mapea la fila del RPC a camelCase", () => {
    const [i] = normalizeSpendingInsights([row()]);
    expect(i).toEqual<SpendingInsight>({
      category: "Delivery",
      actual: 45000,
      average: 18000,
      deltaPct: 150,
      direction: "subio",
    });
  });

  it("acepta numeric serializado como string (PostgREST)", () => {
    const [i] = normalizeSpendingInsights([
      row({ actual: "45000.50", promedio: "18000.25", delta_pct: "150.4" }),
    ]);
    expect(i.actual).toBeCloseTo(45000.5);
    expect(i.average).toBeCloseTo(18000.25);
    expect(i.deltaPct).toBeCloseTo(150.4);
  });

  it("devuelve [] con null/undefined/lista vacía (0 insights es lo normal)", () => {
    expect(normalizeSpendingInsights(null)).toEqual([]);
    expect(normalizeSpendingInsights(undefined)).toEqual([]);
    expect(normalizeSpendingInsights([])).toEqual([]);
  });

  it("descarta filas sin categoría utilizable", () => {
    const out = normalizeSpendingInsights([
      row({ category: null }),
      row({ category: "   " }),
      row({ category: "Nafta" }),
    ]);
    expect(out).toHaveLength(1);
    expect(out[0].category).toBe("Nafta");
  });

  it("normaliza deltaPct a positivo: el signo lo lleva `direction`", () => {
    const [i] = normalizeSpendingInsights([
      row({ delta_pct: -38, direccion: "bajo" }),
    ]);
    expect(i.deltaPct).toBe(38);
    expect(i.direction).toBe("bajo");
  });

  it("tolera `direccion` con mayúsculas o espacios", () => {
    const [i] = normalizeSpendingInsights([row({ direccion: " BAJO " })]);
    expect(i.direction).toBe("bajo");
  });

  it("si `direccion` es desconocida la deduce del signo del delta", () => {
    expect(
      normalizeSpendingInsights([row({ direccion: "???", delta_pct: -30 })])[0]
        .direction,
    ).toBe("bajo");
    expect(
      normalizeSpendingInsights([row({ direccion: null, delta_pct: 30 })])[0]
        .direction,
    ).toBe("subio");
  });

  it("no rompe con numéricos basura: caen a 0", () => {
    const [i] = normalizeSpendingInsights([
      row({ actual: "no-es-un-numero", promedio: null, delta_pct: null }),
    ]);
    expect(i.actual).toBe(0);
    expect(i.average).toBe(0);
    expect(i.deltaPct).toBe(0);
  });
});

describe("insightCopy", () => {
  const base: SpendingInsight = {
    category: "Delivery",
    actual: 45000,
    average: 18000,
    deltaPct: 150,
    direction: "subio",
  };

  it("un aumento arma la frase 'más' y pide ATENCIÓN (no 'rojo')", () => {
    const copy = insightCopy(base);
    expect(copy.key).toBe("dashboard.insightUp");
    expect(copy.vars).toEqual({ pct: 150, category: "Delivery" });
    expect(copy.tone).toBe("attention");
  });

  it("una baja arma la frase 'menos' y es POSITIVA", () => {
    const copy = insightCopy({
      ...base,
      category: "Supermercado",
      deltaPct: 38.4,
      direction: "bajo",
    });
    expect(copy.key).toBe("dashboard.insightDown");
    expect(copy.vars).toEqual({ pct: 38, category: "Supermercado" });
    expect(copy.tone).toBe("positive");
  });

  it("redondea el % a entero", () => {
    expect(insightCopy({ ...base, deltaPct: 27.6 }).vars.pct).toBe(28);
    expect(insightCopy({ ...base, deltaPct: 27.4 }).vars.pct).toBe(27);
  });

  it("nunca produce la frase absurda 'gastaste 0% más'", () => {
    expect(insightCopy({ ...base, deltaPct: 0 }).vars.pct).toBe(1);
    expect(insightCopy({ ...base, deltaPct: 0.2 }).vars.pct).toBe(1);
  });

  it("conserva la categoría tal cual para interpolarla", () => {
    expect(insightCopy({ ...base, category: "Salidas & ocio" }).vars.category).toBe(
      "Salidas & ocio",
    );
  });
});
