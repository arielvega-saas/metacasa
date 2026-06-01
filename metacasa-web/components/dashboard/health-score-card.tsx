import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { Card } from "@/components/ui/card";
import { getT } from "@/lib/i18n/server";

/**
 * Card de Salud financiera. SERVER COMPONENT puro (recibe `score` 0–100 +
 * `streak` ya calculados). Paridad con iOS `HealthScoreCard`: anillo de progreso
 * con el puntaje, etiqueta cualitativa por tramos (≥75 excelente, ≥55 buena,
 * ≥35 aceptable, resto a mejorar) y chip de racha 🔥. Linkea a /reports para el
 * detalle (igual que iOS abre ReportsView).
 *
 * El puntaje NO se muestra cuando `score` es null (sin datos suficientes): la UI
 * la decide el caller no montando la card.
 */
export interface HealthScoreCardProps {
  /** Puntaje 0–100. */
  score: number;
  /** Racha de días consecutivos con movimientos (0 = sin racha). */
  streak: number;
}

function tier(score: number) {
  if (score >= 75) return { key: "healthExcellent", color: "text-income", ring: "var(--color-income)" } as const;
  if (score >= 55) return { key: "healthGood", color: "text-primary", ring: "var(--color-sage)" } as const;
  if (score >= 35) return { key: "healthFair", color: "text-champagne", ring: "var(--color-champagne)" } as const;
  return { key: "healthPoor", color: "text-expense", ring: "var(--color-expense)" } as const;
}

export async function HealthScoreCard({ score, streak }: HealthScoreCardProps) {
  const t = await getT();
  const clamped = Math.max(0, Math.min(100, Math.round(score)));
  const { key, color, ring } = tier(clamped);

  // Anillo: conic-gradient marca el porcentaje; el centro queda hueco con un
  // disco del color de fondo de la card.
  const ringStyle = {
    background: `conic-gradient(${ring} ${clamped * 3.6}deg, color-mix(in srgb, ${ring} 16%, transparent) 0deg)`,
  };

  return (
    <Card className="p-5">
      <Link href="/reports" className="flex items-center gap-4">
        <div
          className="relative flex size-14 shrink-0 items-center justify-center rounded-full"
          style={ringStyle}
          aria-hidden="true"
        >
          <div className="bg-card flex size-11 items-center justify-center rounded-full">
            <span className={`font-num text-lg ${color}`}>{clamped}</span>
          </div>
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
            {t("dashboard.healthTitle")}
          </p>
          <p className={`text-sm font-bold ${color}`}>{t(`dashboard.${key}`)}</p>
          {streak > 0 ? (
            <p className="text-champagne mt-0.5 text-xs font-medium">
              {t("dashboard.healthStreak", { days: streak })}
            </p>
          ) : (
            <p className="text-text-dim mt-0.5 text-xs">{t("dashboard.healthHint")}</p>
          )}
        </div>
        <ChevronRight className="text-text-muted size-4 shrink-0" />
      </Link>
    </Card>
  );
}
