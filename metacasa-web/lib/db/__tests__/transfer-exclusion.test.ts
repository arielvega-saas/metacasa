import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * Vigila que todo lo que AGREGA dinero excluya las piernas de transferencia.
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
 * comportamiento cubre las consultas que existen hoy; el problema real es **la próxima**, la que
 * alguien agregue el mes que viene sin saber que la regla existe. Ésa la caza esto.
 *
 * ─── SON DOS CHEQUEOS, PORQUE HAY DOS FORMAS DE ROMPERLO ────────────────────
 *  (A) Consultando: un `.from("transactions")` que suma sin `.is("transfer_group_id", null)`.
 *  (B) **Sumando en memoria**: traer las filas con `listTransactions` (que legítimamente NO filtra,
 *      porque es "la lista") y agregarlas después. Esto le pasó por al lado al chequeo (A) durante
 *      meses: el Excel exportado mostraba $8.150.000 de ingresos donde la pantalla decía
 *      $7.650.000, y el asistente sumaba las 20 filas de una página como si fueran el mes entero.
 *      Por eso (B) mira también `components/`, que antes ni se escaneaba.
 *
 * Si escribís algo nuevo que suma movimientos:
 *  - usá `lib/db/transfer-exclusion.ts` (o `.is("transfer_group_id", null)` si es SQL);
 *  - si de verdad tenés que contar las dos piernas (un saldo por cuenta, la lista, una mutación),
 *    sumate a la lista de excepciones de acá con el motivo escrito.
 */

const RAIZ = join(__dirname, "..", "..", "..");

/** Directorios de fuente que se escanean. `components/` incluido: ahí también se suma plata. */
const RAICES = ["lib", "app", "components"];

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
  bulkUpdateTransactions:
    "mutación. Igual excluye las transferencias, pero no con este filtro: las resuelve por id en " +
    "un SELECT previo, porque además de no tocarlas necesita CONTARLAS para avisarle al usuario " +
    "cuántas quedaron sin cambios (ver bulk-transactions.test.ts)",
  runUpdateTransaction:
    "tool del asistente IA: lee UNA fila por id antes de mutarla, no agrega dinero. Lejos de " +
    "ignorar las transferencias, trae `transfer_group_id` justamente para RECHAZAR la edición de " +
    "una pierna suelta (editar una sola descuadra los saldos de las dos cuentas)",
  runDeleteTransaction:
    "tool del asistente IA: mismo caso que runUpdateTransaction, pero para el borrado",
};

/** Sumas en memoria que SÍ tienen que contar las dos piernas, con el motivo. */
const SUMA_LAS_DOS_PIERNAS: Record<string, string> = {
  saldoDeCuenta:
    "saldo de UNA cuenta: la pierna de salida tiene que restar en la cuenta origen y la de " +
    "entrada sumar en la destino. Es exactamente para esto que la transferencia son dos filas; " +
    "excluirlas dejaría las dos cuentas mal, que es peor que el bug original",
};

function archivosTS(dir: string): string[] {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    if (n === "node_modules" || n === ".next" || n === "__tests__") return [];
    if (statSync(p).isDirectory()) return archivosTS(p);
    return /\.tsx?$/.test(n) ? [p] : [];
  });
}

/** Todos los archivos de fuente que se escanean, en `lib/`, `app/` y `components/`. */
function fuentes(): string[] {
  return RAICES.flatMap((r) => archivosTS(join(RAIZ, r)));
}

// ── (A) Consultas SQL ───────────────────────────────────────────────────────

/** Cada `.from("transactions")` con la función que lo contiene y si filtra. */
function consultas() {
  const encontradas: { archivo: string; linea: number; fn: string; filtra: boolean }[] = [];
  for (const archivo of fuentes()) {
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

// ── (B) Sumas sobre filas ya traídas ────────────────────────────────────────

/**
 * Una línea que ACUMULA dinero. Cubre las dos formas en que se escribe en este repo: un
 * acumulador con nombre de plata (`income += …`, `expense[idx] += …`, `totalX = xs.reduce(…)`) y
 * cualquier acumulador que sume un monto (`delta += signo * monto`).
 */
const ACUMULA_DINERO: RegExp[] = [
  /(?:income|expense|ingreso|gasto|balance|saldo|total|spent)[\w.[\]]*\s*\+=/i,
  /\+=[^;]*\b(?:amount|monto)\b/i,
  /(?:income|expense|ingreso|gasto|balance|saldo|total|spent)[\w.[\]]*\s*=[^;=]*\.reduce\(/i,
  /\.reduce\([^;]*\b(?:amount|monto)\b/i,
];

/**
 * Marcas de que lo que se está sumando son MOVIMIENTOS y no otra cosa (cuotas, deudas, cuentas,
 * un breakdown ya agregado). Sin esta compuerta el lint gritaría por medio repo.
 */
const SOBRE_MOVIMIENTOS =
  /Transaction\[\]|listTransactions\(|fetchAllTransactions\(|\.from\("transactions"\)|TX_TYPE\.(?:INCOME|EXPENSE)|"(?:INGRESO|GASTO)"/;

/** Marcas de que la función SÍ aplica la regla (por SQL o por el helper compartido). */
const APLICA_LA_REGLA =
  /transfer_group_id|isTransferLeg|excludeTransferLegs|totalsExcludingTransfers|getFilteredTotals/;

/**
 * Declaración de función/arrow **de nivel superior** (sin indentar), para saber en qué función cae
 * cada línea. Sólo las de columna 0: un helper anidado (`const fold = (s) => …`) no abre una
 * función nueva a los ojos de este lint, o partiría el cuerpo justo en el medio y el contexto
 * —de dónde salieron esas filas— se perdería.
 */
const DECLARACION =
  /^(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+(\w+)|^(?:export\s+)?(?:const|let)\s+(\w+)\s*(?::[^=]*)?=\s*(?:async\s*)?\(/;

/** Spans aproximados de cada función del archivo (de su declaración a la siguiente). */
function funciones(lineas: string[]) {
  const decls: { nombre: string; desde: number }[] = [];
  lineas.forEach((l, i) => {
    const m = l.match(DECLARACION);
    if (m) decls.push({ nombre: m[1] ?? m[2], desde: i });
  });
  return decls.map((d, k) => ({
    nombre: d.nombre,
    desde: d.desde,
    hasta: k + 1 < decls.length ? decls[k + 1].desde - 1 : lineas.length - 1,
  }));
}

/** Cada lugar que suma dinero de movimientos, con la función que lo contiene y si excluye. */
function sumasDeMovimientos() {
  const encontradas: { archivo: string; linea: number; fn: string; excluye: boolean }[] = [];
  for (const archivo of fuentes()) {
    const lineas = readFileSync(archivo, "utf8").split("\n");
    const spans = funciones(lineas);

    lineas.forEach((l, i) => {
      const limpia = l.trim();
      // Un ejemplo dentro de un comentario no suma nada.
      if (limpia.startsWith("//") || limpia.startsWith("*") || limpia.startsWith("/*")) return;
      if (!ACUMULA_DINERO.some((re) => re.test(l))) return;

      const span = spans.find((s) => i >= s.desde && i <= s.hasta);
      const cuerpo = span
        ? lineas.slice(span.desde, span.hasta + 1).join("\n")
        : lineas.join("\n");
      if (!SOBRE_MOVIMIENTOS.test(cuerpo)) return; // no son movimientos: no es asunto de este lint

      encontradas.push({
        archivo: archivo.replace(RAIZ + "/", ""),
        linea: i + 1,
        fn: span?.nombre ?? "<nivel superior>",
        excluye: APLICA_LA_REGLA.test(cuerpo),
      });
    });
  }
  return encontradas;
}

// ── Chequeos ────────────────────────────────────────────────────────────────

describe("(A) exclusión de transferencias en las consultas", () => {
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

describe("(B) exclusión de transferencias al sumar filas ya traídas", () => {
  it("encuentra los lugares que suman movimientos", () => {
    // Mismo seguro que arriba: si el detector deja de encontrar sitios, el chequeo pasa en vacío.
    expect(sumasDeMovimientos().length).toBeGreaterThanOrEqual(5);
  });

  it("todo lo que suma movimientos ya traídos excluye las piernas de transferencia", () => {
    const infractoras = sumasDeMovimientos()
      .filter((s) => !s.excluye && !(s.fn in SUMA_LAS_DOS_PIERNAS))
      .map((s) => `${s.archivo}:${s.linea} (${s.fn})`);

    expect(
      infractoras,
      infractoras.length
        ? `Estos lugares suman movimientos YA TRAÍDOS sin sacar las piernas de transferencia. ` +
          `Ojo: traerlos con listTransactions/fetchAllTransactions es correcto (esas funciones ` +
          `no filtran a propósito, porque también alimentan LISTAS) — lo que falta es excluirlas ` +
          `al agregar:\n  ${infractoras.join("\n  ")}\n\n` +
          `Usá totalsExcludingTransfers / excludeTransferLegs / getFilteredTotals de ` +
          `lib/db/transfer-exclusion.ts, o sumalas a SUMA_LAS_DOS_PIERNAS con el motivo.`
        : undefined,
    ).toEqual([]);
  });

  it("las excepciones declaradas siguen existiendo", () => {
    const nombres = new Set(sumasDeMovimientos().map((s) => s.fn));
    for (const fn of Object.keys(SUMA_LAS_DOS_PIERNAS)) {
      expect(
        nombres.has(fn),
        `SUMA_LAS_DOS_PIERNAS menciona '${fn}', que ya no suma movimientos`,
      ).toBe(true);
    }
  });

  it("el saldo de una cuenta sigue contando las dos piernas", () => {
    const saldo = sumasDeMovimientos().find((s) => s.fn === "saldoDeCuenta");
    expect(saldo, "saldoDeCuenta debería seguir sumando movimientos").toBeDefined();
    expect(
      saldo?.excluye,
      "si el saldo de cuenta excluye las transferencias, mover plata entre cuentas propias deja " +
        "las dos cuentas mal: la de origen no baja y la de destino no sube",
    ).toBe(false);
  });
});
