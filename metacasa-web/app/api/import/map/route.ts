import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { heuristicMapping, parseAiMapping } from "../mapping";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Cuántas filas de muestra mandamos al modelo (privacidad + tokens). */
const SAMPLE_ROWS = 5;
const MAX_HEADERS = 60;

/** Extrae el texto de una respuesta Anthropic Messages (bloques type:'text'). */
function extractText(payload: unknown): string {
  const content = (payload as { content?: unknown })?.content;
  if (!Array.isArray(content)) return "";
  return content
    .filter(
      (b): b is { type: "text"; text: string } =>
        !!b &&
        typeof b === "object" &&
        (b as { type?: unknown }).type === "text" &&
        typeof (b as { text?: unknown }).text === "string",
    )
    .map((b) => b.text)
    .join("");
}

/** Normaliza el array de headers recibido del cliente. */
function sanitizeHeaders(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .slice(0, MAX_HEADERS)
    .map((h) => (typeof h === "string" ? h.slice(0, 120) : ""));
}

/** Normaliza las filas de muestra (recortadas a SAMPLE_ROWS × #headers). */
function sanitizeSamples(raw: unknown, cols: number): string[][] {
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, SAMPLE_ROWS).map((row) =>
    Array.isArray(row)
      ? row.slice(0, cols).map((c) => (typeof c === "string" ? c.slice(0, 120) : String(c ?? "")))
      : [],
  );
}

function buildSystemPrompt(headers: string[], samples: string[][]): string {
  const headerList = headers
    .map((h, i) => `${i}: ${JSON.stringify(h || `(column ${i})`)}`)
    .join("\n");
  const sampleBlock = samples
    .map((r, i) => `Row ${i + 1}: ${JSON.stringify(r)}`)
    .join("\n");

  return [
    "You map spreadsheet columns from a bank/finance export to a fixed transaction schema.",
    "The spreadsheet columns are 0-indexed. Here are the headers:",
    headerList,
    "",
    "Sample data rows (string values, same column order):",
    sampleBlock || "(no sample rows)",
    "",
    "Target fields:",
    "- date: the transaction date column.",
    "- amount: the monetary amount column.",
    "- type: a column that says expense vs income (e.g. 'Tipo', 'Debit/Credit'); null if there is none.",
    "- category: a category/concept column; null if none.",
    "- account: an account/bank/wallet/card column; null if none.",
    "- note: a free-text description/memo column; null if none.",
    "",
    "Respond with ONLY a strict JSON object, no prose, no markdown fences:",
    '{"mapping":{"date":<colIndex|null>,"amount":<colIndex|null>,"type":<colIndex|null>,"category":<colIndex|null>,"account":<colIndex|null>,"note":<colIndex|null>},"dateFormat":"<your best guess like DD/MM/YYYY or YYYY-MM-DD>","amountSign":"negativeIsExpense"|"typeColumn"|"allExpense"|"allIncome","notes":"<short note>"}',
    "Rules: each colIndex must be an existing 0-based index or null. If a single amount column carries the sign (negatives are expenses), use amountSign 'negativeIsExpense'. If a separate type column exists, set it in mapping.type and use amountSign 'typeColumn'. Never invent columns.",
  ].join("\n");
}

export async function POST(request: Request) {
  // 1) Sesión + token para el proxy (verify_jwt=true), igual que el asistente.
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  const accessToken = session?.access_token;
  if (!user || !accessToken) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  // 2) Body: headers + filas de muestra.
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "badRequest" }, { status: 400 });
  }
  const headers = sanitizeHeaders((body as { headers?: unknown })?.headers);
  const samples = sanitizeSamples((body as { sampleRows?: unknown })?.sampleRows, headers.length);
  if (headers.length === 0) {
    return NextResponse.json({ error: "badRequest" }, { status: 400 });
  }

  // Heurística lista de antemano: es nuestro fallback ante cualquier fallo de IA.
  const fallback = heuristicMapping(headers);

  // 3) Pedir el mapeo a la IA (NON-streaming). Si falla por cualquier motivo,
  //    devolvemos la heurística con 200 para que el flujo no se corte.
  const proxyUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/ai-proxy`;
  const system = buildSystemPrompt(headers, samples);

  let proxyRes: Response;
  try {
    proxyRes = await fetch(proxyUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        system,
        messages: [{ role: "user", content: "Map the columns now. JSON only." }],
        max_tokens: 400,
        temperature: 0,
        stream: false,
      }),
      cache: "no-store",
    });
  } catch {
    return NextResponse.json(fallback);
  }

  if (!proxyRes.ok) {
    // 401: token vencido → que el cliente reintente logueado. Resto (429/502/…):
    // degradamos a heurística sin romper el flujo, avisando el motivo.
    if (proxyRes.status === 401) {
      return NextResponse.json({ error: "sessionExpired" }, { status: 401 });
    }
    return NextResponse.json({
      ...fallback,
      aiError: proxyRes.status === 429 ? "rateLimit" : "unavailable",
    });
  }

  let data: unknown;
  try {
    data = await proxyRes.json();
  } catch {
    return NextResponse.json({ ...fallback, aiError: "unavailable" });
  }

  const text = extractText(data);
  const aiMapping = parseAiMapping(text, headers.length);
  if (!aiMapping) {
    return NextResponse.json({ ...fallback, aiError: "unavailable" });
  }

  return NextResponse.json(aiMapping);
}
