import { TrendingUp, TrendingDown } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Amount } from "@/components/finance/amount";
import { SectionHeader } from "@/components/finance/section-header";
import { createClient } from "@/lib/supabase/server";
import { getSpendingInsights, insightCopy } from "@/lib/db/insights";
import { getT } from "@/lib/i18n/server";

/**
 * Insights proactivos de gasto (ítem 4.3b). Sección async propia con el mismo
 * patrón que el resto de `sections/`: la page la envuelve en `<Suspense>` con su
 * skeleton y acá adentro fetcheamos y pintamos.
 *
 * ── Caso "0 insights" ────────────────────────────────────────────────────────
 * El RPC sólo devuelve desvíos ≥ 25 %: lo NORMAL es que no devuelva nada. En ese
 * caso la sección **no renderiza nada** (`null`), igual que `SparklinesSection`
 * cuando no hay movimientos. Preferimos eso a una card de "todo tranquilo"
 * permanente: en un dashboard ya denso, un bloque que está vacío 9 de cada 10
 * meses entrena al usuario a ignorar esa zona, y justo ahí es donde aparece la
 * alerta que sí importa. La sección se gana el espacio sólo cuando tiene algo
 * que decir. (Y como incluye su propio encabezado, devolver `null` no deja una
 * card vacía colgada en el shell.)
 *
 * ── Color ────────────────────────────────────────────────────────────────────
 * NO usamos la semántica gasto/ingreso (coral/verde = pérdida/ganancia): gastar
 * más no es "malo" per se ni gastar menos es "bueno" per se. El color comunica
 * **atención** (champagne) vs. **vas bien** (income), y el MONTO va en neutro
 * (`kind="neutral"`) porque es un dato, no un juicio.
 */
export async function InsightsSection({
  householdId,
  currency,
  limit = 4,
}: {
  householdId: string;
  currency: string;
  limit?: number;
}) {
  const supabase = await createClient();
  const [insights, t] = await Promise.all([
    getSpendingInsights(supabase, householdId, limit),
    getT(),
  ]);

  // Mes tranquilo: nada que mostrar (ver comentario arriba).
  if (insights.length === 0) return null;

  return (
    <section>
      <SectionHeader
        title={t("dashboard.insightsTitle")}
        subtitle={t("dashboard.insightsSubtitle")}
      />
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4">
        {insights.map((insight) => {
          const copy = insightCopy(insight);
          const attention = copy.tone === "attention";
          const Icon = insight.direction === "subio" ? TrendingUp : TrendingDown;
          return (
            <Card
              key={`${insight.direction}-${insight.category}`}
              className="flex items-start gap-3 p-4 sm:p-5"
            >
              <span
                className={`flex size-9 shrink-0 items-center justify-center rounded-[var(--radius-md)] ${
                  attention
                    ? "bg-champagne/15 text-champagne"
                    : "bg-income/15 text-income"
                }`}
              >
                <Icon className="size-[18px]" aria-hidden="true" />
              </span>

              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between gap-2">
                  <p className="truncate text-sm font-medium">
                    {insight.category}
                  </p>
                  <Amount
                    value={insight.actual}
                    currency={currency}
                    kind="neutral"
                    className="shrink-0 text-sm font-semibold"
                  />
                </div>

                <p className="text-text-muted mt-1.5 text-xs leading-relaxed">
                  {t(copy.key, copy.vars)}
                </p>

                <div className="mt-2.5 flex flex-wrap items-center gap-x-2 gap-y-1">
                  <Badge variant={attention ? "warning" : "income"}>
                    {t(
                      attention
                        ? "dashboard.insightAttention"
                        : "dashboard.insightPositive",
                    )}
                  </Badge>
                  <span className="text-text-dim inline-flex items-center gap-1 text-[11px]">
                    {t("dashboard.insightAverage")}
                    <Amount
                      value={insight.average}
                      currency={currency}
                      kind="neutral"
                      style="compact"
                      className="text-[11px]"
                    />
                  </span>
                </div>
              </div>
            </Card>
          );
        })}
      </div>
    </section>
  );
}
