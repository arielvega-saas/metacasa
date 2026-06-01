"use client";

// Score de salud financiera 0–100 con desglose de qué lo compone.
// Presentador puro: el cálculo vive en `reports/page.tsx` (server) y espeja la
// fórmula de iOS `ReportsView.swift` → `healthScore`:
//   • Tasa de ahorro:   min(50, max(0,(ing−gas)/ing) · 250)   → 20% rate = 50 pts
//   • Gasto vs ingreso:  ratio<1 ⇒ (1−ratio)·30                → hasta 30 pts
//   • Constancia:        min(20, díasConTx30 · 0.67)           → 30 días = 20 pts
// El color del tramo (≥75 excelente, ≥55 bien, ≥35 regular, resto a mejorar)
// también es paridad con iOS.
import { Heart } from "lucide-react";
import { useT } from "@/components/i18n/locale-provider";
import { healthColor } from "./chart-tokens";

export interface HealthFactor {
  key: "savings" | "ratio" | "activity";
  /** Puntos obtenidos (redondeados). */
  value: number;
  /** Puntos máximos del factor. */
  max: number;
}

export interface HealthScoreData {
  score: number;
  factors: HealthFactor[];
}

const FACTOR_LABEL: Record<HealthFactor["key"], { label: string; hint: string }> = {
  savings: {
    label: "reports.healthFactorSavings",
    hint: "reports.healthFactorSavingsHint",
  },
  ratio: {
    label: "reports.healthFactorRatio",
    hint: "reports.healthFactorRatioHint",
  },
  activity: {
    label: "reports.healthFactorActivity",
    hint: "reports.healthFactorActivityHint",
  },
};

function bandKey(score: number): string {
  if (score >= 75) return "reports.healthExcellent";
  if (score >= 55) return "reports.healthGood";
  if (score >= 35) return "reports.healthFair";
  return "reports.healthPoor";
}

export function HealthScore({
  data,
  className,
}: {
  data: HealthScoreData;
  className?: string;
}) {
  const t = useT();
  const score = Math.max(0, Math.min(100, Math.round(data.score)));
  const color = healthColor(score);
  const band = t(bandKey(score));

  return (
    <div className={className}>
      <div className="flex items-center justify-between gap-3">
        <span className="text-text-muted flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wider">
          <Heart className="size-4" style={{ color }} />
          {t("reports.healthScore")}
        </span>
        <span
          className="rounded-full px-2.5 py-1 text-xs font-bold"
          style={{ color, backgroundColor: `${color}2e` }}
        >
          {band}
        </span>
      </div>

      {/* Número grande + barra de progreso del total. */}
      <div className="mt-3 flex items-baseline gap-1.5">
        <span className="font-num tnum text-[52px] leading-none" style={{ color }}>
          {score}
        </span>
        <span className="text-text-muted text-lg">{t("reports.healthOf100")}</span>
      </div>
      <div
        className="bg-inset mt-3 h-2 overflow-hidden rounded-full"
        role="progressbar"
        aria-valuenow={score}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <div
          className="h-full rounded-full transition-[width]"
          style={{ width: `${score}%`, backgroundColor: color }}
        />
      </div>

      {/* Desglose transparente de los 3 factores. */}
      <p className="text-text-muted mt-5 mb-2 text-[11px] font-semibold uppercase tracking-wider">
        {t("reports.healthBreakdown")}
      </p>
      <ul className="space-y-3">
        {data.factors.map((f) => {
          const pct = f.max > 0 ? Math.round((f.value / f.max) * 100) : 0;
          const meta = FACTOR_LABEL[f.key];
          return (
            <li key={f.key}>
              <div className="mb-1 flex items-center justify-between gap-3">
                <span className="text-sm font-medium text-foreground">
                  {t(meta.label)}
                </span>
                <span className="text-text-dim tnum text-xs">
                  {t("reports.healthPoints", { value: f.value, max: f.max })}
                </span>
              </div>
              <div className="bg-inset h-1.5 overflow-hidden rounded-full">
                <div
                  className="h-full rounded-full"
                  style={{ width: `${pct}%`, backgroundColor: color }}
                />
              </div>
              <p className="text-text-dim mt-1 text-[11px]">{t(meta.hint)}</p>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
