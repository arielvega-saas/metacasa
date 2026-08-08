import { describe, expect, it } from "vitest";
import { claveDeDia, lectorDeIndice, type SerieCER } from "@/lib/cer";

/**
 * El lector del índice. Lo que más se rompe solo es qué valor usar para un día
 * sin dato: el CER se publica los días hábiles, y un gasto de sábado tiene que
 * usar el del viernes —el último publicado—, no interpolar uno que nadie
 * difundió ni quedarse sin valor.
 *
 * Mismo comportamiento que `CERService.Snapshot.valor` en iOS.
 */

const serie: SerieCER = {
  "2026-08-05": 817.91374117394, // miércoles
  "2026-08-06": 818.41049103863,
  "2026-08-07": 818.90754259824, // viernes
  // 08 y 09 son fin de semana: sin dato a propósito.
  "2026-08-10": 819.9,
};

const leer = lectorDeIndice(serie);

function fecha(iso: string): Date {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y, m - 1, d);
}

describe("lector del índice CER", () => {
  it("un día con dato devuelve su valor exacto", () => {
    expect(leer(fecha("2026-08-07"))).toBe(818.90754259824);
  });

  it("un fin de semana usa el último valor publicado", () => {
    expect(leer(fecha("2026-08-08"))).toBe(818.90754259824);
    expect(leer(fecha("2026-08-09"))).toBe(818.90754259824);
  });

  it("antes del inicio de la serie devuelve null en vez de inventar", () => {
    expect(leer(fecha("2026-08-04"))).toBeNull();
    expect(leer(fecha("2019-01-01"))).toBeNull();
  });

  it("después del final usa el último, no null", () => {
    expect(leer(fecha("2026-08-20"))).toBe(819.9);
  });

  it("una serie vacía no rompe: devuelve null", () => {
    expect(lectorDeIndice({})(fecha("2026-08-07"))).toBeNull();
  });

  it("la clave es el día local y no se corre por la hora", () => {
    for (const hora of [0, 6, 12, 18, 23]) {
      expect(claveDeDia(new Date(2026, 7, 7, hora, 30))).toBe("2026-08-07");
    }
  });

  it("la búsqueda binaria acierta sobre una serie larga", () => {
    const larga: SerieCER = {};
    for (let i = 1; i <= 400; i++) {
      const d = new Date(2025, 0, i);
      larga[claveDeDia(d)] = 100 + i;
    }
    const leerLarga = lectorDeIndice(larga);
    expect(leerLarga(new Date(2025, 0, 1))).toBe(101);
    expect(leerLarga(new Date(2025, 0, 250))).toBe(350);
    expect(leerLarga(new Date(2025, 0, 400))).toBe(500);
  });
});
