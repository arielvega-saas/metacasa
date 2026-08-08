import { describe, expect, it } from "vitest";
import { variacionReal, type Indice } from "@/lib/reexpresion";
import { lectorDeIndice, claveDeDia, type SerieCER } from "@/lib/cer";

/**
 * El caso real de la pantalla de reportes: comparar el gasto de un mes contra
 * el anterior descontando la inflación.
 *
 * Con 33,5% interanual —y ~2,5% mensual— "gastaste 2% más que el mes pasado"
 * es en realidad haber gastado MENOS. Ese es el número que cambia la decisión
 * del usuario, y el que ninguna app global muestra.
 */

/** Serie sintética que sube 2,5% en un mes, como la inflación real de 2026. */
function serieMensual(): SerieCER {
  const s: SerieCER = {};
  const base = new Date(2026, 5, 1); // 1 de junio
  for (let i = 0; i < 90; i++) {
    const d = new Date(base);
    d.setDate(base.getDate() + i);
    // ~2,5% mensual compuesto diario.
    s[claveDeDia(d)] = 100 * Math.pow(1.025, i / 30);
  }
  return s;
}

const indice: Indice = lectorDeIndice(serieMensual());

describe("variación real del gasto mes contra mes", () => {
  const mesAnterior = new Date(2026, 5, 15); // 15 de junio
  const mesActual = new Date(2026, 6, 15); // 15 de julio

  it("gastar 2% más con 2,5% de inflación es gastar menos en términos reales", () => {
    const v = variacionReal(100_000, mesAnterior, 102_000, mesActual, indice)!;
    expect(v).toBeLessThan(0);
  });

  it("gastar lo mismo en pesos es gastar menos en términos reales", () => {
    const v = variacionReal(100_000, mesAnterior, 100_000, mesActual, indice)!;
    expect(v).toBeLessThan(0);
    expect(Math.round(v * 1000) / 1000).toBeCloseTo(-0.024, 2);
  });

  it("gastar 10% más sí es un aumento real", () => {
    const v = variacionReal(100_000, mesAnterior, 110_000, mesActual, indice)!;
    expect(v).toBeGreaterThan(0);
    // Pero menor que el 10% nominal: la inflación se comió una parte.
    expect(v).toBeLessThan(0.1);
  });

  it("sin gasto el mes anterior no se inventa una comparación", () => {
    expect(variacionReal(0, mesAnterior, 100_000, mesActual, indice)).toBeNull();
  });

  it("sin índice para esas fechas devuelve null y la pantalla no muestra nada", () => {
    const vacio = lectorDeIndice({});
    expect(variacionReal(100_000, mesAnterior, 102_000, mesActual, vacio)).toBeNull();
  });
});
