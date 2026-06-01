import { NextResponse } from "next/server";
import { Readable } from "node:stream";
import ExcelJS from "exceljs";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
// El contenido depende del archivo subido por el usuario; nunca cachear.
export const dynamic = "force-dynamic";

/** Tope de filas de datos que devolvemos al cliente (privacidad + payload). */
const MAX_ROWS = 2000;
/** Tope duro de tamaño de archivo (5 MB). */
const MAX_BYTES = 5 * 1024 * 1024;
/** Tope de columnas que consideramos (planillas anchas no aportan acá). */
const MAX_COLS = 60;
/** Tope de largo por celda al serializar a string (defensivo). */
const MAX_CELL_LEN = 200;

type ErrorCode =
  | "fileTooLargeError"
  | "fileTypeError"
  | "emptyFileError"
  | "parseError";

function fail(code: ErrorCode, status = 400) {
  return NextResponse.json({ error: code }, { status });
}

/**
 * Convierte un valor de celda de ExcelJS a string plano y seguro. Maneja los
 * tipos ricos (fechas, fórmulas, hyperlinks, rich-text) sin volcar objetos
 * crudos ni `[object Object]`. Nunca lanza.
 */
function cellToString(value: unknown): string {
  if (value == null) return "";
  if (typeof value === "string") return value.slice(0, MAX_CELL_LEN);
  if (typeof value === "number") return Number.isFinite(value) ? String(value) : "";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (value instanceof Date) {
    // Fecha-sólo en ISO (YYYY-MM-DD): es lo que la IA/heurística esperan parsear.
    return value.toISOString().slice(0, 10);
  }
  if (typeof value === "object") {
    const v = value as Record<string, unknown>;
    // Fórmula → su resultado calculado.
    if ("result" in v && v.result != null) return cellToString(v.result);
    // Rich text → concatenar los fragmentos de texto.
    if (Array.isArray(v.richText)) {
      return v.richText
        .map((r) => (typeof (r as { text?: unknown }).text === "string" ? (r as { text: string }).text : ""))
        .join("")
        .slice(0, MAX_CELL_LEN);
    }
    // Hyperlink → el texto visible.
    if (typeof v.text === "string") return v.text.slice(0, MAX_CELL_LEN);
    if (typeof v.hyperlink === "string") return v.hyperlink.slice(0, MAX_CELL_LEN);
    // Errores de celda u objetos desconocidos: mejor vacío que ruido.
    return "";
  }
  return "";
}

/** Extrae headers + filas de un Worksheet de ExcelJS de forma defensiva. */
function extractFromWorksheet(ws: ExcelJS.Worksheet | undefined): {
  headers: string[];
  rows: string[][];
  rowCount: number;
  truncated: boolean;
} {
  if (!ws) return { headers: [], rows: [], rowCount: 0, truncated: false };

  const colCount = Math.min(ws.actualColumnCount || ws.columnCount || 0, MAX_COLS);
  if (colCount <= 0) return { headers: [], rows: [], rowCount: 0, truncated: false };

  // Fila 1 = headers. Cada celda por índice 1..colCount (ExcelJS es 1-based).
  const headerRow = ws.getRow(1);
  const headers: string[] = [];
  for (let c = 1; c <= colCount; c++) {
    headers.push(cellToString(headerRow.getCell(c).value).trim());
  }

  const rows: string[][] = [];
  let truncated = false;
  const lastRow = ws.actualRowCount || ws.rowCount || 0;
  for (let r = 2; r <= lastRow; r++) {
    if (rows.length >= MAX_ROWS) {
      truncated = true;
      break;
    }
    const row = ws.getRow(r);
    const cells: string[] = [];
    let hasValue = false;
    for (let c = 1; c <= colCount; c++) {
      const s = cellToString(row.getCell(c).value).trim();
      if (s) hasValue = true;
      cells.push(s);
    }
    // Saltar filas completamente vacías (separadores, padding del export).
    if (hasValue) rows.push(cells);
  }

  return { headers, rows, rowCount: rows.length, truncated };
}

export async function POST(request: Request) {
  // 1) Sesión obligatoria (no parseamos archivos de anónimos).
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  // 2) Leer el archivo del multipart form-data.
  let file: File | null = null;
  try {
    const form = await request.formData();
    const f = form.get("file");
    if (f instanceof File) file = f;
  } catch {
    return fail("parseError");
  }
  if (!file) return fail("parseError");

  // 3) Validar tamaño y tipo ANTES de leer en memoria.
  if (file.size > MAX_BYTES) return fail("fileTooLargeError");

  const name = (file.name || "").toLowerCase();
  const isCsv = name.endsWith(".csv");
  const isXlsx = name.endsWith(".xlsx");
  if (!isCsv && !isXlsx) return fail("fileTypeError");

  const arrayBuf = await file.arrayBuffer();
  if (arrayBuf.byteLength === 0) return fail("emptyFileError");
  if (arrayBuf.byteLength > MAX_BYTES) return fail("fileTooLargeError");
  const buffer = Buffer.from(arrayBuf);

  // 4) Parsear con ExcelJS. Nunca confiamos en el contenido: todo se serializa
  //    a string plano y acotado en `cellToString`.
  let parsed: ReturnType<typeof extractFromWorksheet>;
  try {
    if (isXlsx) {
      const wb = new ExcelJS.Workbook();
      // `@types/node` v22 hizo `Buffer` genérico (`Buffer<ArrayBufferLike>`),
      // pero los typings de exceljs esperan el `Buffer` no-genérico. En runtime
      // `.load` acepta el buffer tal cual; casteamos al tipo EXACTO del parámetro
      // para salvar la incompatibilidad sin perder seguridad en el resto.
      type LoadArg = Parameters<typeof wb.xlsx.load>[0];
      await wb.xlsx.load(buffer as unknown as LoadArg);
      parsed = extractFromWorksheet(wb.worksheets[0]);
    } else {
      const wb = new ExcelJS.Workbook();
      const stream = Readable.from(buffer);
      const ws = await wb.csv.read(stream);
      parsed = extractFromWorksheet(ws);
    }
  } catch {
    return fail("parseError");
  }

  if (parsed.rowCount === 0 || parsed.headers.length === 0) {
    return fail("emptyFileError");
  }

  return NextResponse.json({
    headers: parsed.headers,
    rows: parsed.rows,
    rowCount: parsed.rowCount,
    truncated: parsed.truncated,
    maxRows: MAX_ROWS,
  });
}
