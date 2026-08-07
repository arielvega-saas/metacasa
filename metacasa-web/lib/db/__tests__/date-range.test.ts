import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { inclusiveDateEnd } from "@/lib/db/date-range";

/**
 * El último día de un rango de fechas tiene que entrar.
 *
 * `transactions.date` es `timestamptz` pero guarda un día de calendario, y
 * `toStableDate` lo escribe al mediodía UTC. Un `.lte("date", "2026-08-01")`
 * compara contra la medianoche, que es ANTERIOR, así que el día entero se cae
 * del resultado.
 *
 * Medido contra la base de producción antes del fix: "hasta 2026-08-01"
 * devolvía 60 movimientos de 86. Faltaban las 26 de ese día, sueldo incluido.
 */
describe("inclusiveDateEnd", () => {
  it("extiende una fecha-sólo al final del día", () => {
    expect(inclusiveDateEnd("2026-08-01")).toBe("2026-08-01T23:59:59.999Z");
  });

  /// El caso real: la cota tiene que quedar DESPUÉS del mediodía UTC en que se
  /// guardan las transacciones, o el día no entra.
  it("la cota queda después del mediodía UTC en que se guardan las tx", () => {
    const cota = Date.parse(inclusiveDateEnd("2026-08-01"));
    const txDeEseDia = Date.parse("2026-08-01T12:00:00.000Z");
    expect(cota).toBeGreaterThan(txDeEseDia);
  });

  it("no toca una cota que ya trae hora explícita", () => {
    expect(inclusiveDateEnd("2026-08-01T09:30:00Z")).toBe("2026-08-01T09:30:00Z");
  });

  it("no se pasa al día siguiente", () => {
    const cota = Date.parse(inclusiveDateEnd("2026-08-01"));
    expect(cota).toBeLessThan(Date.parse("2026-08-02T00:00:00.000Z"));
  });
});

/**
 * Lint sobre el fuente: la regla vale para toda consulta con cota superior de
 * fecha, no sólo para las tres que existen hoy.
 *
 * Esta corrección ya vivía dentro de `db/budget.ts` y era correcta, pero era
 * privada de ese archivo: la lista de movimientos y su pie de totales repetían
 * el `.lte(...)` crudo y perdían el último día igual. El test de comportamiento
 * de arriba cubre el helper; éste caza la próxima consulta que lo saltee.
 */
describe("ninguna consulta usa una cota superior de fecha cruda", () => {
  const RAIZ = join(__dirname, "..", "..", "..");
  const IGNORAR = new Set(["node_modules", ".next", ".git", "__tests__", "out", "build"]);

  function fuentes(dir: string, acc: string[] = []): string[] {
    for (const nombre of readdirSync(dir)) {
      if (IGNORAR.has(nombre)) continue;
      const ruta = join(dir, nombre);
      if (statSync(ruta).isDirectory()) fuentes(ruta, acc);
      else if (/\.tsx?$/.test(nombre)) acc.push(ruta);
    }
    return acc;
  }

  it("todo .lte sobre 'date' pasa por inclusiveDateEnd", () => {
    const infractores: string[] = [];
    // El archivo que DEFINE el helper habla del `.lte("date", …)` roto en su
    // propia documentación; explicar el bug no es cometerlo.
    const DEFINICION = join("lib", "db", "date-range.ts");
    for (const ruta of fuentes(RAIZ)) {
      if (ruta.endsWith(DEFINICION)) continue;
      const texto = readFileSync(ruta, "utf8");
      for (const [i, linea] of texto.split("\n").entries()) {
        if (!/\.lte\(\s*["']date["']/.test(linea)) continue;
        if (linea.includes("inclusiveDateEnd")) continue;
        infractores.push(`${ruta.slice(RAIZ.length + 1)}:${i + 1} → ${linea.trim()}`);
      }
    }
    expect(infractores, "usá inclusiveDateEnd(...) o el último día se pierde").toEqual([]);
  });
});
