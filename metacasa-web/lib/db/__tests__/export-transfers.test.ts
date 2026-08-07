import ExcelJS from "exceljs";
import { describe, expect, it } from "vitest";
import { buildTransactionsWorkbook } from "@/app/api/export/_lib/excel";
import type { ExportContext } from "@/app/api/export/_lib/shared";
import { excludeTransferLegs } from "@/lib/db/transfer-exclusion";
import type { Transaction } from "@/lib/db/transactions";
import { TX_TYPE } from "@/lib/constants";

/**
 * El Excel exportado tiene que decir **lo mismo que la pantalla**: es literalmente la exportación
 * de la vista de Movimientos, con sus mismos filtros (`buildExportHref` en `transaction-list.tsx`).
 *
 * El bug real, con los números del hogar de prueba: $7.650.000 de ingresos, $2.000.000 de gastos y
 * UNA transferencia de $500.000 entre cuentas propias. La pantalla mostraba 7.650.000 / 2.000.000 y
 * 74% de tasa de ahorro; el archivo descargado decía 8.150.000 / 2.500.000 y 69%, porque sumaba las
 * dos piernas de la transferencia. Cuando el número que el usuario baja para hacer sus cuentas
 * contradice al de la app, la app perdió.
 */

/** `t()` de prueba: devuelve la clave, así se puede ubicar cada fila por su label. */
const t = (key: string) => key;

const CTX = {
  t,
  locale: "es",
  currency: "ARS",
  household: { id: "hogar-1", name: "Casa" },
  supabase: null,
} as unknown as ExportContext;

const CUENTAS = new Map([
  ["caja-ahorro", "Caja de ahorro"],
  ["cuenta-corriente", "Cuenta corriente"],
]);

function tx(p: Partial<Transaction> & Pick<Transaction, "id" | "type" | "amount">): Transaction {
  return {
    date: "2026-07-15T12:00:00.000Z",
    category: "Varios",
    account_id: "caja-ahorro",
    note: null,
    transfer_group_id: null,
    ...p,
  } as Transaction;
}

/**
 * El mes de prueba: sueldo + gasto + las DOS piernas de una transferencia de $500.000 de la caja de
 * ahorro a la cuenta corriente.
 */
const MOVIMIENTOS: Transaction[] = [
  tx({ id: "1", type: TX_TYPE.INCOME, amount: 7_650_000, category: "Sueldo" }),
  tx({ id: "2", type: TX_TYPE.EXPENSE, amount: 2_000_000, category: "Alimentación" }),
  tx({
    id: "3",
    type: TX_TYPE.EXPENSE,
    amount: 500_000,
    category: "Transferencia",
    account_id: "caja-ahorro",
    transfer_group_id: "grupo-1",
  }),
  tx({
    id: "4",
    type: TX_TYPE.INCOME,
    amount: 500_000,
    category: "Transferencia",
    account_id: "cuenta-corriente",
    transfer_group_id: "grupo-1",
  }),
];

/** Abre el buffer generado y devuelve la hoja pedida. */
async function abrir(buffer: Buffer, hoja: string) {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(buffer as unknown as ArrayBuffer);
  const ws = wb.getWorksheet(hoja);
  expect(ws, `falta la hoja ${hoja}`).toBeDefined();
  return ws!;
}

/** Valor de la fila del Resumen cuyo label es `label`. */
function valorDe(ws: ExcelJS.Worksheet, label: string): number {
  let valor: number | undefined;
  ws.eachRow((row) => {
    if (row.getCell(1).value === label) valor = Number(row.getCell(2).value);
  });
  expect(valor, `no se encontró la fila '${label}' en el Resumen`).toBeDefined();
  return valor as number;
}

describe("Excel de Movimientos: los totales no cuentan las transferencias", () => {
  it("el Resumen coincide con el de la pantalla", async () => {
    const buffer = await buildTransactionsWorkbook(CTX, MOVIMIENTOS, CUENTAS);
    const ws = await abrir(buffer, "exportTools.sheet.summary");

    // Los mismos números que muestran las tarjetas de la pantalla.
    expect(valorDe(ws, "exportTools.summary.income")).toBe(7_650_000);
    // El gasto va negativo en la planilla (convención de hoja de cálculo).
    expect(valorDe(ws, "exportTools.summary.expense")).toBe(-2_000_000);
    expect(valorDe(ws, "exportTools.summary.balance")).toBe(5_650_000);
  });

  /// 74% es lo que dice la app. Sumando las dos piernas daba 69%: la transferencia le mentía al
  /// usuario sobre cuánto ahorró.
  it("la tasa de ahorro es la de la pantalla (74%), no la inflada (69%)", async () => {
    const buffer = await buildTransactionsWorkbook(CTX, MOVIMIENTOS, CUENTAS);
    const ws = await abrir(buffer, "exportTools.sheet.summary");

    const rate = valorDe(ws, "exportTools.summary.savingsRate");
    expect(Math.round(rate * 100)).toBe(74);
    expect(Math.round(rate * 100)).not.toBe(69);
  });

  it("una transferencia no mueve ningún total", async () => {
    const conTransferencia = await buildTransactionsWorkbook(CTX, MOVIMIENTOS, CUENTAS);
    const sinTransferencia = await buildTransactionsWorkbook(
      CTX,
      MOVIMIENTOS.filter((m) => !m.transfer_group_id),
      CUENTAS,
    );

    const a = await abrir(conTransferencia, "exportTools.sheet.summary");
    const b = await abrir(sinTransferencia, "exportTools.sheet.summary");
    for (const label of [
      "exportTools.summary.income",
      "exportTools.summary.expense",
      "exportTools.summary.balance",
      "exportTools.summary.savingsRate",
    ]) {
      expect(valorDe(a, label), `'${label}' cambia al agregar una transferencia`).toBe(
        valorDe(b, label),
      );
    }
  });

  /// La contracara: excluirlas del total no es excluirlas del archivo. El usuario tiene que poder
  /// ver que movió plata entre sus cuentas, igual que la ve en la lista de la pantalla.
  it("las transferencias SÍ se listan en la hoja de movimientos", async () => {
    const buffer = await buildTransactionsWorkbook(CTX, MOVIMIENTOS, CUENTAS);
    const ws = await abrir(buffer, "exportTools.sheet.transactions");

    // Encabezado + 4 movimientos + fila de balance.
    expect(ws.rowCount).toBe(MOVIMIENTOS.length + 2);

    const categorias: unknown[] = [];
    ws.eachRow((row, i) => {
      if (i > 1) categorias.push(row.getCell(3).value);
    });
    expect(categorias.filter((c) => c === "Transferencia")).toHaveLength(2);
  });

  it("la fila de balance del pie tampoco cuenta la transferencia", async () => {
    const buffer = await buildTransactionsWorkbook(CTX, MOVIMIENTOS, CUENTAS);
    const ws = await abrir(buffer, "exportTools.sheet.transactions");

    const ultima = ws.getRow(ws.rowCount);
    expect(ultima.getCell(4).value).toBe("exportTools.summary.balance");
    expect(Number(ultima.getCell(5).value)).toBe(5_650_000);
  });
});

/**
 * El reporte mensual (PDF/xlsx) arma sus KPIs con `getMonthSummary` y `getCategoryBreakdown`, que
 * excluyen las transferencias, pero listaba los movimientos con `listTransactions`, que no. La
 * tabla no cerraba contra sus propios KPIs ni contra `summary.count`.
 */
describe("reporte mensual: la tabla cierra contra sus KPIs", () => {
  it("no lista las piernas de transferencia", () => {
    const listadas = excludeTransferLegs(MOVIMIENTOS);
    expect(listadas.map((m) => m.id)).toEqual(["1", "2"]);
    expect(listadas.some((m) => m.transfer_group_id)).toBe(false);
  });

  it("la cantidad listada coincide con el count del resumen", () => {
    // `getMonthSummary` cuenta sólo las filas sin `transfer_group_id`.
    const countDelResumen = MOVIMIENTOS.filter((m) => !m.transfer_group_id).length;
    expect(excludeTransferLegs(MOVIMIENTOS)).toHaveLength(countDelResumen);
  });
});
