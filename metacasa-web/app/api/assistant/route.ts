import { NextResponse } from "next/server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listAccountsWithBalance } from "@/lib/db/accounts";
import { getMonthSummary, getCategoryBreakdown } from "@/lib/db/transactions";
import { upcomingBills } from "@/lib/db/bills";
import { listGoals } from "@/lib/db/goals";
import { formatMoney } from "@/lib/money";
import { parseFxRates, convertToBase, canConvertAll, type FXRateMap } from "@/lib/fx";
import { ASSISTANT_TOOLS } from "@/lib/ai/tools";
import { dispatchTool, type ToolContext } from "@/lib/ai/dispatch";
// `normalizeToday` vive en `lib/today.ts`: es la ÚNICA regla de validación del
// "hoy" que manda el cliente, compartida entre este endpoint (body `today`) y la
// cookie de zona horaria que leen los Server Components (`lib/today-server.ts`).
// No duplicar la validación acá: dos copias divergen.
import { normalizeToday, splitYm } from "@/lib/today";

export const runtime = "nodejs";
// El contexto depende del usuario; nunca cachear la respuesta.
export const dynamic = "force-dynamic";

/**
 * Tope de vueltas del loop tool_use → tool_result → continuar. Mismo número que
 * iOS (`AnthropicProvider.maxToolLoopIterations`): alcanza para "buscá el
 * movimiento y borralo" sin dejar que un modelo en loop queme la cuota.
 */
const MAX_TOOL_ITERATIONS = 4;

/** Bloques de contenido de la Messages API que este endpoint maneja. */
type TextBlock = { type: "text"; text: string };
type ToolUseBlock = { type: "tool_use"; id: string; name: string; input: unknown };
type ToolResultBlock = {
  type: "tool_result";
  tool_use_id: string;
  content: string;
  is_error?: boolean;
};
type ContentBlock = TextBlock | ToolUseBlock | ToolResultBlock;

/**
 * Un turno del chat. El contenido puede ser texto plano (lo normal) o una lista
 * de bloques: es lo que exige el protocolo de tools, donde el turno del
 * assistant lleva los `tool_use` y el siguiente turno del usuario los
 * `tool_result` correspondientes.
 */
type ChatMessage = { role: "user" | "assistant"; content: string | ContentBlock[] };

type Locale = "es" | "en" | "pt";

/** Normaliza el locale recibido del widget a uno soportado (default ES). */
function normalizeLocale(locale: unknown): Locale {
  return locale === "en" || locale === "pt" ? locale : "es";
}

/**
 * Instrucción de idioma de respuesta según el locale + la región del usuario.
 * Adaptación POR REGIÓN (decisión de producto): España→castellano, Argentina/
 * Uruguay→voseo rioplatense, resto de LatAm→neutro; Brasil→pt-BR, Portugal→pt-PT.
 * La `region` sale del Accept-Language del navegador (sin geo-IP ni permisos).
 */
function languageDirective(locale: Locale, region?: string): string {
  switch (locale) {
    case "en":
      return "Always reply in English, regardless of the language of the question.";
    case "pt":
      return region === "PT"
        ? "Responda sempre em português europeu, independentemente do idioma da pergunta."
        : "Responda sempre em português do Brasil, independentemente do idioma da pergunta.";
    case "es":
    default:
      switch (region) {
        case "ES":
          return "Respondé siempre en español de España (tuteo: tú tienes, fíjate, mira, coge, vale; vocabulario peninsular: móvil, ordenador, dinero; NUNCA voseo, nada de 'tenés/podés/mirá'), sin importar el idioma de la pregunta.";
        case "AR":
        case "UY":
          return "Respondé siempre en español rioplatense (voseo: 'tenés', 'fijate', 'mirá'), sin importar el idioma de la pregunta.";
        default:
          return "Respondé siempre en español latinoamericano neutro (tuteo: 'tú tienes', 'fíjate'; sin voseo marcado ni modismos de un solo país), sin importar el idioma de la pregunta.";
      }
  }
}

/**
 * Extrae la región (ES, AR, BR, …) del header Accept-Language para la variante
 * de idioma. Toma el primer tag cuyo idioma coincida con el `locale` elegido.
 * Devuelve `undefined` si el navegador no manda región.
 */
function regionFromAcceptLanguage(header: string | null, lang: Locale): string | undefined {
  if (!header) return undefined;
  for (const part of header.split(",")) {
    const tag = part.split(";")[0]?.trim() ?? "";
    const [l, r] = tag.split("-");
    if (l?.toLowerCase() === lang && r) return r.toUpperCase();
  }
  return undefined;
}

/**
 * Etiquetas de las secciones del contexto financiero, por locale. El contexto
 * que "ancla" al modelo debe estar en el idioma del usuario para que el grounding
 * coincida con la conversación (la directiva de idioma de respuesta ya existe).
 */
const CONTEXT_LABELS: Record<Locale, Record<string, string>> = {
  es: {
    baseCurrency: "Moneda base del hogar",
    currentMonth: "Mes actual",
    accountsTitle: "Cuentas y saldos",
    totalConsolidated: "Saldo total (consolidado a {currency} con tus tasas de cambio)",
    totalBreakdownNote:
      "Saldo total: no puedo consolidar a una sola moneda porque faltan tasas de cambio. Detalle por moneda",
    noAccounts: "Cuentas: el hogar todavía no tiene cuentas cargadas.",
    movementsOf: "Movimientos de {month}",
    income: "Ingresos",
    expenses: "Gastos",
    monthBalance: "Balance del mes",
    txCount: "Cantidad de movimientos",
    topCategories: "Top categorías de gasto del mes",
    upcomingBills: "Próximos vencimientos",
    dueOn: "vence",
    activeGoals: "Metas de ahorro activas",
    goalOf: "de",
    goalTarget: "objetivo",
    contextHeader: "Datos del hogar (mes actual)",
    contextUnavailable:
      "Moneda base del hogar: {currency}. (No se pudo cargar el detalle financiero ahora mismo.)",
  },
  en: {
    baseCurrency: "Household base currency",
    currentMonth: "Current month",
    accountsTitle: "Accounts and balances",
    totalConsolidated: "Total balance (consolidated to {currency} using your exchange rates)",
    totalBreakdownNote:
      "Total balance: can't consolidate to a single currency because some exchange rates are missing. Breakdown by currency",
    noAccounts: "Accounts: this household has no accounts yet.",
    movementsOf: "Activity in {month}",
    income: "Income",
    expenses: "Expenses",
    monthBalance: "Month balance",
    txCount: "Transaction count",
    topCategories: "Top spending categories this month",
    upcomingBills: "Upcoming bills",
    dueOn: "due",
    activeGoals: "Active savings goals",
    goalOf: "of",
    goalTarget: "target",
    contextHeader: "Household data (current month)",
    contextUnavailable:
      "Household base currency: {currency}. (Couldn't load the financial detail right now.)",
  },
  pt: {
    baseCurrency: "Moeda base do lar",
    currentMonth: "Mês atual",
    accountsTitle: "Contas e saldos",
    totalConsolidated: "Saldo total (consolidado em {currency} com suas taxas de câmbio)",
    totalBreakdownNote:
      "Saldo total: não dá para consolidar em uma única moeda porque faltam taxas de câmbio. Detalhe por moeda",
    noAccounts: "Contas: este lar ainda não tem contas cadastradas.",
    movementsOf: "Movimentações de {month}",
    income: "Receitas",
    expenses: "Despesas",
    monthBalance: "Saldo do mês",
    txCount: "Quantidade de movimentações",
    topCategories: "Principais categorias de gasto do mês",
    upcomingBills: "Próximos vencimentos",
    dueOn: "vence",
    activeGoals: "Metas de poupança ativas",
    goalOf: "de",
    goalTarget: "objetivo",
    contextHeader: "Dados do lar (mês atual)",
    contextUnavailable:
      "Moeda base do lar: {currency}. (Não foi possível carregar o detalhe financeiro agora.)",
  },
};

/**
 * Confirmación mínima para el caso raro en que el modelo ejecutó una escritura
 * pero no devolvió texto. Sin esto el usuario vería un error después de que el
 * movimiento YA se cargó, y el reflejo sería volver a pedirlo → duplicado.
 */
const WRITE_DONE_FALLBACK: Record<Locale, string> = {
  es: "Listo, lo registré en tu hogar.",
  en: "Done — I saved it to your household.",
  pt: "Pronto, registrei na sua casa.",
};

/** Tag BCP-47 para `toLocaleDateString` del mes actual, por locale. */
const MONTH_LOCALE_TAG: Record<Locale, string> = {
  es: "es-AR",
  en: "en-US",
  pt: "pt-BR",
};

/** Bloque de contenido validado, o `null` si no tiene la forma esperada. */
function sanitizeBlock(raw: unknown): ContentBlock | null {
  if (!raw || typeof raw !== "object") return null;
  const b = raw as Record<string, unknown>;

  if (b.type === "text" && typeof b.text === "string") {
    const text = b.text.trim();
    return text ? { type: "text", text: text.slice(0, 4000) } : null;
  }

  if (
    b.type === "tool_use" &&
    typeof b.id === "string" &&
    typeof b.name === "string" &&
    b.id.length <= 128
  ) {
    return { type: "tool_use", id: b.id, name: b.name.slice(0, 64), input: b.input ?? {} };
  }

  if (
    b.type === "tool_result" &&
    typeof b.tool_use_id === "string" &&
    typeof b.content === "string" &&
    b.tool_use_id.length <= 128
  ) {
    const block: ToolResultBlock = {
      type: "tool_result",
      tool_use_id: b.tool_use_id,
      content: b.content.slice(0, 6000),
    };
    if (b.is_error === true) block.is_error = true;
    return block;
  }

  return null;
}

/**
 * Valida y normaliza el historial recibido del cliente. Acepta el formato viejo
 * (`content` string) y el nuevo con bloques, que es el que devuelve este mismo
 * endpoint para no perder los `tool_use` entre turnos.
 */
function sanitizeMessages(raw: unknown): ChatMessage[] {
  if (!Array.isArray(raw)) return [];
  const out: ChatMessage[] = [];

  for (const m of raw) {
    if (!m || typeof m !== "object") continue;
    const role = (m as { role?: unknown }).role;
    const content = (m as { content?: unknown }).content;
    if (role !== "user" && role !== "assistant") continue;

    if (typeof content === "string") {
      const trimmed = content.trim();
      if (!trimmed) continue;
      // Tope defensivo de tamaño por mensaje (no abusar del proxy).
      out.push({ role, content: trimmed.slice(0, 4000) });
      continue;
    }

    if (Array.isArray(content)) {
      const blocks = content
        .slice(0, 20)
        .map(sanitizeBlock)
        .filter((b): b is ContentBlock => b !== null);
      if (blocks.length > 0) out.push({ role, content: blocks });
    }
  }

  // Quedarnos con la cola más reciente: contexto suficiente, payload acotado.
  return pairToolBlocks(out.slice(-24));
}

/**
 * Deja el historial en un estado que la Messages API acepta. Dos invariantes que
 * el recorte de la cola (o un cliente desactualizado) pueden romper:
 *   1. Un `tool_result` sin su `tool_use` previo → 400 del upstream.
 *   2. Un `tool_use` sin el `tool_result` inmediatamente después → 400 también.
 * En ambos casos se descarta el bloque huérfano, y el mensaje si queda vacío.
 * Además la conversación tiene que arrancar con un turno del usuario.
 */
function pairToolBlocks(messages: ChatMessage[]): ChatMessage[] {
  // 1) tool_result sin tool_use previo.
  const seenToolUse = new Set<string>();
  const pass1: ChatMessage[] = [];
  for (const m of messages) {
    if (typeof m.content === "string") {
      pass1.push(m);
      continue;
    }
    const kept = m.content.filter((b) =>
      b.type === "tool_result" ? seenToolUse.has(b.tool_use_id) : true,
    );
    for (const b of kept) if (b.type === "tool_use") seenToolUse.add(b.id);
    if (kept.length > 0) pass1.push({ role: m.role, content: kept });
  }

  // 2) tool_use sin su tool_result en el mensaje siguiente.
  const pass2: ChatMessage[] = [];
  for (let i = 0; i < pass1.length; i++) {
    const m = pass1[i];
    if (typeof m.content === "string") {
      pass2.push(m);
      continue;
    }
    const next = pass1[i + 1];
    const answered = new Set<string>(
      next && Array.isArray(next.content)
        ? next.content.flatMap((b) => (b.type === "tool_result" ? [b.tool_use_id] : []))
        : [],
    );
    const kept = m.content.filter((b) => (b.type === "tool_use" ? answered.has(b.id) : true));
    if (kept.length > 0) pass2.push({ role: m.role, content: kept });
  }

  // 3) La API exige que el primer turno sea del usuario, y ese turno no puede
  //    abrir con un `tool_result` (su `tool_use` quedó del otro lado del corte:
  //    el paso 1 lo dio por bueno porque en ese momento el assistant todavía
  //    estaba en la lista). Se descartan de a uno hasta encontrar un turno de
  //    usuario "limpio" — el último siempre lo es: es la pregunta nueva.
  while (pass2.length > 0) {
    const first = pass2[0];
    const opensWithToolResult =
      Array.isArray(first.content) && first.content.some((b) => b.type === "tool_result");
    if (first.role !== "user" || opensWithToolResult) pass2.shift();
    else break;
  }
  return pass2;
}

/**
 * Arma un resumen financiero compacto del hogar para el system prompt, en el
 * idioma del usuario (`locale`). Los montos por cuenta se muestran en la moneda
 * propia de cada cuenta; el saldo total se CONSOLIDA a la moneda base usando las
 * tasas FX del hogar (`fxRates`), igual que el net worth de iOS. Falla en
 * silencio por sección: un módulo caído no debe tumbar al asistente entero.
 */
async function buildFinancialContext(
  supabase: Awaited<ReturnType<typeof createClient>>,
  householdId: string,
  currency: string,
  locale: Locale,
  fxRates: FXRateMap,
  today: string,
): Promise<string> {
  const L = CONTEXT_LABELS[locale];
  const fmt = (s: string, vars?: Record<string, string | number>) =>
    vars
      ? s.replace(/\{(\w+)\}/g, (_, k) => String(vars[k] ?? `{${k}}`))
      : s;

  // El "mes actual" sale del día del USUARIO (`today`), no del reloj del server:
  // corre en UTC y el 31 a las 21:05 en Argentina el asistente le contaba al
  // modelo el mes siguiente, todo en $0.
  const [year, month] = splitYm(today);
  const monthLabel = new Date(Date.UTC(year, month - 1, 1)).toLocaleDateString(
    MONTH_LOCALE_TAG[locale],
    { month: "long", year: "numeric", timeZone: "UTC" },
  );

  const [accounts, summary, breakdown, bills, goals] = await Promise.all([
    listAccountsWithBalance(supabase, householdId).catch(() => []),
    getMonthSummary(supabase, householdId, year, month).catch(() => null),
    getCategoryBreakdown(supabase, householdId, year, month).catch(() => []),
    upcomingBills(supabase, householdId, 5).catch(() => []),
    listGoals(supabase, householdId, { activeOnly: true, limit: 5 }).catch(() => []),
  ]);

  const lines: string[] = [];
  lines.push(`${L.baseCurrency}: ${currency}.`);
  lines.push(`${L.currentMonth}: ${monthLabel}.`);

  // Saldos por cuenta (en la moneda propia de cada cuenta) + total consolidado.
  if (accounts.length > 0) {
    lines.push("");
    lines.push(`${L.accountsTitle}:`);
    for (const a of accounts) {
      lines.push(`- ${a.name}: ${formatMoney(a.balance, a.currency)}`);
    }

    const accountCurrencies = accounts.map((a) => a.currency || currency);
    if (canConvertAll(accountCurrencies, currency, fxRates)) {
      // Todas las monedas convertibles → un único total consolidado (como iOS).
      const total = accounts.reduce(
        (s, a) =>
          s + (convertToBase(a.balance, a.currency || currency, currency, fxRates) ?? 0),
        0,
      );
      lines.push(
        `${fmt(L.totalConsolidated, { currency })}: ${formatMoney(total, currency)}`,
      );
    } else {
      // Faltan tasas: en vez de mentir con una "suma directa", damos un desglose
      // por moneda y aclaramos que no hay total único.
      const byCurrency = new Map<string, number>();
      for (const a of accounts) {
        const cur = a.currency || currency;
        byCurrency.set(cur, (byCurrency.get(cur) ?? 0) + a.balance);
      }
      lines.push(`${L.totalBreakdownNote}:`);
      for (const [cur, sum] of byCurrency) {
        lines.push(`- ${formatMoney(sum, cur)}`);
      }
    }
  } else {
    lines.push("");
    lines.push(L.noAccounts);
  }

  // Ingresos / gastos / balance del mes.
  if (summary) {
    lines.push("");
    lines.push(`${fmt(L.movementsOf, { month: monthLabel })}:`);
    lines.push(`- ${L.income}: ${formatMoney(summary.income, currency)}`);
    lines.push(`- ${L.expenses}: ${formatMoney(summary.expense, currency)}`);
    lines.push(`- ${L.monthBalance}: ${formatMoney(summary.balance, currency)}`);
    lines.push(`- ${L.txCount}: ${summary.count}`);
  }

  // Top categorías de gasto del mes.
  if (breakdown.length > 0) {
    lines.push("");
    lines.push(`${L.topCategories}:`);
    for (const c of breakdown.slice(0, 5)) {
      lines.push(`- ${c.category}: ${formatMoney(c.total, currency)}`);
    }
  }

  // Próximos vencimientos.
  if (bills.length > 0) {
    lines.push("");
    lines.push(`${L.upcomingBills}:`);
    for (const b of bills) {
      lines.push(
        `- ${b.title}: ${formatMoney(Number(b.amount), b.currency)} ${L.dueOn} ${b.due_date}`,
      );
    }
  }

  // Metas activas con progreso.
  if (goals.length > 0) {
    lines.push("");
    lines.push(`${L.activeGoals}:`);
    for (const g of goals) {
      const target = Number(g.target_amount);
      const current = Number(g.current_amount);
      const pct = target > 0 ? Math.round((current / target) * 100) : 0;
      lines.push(
        `- ${g.name}: ${formatMoney(current, g.currency)} ${L.goalOf} ${formatMoney(
          target,
          g.currency,
        )} (${pct}%)${g.target_date ? ` · ${L.goalTarget} ${g.target_date}` : ""}`,
      );
    }
  }

  return lines.join("\n");
}

/**
 * Bloques de contenido de una respuesta Anthropic. A diferencia de la versión
 * anterior (que sólo miraba `type:"text"` y descartaba todo lo demás), acá se
 * conservan también los `tool_use`: son los que disparan la ejecución y los que
 * hay que devolver tal cual en el turno del assistant.
 */
function extractBlocks(payload: unknown): ContentBlock[] {
  const content = (payload as { content?: unknown })?.content;
  if (!Array.isArray(content)) return [];
  return content.map(sanitizeBlock).filter((b): b is ContentBlock => b !== null);
}

/** Texto plano de un conjunto de bloques (ignora `tool_use`). */
function textOf(blocks: ContentBlock[]): string {
  return blocks
    .filter((b): b is TextBlock => b.type === "text")
    .map((b) => b.text)
    .join("");
}

/** Respuesta del proxy ya interpretada, o el error a devolverle al cliente. */
type ProxyResult =
  | { ok: true; blocks: ContentBlock[]; stopReason: string | null }
  | { ok: false; response: NextResponse };

/**
 * Una llamada al proxy Anthropic (NON-streaming). El proxy hace pass-through de
 * `tools` y devuelve la respuesta completa con `stop_reason`. Nunca logueamos el
 * token.
 */
async function callProxy(params: {
  accessToken: string;
  system: string;
  messages: ChatMessage[];
  tools?: typeof ASSISTANT_TOOLS;
}): Promise<ProxyResult> {
  const proxyUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/ai-proxy`;

  let proxyRes: Response;
  try {
    proxyRes = await fetch(proxyUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${params.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        system: params.system,
        messages: params.messages,
        // Sin `tools`, el modelo no puede escribir: era exactamente el bug que
        // hacía que el asistente dijera "no puedo cargarlo".
        ...(params.tools ? { tools: params.tools } : {}),
        max_tokens: 1024,
      }),
      cache: "no-store",
    });
  } catch {
    return {
      ok: false,
      response: NextResponse.json(
        { error: "No pude conectarme con el asistente. Probá de nuevo en un momento." },
        { status: 502 },
      ),
    };
  }

  if (!proxyRes.ok) {
    if (proxyRes.status === 401) {
      return {
        ok: false,
        response: NextResponse.json(
          { error: "Tu sesión expiró. Volvé a iniciar sesión." },
          { status: 401 },
        ),
      };
    }
    if (proxyRes.status === 429) {
      return {
        ok: false,
        response: NextResponse.json(
          { error: "Llegaste al límite de consultas por hoy. Probá de nuevo mañana." },
          { status: 429 },
        ),
      };
    }
    return {
      ok: false,
      response: NextResponse.json(
        { error: "El asistente no está disponible ahora. Probá más tarde." },
        { status: 502 },
      ),
    };
  }

  let data: unknown;
  try {
    data = await proxyRes.json();
  } catch {
    return {
      ok: false,
      response: NextResponse.json(
        { error: "El asistente devolvió una respuesta inesperada." },
        { status: 502 },
      ),
    };
  }

  const stopReason = (data as { stop_reason?: unknown })?.stop_reason;
  return {
    ok: true,
    blocks: extractBlocks(data),
    stopReason: typeof stopReason === "string" ? stopReason : null,
  };
}

export async function POST(request: Request) {
  const supabase = await createClient();

  // 1) Sesión: necesitamos user + access token para el proxy (verify_jwt=true).
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const {
    data: { session },
  } = await supabase.auth.getSession();
  const accessToken = session?.access_token;

  if (!user || !accessToken) {
    return NextResponse.json({ error: "No hay sesión activa." }, { status: 401 });
  }

  // 2) Body con el historial del chat.
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Cuerpo inválido." }, { status: 400 });
  }
  const messages = sanitizeMessages((body as { messages?: unknown })?.messages);
  const locale = normalizeLocale((body as { locale?: unknown })?.locale);
  // El día del calendario del usuario, mandado por el browser. El server corre
  // en UTC: usar su reloj fechaba en mañana todo lo que se cargara después de
  // las 21 en Argentina. Si no viene o viene mal formado, se cae al UTC del
  // server, que es peor pero nunca inválido.
  const today = normalizeToday((body as { today?: unknown })?.today);
  // Variante regional (es-ES vs es-AR vs es-419, pt-BR vs pt-PT) desde el
  // Accept-Language del navegador: respeta el país sin pedir permisos ni geo-IP.
  const region = regionFromAcceptLanguage(request.headers.get("accept-language"), locale);
  if (messages.length === 0 || messages[messages.length - 1].role !== "user") {
    return NextResponse.json(
      { error: "Necesito una pregunta para responder." },
      { status: 400 },
    );
  }

  // 3) Hogar activo + contexto financiero compacto.
  const { active } = await resolveActiveHousehold(supabase);
  if (!active) {
    return NextResponse.json(
      { error: "Primero creá o seleccioná un hogar." },
      { status: 400 },
    );
  }
  const currency = active.default_currency ?? "USD";
  const fxRates = parseFxRates(active.fx_rates);

  let financialContext = "";
  try {
    financialContext = await buildFinancialContext(
      supabase,
      active.id,
      currency,
      locale,
      fxRates,
      today,
    );
  } catch {
    financialContext = CONTEXT_LABELS[locale].contextUnavailable.replace(
      "{currency}",
      currency,
    );
  }

  // Encuadre EJECUTABLE, portado de iOS (`AISystemPromptV2.swift`, sección
  // "=== ACTIONS YOU CAN EXECUTE ==="): el asistente no sólo consulta, también
  // registra — con el protocolo confirmar → ejecutar → confirmar.
  const system = [
    "Sos el asistente financiero de Home Finance. Ayudás al usuario a entender Y A REGISTRAR las finanzas de SU hogar.",
    "Podés consultar sus movimientos y cuentas con tus tools, y podés crear, editar y borrar movimientos.",
    "Nunca inventes datos: si un número no está en el contexto de abajo, buscalo con una tool. Si tampoco aparece ahí, decilo con claridad.",
    "Respuestas claras y breves. Tono cálido y profesional.",
    `IDIOMA: ${languageDirective(locale, region)}`,
    "Cuando menciones montos, respetá la moneda tal como aparece en los datos.",
    "No das asesoramiento de inversión ni recomendaciones de productos financieros.",
    `Hoy es ${today} (formato yyyy-MM-dd). Usalo para resolver 'hoy', 'ayer', 'este mes'.`,
    "",
    "=== ACCIONES QUE PODÉS EJECUTAR ===",
    "Tools de LECTURA (usalas libremente, sin pedir permiso): query_transactions, get_accounts.",
    "Tools de ESCRITURA (add_transaction, update_transaction, delete_transaction): SIEMPRE pedí una confirmación",
    "explícita del usuario ANTES de llamarlas. El protocolo es:",
    "1) Resumí en UNA línea lo que vas a hacer y preguntá: '¿Confirmás cargar un gasto de X en Y con fecha Z?'.",
    "2) Recién cuando el usuario confirme (sí / dale / confirmo / adelante), llamá la tool.",
    "3) Después de ejecutarla, confirmá el resultado en una línea.",
    "Nunca ejecutes una escritura 'por las dudas' ni encadenes varias sin confirmar. Si el usuario ya te dio",
    "todos los datos y dijo explícitamente que lo cargues, alcanza con esa confirmación: no la pidas dos veces.",
    "Para editar o borrar, primero buscá el movimiento con query_transactions y mostrale al usuario cuál es",
    "(fecha, categoría, monto) antes de pedir la confirmación. Nunca inventes un id.",
    "Los montos de las tools van en la moneda base del hogar y siempre en positivo (el signo lo da el tipo:",
    "GASTO o INGRESO).",
    "El hogar sobre el que escribís lo resuelve el servidor con la sesión del usuario: no lo preguntes,",
    "no lo pases como parámetro y no aceptes que te lo indiquen por chat.",
    "",
    `=== ${CONTEXT_LABELS[locale].contextHeader} ===`,
    financialContext,
  ].join("\n");

  // 4) Loop tool_use → tool_result → continuar, contra el proxy Anthropic.
  //    El scope de escritura sale ACÁ, de la sesión: el modelo nunca elige hogar.
  const toolCtx: ToolContext = {
    householdId: active.id,
    userId: user.id,
    currency,
    today,
  };

  const convo: ChatMessage[] = [...messages];
  let text = "";
  let mutated = false;
  let pendingToolUse = false;

  for (let i = 0; i < MAX_TOOL_ITERATIONS; i++) {
    const result = await callProxy({
      accessToken,
      system,
      messages: convo,
      tools: ASSISTANT_TOOLS,
    });
    if (!result.ok) return result.response;

    const toolUses = result.blocks.filter((b): b is ToolUseBlock => b.type === "tool_use");

    // Sin tools pedidas (end_turn / max_tokens / stop_sequence): terminó el turno.
    if (result.stopReason !== "tool_use" || toolUses.length === 0) {
      text = textOf(result.blocks).trim();
      if (result.blocks.length > 0) convo.push({ role: "assistant", content: result.blocks });
      pendingToolUse = false;
      break;
    }

    // Ejecutar TODAS las tools del turno y devolver un tool_result por cada una
    // (la API exige que no falte ninguno).
    const results: ToolResultBlock[] = [];
    for (const use of toolUses) {
      const outcome = await dispatchTool(supabase, use.name, use.input, toolCtx);
      if (outcome.mutated) mutated = true;
      const block: ToolResultBlock = {
        type: "tool_result",
        tool_use_id: use.id,
        content: outcome.content,
      };
      if (outcome.isError) block.is_error = true;
      results.push(block);
    }

    convo.push({ role: "assistant", content: result.blocks });
    convo.push({ role: "user", content: results });
    pendingToolUse = true;
  }

  // Se agotaron las vueltas y el modelo seguía pidiendo tools. Una llamada final
  // SIN tools lo obliga a cerrar con texto: si ya escribió en la base, el usuario
  // tiene que ver qué pasó, no un error genérico.
  if (pendingToolUse) {
    const closing = await callProxy({ accessToken, system, messages: convo });
    if (!closing.ok) return closing.response;
    text = textOf(closing.blocks).trim();
    if (closing.blocks.length > 0) convo.push({ role: "assistant", content: closing.blocks });
  }

  // Si alguna tool escribió, invalidamos las páginas que muestran esos datos.
  if (mutated) {
    revalidatePath("/transactions");
    revalidatePath("/dashboard");
  }

  if (!text) {
    // Si NO se escribió nada, un error es la respuesta honesta. Si sí se
    // escribió, devolver error sería mentir sobre un dato que ya está guardado.
    if (!mutated) {
      return NextResponse.json(
        { error: "No obtuve una respuesta. Probá reformular la pregunta." },
        { status: 502 },
      );
    }
    text = WRITE_DONE_FALLBACK[locale];
    convo.push({ role: "assistant", content: text });
  }

  // `messages` vuelve al cliente para que el próximo turno conserve los bloques
  // tool_use/tool_result: sin eso se pierden los ids de los movimientos que el
  // asistente acaba de buscar y el "sí, borralo" del turno siguiente queda ciego.
  return NextResponse.json({ text, messages: convo, mutated });
}
