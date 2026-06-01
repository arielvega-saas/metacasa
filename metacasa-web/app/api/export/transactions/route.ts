import { NextResponse } from "next/server";
import {
  resolveExportContext,
  parseTxFilters,
  fetchAllTransactions,
  fetchAccountNameMap,
  safeFilePart,
  currentYearMonth,
} from "../_lib/shared";
import { buildTransactionsWorkbook } from "../_lib/excel";

// ExcelJS necesita el runtime Node (Buffer, streams), no Edge.
export const runtime = "nodejs";
// La exportación depende del usuario y de sus datos: nunca cachear.
export const dynamic = "force-dynamic";

const XLSX_MIME =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

/**
 * GET /api/export/transactions
 * Exporta a Excel los movimientos del hogar activo que matchean los MISMOS
 * filtros de la página de Movimientos (`from`, `to`, `type`, `category`,
 * `account`, `q`, `min`, `max`). Sin paginar: trae todo el resultado del filtro.
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

  const filters = parseTxFilters(new URL(request.url).searchParams);

  try {
    const [rows, accountNames] = await Promise.all([
      fetchAllTransactions(ctx, filters),
      fetchAccountNameMap(ctx),
    ]);

    const buffer = await buildTransactionsWorkbook(ctx, rows, accountNames);
    const filename = `${ctx.t("exportTools.file.transactions")}-${safeFilePart(
      currentYearMonth(),
    )}.xlsx`;

    return new NextResponse(new Uint8Array(buffer), {
      status: 200,
      headers: {
        "Content-Type": XLSX_MIME,
        "Content-Disposition": `attachment; filename="${filename}"`,
        "Content-Length": String(buffer.length),
        "Cache-Control": "no-store",
      },
    });
  } catch {
    // No logueamos detalle (puede contener datos del hogar).
    return NextResponse.json(
      { error: "Export failed" },
      { status: 500 },
    );
  }
}
