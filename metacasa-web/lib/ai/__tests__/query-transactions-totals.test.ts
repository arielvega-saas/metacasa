import { describe, expect, it } from "vitest";
import { dispatchTool, type ToolContext } from "@/lib/ai/dispatch";
import { formatMoney } from "@/lib/money";
import { TX_TYPE } from "@/lib/constants";
import type { Client } from "@/lib/supabase/types";

/**
 * Cuando el usuario le pregunta al asistente "¿cuánto gasté en julio?", la respuesta tiene que
 * cubrir **todo el filtro**, no la página.
 *
 * `query_transactions` trae como mucho 20 filas (tope 50) para que el modelo pueda citar
 * movimientos concretos con su id. Los totales se sumaban sobre ESAS filas: con 86 movimientos en
 * el mes, el asistente respondía el total de los primeros 20 con total aplomo. Y encima contaba las
 * transferencias entre cuentas propias, que no son ni ingreso ni gasto del hogar.
 *
 * Ahora los totales salen de un agregado sobre el filtro completo (`getFilteredTotals`), con los
 * mismos filtros que la lista y sin las piernas de transferencia.
 */

const CTX: ToolContext = {
  householdId: "11111111-1111-4111-8111-111111111111",
  userId: "22222222-2222-4222-8222-222222222222",
  currency: "ARS",
  today: "2026-08-05",
};

/** El mes real: 86 movimientos, $7.650.000 de ingresos y $2.000.000 de gastos (sin transferencias). */
const TOTAL_MOVIMIENTOS = 86;
const INGRESOS_DEL_MES = 7_650_000;
const GASTOS_DEL_MES = 2_000_000;

/** Lo que entra en la página: 20 filas que suman una fracción del mes. */
const GASTO_POR_FILA = 17_000;
const PAGINA = Array.from({ length: 20 }, (_, i) => ({
  id: `id-${i}`,
  date: "2026-07-15T12:00:00.000Z",
  type: TX_TYPE.EXPENSE,
  amount: GASTO_POR_FILA,
  category: "Alimentación",
  note: null,
  transfer_group_id: null,
}));
const GASTOS_DE_LA_PAGINA = GASTO_POR_FILA * PAGINA.length; // $340.000

interface ConsultaRegistrada {
  select: string;
  filtros: Array<{ op: string; columna: string; valor: unknown }>;
}

/**
 * Cliente Supabase falso, encadenable y awaitable. Distingue las dos consultas por su `select`:
 * la lista pide `*` (con count) y el agregado pide `amount, type`. Registra los filtros de cada una
 * para poder afirmar que miran el mismo conjunto.
 */
function clienteFalso() {
  const consultas: ConsultaRegistrada[] = [];

  function cadena(select: string) {
    const registro: ConsultaRegistrada = { select, filtros: [] };
    consultas.push(registro);
    const anotar = (op: string) => (columna: string, valor: unknown) => {
      registro.filtros.push({ op, columna, valor });
      return chain;
    };
    const chain = {
      eq: anotar("eq"),
      gte: anotar("gte"),
      lte: anotar("lte"),
      ilike: anotar("ilike"),
      is: anotar("is"),
      order: () => chain,
      range: () => chain,
      then: (resolve: (v: { data: unknown; count?: number; error: null }) => unknown) => {
        const esLaLista = select.startsWith("*");
        return Promise.resolve(
          resolve(
            esLaLista
              ? { data: PAGINA, count: TOTAL_MOVIMIENTOS, error: null }
              : {
                  // El agregado vuelve del server ya sin las piernas de transferencia.
                  data: [
                    { amount: INGRESOS_DEL_MES, type: TX_TYPE.INCOME },
                    { amount: GASTOS_DEL_MES, type: TX_TYPE.EXPENSE },
                  ],
                  error: null,
                },
          ),
        );
      },
    };
    return chain;
  }

  const client = { from: () => ({ select: (select: string) => cadena(select) }) };
  return { client: client as unknown as Client, consultas };
}

/** Corre la tool con el filtro "julio 2026". */
async function preguntarPorJulio(input: Record<string, unknown> = {}) {
  const { client, consultas } = clienteFalso();
  const outcome = await dispatchTool(
    client,
    "query_transactions",
    { dateFrom: "2026-07-01", dateTo: "2026-07-31", ...input },
    CTX,
  );
  return { outcome, consultas };
}

const lista = (c: ConsultaRegistrada[]) => c.find((q) => q.select.startsWith("*"))!;
const agregado = (c: ConsultaRegistrada[]) => c.find((q) => !q.select.startsWith("*"))!;

describe("query_transactions: los totales cubren el filtro, no la página", () => {
  it("responde el gasto de los 86 movimientos, no el de las 20 filas listadas", async () => {
    const { outcome } = await preguntarPorJulio();

    expect(outcome.content).toContain(formatMoney(GASTOS_DEL_MES, CTX.currency));
    expect(
      outcome.content,
      "el total salió de las filas de la página: con 86 movimientos, el asistente le contesta " +
        "al usuario el total de los primeros 20",
    ).not.toContain(formatMoney(GASTOS_DE_LA_PAGINA, CTX.currency));
  });

  it("responde el ingreso del filtro completo", async () => {
    const { outcome } = await preguntarPorJulio();
    // La página no trae NINGÚN ingreso: sumándola, el asistente diría que el mes no tuvo ingresos.
    expect(outcome.content).toContain(formatMoney(INGRESOS_DEL_MES, CTX.currency));
  });

  it("le dice al modelo que los totales son del filtro entero", async () => {
    const { outcome } = await preguntarPorJulio();
    expect(outcome.content).toMatch(/FULL filter/);
    expect(outcome.content).toMatch(/Showing 20 of 86/);
  });

  it("sigue listando las filas con su id, para poder editarlas después", async () => {
    const { outcome } = await preguntarPorJulio();
    expect(outcome.content).toContain("id=id-0");
    expect(outcome.content.split("\n").filter((l) => l.startsWith("- "))).toHaveLength(20);
  });
});

describe("query_transactions: el agregado y la lista miran el mismo conjunto", () => {
  it("el agregado excluye las piernas de transferencia y la lista NO", async () => {
    const { consultas } = await preguntarPorJulio();

    expect(
      agregado(consultas).filtros,
      "un total que incluye transferencias infla ingresos Y gastos con plata que no se movió",
    ).toContainEqual({ op: "is", columna: "transfer_group_id", valor: null });

    expect(
      lista(consultas).filtros.some((f) => f.columna === "transfer_group_id"),
      "la lista tiene que seguir mostrando las transferencias: son movimientos reales del usuario",
    ).toBe(false);
  });

  it("aplica los mismos filtros de fecha a las dos consultas", async () => {
    const { consultas } = await preguntarPorJulio();
    const fechas = (q: ConsultaRegistrada) =>
      q.filtros.filter((f) => f.columna === "date").map((f) => `${f.op}:${f.valor}`);

    expect(fechas(agregado(consultas))).toEqual(fechas(lista(consultas)));
  });

  /// La cota superior se compensa UNA sola vez, en `listTransactions`/`applyTxFilters` vía
  /// `inclusiveDateEnd`. Si el agregado la volviera a compensar por su cuenta, el total incluiría
  /// un día que la lista no muestra.
  it("la cota del último día se aplica una sola vez", async () => {
    const { consultas } = await preguntarPorJulio();
    const cota = agregado(consultas).filtros.find((f) => f.op === "lte" && f.columna === "date");

    expect(cota?.valor).toBe("2026-07-31T23:59:59.999Z");
  });

  it("el resto de los filtros del modelo también llega al agregado", async () => {
    const { consultas } = await preguntarPorJulio({
      type: "GASTO",
      category: "Alimentación",
      noteContains: "super",
      amountMin: 1000,
    });
    const agg = agregado(consultas).filtros;

    expect(agg).toContainEqual({ op: "eq", columna: "type", valor: TX_TYPE.EXPENSE });
    expect(agg).toContainEqual({ op: "eq", columna: "category", valor: "Alimentación" });
    expect(agg).toContainEqual({ op: "ilike", columna: "note", valor: "%super%" });
    expect(agg).toContainEqual({ op: "gte", columna: "amount", valor: 1000 });
  });

  it("el hogar del agregado sale de la sesión, nunca del modelo", async () => {
    const { consultas } = await preguntarPorJulio({
      householdId: "99999999-9999-4999-8999-999999999999",
      household_id: "99999999-9999-4999-8999-999999999999",
    });

    expect(agregado(consultas).filtros).toContainEqual({
      op: "eq",
      columna: "household_id",
      valor: CTX.householdId,
    });
  });
});
