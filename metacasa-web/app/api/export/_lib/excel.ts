import "server-only";
import ExcelJS from "exceljs";
import type { Transaction } from "@/lib/db/transactions";
import { intlLocale } from "@/lib/i18n/dates";
import { TX_TYPE } from "@/lib/constants";
import { signedAmount, typeLabel, type ExportContext } from "./shared";

/** Paleta Midnight-Sage para el header (apta para impresión: fondo oscuro/letra clara). */
const HEADER_FILL = "FF1B2A24"; // verde-noche
const HEADER_FONT = "FFE8EFE9"; // off-white
const ACCENT_FILL = "FF223A30"; // sage profundo para la fila de totales
const INCOME_FONT = "FF3F8F6E"; // sage
const EXPENSE_FONT = "FFC65B4E"; // coral

/** Formato de número de Excel con signo y 2 decimales (negativos en rojo). */
const MONEY_FMT = "#,##0.00;[Red]-#,##0.00";

/** Aplica estilo de cabecera (negrita, fondo oscuro, centrado) a una fila. */
function styleHeaderRow(row: ExcelJS.Row) {
  row.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: HEADER_FONT }, size: 11 };
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: HEADER_FILL },
    };
    cell.alignment = { vertical: "middle", horizontal: "left" };
    cell.border = { bottom: { style: "thin", color: { argb: "FF324A3D" } } };
  });
  row.height = 22;
}

/**
 * Construye el workbook de Movimientos: hoja "Movimientos" (una fila por tx) +
 * hoja "Resumen" (ingresos/gastos/balance). Encabezados y fechas localizados con
 * el locale activo. El monto va como NÚMERO con signo (GASTO negativo), para que
 * el usuario pueda sumar/filtrar en la planilla.
 */
export async function buildTransactionsWorkbook(
  ctx: ExportContext,
  rows: Transaction[],
  accountNames: Map<string, string>,
): Promise<Buffer> {
  const { t, locale, currency } = ctx;
  const wb = new ExcelJS.Workbook();
  wb.creator = t("exportTools.meta.author");
  wb.created = new Date();

  // Fechas localizadas (texto legible; el orden ya viene desc por fecha).
  const dateFmt = new Intl.DateTimeFormat(intlLocale(locale), {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });

  // ── Hoja Movimientos ──────────────────────────────────────────────────────
  const ws = wb.addWorksheet(t("exportTools.sheet.transactions"), {
    views: [{ state: "frozen", ySplit: 1 }],
  });
  ws.columns = [
    { header: t("exportTools.sheet.colDate"), key: "date", width: 14 },
    { header: t("exportTools.sheet.colType"), key: "type", width: 12 },
    { header: t("exportTools.sheet.colCategory"), key: "category", width: 22 },
    { header: t("exportTools.sheet.colAccount"), key: "account", width: 20 },
    { header: t("exportTools.sheet.colAmount"), key: "amount", width: 16 },
    { header: t("exportTools.sheet.colCurrency"), key: "currency", width: 10 },
    { header: t("exportTools.sheet.colNote"), key: "note", width: 36 },
  ];
  styleHeaderRow(ws.getRow(1));

  let income = 0;
  let expense = 0;
  for (const tx of rows) {
    const signed = signedAmount(tx);
    if (tx.type === TX_TYPE.INCOME) income += Math.abs(Number(tx.amount));
    else if (tx.type === TX_TYPE.EXPENSE) expense += Math.abs(Number(tx.amount));

    const row = ws.addRow({
      date: dateFmt.format(new Date(tx.date)),
      type: typeLabel(tx.type, t),
      category: tx.category || t("exportTools.sheet.noCategory"),
      account: tx.account_id
        ? (accountNames.get(tx.account_id) ?? t("exportTools.sheet.noAccount"))
        : t("exportTools.sheet.noAccount"),
      amount: signed,
      currency: currency.toUpperCase(),
      note: tx.note?.trim() || "",
    });

    const amountCell = row.getCell("amount");
    amountCell.numFmt = MONEY_FMT;
    amountCell.font = {
      color: { argb: tx.type === TX_TYPE.EXPENSE ? EXPENSE_FONT : INCOME_FONT },
    };
  }

  // Fila de totales al pie de Movimientos (balance neto = ingresos − gastos).
  const totalRow = ws.addRow({
    date: "",
    type: "",
    category: "",
    account: t("exportTools.summary.balance"),
    amount: income - expense,
    currency: currency.toUpperCase(),
    note: "",
  });
  totalRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: HEADER_FONT } };
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: ACCENT_FILL },
    };
  });
  totalRow.getCell("amount").numFmt = MONEY_FMT;
  // Autofiltro sobre los encabezados (hasta la última fila de datos, no el total).
  ws.autoFilter = { from: "A1", to: `G${rows.length + 1}` };

  // ── Hoja Resumen ──────────────────────────────────────────────────────────
  addSummarySheet(wb, ctx, { income, expense, count: rows.length });

  const buf = await wb.xlsx.writeBuffer();
  return Buffer.from(buf);
}

/** Resumen del reporte mensual como un único workbook (hoja "Resumen"). */
export async function buildReportSummaryWorkbook(
  ctx: ExportContext,
  summary: { income: number; expense: number; count: number },
  topCategories: { category: string; total: number; pct: number }[],
): Promise<Buffer> {
  const { t } = ctx;
  const wb = new ExcelJS.Workbook();
  wb.creator = t("exportTools.meta.author");
  wb.created = new Date();

  addSummarySheet(wb, ctx, summary);

  // Hoja con el top de categorías del mes.
  const ws = wb.addWorksheet(t("exportTools.sheet.report"), {
    views: [{ state: "frozen", ySplit: 1 }],
  });
  ws.columns = [
    { header: t("exportTools.pdf.topCategoriesName"), key: "category", width: 28 },
    { header: t("exportTools.pdf.topCategoriesAmount"), key: "total", width: 16 },
    { header: t("exportTools.pdf.topCategoriesPct"), key: "pct", width: 8 },
  ];
  styleHeaderRow(ws.getRow(1));
  for (const c of topCategories) {
    const row = ws.addRow({
      category: c.category,
      total: -Math.abs(c.total), // gasto → negativo, consistente con la hoja Movimientos
      pct: c.pct / 100,
    });
    row.getCell("total").numFmt = MONEY_FMT;
    row.getCell("total").font = { color: { argb: EXPENSE_FONT } };
    row.getCell("pct").numFmt = "0%";
  }

  const buf = await wb.xlsx.writeBuffer();
  return Buffer.from(buf);
}

/** Agrega una hoja "Resumen" con ingresos/gastos/balance/tasa de ahorro. */
function addSummarySheet(
  wb: ExcelJS.Workbook,
  ctx: ExportContext,
  summary: { income: number; expense: number; count: number },
) {
  const { t, currency } = ctx;
  const balance = summary.income - summary.expense;
  const savingsRate =
    summary.income > 0 ? Math.max(0, balance / summary.income) : 0;

  const ws = wb.addWorksheet(t("exportTools.sheet.summary"));
  ws.columns = [
    { header: "", key: "label", width: 24 },
    { header: "", key: "value", width: 18 },
  ];

  const titleRow = ws.addRow({
    label: t("exportTools.summary.title"),
    value: currency.toUpperCase(),
  });
  styleHeaderRow(titleRow);

  const lines: { label: string; value: number; pct?: boolean; income?: boolean; expense?: boolean }[] =
    [
      { label: t("exportTools.summary.income"), value: summary.income, income: true },
      { label: t("exportTools.summary.expense"), value: -Math.abs(summary.expense), expense: true },
      { label: t("exportTools.summary.balance"), value: balance },
      { label: t("exportTools.summary.savingsRate"), value: savingsRate, pct: true },
      { label: t("exportTools.summary.txCount"), value: summary.count },
    ];

  for (const l of lines) {
    const row = ws.addRow({ label: l.label, value: l.value });
    row.getCell("label").font = { bold: true };
    const valueCell = row.getCell("value");
    if (l.pct) valueCell.numFmt = "0%";
    else if (l.label === t("exportTools.summary.txCount")) valueCell.numFmt = "#,##0";
    else {
      valueCell.numFmt = MONEY_FMT;
      if (l.income) valueCell.font = { color: { argb: INCOME_FONT } };
      if (l.expense) valueCell.font = { color: { argb: EXPENSE_FONT } };
    }
  }
}
