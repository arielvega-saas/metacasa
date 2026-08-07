import { describe, expect, it, vi } from "vitest";
import { dispatchTool, type ToolContext } from "@/lib/ai/dispatch";
import type { Client } from "@/lib/supabase/types";

/**
 * El dispatcher del asistente escribe movimientos reales a partir de texto que
 * emite un modelo. Dos cosas tienen que ser ciertas pase lo que pase:
 *
 * 1. **El scope no se negocia.** El hogar y el usuario salen de la sesión. Si el
 *    modelo manda un `householdId` —porque alucinó, o porque alguien le inyectó
 *    una instrucción en una nota de un movimiento— tiene que ignorarse. Sin
 *    esto, un prompt injection escribe en el hogar de otro.
 * 2. **La fecha es el día del usuario.** El server corre en UTC: si "hoy" se
 *    calculara con su reloj, todo lo cargado después de las 21 en Argentina
 *    quedaría fechado mañana. Es la misma clase de bug que ya se arregló dos
 *    veces en este repo (el decoder de iOS y `parseDayLocal` en la web).
 */

const CTX: ToolContext = {
  householdId: "11111111-1111-4111-8111-111111111111",
  userId: "22222222-2222-4222-8222-222222222222",
  currency: "ARS",
  today: "2026-08-05",
};

const CUENTA_DEFAULT = "44444444-4444-4444-8444-444444444444";

/**
 * Supabase mockeado. Devuelve una cuenta activa para que `defaultAccountId`
 * tenga a quién imputar; `getCategories` se conforma con la misma forma.
 */
function clienteFalso(cuentas: Array<{ id: string }> = [{ id: CUENTA_DEFAULT }]): Client {
  return {
    from: (tabla: string) => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            order: () =>
              Promise.resolve({ data: tabla === "accounts" ? cuentas : [], error: null }),
          }),
          order: () => Promise.resolve({ data: [], error: null }),
          maybeSingle: () => Promise.resolve({ data: null, error: null }),
        }),
      }),
    }),
  } as unknown as Client;
}

/** Espía sobre `createTransaction` para leer el payload que se manda a la base. */
async function capturarAlta(
  input: Record<string, unknown>,
  ctx: ToolContext = CTX,
  cliente: Client = clienteFalso(),
) {
  const capturado: Record<string, unknown>[] = [];
  vi.doMock("@/lib/db/transactions", async (orig) => ({
    ...(await orig<Record<string, unknown>>()),
    createTransaction: async (_c: unknown, payload: Record<string, unknown>) => {
      capturado.push(payload);
      return { id: "33333333-3333-4333-8333-333333333333" };
    },
  }));
  vi.resetModules();
  const { dispatchTool: dispatchAislado } = await import("@/lib/ai/dispatch");
  const outcome = await dispatchAislado(cliente, "add_transaction", input, ctx);
  vi.doUnmock("@/lib/db/transactions");
  return { payload: capturado[0], outcome };
}

describe("scope: el modelo no elige hogar ni usuario", () => {
  it("ignora el householdId que mande el modelo", async () => {
    const { payload } = await capturarAlta({
      type: "GASTO",
      amount: 12500,
      category: "Alimentación",
      householdId: "99999999-9999-4999-8999-999999999999",
      household_id: "99999999-9999-4999-8999-999999999999",
      userId: "99999999-9999-4999-8999-999999999999",
    });
    expect(payload.householdId).toBe(CTX.householdId);
    expect(payload.userId).toBe(CTX.userId);
  });
});

describe("fecha: el día del usuario, no el UTC del server", () => {
  it("usa ctx.today cuando el modelo no manda fecha", async () => {
    const { payload } = await capturarAlta({
      type: "GASTO",
      amount: 5000,
      category: "Alimentación",
    });
    expect(payload.date).toBe("2026-08-05");
  });

  /// El caso real: 21:30 del 5 de agosto en Argentina ya es el 6 en UTC.
  /// Con el reloj del server el gasto se iba a mañana.
  it("un gasto cargado de noche queda en el día del usuario", async () => {
    const { payload } = await capturarAlta(
      { type: "GASTO", amount: 5000, category: "Alimentación" },
      { ...CTX, today: "2026-08-05" },
    );
    expect(payload.date).toBe("2026-08-05");
    expect(payload.date).not.toBe("2026-08-06");
  });

  it("respeta la fecha explícita si es válida", async () => {
    const { payload } = await capturarAlta({
      type: "GASTO",
      amount: 5000,
      category: "Alimentación",
      date: "2026-07-31",
    });
    expect(payload.date).toBe("2026-07-31");
  });

  it("rechaza una fecha que no existe en vez de inventarla", async () => {
    const { outcome } = await capturarAlta({
      type: "GASTO",
      amount: 5000,
      category: "Alimentación",
      date: "2026-02-31",
    });
    expect(outcome.isError).toBe(true);
    expect(outcome.mutated).toBeFalsy();
  });
});

describe("validación del input del modelo", () => {
  const casos: Array<[string, Record<string, unknown>]> = [
    ["monto negativo", { type: "GASTO", amount: -100, category: "Alimentación" }],
    ["monto cero", { type: "GASTO", amount: 0, category: "Alimentación" }],
    ["monto no numérico", { type: "GASTO", amount: "mucho", category: "Alimentación" }],
    ["sin categoría", { type: "GASTO", amount: 100 }],
    ["tipo inválido", { type: "TRANSFERENCIA", amount: 100, category: "Alimentación" }],
    ["input vacío", {}],
  ];

  it.each(casos)("no escribe nada con %s", async (_nombre, input) => {
    const { outcome, payload } = await capturarAlta(input);
    expect(outcome.isError).toBe(true);
    expect(outcome.mutated).toBeFalsy();
    expect(payload).toBeUndefined();
  });

  it("acepta los sinónimos en inglés que emite el modelo", async () => {
    const { payload } = await capturarAlta({
      type: "EXPENSE",
      amount: "12500",
      category: "Alimentación",
    });
    expect(payload.type).toBe("GASTO");
    expect(payload.amount).toBe(12500);
  });
});

/**
 * Un movimiento sin `account_id` no mueve ningún saldo: queda "del hogar" y las
 * cuentas siguen mostrando el número viejo. El asistente cargaba todo así, así
 * que lo que registrabas por chat no aparecía en ninguna cuenta. iOS ya imputa
 * a la cuenta por defecto (`AIToolHandler`); esto es la paridad.
 */
describe("cuenta: el movimiento tiene que mover un saldo", () => {
  it("imputa a la cuenta por defecto del hogar", async () => {
    const { payload } = await capturarAlta({
      type: "GASTO",
      amount: 12500,
      category: "Alimentación",
    });
    expect(payload.accountId).toBe(CUENTA_DEFAULT);
  });

  it("si el hogar todavía no tiene cuentas, guarda sin imputar en vez de fallar", async () => {
    const { payload, outcome } = await capturarAlta(
      { type: "GASTO", amount: 12500, category: "Alimentación" },
      CTX,
      clienteFalso([]),
    );
    expect(payload.accountId).toBeNull();
    expect(outcome.isError).toBeFalsy();
  });
});

describe("tools desconocidas", () => {
  it("devuelve error sin tumbar el turno", async () => {
    const r = await dispatchTool(clienteFalso(), "drop_database", {}, CTX);
    expect(r.isError).toBe(true);
    expect(r.mutated).toBeFalsy();
  });
});
