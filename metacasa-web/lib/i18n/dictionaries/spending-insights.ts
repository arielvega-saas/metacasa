import type { LocaleModule } from "./types";

/**
 * Diccionario de los INSIGHTS PROACTIVOS de gasto del dashboard (ítem 4.3b).
 *
 * Namespace `dashboard` (claves NUEVAS: deep-merge aditivo sobre `dashboard-tx`
 * y `dashboard-extras`, sin pisar nada). Alimentan
 * `components/dashboard/sections/insights-section.tsx`, que arma la frase con
 * `insightCopy()` de `lib/db/insights.ts`.
 *
 * Interpolación: `{pct}` (desvío en % contra el promedio, siempre positivo) y
 * `{category}` (categoría de gasto del hogar). El ES es rioplatense ("gastaste").
 */
export const spendingInsights: LocaleModule = {
  es: {
    dashboard: {
      insightsTitle: "Qué cambió este mes",
      insightsSubtitle: "Contra tu promedio de los últimos 3 meses",
      insightUp:
        "Gastaste {pct}% más en {category} que tu promedio de los últimos 3 meses",
      insightDown:
        "Gastaste {pct}% menos en {category} que tu promedio de los últimos 3 meses",
      insightAverage: "Promedio 3 meses",
      insightAttention: "Atención",
      insightPositive: "Bien",
    },
  },
  en: {
    dashboard: {
      insightsTitle: "What changed this month",
      insightsSubtitle: "Compared with your last 3-month average",
      insightUp:
        "You spent {pct}% more on {category} than your last 3-month average",
      insightDown:
        "You spent {pct}% less on {category} than your last 3-month average",
      insightAverage: "3-month average",
      insightAttention: "Heads-up",
      insightPositive: "Nice",
    },
  },
  pt: {
    dashboard: {
      insightsTitle: "O que mudou neste mês",
      insightsSubtitle: "Comparado com sua média dos últimos 3 meses",
      insightUp:
        "Você gastou {pct}% a mais em {category} do que sua média dos últimos 3 meses",
      insightDown:
        "Você gastou {pct}% a menos em {category} do que sua média dos últimos 3 meses",
      insightAverage: "Média de 3 meses",
      insightAttention: "Atenção",
      insightPositive: "Muito bem",
    },
  },
};
