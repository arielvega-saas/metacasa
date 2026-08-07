import { type FXRateMap } from "@/lib/fx";

/**
 * El saldo de una cuenta, en LA MONEDA DE ESA CUENTA.
 *
 * ─── EL PROBLEMA ───────────────────────────────────────────────────────────
 * `accounts.starting_balance` se guarda en la moneda de la cuenta (el diálogo
 * de alta muestra el símbolo de la cuenta al lado del campo), pero
 * `transactions.amount` está en la moneda BASE del hogar. Sumar los dos era
 * sumar dólares con pesos.
 *
 * Con una caja de ahorro en USD dentro de un hogar en ARS, saldo inicial
 * US$1.000 y un ingreso de US$500 a tasa 1000:
 *
 *   amount (base ARS) = 500.000
 *   balance = 1.000 + 500.000 = 501.000   → la pantalla mostraba **US$ 501.000**
 *
 * cuando el saldo real es US$1.500. Y el dashboard lo empeoraba: volvía a
 * convertir ese número *desde* USD, dando $501.000.000.
 *
 * ─── LA REGLA ──────────────────────────────────────────────────────────────
 * El saldo se expresa en la moneda de la cuenta, que es lo que la UI ya asume
 * al pintarlo (`account.currency`) y lo que el usuario espera: el saldo de una
 * cuenta en dólares se lee en dólares.
 *
 * Para cada movimiento imputado a la cuenta se toma el monto **en la moneda de
 * la cuenta**:
 *
 *  1. `currency_original === account.currency` → `amount_original` tal cual.
 *     Es el caso normal y no necesita ninguna tasa.
 *  2. Si difiere → se convierte desde la moneda base usando la tasa del hogar.
 *  3. Si falta esa tasa → se usa `amount` crudo y se marca el saldo como
 *     aproximado. Descartar el movimiento sería peor: el saldo quedaría mal sin
 *     que nada lo indique.
 *
 * Vive en su propio archivo, y no dentro de `listAccountsWithBalance`, porque
 * la misma definición existe en iOS (`AccountBalanceService.currentBalance`) y
 * en el RPC `account_balances`. Las tres tienen que dar el mismo número.
 */

/** Lo mínimo de un movimiento para calcular saldo. */
export interface MovimientoParaSaldo {
  type: string;
  amount: number | string;
  amount_original: number | string | null;
  currency_original: string | null;
}

export interface SaldoCalculado {
  /** Saldo en la moneda de la cuenta. */
  balance: number;
  /** `true` si algún movimiento no se pudo convertir y se sumó crudo. */
  aproximado: boolean;
}

/**
 * @param startingBalance en la moneda de la cuenta
 * @param accountCurrency moneda de la cuenta
 * @param baseCurrency moneda base del hogar (en la que está `amount`)
 * @param rates tasas del hogar (moneda → tasa hacia base)
 */
export function saldoDeCuenta(
  startingBalance: number,
  accountCurrency: string,
  baseCurrency: string,
  movimientos: MovimientoParaSaldo[],
  rates: FXRateMap,
): SaldoCalculado {
  const cuenta = (accountCurrency || baseCurrency || "").toUpperCase();
  const base = (baseCurrency || "").toUpperCase();
  let delta = 0;
  let aproximado = false;

  for (const mov of movimientos) {
    // Paridad con iOS: GASTO resta, todo lo demás suma.
    const signo = mov.type === "GASTO" ? -1 : 1;
    const original = (mov.currency_original || base).toUpperCase();

    let monto: number;
    if (original === cuenta && mov.amount_original != null) {
      monto = Number(mov.amount_original);
    } else {
      const enBase = Number(mov.amount);
      if (cuenta === base) {
        monto = enBase;
      } else {
        // `amount` está en base; la tasa va de la moneda de la cuenta HACIA
        // base, así que para ir de base a la cuenta se divide.
        const tasa = rates[cuenta]?.rate;
        if (Number.isFinite(tasa) && (tasa as number) !== 0) {
          monto = enBase / (tasa as number);
        } else {
          monto = enBase;
          aproximado = true;
        }
      }
    }

    if (Number.isFinite(monto)) delta += signo * monto;
  }

  return { balance: Number(startingBalance) + delta, aproximado };
}
