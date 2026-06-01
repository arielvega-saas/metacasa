import { NextResponse } from "next/server";
import {
  getMonthSummary,
  getCategoryBreakdown,
  listTransactions,
  type Transaction,
} from "@/lib/db/transactions";
import {
  resolveExportContext,
  fetchAccountNameMap,
  safeFilePart,
  currentYearMonth,
  EXPORT_ROW_CAP,
  type ExportContext,
} from "../_lib/shared";
import { buildReportPdf } from "../_lib/pdf";
import { buildReportSummaryWorkbook } from "../_lib/excel";

// jsPDF / ExcelJS necesitan runtime Node.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const PDF_MIME = "application/pdf";
const XLSX_MIME =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

/** Valida y normaliza `?ym=YYYY-MM`; cae al mes actual si falta o es inválido. */
function parseYearMonth(raw: string | null): { year: number; month: number; ym: string } {
  const fallback = currentYearMonth();
  const value = raw && /^\d{4}-\d{2}$/.test(raw) ? raw : fallback;
  const [year, month] = value.split("-").map(Number);
  // Mes fuera de 1–12 → mes actual (defensivo).
  if (month < 1 || month > 12) {
    const [fy, fm] = fallback.split("-").map(Number);
    return { year: fy, month: fm, ym: fallback };
  }
  return { year, month, ym: value };
}

/** Límites ISO [inicio, fin) del mes en UTC (igual que el data-layer de reportes). */
function monthBounds(year: number, month: number): { from: string; to: string } {
  return {
    from: new Date(Date.UTC(year, month - 1, 1)).toISOString(),
    to: new Date(Date.UTC(year, month, 1)).toISOString(),
  };
}

/** Reúne summary + top categorías + movimientos del mes para el reporte. */
async function gatherMonthData(
  ctx: ExportContext,
  year: number,
  month: number,
): Promise<{
  summary: { income: number; expense: number; count: number };
  topCategories: { category: string; total: number; pct: number }[];
  transactions: Transaction[];
}> {
  const { from, to } = monthBounds(year, month);

  const [summary, breakdown, list] = await Promise.all([
    getMonthSummary(ctx.supabase, ctx.household.id, year, month),
    getCategoryBreakdown(ctx.supabase, ctx.household.id, year, month),
    listTransactions(ctx.supabase, {
      householdId: ctx.household.id,
      // `to` es exclusivo (< primer día del mes siguiente). `listTransactions`
      // usa `.lte`, así que restamos 1ms para no incluir el primer instante del
      // mes siguiente.
      from,
      to: new Date(new Date(to).getTime() - 1).toISOString(),
      limit: EXPORT_ROW_CAP,
    }),
  ]);

  const expenseTotal = breakdown.reduce((s, d) => s + d.total, 0);
  const topCategories = breakdown.slice(0, 8).map((d) => ({
    category: d.category,
    total: d.total,
    pct: expenseTotal > 0 ? Math.round((d.total / expenseTotal) * 100) : 0,
  }));

  return {
    summary: { income: summary.income, expense: summary.expense, count: summary.count },
    topCategories,
    transactions: list.rows,
  };
}

/**
 * GET /api/export/report?ym=YYYY-MM
 * Genera el reporte mensual del hogar activo en PDF (por defecto) o en Excel
 * (`?format=xlsx`): resumen (ingresos/gastos/balance/tasa), top categorías y
 * los movimientos del mes. Todo localizado con el locale activo.
 */
export async function GET(request: Request) {
  const resolved = await resolveExportContext();
  if ("error" in resolved) {
    return NextResponse.json(
      { error: resolved.error.message },
      { status: resolved.error.status },
    );
  }
  const { ctx } = resolved;

  const params = new URL(request.url).searchParams;
  const { year, month, ym } = parseYearMonth(params.get("ym"));
  const format = params.get("format") === "xlsx" ? "xlsx" : "pdf";

  try {
    const data = await gatherMonthData(ctx, year, month);

    if (format === "xlsx") {
      const buffer = await buildReportSummaryWorkbook(
        ctx,
        data.summary,
        data.topCategories,
      );
      const filename = `${ctx.t("exportTools.file.report")}-${safeFilePart(ym)}.xlsx`;
      return new NextResponse(new Uint8Array(buffer), {
        status: 200,
        headers: {
          "Content-Type": XLSX_MIME,
          "Content-Disposition": `attachment; filename="${filename}"`,
          "Content-Length": String(buffer.length),
          "Cache-Control": "no-store",
        },
      });
    }

    const accountNames = await fetchAccountNameMap(ctx);
    const buffer = buildReportPdf(ctx, {
      year,
      month,
      summary: data.summary,
      topCategories: data.topCategories,
      transactions: data.transactions,
      accountNames,
    });
    const filename = `${ctx.t("exportTools.file.report")}-${safeFilePart(ym)}.pdf`;

    return new NextResponse(new Uint8Array(buffer), {
      status: 200,
      headers: {
        "Content-Type": PDF_MIME,
        "Content-Disposition": `attachment; filename="${filename}"`,
        "Content-Length": String(buffer.length),
        "Cache-Control": "no-store",
      },
    });
  } catch {
    return NextResponse.json({ error: "Export failed" }, { status: 500 });
  }
}
