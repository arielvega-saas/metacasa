import type { LocaleModule } from "./types";

/**
 * Análisis AVANZADOS de la pantalla de Reportes (Pareto 80/20, comparación
 * mes a mes, tendencia de tasa de ahorro y score de salud financiera).
 *
 * Namespace `reports`: usa SOLO claves nuevas (`paretoTitle`, `healthScore`,
 * `momTitle`, …) para que el deep-merge del diccionario las AGREGUE al
 * namespace existente sin pisar las claves base de `insights.ts`.
 *
 * Espeja el `ReportsView` de iOS (`Features/Reports/ReportsView.swift` +
 * `CompareMonthsView.swift`). ES = copy de producto; EN/PT = tono fintech.
 */
export const reportsAdvanced: LocaleModule = {
  es: {
    reports: {
      // ── Pareto 80/20 ───────────────────────────────────────────
      paretoTitle: "Regla 80/20 (Pareto)",
      paretoSubtitle: "Pocas categorías concentran la mayor parte del gasto",
      paretoCumulative: "Acumulado",
      paretoThreshold: "Umbral 80%",
      paretoVital: "Pocas vitales",
      paretoTrivial: "Muchas triviales",
      paretoInsight: "{count} categorías concentran el 80% de tu gasto.",
      paretoInsightOne: "1 categoría concentra el 80% de tu gasto.",
      paretoEmptyTitle: "Sin datos para Pareto",
      paretoEmptyDesc: "Registrá gastos este mes para ver qué los concentra.",

      // ── Comparación mes a mes ──────────────────────────────────
      momTitle: "Mes vs mes anterior",
      momSubtitle: "{current} comparado con {previous}",
      momIncome: "Ingresos",
      realChangeLabel: "Gasto real, descontando inflación",
      realChangeBetter: "En pesos comparables gastaste menos que el mes pasado.",
      realChangeWorse: "En pesos comparables gastaste más que el mes pasado.",
      momExpense: "Gastos",
      momBalance: "Balance",
      momDelta: "Variación",
      momNoChange: "Sin cambios",
      momVsPrev: "vs mes anterior",
      momEmptyTitle: "Sin comparación disponible",
      momEmptyDesc: "Necesitás movimientos en este mes y en el anterior.",

      // ── Tendencia de tasa de ahorro ────────────────────────────
      savingsTrendTitle: "Tendencia de tu tasa de ahorro",
      savingsTrendSubtitle: "% del ingreso que te queda, mes a mes",
      savingsTrendLegend: "Tasa de ahorro",
      savingsTrendAvg: "Promedio {value}%",
      savingsTrendEmptyTitle: "Sin tendencia todavía",
      savingsTrendEmptyDesc:
        "Cuando tengas ingresos en varios meses, vas a ver acá cómo evoluciona tu ahorro.",

      // ── Score de salud financiera ──────────────────────────────
      healthScore: "Salud financiera",
      healthScoreSubtitle: "Un puntaje de 0 a 100 sobre cómo venís este mes",
      healthOf100: "/ 100",
      healthExcellent: "Excelente",
      healthGood: "Bien",
      healthFair: "Regular",
      healthPoor: "A mejorar",
      healthBreakdown: "Qué lo compone",
      healthFactorSavings: "Tasa de ahorro",
      healthFactorSavingsHint: "Cuánto del ingreso te queda (ideal ≥ 20%)",
      healthFactorRatio: "Gasto vs ingreso",
      healthFactorRatioHint: "Premia gastar menos de lo que ingresás",
      healthFactorActivity: "Constancia",
      healthFactorActivityHint: "Días con registros en los últimos 30",
      healthPoints: "{value} / {max} pts",
      healthEmptyTitle: "Sin score todavía",
      healthEmptyDesc: "Registrá ingresos y gastos este mes para calcular tu salud financiera.",
    },
  },
  en: {
    reports: {
      paretoTitle: "80/20 rule (Pareto)",
      paretoSubtitle: "A few categories drive most of your spending",
      paretoCumulative: "Cumulative",
      paretoThreshold: "80% threshold",
      paretoVital: "Vital few",
      paretoTrivial: "Trivial many",
      paretoInsight: "{count} categories drive 80% of your spending.",
      paretoInsightOne: "1 category drives 80% of your spending.",
      paretoEmptyTitle: "No data for Pareto",
      paretoEmptyDesc: "Log expenses this month to see what concentrates them.",

      momTitle: "Month vs previous",
      momSubtitle: "{current} compared to {previous}",
      momIncome: "Income",
      realChangeLabel: "Real spending, inflation removed",
      realChangeBetter: "In comparable money you spent less than last month.",
      realChangeWorse: "In comparable money you spent more than last month.",
      momExpense: "Expenses",
      momBalance: "Balance",
      momDelta: "Change",
      momNoChange: "No change",
      momVsPrev: "vs previous month",
      momEmptyTitle: "No comparison available",
      momEmptyDesc: "You need activity in this month and the previous one.",

      savingsTrendTitle: "Your savings-rate trend",
      savingsTrendSubtitle: "% of income you keep, month by month",
      savingsTrendLegend: "Savings rate",
      savingsTrendAvg: "Average {value}%",
      savingsTrendEmptyTitle: "No trend yet",
      savingsTrendEmptyDesc:
        "Once you have income across several months, you'll see how your savings evolve here.",

      healthScore: "Financial health",
      healthScoreSubtitle: "A 0–100 score on how you're doing this month",
      healthOf100: "/ 100",
      healthExcellent: "Excellent",
      healthGood: "Good",
      healthFair: "Fair",
      healthPoor: "Needs work",
      healthBreakdown: "What drives it",
      healthFactorSavings: "Savings rate",
      healthFactorSavingsHint: "How much of your income you keep (ideal ≥ 20%)",
      healthFactorRatio: "Spending vs income",
      healthFactorRatioHint: "Rewards spending less than you earn",
      healthFactorActivity: "Consistency",
      healthFactorActivityHint: "Days with entries in the last 30",
      healthPoints: "{value} / {max} pts",
      healthEmptyTitle: "No score yet",
      healthEmptyDesc: "Log income and expenses this month to compute your financial health.",
    },
  },
  pt: {
    reports: {
      paretoTitle: "Regra 80/20 (Pareto)",
      paretoSubtitle: "Poucas categorias concentram a maior parte do gasto",
      paretoCumulative: "Acumulado",
      paretoThreshold: "Limite 80%",
      paretoVital: "Poucas vitais",
      paretoTrivial: "Muitas triviais",
      paretoInsight: "{count} categorias concentram 80% do seu gasto.",
      paretoInsightOne: "1 categoria concentra 80% do seu gasto.",
      paretoEmptyTitle: "Sem dados para Pareto",
      paretoEmptyDesc: "Registre despesas neste mês para ver o que as concentra.",

      momTitle: "Mês vs anterior",
      momSubtitle: "{current} comparado com {previous}",
      momIncome: "Receitas",
      realChangeLabel: "Gasto real, descontando a inflação",
      realChangeBetter: "Em valores comparáveis você gastou menos que no mês passado.",
      realChangeWorse: "Em valores comparáveis você gastou mais que no mês passado.",
      momExpense: "Despesas",
      momBalance: "Saldo",
      momDelta: "Variação",
      momNoChange: "Sem mudança",
      momVsPrev: "vs mês anterior",
      momEmptyTitle: "Sem comparação disponível",
      momEmptyDesc: "Você precisa de movimentos neste mês e no anterior.",

      savingsTrendTitle: "Tendência da sua taxa de economia",
      savingsTrendSubtitle: "% da receita que você guarda, mês a mês",
      savingsTrendLegend: "Taxa de economia",
      savingsTrendAvg: "Média {value}%",
      savingsTrendEmptyTitle: "Ainda sem tendência",
      savingsTrendEmptyDesc:
        "Quando tiver receitas em vários meses, verá aqui como sua economia evolui.",

      healthScore: "Saúde financeira",
      healthScoreSubtitle: "Uma nota de 0 a 100 sobre como você está este mês",
      healthOf100: "/ 100",
      healthExcellent: "Excelente",
      healthGood: "Bom",
      healthFair: "Regular",
      healthPoor: "A melhorar",
      healthBreakdown: "O que compõe",
      healthFactorSavings: "Taxa de economia",
      healthFactorSavingsHint: "Quanto da receita você guarda (ideal ≥ 20%)",
      healthFactorRatio: "Gasto vs receita",
      healthFactorRatioHint: "Premia gastar menos do que você ganha",
      healthFactorActivity: "Constância",
      healthFactorActivityHint: "Dias com registros nos últimos 30",
      healthPoints: "{value} / {max} pts",
      healthEmptyTitle: "Ainda sem nota",
      healthEmptyDesc: "Registre receitas e despesas neste mês para calcular sua saúde financeira.",
    },
  },
};
