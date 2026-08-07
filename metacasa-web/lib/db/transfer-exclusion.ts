import type { Client } from "@/lib/supabase/types";
import { TX_TYPE } from "@/lib/constants";
import { applyTxFilters, type TxFilters } from "@/lib/db/transactions";

/**
 * La regla de exclusión de transferencias, en UN solo lugar.
 *
 * ─── LA REGLA ──────────────────────────────────────────────────────────────
 * Una transferencia entre cuentas propias se guarda como DOS transacciones que
 * comparten `transfer_group_id`: un GASTO en la cuenta origen y un INGRESO en la
 * destino. Las dos piernas son el mecanismo que mueve bien los saldos por cuenta.
 * Pero la plata **nunca salió del hogar**, así que agregarle una transferencia a
 * un conjunto de movimientos no puede cambiar ningún total de ingreso ni de gasto.
 *
 * ─── POR QUÉ VIVE ACÁ ──────────────────────────────────────────────────────
 * La regla ya estaba implementada en las consultas SQL del data-layer
 * (`.is("transfer_group_id", null)`) y otra vez, a mano, en el pie de la pantalla
 * de Movimientos. Lo que quedaba afuera era todo lo que **suma sobre un
 * `Transaction[]` ya traído**: el Excel exportado sumaba las dos piernas y le
 * mostraba al usuario $8.150.000 de ingresos donde la pantalla decía $7.650.000,
 * y el asistente hacía lo mismo sobre las 20 filas de una página.
 *
 * Si escribís algo que suma, promedia o cuenta dinero de movimientos, usá alguna
 * de estas funciones. No vuelvas a escribir el filtro a mano: una regla
 * implementada dos veces diverge siempre (ver `lib/db/date-range.ts`).
 */

/** Ingresos y gastos agregados, en la moneda base del hogar. */
export interface MoneyTotals {
  income: number;
  expense: number;
}

/**
 * Una fila con `transfer_group_id` es UNA PIERNA de una transferencia entre
 * cuentas propias, no plata que entró ni salió del hogar.
 */
export function isTransferLeg(tx: { transfer_group_id?: string | null }): boolean {
  return tx.transfer_group_id != null;
}

/**
 * Saca las piernas de transferencia de un conjunto YA TRAÍDO.
 *
 * Para cuando lo que sigue **agrega** (un resumen, un reporte, un promedio). Si
 * lo que sigue es LISTAR, no la uses: el usuario tiene que poder ver que movió
 * plata entre sus cuentas.
 */
export function excludeTransferLegs<T extends { transfer_group_id?: string | null }>(
  rows: T[],
): T[] {
  return rows.filter((row) => !isTransferLeg(row));
}

/**
 * Ingresos/gastos de un conjunto de movimientos YA TRAÍDO, salteando las piernas
 * de transferencia. Los montos se guardan como magnitud positiva (el signo lo da
 * `type`), pero tomamos el valor absoluto igual: un `amount` negativo cargado por
 * error no puede restarle a la columna equivocada.
 */
export function totalsExcludingTransfers(
  rows: Array<{
    amount: number | string | null;
    type: string | null;
    transfer_group_id?: string | null;
  }>,
): MoneyTotals {
  let income = 0;
  let expense = 0;
  for (const tx of rows) {
    if (isTransferLeg(tx)) continue;
    const amount = Math.abs(Number(tx.amount));
    if (!Number.isFinite(amount)) continue;
    if (tx.type === TX_TYPE.INCOME) income += amount;
    else if (tx.type === TX_TYPE.EXPENSE) expense += amount;
    // Otros tipos futuros no se cuentan como ingreso ni gasto.
  }
  return { income, expense };
}

/**
 * Ingresos/gastos del filtro **completo**, agregando en Postgres.
 *
 * Es el par de `listTransactions`: misma forma de filtros (`applyTxFilters`, una
 * sola implementación) pero sin `limit`/`offset`, porque un total no puede salir
 * de una página. Trae sólo `amount, type` para mantenerlo liviano.
 *
 * Lo usan el pie de la pantalla de Movimientos y la tool `query_transactions` del
 * asistente: cuando el usuario pregunta "¿cuánto gasté en julio?", la respuesta
 * tiene que cubrir los 86 movimientos del mes, no los 20 que entraron en la
 * página.
 */
export async function getFilteredTotals(supabase: Client, f: TxFilters): Promise<MoneyTotals> {
  const q = applyTxFilters(
    supabase
      .from("transactions")
      .select("amount, type")
      .eq("household_id", f.householdId)
      // Este es un AGREGADO: las transferencias no cuentan. La LISTA que muestra
      // la misma pantalla sí las trae — son movimientos reales del usuario.
      .is("transfer_group_id", null),
    f,
  );

  const { data, error } = await q;
  if (error) throw error;

  return totalsExcludingTransfers(data ?? []);
}
