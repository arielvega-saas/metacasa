import "server-only";
import { jsPDF } from "jspdf";
import autoTable from "jspdf-autotable";
import type { Transaction } from "@/lib/db/transactions";
import { formatMoney } from "@/lib/money";
import { intlLocale, formatMonthYear } from "@/lib/i18n/dates";
import { TX_TYPE } from "@/lib/constants";
import { signedAmount, typeLabel, type ExportContext } from "./shared";

// Paleta Midnight-Sage adaptada a impresión: acentos oscuros sobre blanco.
const SAGE: [number, number, number] = [31, 42, 36]; // verde-noche (header band)
const SAGE_TEXT: [number, number, number] = [232, 239, 233]; // off-white sobre sage
const INK: [number, number, number] = [26, 32, 28]; // texto principal
const MUTED: [number, number, number] = [110, 122, 114]; // texto secundario
const INCOME: [number, number, number] = [47, 110, 84];
const EXPENSE: [number, number, number] = [176, 74, 64];
const HAIRLINE: [number, number, number] = [228, 232, 229];

const MARGIN = 40;

/**
 * Lee el `finalY` de la última tabla dibujada. `jspdf-autotable` v5 (API
 * funcional) adjunta `lastAutoTable` al doc pero no lo declara en los tipos del
 * módulo `jspdf`, así que accedemos con un cast acotado en vez de `any`.
 */
function lastTableFinalY(doc: jsPDF, fallback: number): number {
  const t = (doc as unknown as { lastAutoTable?: { finalY?: number } })
    .lastAutoTable;
  return t?.finalY ?? fallback;
}

/**
 * Genera el PDF del reporte mensual: banda de marca (Home Finance + hogar + mes),
 * bloque de KPIs (ingresos/gastos/balance/tasa de ahorro), tabla "Top categorías"
 * y tabla de movimientos del mes. Texto oscuro sobre blanco (legible al imprimir).
 * Todas las labels salen del diccionario en el locale activo.
 */
export function buildReportPdf(
  ctx: ExportContext,
  args: {
    year: number;
    month: number;
    summary: { income: number; expense: number; count: number };
    topCategories: { category: string; total: number; pct: number }[];
    transactions: Transaction[];
    accountNames: Map<string, string>;
  },
): Buffer {
  const { t, locale, currency, household } = ctx;
  const { year, month, summary, topCategories, transactions, accountNames } = args;

  const doc = new jsPDF({ unit: "pt", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const contentWidth = pageWidth - MARGIN * 2;

  doc.setProperties({
    title: `${t("exportTools.pdf.brand")} — ${t("exportTools.pdf.reportTitle")}`,
    author: t("exportTools.meta.author"),
    subject: t("exportTools.meta.subject"),
  });

  const monthLongRaw = formatMonthYear(year, month, locale);
  const monthLong = monthLongRaw.charAt(0).toUpperCase() + monthLongRaw.slice(1);
  const balance = summary.income - summary.expense;
  const savingsRate =
    summary.income > 0
      ? Math.max(0, Math.round((balance / summary.income) * 100))
      : 0;

  // ── Banda de marca ──────────────────────────────────────────────────────
  doc.setFillColor(...SAGE);
  doc.rect(0, 0, pageWidth, 84, "F");
  doc.setTextColor(...SAGE_TEXT);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(20);
  doc.text(t("exportTools.pdf.brand"), MARGIN, 38);
  doc.setFont("helvetica", "normal");
  doc.setFontSize(11);
  doc.text(`${household.name} · ${monthLong}`, MARGIN, 58);
  doc.setFontSize(9);
  const genDate = new Intl.DateTimeFormat(intlLocale(locale), {
    dateStyle: "long",
  }).format(new Date());
  doc.text(
    t("exportTools.pdf.generatedOn", { date: genDate }),
    pageWidth - MARGIN,
    58,
    { align: "right" },
  );

  // ── Bloque de KPIs ────────────────────────────────────────────────────────
  let cursorY = 110;
  doc.setTextColor(...INK);
  doc.setFont("helvetica", "bold");
  doc.setFontSize(13);
  doc.text(t("exportTools.pdf.kpiSectionTitle"), MARGIN, cursorY);
  cursorY += 14;

  const kpis: { label: string; value: string; color: [number, number, number] }[] = [
    {
      label: t("exportTools.summary.income"),
      value: formatMoney(summary.income, currency, "precise"),
      color: INCOME,
    },
    {
      label: t("exportTools.summary.expense"),
      value: formatMoney(summary.expense, currency, "precise"),
      color: EXPENSE,
    },
    {
      label: t("exportTools.summary.balance"),
      value: formatMoney(balance, currency, "precise"),
      color: balance < 0 ? EXPENSE : INCOME,
    },
    {
      label: t("exportTools.summary.savingsRate"),
      value: `${savingsRate}%`,
      color: INK,
    },
  ];

  const gap = 12;
  const cardW = (contentWidth - gap * (kpis.length - 1)) / kpis.length;
  const cardH = 56;
  kpis.forEach((k, i) => {
    const x = MARGIN + i * (cardW + gap);
    doc.setDrawColor(...HAIRLINE);
    doc.setFillColor(250, 251, 250);
    doc.roundedRect(x, cursorY, cardW, cardH, 6, 6, "FD");
    doc.setFont("helvetica", "normal");
    doc.setFontSize(8);
    doc.setTextColor(...MUTED);
    doc.text(k.label.toUpperCase(), x + 10, cursorY + 18);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(13);
    doc.setTextColor(...k.color);
    doc.text(k.value, x + 10, cursorY + 40, { maxWidth: cardW - 20 });
  });
  cursorY += cardH + 26;

  // ── Tabla Top categorías ────────────────────────────────────────────────
  if (topCategories.length > 0) {
    doc.setFont("helvetica", "bold");
    doc.setFontSize(13);
    doc.setTextColor(...INK);
    doc.text(t("exportTools.pdf.topCategoriesTitle"), MARGIN, cursorY);
    cursorY += 8;

    autoTable(doc, {
      startY: cursorY,
      margin: { left: MARGIN, right: MARGIN },
      head: [
        [
          t("exportTools.pdf.topCategoriesName"),
          t("exportTools.pdf.topCategoriesAmount"),
          t("exportTools.pdf.topCategoriesPct"),
        ],
      ],
      body: topCategories.map((c) => [
        c.category,
        formatMoney(c.total, currency, "precise"),
        `${c.pct}%`,
      ]),
      theme: "striped",
      headStyles: { fillColor: SAGE, textColor: SAGE_TEXT, fontStyle: "bold" },
      bodyStyles: { textColor: INK, fontSize: 9 },
      alternateRowStyles: { fillColor: [247, 249, 248] },
      columnStyles: {
        1: { halign: "right" },
        2: { halign: "right", cellWidth: 60 },
      },
    });
    cursorY = lastTableFinalY(doc, cursorY) + 26;
  }

  // ── Tabla de movimientos del mes ──────────────────────────────────────────
  doc.setFont("helvetica", "bold");
  doc.setFontSize(13);
  doc.setTextColor(...INK);
  doc.text(t("exportTools.pdf.transactionsTitle"), MARGIN, cursorY);
  cursorY += 8;

  const dateFmt = new Intl.DateTimeFormat(intlLocale(locale), {
    month: "2-digit",
    day: "2-digit",
  });

  if (transactions.length === 0) {
    doc.setFont("helvetica", "normal");
    doc.setFontSize(10);
    doc.setTextColor(...MUTED);
    doc.text(t("exportTools.meta.empty"), MARGIN, cursorY + 16);
  } else {
    autoTable(doc, {
      startY: cursorY,
      margin: { left: MARGIN, right: MARGIN },
      head: [
        [
          t("exportTools.sheet.colDate"),
          t("exportTools.sheet.colCategory"),
          t("exportTools.sheet.colAccount"),
          t("exportTools.sheet.colAmount"),
        ],
      ],
      body: transactions.map((tx) => [
        dateFmt.format(new Date(tx.date)),
        tx.category || t("exportTools.sheet.noCategory"),
        tx.account_id
          ? (accountNames.get(tx.account_id) ?? t("exportTools.sheet.noAccount"))
          : t("exportTools.sheet.noAccount"),
        formatMoney(signedAmount(tx), currency, "precise"),
      ]),
      theme: "striped",
      headStyles: { fillColor: SAGE, textColor: SAGE_TEXT, fontStyle: "bold" },
      bodyStyles: { textColor: INK, fontSize: 9 },
      alternateRowStyles: { fillColor: [247, 249, 248] },
      columnStyles: { 3: { halign: "right", cellWidth: 90 } },
      // Colorea el monto por tipo (ingreso sage / gasto coral).
      didParseCell: (data) => {
        if (data.section === "body" && data.column.index === 3) {
          const tx = transactions[data.row.index];
          if (tx) {
            data.cell.styles.textColor = tx.type === TX_TYPE.EXPENSE ? EXPENSE : INCOME;
          }
        }
      },
    });
  }

  // ── Pie de página (paginado + confidencialidad) en cada página ────────────
  const pageCount = doc.getNumberOfPages();
  const pageHeight = doc.internal.pageSize.getHeight();
  for (let p = 1; p <= pageCount; p++) {
    doc.setPage(p);
    doc.setFont("helvetica", "normal");
    doc.setFontSize(8);
    doc.setTextColor(...MUTED);
    doc.text(t("exportTools.pdf.confidential"), MARGIN, pageHeight - 20);
    doc.text(
      t("exportTools.pdf.page", { n: p, total: pageCount }),
      pageWidth - MARGIN,
      pageHeight - 20,
      { align: "right" },
    );
  }

  // jsPDF en Node devuelve un ArrayBuffer con "arraybuffer".
  const out = doc.output("arraybuffer");
  return Buffer.from(out);
}
