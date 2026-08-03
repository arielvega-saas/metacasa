import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * Vigila que toda consulta que AGREGA dinero excluya las piernas de transferencia.
 *
 * Una transferencia entre cuentas propias se guarda como DOS transacciones que comparten
 * `transfer_group_id`: un GASTO en origen y un INGRESO en destino. Es lo que mueve bien los saldos
 * por cuenta. Pero la plata nunca salió del hogar, así que **agregarle una transferencia a un
 * conjunto de movimientos no puede cambiar ningún total de ingreso, gasto o categoría**.
 *
 * Sin el filtro, mover $500.000 de la caja de ahorro a la cuenta corriente sumaba $500.000 a los
 * ingresos Y $500.000 a los gastos del mes, e inflaba "Transferencia" en el donut de categorías.
 *
 * Este test es un lint sobre el código fuente y no sobre el resultado a propósito. Un test de
 * comportamiento cubre las 9 consultas que existen hoy; el problema real es **la número 10**, la
 * que alguien agregue el mes que viene sin saber que la regla existe. Ésa la caza esto.
 *
 * Si agregás una consulta nueva a `transactions`:
 *  - ¿suma, promedia o cuenta movimientos? → agregale `.is("transfer_group_id", null)`
 *  - ¿es un saldo por cuenta, la lista, o una mutación? → agregala a `SIN_FILTRO` con el motivo.
 */

const RAIZ = join(__dirname, "..", "..", "..");

/** Consultas que NO deben filtrar, con el motivo. La lista es la parte importante del test. */
const SIN_FILTRO: Record<string, string> = {
  listTransactions:
    "es la lista: el usuario tiene que VER sus transferencias, no que desaparezcan",
  listAccountsWithBalance:
    "saldos por cuenta: acá las dos piernas son el mecanismo. Filtrarlas rompería el saldo, " +
    "que es peor que el bug original",
  createTransaction: "mutación",
  updateTransaction: "mutación",
  deleteTransaction: "mutación",
  bulkCreateTransactions: "mutación",
};

function archivosTS(dir: string): string[] {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    if (n === "node_modules" || n === ".next" || n === "__tests__") return [];
    if (statSync(p).isDirectory()) return archivosTS(p);
    return /\.tsx?$/.test(n) ? [p] : [];
  });
}

/** Cada `.from("transactions")` con la función que lo contiene y si filtra. */
function consultas() {
  const encontradas: { archivo: string; linea: number; fn: string; filtra: boolean }[] = [];
  for (const archivo of [...archivosTS(join(RAIZ, "lib")), ...archivosTS(join(RAIZ, "app"))]) {
    const lineas = readFileSync(archivo, "utf8").split("\n");
    lineas.forEach((l, i) => {
      if (!l.includes('.from("transactions")')) return;
      let fn = "<desconocida>";
      for (let j = i; j >= Math.max(0, i - 60); j--) {
        const m = lineas[j].match(/(?:export )?(?:async )?function (\w+)|const (\w+) = async/);
        if (m) {
          fn = m[1] ?? m[2];
          break;
        }
      }
      // El filtro va dentro de las ~20 líneas de la cadena de la consulta.
      const bloque = lineas.slice(i, i + 20).join("\n");
      encontradas.push({
        archivo: archivo.replace(RAIZ + "/", ""),
        linea: i + 1,
        fn,
        filtra: bloque.includes('"transfer_group_id"'),
      });
    });
  }
  return encontradas;
}

describe("exclusión de transferencias en los agregados", () => {
  it("encuentra las consultas a transactions", () => {
    // Si esto baja a 0, el detector se rompió (cambió el estilo de comillas, se movió el código)
    // y el resto del test estaría pasando en vacío.
    expect(consultas().length).toBeGreaterThanOrEqual(9);
  });

  it("toda consulta que agrega dinero excluye las piernas de transferencia", () => {
    const infractoras = consultas()
      .filter((c) => !c.filtra && !(c.fn in SIN_FILTRO))
      .map((c) => `${c.archivo}:${c.linea} (${c.fn})`);

    expect(
      infractoras,
      infractoras.length
        ? `Estas consultas suman transacciones sin excluir las transferencias, así que una ` +
          `transferencia entre cuentas propias les infla el total:\n  ${infractoras.join("\n  ")}\n\n` +
          `Agregales .is("transfer_group_id", null), o sumalas a SIN_FILTRO con el motivo.`
        : undefined,
    ).toEqual([]);
  });

  it("las excepciones declaradas siguen existiendo", () => {
    // Una excepción que sobrevive a la función que la justificaba es una trampa: el día que
    // alguien reusa ese nombre, hereda un permiso que nadie le dio.
    const nombres = new Set(consultas().map((c) => c.fn));
    for (const fn of Object.keys(SIN_FILTRO)) {
      expect(nombres.has(fn), `SIN_FILTRO menciona '${fn}', que ya no consulta transactions`).toBe(
        true,
      );
    }
  });

  it("los saldos por cuenta NO filtran", () => {
    const saldos = consultas().find((c) => c.fn === "listAccountsWithBalance");
    expect(saldos, "listAccountsWithBalance debería seguir consultando transactions").toBeDefined();
    expect(
      saldos?.filtra,
      "si los saldos filtran las transferencias, mover plata entre cuentas propias deja " +
        "las dos cuentas mal: la de origen no baja y la de destino no sube",
    ).toBe(false);
  });
});
