import { describe, it, expect } from "vitest";
import {
  buildMercadoPagoAuthUrl,
  counterpartIdsToResolve,
  counterpartIdOf,
  dedupeByExternalId,
  describePayment,
  isIncoming,
  mapMercadoPagoPayments,
  mpPaymentsSearchPath,
  mpPublicName,
  selectNewMovements,
  DEFAULT_MP_LABELS,
  type MpPayment,
  type WalletMovementDraft,
} from "@/lib/wallets/mercadopago";

/** id de la cuenta conectada en los fixtures. */
const ME = "123456";

function payment(over: Partial<MpPayment> = {}): MpPayment {
  return {
    id: "1",
    date_created: "2026-03-12T10:00:00.000Z",
    transaction_amount: 1500,
    currency_id: "ARS",
    status: "approved",
    collector: { id: ME },
    payer: { id: "999" },
    ...over,
  };
}

describe("buildMercadoPagoAuthUrl", () => {
  it("arma la URL de autorización con todos los parámetros obligatorios", () => {
    const url = new URL(
      buildMercadoPagoAuthUrl({
        clientId: "2693470312497962",
        redirectUri: "https://usehomefinance.com/wallets/callback",
        state: "abc123",
      }),
    );
    expect(url.origin + url.pathname).toBe(
      "https://auth.mercadopago.com.ar/authorization",
    );
    expect(url.searchParams.get("client_id")).toBe("2693470312497962");
    expect(url.searchParams.get("response_type")).toBe("code");
    expect(url.searchParams.get("platform_id")).toBe("mp");
    expect(url.searchParams.get("redirect_uri")).toBe(
      "https://usehomefinance.com/wallets/callback",
    );
    expect(url.searchParams.get("state")).toBe("abc123");
  });

  it("nunca genera una URL sin `state` (protección CSRF obligatoria)", () => {
    expect(() =>
      buildMercadoPagoAuthUrl({
        clientId: "x",
        redirectUri: "https://x.com/cb",
        state: "",
      }),
    ).toThrow(/state/);
  });

  it("exige client_id y redirect_uri", () => {
    expect(() =>
      buildMercadoPagoAuthUrl({ clientId: "", redirectUri: "u", state: "s" }),
    ).toThrow(/client_id/);
    expect(() =>
      buildMercadoPagoAuthUrl({ clientId: "c", redirectUri: "", state: "s" }),
    ).toThrow(/redirect_uri/);
  });
});

describe("mpPaymentsSearchPath", () => {
  it("acota el limit a un rango sano", () => {
    expect(mpPaymentsSearchPath(50)).toContain("limit=50");
    expect(mpPaymentsSearchPath(0)).toContain("limit=50");
    expect(mpPaymentsSearchPath(9999)).toContain("limit=200");
  });
});

describe("dirección del movimiento", () => {
  it("es INGRESO cuando la cuenta conectada es el cobrador", () => {
    expect(isIncoming(payment({ collector: { id: ME } }), ME)).toBe(true);
  });

  it("es GASTO cuando cobra otro", () => {
    expect(isIncoming(payment({ collector: { id: "777" } }), ME)).toBe(false);
  });

  it("soporta el campo legacy `collector_id`", () => {
    const p = payment({ collector: null, collector_id: ME });
    expect(isIncoming(p, ME)).toBe(true);
  });

  it("sin identidad de la cuenta asume GASTO (igual que la PWA)", () => {
    expect(isIncoming(payment(), null)).toBe(false);
  });

  it("la contraparte es el otro lado del pago", () => {
    expect(counterpartIdOf(payment({ payer: { id: "999" } }), ME)).toBe("999");
    expect(
      counterpartIdOf(
        payment({ collector: { id: "777" }, payer: { id: ME } }),
        ME,
      ),
    ).toBe("777");
  });

  it("no hay contraparte si somos los dos lados", () => {
    expect(
      counterpartIdOf(payment({ collector: { id: ME }, payer: { id: ME } }), ME),
    ).toBeNull();
  });
});

describe("describePayment", () => {
  it("prefiere la descripción real de MP", () => {
    const p = payment({ description: "Supermercado Coto" });
    expect(describePayment(p, ME)).toBe("Supermercado Coto");
  });

  it("cae a statement_descriptor si no hay description", () => {
    const p = payment({ description: null, statement_descriptor: "MERPAGO*UBER" });
    expect(describePayment(p, ME)).toBe("MERPAGO*UBER");
  });

  it('trata "Varios" como descripción inútil', () => {
    const p = payment({ description: "Varios", payer: { id: "999" } });
    const names = new Map([["999", "Ana Pérez"]]);
    expect(describePayment(p, ME, names)).toBe("Transferencia de Ana Pérez");
  });

  it("nombra la contraparte en transferencias entrantes y salientes", () => {
    const names = new Map([["999", "Ana Pérez"]]);
    const incoming = payment({ description: null, payer: { id: "999" } });
    expect(describePayment(incoming, ME, names)).toBe(
      "Transferencia de Ana Pérez",
    );

    const outgoing = payment({
      description: null,
      collector: { id: "999" },
      payer: { id: ME },
    });
    expect(describePayment(outgoing, ME, names)).toBe("Transferencia a Ana Pérez");
  });

  it("sin nombre resuelto usa el genérico según la dirección", () => {
    const incoming = payment({ description: null, payer: { id: "999" } });
    expect(describePayment(incoming, ME)).toBe("Transferencia recibida");

    const outgoing = payment({
      description: null,
      collector: { id: "999" },
      payer: { id: ME },
    });
    expect(describePayment(outgoing, ME)).toBe("Transferencia enviada");
  });

  it("usa el operation_type cuando no hay contraparte", () => {
    const p = payment({
      description: null,
      operation_type: "account_fund",
      payer: { id: ME },
      collector: { id: ME },
    });
    expect(describePayment(p, ME)).toBe("Depósito bancario");
  });

  it("acepta etiquetas traducidas", () => {
    const p = payment({ description: null, payer: { id: "999" } });
    const en = {
      ...DEFAULT_MP_LABELS,
      transferFrom: "Transfer from {name}",
      transferReceived: "Transfer received",
    };
    expect(describePayment(p, ME, new Map(), en)).toBe("Transfer received");
    expect(
      describePayment(p, ME, new Map([["999", "Ana"]]), en),
    ).toBe("Transfer from Ana");
  });

  it("nunca deja la descripción vacía", () => {
    const p = payment({
      description: null,
      statement_descriptor: null,
      operation_type: null,
      payer: { id: ME },
      collector: { id: ME },
    });
    expect(describePayment(p, ME)).toBe("Movimiento MP");
  });
});

describe("counterpartIdsToResolve", () => {
  it("sólo pide nombres para los pagos SIN descripción propia", () => {
    const payments = [
      payment({ id: "1", description: "Coto", payer: { id: "111" } }),
      payment({ id: "2", description: null, payer: { id: "222" } }),
      payment({ id: "3", description: "Varios", payer: { id: "333" } }),
    ];
    expect(counterpartIdsToResolve(payments, ME)).toEqual(["222", "333"]);
  });

  it("deduplica y respeta el tope de fan-out", () => {
    const payments = Array.from({ length: 30 }, (_, i) =>
      payment({ id: String(i), description: null, payer: { id: String(i) } }),
    );
    expect(counterpartIdsToResolve(payments, ME, 5)).toHaveLength(5);

    const repeated = [
      payment({ id: "1", description: null, payer: { id: "999" } }),
      payment({ id: "2", description: null, payer: { id: "999" } }),
    ];
    expect(counterpartIdsToResolve(repeated, ME)).toEqual(["999"]);
  });
});

describe("mpPublicName", () => {
  it("prefiere nombre + apellido, luego nickname", () => {
    expect(mpPublicName({ first_name: "Ana", last_name: "Pérez" })).toBe(
      "Ana Pérez",
    );
    expect(
      mpPublicName({ first_name: null, last_name: null, nickname: "ANAP123" }),
    ).toBe("ANAP123");
    expect(mpPublicName({})).toBeNull();
  });
});

describe("mapMercadoPagoPayments", () => {
  it("mapea el modelo de MP al nuestro", () => {
    const [m] = mapMercadoPagoPayments(
      [
        payment({
          id: 987654321,
          description: "Sueldo marzo",
          transaction_amount: 250000.5,
          currency_id: "ars",
          status: "approved",
          operation_type: "money_transfer",
          payment_method_id: "account_money",
          payer: { id: "999" },
        }),
      ],
      ME,
    );
    expect(m).toEqual<WalletMovementDraft>({
      externalId: "987654321",
      date: "2026-03-12T10:00:00.000Z",
      amount: 250000.5,
      type: "INGRESO",
      description: "Sueldo marzo",
      currency: "ARS",
      status: "approved",
      counterpartId: "999",
      operationType: "money_transfer",
      paymentMethodId: "account_money",
    });
  });

  it("guarda el monto como magnitud positiva y el signo va en `type`", () => {
    const [gasto] = mapMercadoPagoPayments(
      [
        payment({
          transaction_amount: -3200,
          collector: { id: "777" },
          payer: { id: ME },
          description: "Uber",
        }),
      ],
      ME,
    );
    expect(gasto.amount).toBe(3200);
    expect(gasto.type).toBe("GASTO");
  });

  it("descarta pagos sin id (no se pueden deduplicar)", () => {
    const out = mapMercadoPagoPayments(
      [payment({ id: null }), payment({ id: "ok" })],
      ME,
    );
    expect(out.map((m) => m.externalId)).toEqual(["ok"]);
  });

  it("cae a ARS cuando MP no manda moneda", () => {
    const [m] = mapMercadoPagoPayments([payment({ currency_id: null })], ME);
    expect(m.currency).toBe("ARS");
  });

  it("tolera una respuesta vacía", () => {
    expect(mapMercadoPagoPayments([], ME)).toEqual([]);
  });
});

describe("dedupe por external_id", () => {
  const draft = (externalId: string, amount = 100): WalletMovementDraft => ({
    externalId,
    date: "2026-03-12T10:00:00.000Z",
    amount,
    type: "GASTO",
    description: "x",
    currency: "ARS",
    status: "approved",
    counterpartId: null,
    operationType: null,
    paymentMethodId: null,
  });

  it("dentro del mismo lote conserva la primera aparición", () => {
    const out = dedupeByExternalId([
      draft("a", 1),
      draft("b", 2),
      draft("a", 3),
    ]);
    expect(out.map((d) => d.externalId)).toEqual(["a", "b"]);
    expect(out[0].amount).toBe(1);
  });

  it("descarta lo que ya está persistido para esa wallet", () => {
    const out = selectNewMovements(
      [draft("a"), draft("b"), draft("c")],
      new Set(["b"]),
    );
    expect(out.map((d) => d.externalId)).toEqual(["a", "c"]);
  });

  it("un re-sync sin novedades no genera inserts", () => {
    const batch = [draft("a"), draft("b")];
    expect(selectNewMovements(batch, new Set(["a", "b"]))).toEqual([]);
  });

  it("combina ambos dedupes (lote repetido + histórico)", () => {
    const out = selectNewMovements(
      [draft("a"), draft("a"), draft("b"), draft("c"), draft("c")],
      new Set(["b"]),
    );
    expect(out.map((d) => d.externalId)).toEqual(["a", "c"]);
  });
});
