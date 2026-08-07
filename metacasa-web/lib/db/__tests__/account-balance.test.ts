import { describe, expect, it } from "vitest";
import { saldoDeCuenta, type MovimientoParaSaldo } from "@/lib/db/account-balance";
import type { FXRateMap } from "@/lib/fx";

/**
 * El saldo de una cuenta no puede mezclar monedas.
 *
 * `starting_balance` está en la moneda de la cuenta y `transactions.amount` en
 * la moneda base del hogar. Sumarlos directo hacía que una caja de ahorro en
 * USD dentro de un hogar en ARS mostrara el saldo multiplicado por la
 * cotización — y el dashboard lo volvía a convertir, elevándolo al cuadrado.
 */

const TASAS: FXRateMap = { USD: { rate: 1000 } as FXRateMap[string] };

function ingreso(amount: number, original: number, moneda: string): MovimientoParaSaldo {
  return { type: "INGRESO", amount, amount_original: original, currency_original: moneda };
}
function gasto(amount: number, original: number, moneda: string): MovimientoParaSaldo {
  return { type: "GASTO", amount, amount_original: original, currency_original: moneda };
}

describe("cuenta en la misma moneda que el hogar", () => {
  it("suma y resta como siempre", () => {
    const r = saldoDeCuenta(
      100_000,
      "ARS",
      "ARS",
      [ingreso(50_000, 50_000, "ARS"), gasto(20_000, 20_000, "ARS")],
      {},
    );
    expect(r.balance).toBe(130_000);
    expect(r.aproximado).toBe(false);
  });

  it("no necesita tasas", () => {
    const r = saldoDeCuenta(0, "ARS", "ARS", [ingreso(1_000, 1_000, "ARS")], {});
    expect(r.aproximado).toBe(false);
  });
});

describe("cuenta en moneda distinta a la base", () => {
  /// El caso exacto que estaba roto: caja de ahorro en USD, hogar en ARS,
  /// saldo inicial US$1.000 y un ingreso de US$500 cargado a tasa 1000.
  /// `amount` (base) = 500.000 → el viejo cálculo daba US$ 501.000.
  it("un ingreso en la moneda de la cuenta suma su monto original", () => {
    const r = saldoDeCuenta(1_000, "USD", "ARS", [ingreso(500_000, 500, "USD")], TASAS);
    expect(r.balance).toBe(1_500);
    expect(r.balance).not.toBe(501_000);
  });

  it("un gasto en la moneda de la cuenta resta su monto original", () => {
    const r = saldoDeCuenta(1_000, "USD", "ARS", [gasto(200_000, 200, "USD")], TASAS);
    expect(r.balance).toBe(800);
  });

  /// Cargar un gasto en pesos contra una cuenta en dólares: hay que traerlo a
  /// la moneda de la cuenta antes de restarlo.
  it("un movimiento en otra moneda se convierte a la de la cuenta", () => {
    const r = saldoDeCuenta(1_000, "USD", "ARS", [gasto(100_000, 100_000, "ARS")], TASAS);
    expect(r.balance).toBe(900); // 100.000 ARS / 1000 = US$100
    expect(r.aproximado).toBe(false);
  });

  /// Descartar el movimiento dejaría el saldo mal sin que nada lo indique.
  it("sin tasa suma crudo pero marca el saldo como aproximado", () => {
    const r = saldoDeCuenta(1_000, "USD", "ARS", [gasto(100_000, 100_000, "ARS")], {});
    expect(r.aproximado).toBe(true);
  });
});

describe("datos incompletos", () => {
  it("sin amount_original cae al monto en base", () => {
    const r = saldoDeCuenta(
      0,
      "ARS",
      "ARS",
      [{ type: "INGRESO", amount: 5_000, amount_original: null, currency_original: null }],
      {},
    );
    expect(r.balance).toBe(5_000);
  });

  it("los montos que llegan como string de numeric se suman igual", () => {
    const r = saldoDeCuenta(
      0,
      "ARS",
      "ARS",
      [{ type: "INGRESO", amount: "7650000", amount_original: "7650000", currency_original: "ARS" }],
      {},
    );
    expect(r.balance).toBe(7_650_000);
  });

  it("sin movimientos el saldo es el inicial", () => {
    expect(saldoDeCuenta(845_000, "ARS", "ARS", [], {}).balance).toBe(845_000);
  });
});
