import { describe, expect, it } from "vitest";
import { bulkUpdateTransactions } from "@/lib/db/transactions";

/**
 * Cliente Supabase falso, encadenable y awaitable.
 *
 * `transferIds` son las filas que el SELECT va a reportar como transferencias.
 * `updates` acumula lo que el UPDATE intentó escribir, que es lo que se afirma:
 * la garantía a proteger es que las piernas de una transferencia NUNCA lleguen
 * al UPDATE.
 */
function fakeClient(transferIds: string[]) {
  const updates: Array<{ fields: Record<string, unknown>; ids: string[] }> = [];

  function builder(mode: "select" | "update", fields: Record<string, unknown> = {}) {
    const state: { ids: string[] } = { ids: [] };
    const chain = {
      select: () => chain,
      in: (_col: string, ids: string[]) => {
        state.ids = ids;
        return chain;
      },
      eq: () => chain,
      not: () => chain,
      // Lo que hace awaitable a la cadena: `await supabase.from(...)...` resuelve acá.
      then: (resolve: (v: { data: unknown; error: null }) => unknown) => {
        if (mode === "select") {
          const encontradas = state.ids
            .filter((id) => transferIds.includes(id))
            .map((id) => ({ id }));
          return Promise.resolve(resolve({ data: encontradas, error: null }));
        }
        updates.push({ fields, ids: state.ids });
        return Promise.resolve(
          resolve({ data: state.ids.map((id) => ({ id })), error: null }),
        );
      },
    };
    return chain;
  }

  const client = {
    from: () => ({
      select: () => builder("select"),
      update: (fields: Record<string, unknown>) => builder("update", fields),
    }),
  };

  return { client: client as never, updates };
}

const HOGAR = "hogar-1";

describe("bulkUpdateTransactions", () => {
  it("actualiza las filas comunes", async () => {
    const { client, updates } = fakeClient([]);
    const r = await bulkUpdateTransactions(client, ["a", "b", "c"], HOGAR, {
      category: "Alimentación",
    });

    expect(r).toEqual({ updated: 3, skippedTransfers: 0 });
    expect(updates).toHaveLength(1);
    expect(updates[0].ids).toEqual(["a", "b", "c"]);
    expect(updates[0].fields).toEqual({ category: "Alimentación" });
  });

  it("NUNCA manda al UPDATE una pierna de transferencia", async () => {
    const { client, updates } = fakeClient(["b"]);
    const r = await bulkUpdateTransactions(client, ["a", "b", "c"], HOGAR, {
      category: "Alimentación",
    });

    expect(r).toEqual({ updated: 2, skippedTransfers: 1 });
    expect(updates[0].ids).toEqual(["a", "c"]);
    expect(updates[0].ids).not.toContain("b");
  });

  it("si TODAS son transferencias no escribe nada", async () => {
    const { client, updates } = fakeClient(["a", "b"]);
    const r = await bulkUpdateTransactions(client, ["a", "b"], HOGAR, {
      category: "Ocio",
    });

    expect(r).toEqual({ updated: 0, skippedTransfers: 2 });
    expect(updates).toHaveLength(0);
  });

  it("mover a cuenta escribe account_id y nada más", async () => {
    const { client, updates } = fakeClient([]);
    await bulkUpdateTransactions(client, ["a"], HOGAR, { account_id: "cuenta-9" });

    expect(updates[0].fields).toEqual({ account_id: "cuenta-9" });
  });

  it("account_id null deja el movimiento sin cuenta", async () => {
    const { client, updates } = fakeClient([]);
    await bulkUpdateTransactions(client, ["a"], HOGAR, { account_id: null });

    expect(updates[0].fields).toEqual({ account_id: null });
  });

  it("corta temprano sin ids o sin campos", async () => {
    const { client, updates } = fakeClient([]);

    expect(await bulkUpdateTransactions(client, [], HOGAR, { category: "X" })).toEqual({
      updated: 0,
      skippedTransfers: 0,
    });
    expect(await bulkUpdateTransactions(client, ["a"], HOGAR, {})).toEqual({
      updated: 0,
      skippedTransfers: 0,
    });
    expect(updates).toHaveLength(0);
  });

  it("parte en lotes sin perder filas", async () => {
    const ids = Array.from({ length: 25 }, (_, i) => `id-${i}`);
    const { client, updates } = fakeClient([]);

    const r = await bulkUpdateTransactions(client, ids, HOGAR, { category: "Varios" }, 10);

    expect(r.updated).toBe(25);
    expect(updates.map((u) => u.ids.length)).toEqual([10, 10, 5]);
    expect(updates.flatMap((u) => u.ids)).toEqual(ids);
  });
});
