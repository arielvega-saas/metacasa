import type { Client } from "@/lib/supabase/types";

/**
 * Insights proactivos de gasto (ítem 4.3b).
 *
 * Fuente: el RPC `public.spending_insights(p_household, p_limit)`, que compara
 * el gasto por categoría del mes EN CURSO contra el promedio de los 3 meses
 * previos y devuelve SOLO los desvíos ≥ 25 % (o sea: puede devolver 0 filas, y
 * ese es el caso normal cuando el mes viene parejo).
 *
 * Todo lo que no toca la red vive acá como función pura y testeada
 * (`lib/db/__tests__/insights.test.ts`): normalización de filas y armado de la
 * frase. El componente sólo pinta.
 */

/** Dirección del desvío tal como la devuelve el RPC. */
export type InsightDirection = "subio" | "bajo";

/**
 * Tono del insight. NO es ganancia/pérdida: `attention` = "mirá esto",
 * `positive` = "vas bien". Gastar más no es "rojo" automáticamente.
 */
export type InsightTone = "attention" | "positive";

/** Un desvío de gasto ya normalizado (camelCase, números garantizados). */
export interface SpendingInsight {
  /** Categoría de gasto (texto libre del hogar). */
  category: string;
  /** Gasto del mes en curso en esa categoría, en moneda base del hogar. */
  actual: number;
  /** Promedio de los 3 meses previos, misma moneda. */
  average: number;
  /** Desvío en % contra el promedio. Siempre POSITIVO: el signo lo lleva `direction`. */
  deltaPct: number;
  direction: InsightDirection;
}

/** Fila cruda del RPC (los `numeric` de Postgres pueden llegar como string). */
interface SpendingInsightRow {
  category: string | null;
  actual: number | string | null;
  promedio: number | string | null;
  delta_pct: number | string | null;
  direccion: string | null;
}

/** Copy listo para `t()`: clave i18n + variables a interpolar + tono. */
export interface InsightCopy {
  /** Clave del diccionario (`dashboard.insightUp` / `dashboard.insightDown`). */
  key: string;
  vars: { pct: number; category: string };
  tone: InsightTone;
}

function toNumber(v: number | string | null | undefined): number {
  const n = typeof v === "string" ? Number(v) : (v ?? 0);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Normaliza las filas del RPC.
 *
 * - Descarta filas sin categoría (no hay nada que contarle al usuario).
 * - Coerce a número: PostgREST puede serializar `numeric` como string.
 * - `deltaPct` queda SIEMPRE positivo; la semántica va en `direction`.
 * - Si `direccion` no es un valor conocido, la deducimos del signo de
 *   `delta_pct` en vez de asumir "subio" (mentir hacia "atención" es peor que
 *   mentir hacia "bien", pero acá simplemente no adivinamos).
 */
export function normalizeSpendingInsights(
  rows: readonly SpendingInsightRow[] | null | undefined,
): SpendingInsight[] {
  const out: SpendingInsight[] = [];
  for (const r of rows ?? []) {
    const category = (r?.category ?? "").trim();
    if (!category) continue;

    const delta = toNumber(r.delta_pct);
    const raw = (r.direccion ?? "").trim().toLowerCase();
    const direction: InsightDirection =
      raw === "subio" || raw === "bajo"
        ? (raw as InsightDirection)
        : delta < 0
          ? "bajo"
          : "subio";

    out.push({
      category,
      actual: toNumber(r.actual),
      average: toNumber(r.promedio),
      deltaPct: Math.abs(delta),
      direction,
    });
  }
  return out;
}

/**
 * Arma la frase natural del insight (clave i18n + variables) y su tono.
 *
 * El % se redondea a entero: "Gastaste 150 % más en Delivery" se lee, "150,3 %"
 * no. El mínimo es 1 % para no producir la frase absurda "gastaste 0 % más".
 */
export function insightCopy(insight: SpendingInsight): InsightCopy {
  const pct = Math.max(1, Math.round(insight.deltaPct));
  return insight.direction === "subio"
    ? {
        key: "dashboard.insightUp",
        vars: { pct, category: insight.category },
        tone: "attention",
      }
    : {
        key: "dashboard.insightDown",
        vars: { pct, category: insight.category },
        tone: "positive",
      };
}

/**
 * Desvíos de gasto del hogar (mes en curso vs. promedio de 3 meses).
 *
 * Devuelve `[]` cuando no hay nada raro — es el caso NORMAL, no un error: la
 * sección del dashboard directamente no se renderiza. Si el RPC falla tampoco
 * queremos tumbar el dashboard entero: devolvemos `[]` y seguimos.
 *
 * RLS valida la pertenencia al hogar; igual pasamos `p_household` explícito.
 */
export async function getSpendingInsights(
  supabase: Client,
  householdId: string,
  limit = 5,
): Promise<SpendingInsight[]> {
  const { data, error } = await supabase.rpc("spending_insights", {
    p_household: householdId,
    p_limit: limit,
  });
  if (error) return [];
  return normalizeSpendingInsights(data as SpendingInsightRow[] | null);
}
