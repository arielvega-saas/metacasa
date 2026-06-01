import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listAccountsWithBalance } from "@/lib/db/accounts";
import { getMonthSummary, getCategoryBreakdown } from "@/lib/db/transactions";
import { upcomingBills } from "@/lib/db/bills";
import { listGoals } from "@/lib/db/goals";
import { formatMoney } from "@/lib/money";
import { parseFxRates, convertToBase, canConvertAll, type FXRateMap } from "@/lib/fx";

export const runtime = "nodejs";
// El contexto depende del usuario; nunca cachear la respuesta.
export const dynamic = "force-dynamic";

/** Un turno del chat tal como llega del cliente. */
type ChatMessage = { role: "user" | "assistant"; content: string };

type Locale = "es" | "en" | "pt";

/** Normaliza el locale recibido del widget a uno soportado (default ES). */
function normalizeLocale(locale: unknown): Locale {
  return locale === "en" || locale === "pt" ? locale : "es";
}

/** Instrucción de idioma de respuesta según el locale de la web (default ES). */
function languageDirective(locale: Locale): string {
  switch (locale) {
    case "en":
      return "Always reply in English, regardless of the language of the question.";
    case "pt":
      return "Responda sempre em português do Brasil, independentemente do idioma da pergunta.";
    case "es":
    default:
      return "Respondé siempre en español rioplatense (tratá de vos: 'tenés', 'fijate'), sin importar el idioma de la pregunta.";
  }
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

/** Tag BCP-47 para `toLocaleDateString` del mes actual, por locale. */
const MONTH_LOCALE_TAG: Record<Locale, string> = {
  es: "es-AR",
  en: "en-US",
  pt: "pt-BR",
};

/** Valida y normaliza el historial de mensajes recibido en el body. */
function sanitizeMessages(raw: unknown): ChatMessage[] {
  if (!Array.isArray(raw)) return [];
  const out: ChatMessage[] = [];
  for (const m of raw) {
    if (!m || typeof m !== "object") continue;
    const role = (m as { role?: unknown }).role;
    const content = (m as { content?: unknown }).content;
    if ((role !== "user" && role !== "assistant") || typeof content !== "string") {
      continue;
    }
    const trimmed = content.trim();
    if (!trimmed) continue;
    // Tope defensivo de tamaño por mensaje (no abusar del proxy).
    out.push({ role, content: trimmed.slice(0, 4000) });
  }
  // Quedarnos con la cola más reciente: contexto suficiente, payload acotado.
  return out.slice(-20);
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
): Promise<string> {
  const L = CONTEXT_LABELS[locale];
  const fmt = (s: string, vars?: Record<string, string | number>) =>
    vars
      ? s.replace(/\{(\w+)\}/g, (_, k) => String(vars[k] ?? `{${k}}`))
      : s;

  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  const monthLabel = now.toLocaleDateString(MONTH_LOCALE_TAG[locale], {
    month: "long",
    year: "numeric",
  });

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
    );
  } catch {
    financialContext = CONTEXT_LABELS[locale].contextUnavailable.replace(
      "{currency}",
      currency,
    );
  }

  const system = [
    "Sos el asistente financiero de Home Finance. Ayudás al usuario a entender las finanzas de SU hogar.",
    "Usá SOLO los datos provistos abajo; si no sabés algo o el dato no está, decílo con claridad y no lo inventes.",
    "Respuestas claras y breves. Tono cálido y profesional.",
    `IDIOMA: ${languageDirective(locale)}`,
    "Cuando menciones montos, respetá la moneda tal como aparece en los datos.",
    "No das asesoramiento de inversión ni recomendaciones de productos financieros.",
    "",
    `=== ${CONTEXT_LABELS[locale].contextHeader} ===`,
    financialContext,
  ].join("\n");

  // 4) Llamada al proxy Anthropic (NON-streaming). Nunca logueamos el token.
  const proxyUrl = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/ai-proxy`;
  let proxyRes: Response;
  try {
    proxyRes = await fetch(proxyUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ system, messages, max_tokens: 700 }),
      cache: "no-store",
    });
  } catch {
    return NextResponse.json(
      { error: "No pude conectarme con el asistente. Probá de nuevo en un momento." },
      { status: 502 },
    );
  }

  if (!proxyRes.ok) {
    if (proxyRes.status === 401) {
      return NextResponse.json(
        { error: "Tu sesión expiró. Volvé a iniciar sesión." },
        { status: 401 },
      );
    }
    if (proxyRes.status === 429) {
      return NextResponse.json(
        {
          error:
            "Llegaste al límite de consultas por hoy. Probá de nuevo mañana.",
        },
        { status: 429 },
      );
    }
    return NextResponse.json(
      { error: "El asistente no está disponible ahora. Probá más tarde." },
      { status: 502 },
    );
  }

  let data: unknown;
  try {
    data = await proxyRes.json();
  } catch {
    return NextResponse.json(
      { error: "El asistente devolvió una respuesta inesperada." },
      { status: 502 },
    );
  }

  const text = extractText(data).trim();
  if (!text) {
    return NextResponse.json(
      { error: "No obtuve una respuesta. Probá reformular la pregunta." },
      { status: 502 },
    );
  }

  return NextResponse.json({ text });
}
