import type { LocaleModule } from "./types";

/**
 * Secciones EXTRA de la pantalla de Reportes: Heatmap de gasto diario (estilo
 * GitHub) + Vista anual (12 meses con ingresos/gastos/balance + chart).
 *
 * Namespace `reports`: usa SOLO claves nuevas (`heatmapTitle`, `annualTitle`,
 * …) para que el deep-merge del diccionario las AGREGUE al namespace existente
 * sin pisar las claves base de `insights.ts` ni de `reports-advanced.ts`.
 *
 * Espeja `Features/Reports/SpendingHeatmapView.swift` y `AnnualView.swift` de
 * iOS. ES = copy de producto; EN/PT = tono fintech.
 */
export const reportsExtra: LocaleModule = {
  es: {
    reports: {
      // ── Heatmap de gasto diario ────────────────────────────────
      heatmapTitle: "Mapa de gasto diario",
      heatmapSubtitle: "Tus gastos día a día durante el año",
      heatmapTotal: "Total del año",
      activeDays: "Días con gasto",
      avgPerDay: "Promedio por día",
      heatmapLess: "Menos",
      heatmapMore: "Más",
      heatmapHint: "Tocá un día para ver cuánto gastaste.",
      heatmapNoSpend: "Sin gastos ese día",
      heatmapSelectDay: "Elegí un día del mapa para ver el detalle.",
      heatmapEmptyTitle: "Sin gastos este año",
      heatmapEmptyDesc: "Cuando registres gastos vas a ver acá tu mapa de actividad.",

      // ── Vista anual ────────────────────────────────────────────
      annualTitle: "Vista anual",
      annualSubtitle: "Ingresos, gastos y balance de los 12 meses",
      yearIncome: "Ingresos del año",
      yearExpense: "Gastos del año",
      yearBalance: "Balance del año",
      annualEvolution: "Evolución mensual",
      annualEmptyTitle: "Sin movimientos este año",
      annualEmptyDesc: "Registrá ingresos o gastos para ver tu resumen anual.",

      // ── Selector de año (compartido por ambas secciones) ───────
      prevYear: "Año anterior",
      nextYear: "Año siguiente",
    },
  },
  en: {
    reports: {
      heatmapTitle: "Daily spending map",
      heatmapSubtitle: "Your day-by-day spending across the year",
      heatmapTotal: "Year total",
      activeDays: "Days with spend",
      avgPerDay: "Average per day",
      heatmapLess: "Less",
      heatmapMore: "More",
      heatmapHint: "Tap a day to see how much you spent.",
      heatmapNoSpend: "No spending that day",
      heatmapSelectDay: "Pick a day on the map to see the detail.",
      heatmapEmptyTitle: "No spending this year",
      heatmapEmptyDesc: "Once you log expenses, your activity map will appear here.",

      annualTitle: "Annual view",
      annualSubtitle: "Income, expenses and balance across 12 months",
      yearIncome: "Income this year",
      yearExpense: "Expenses this year",
      yearBalance: "Balance this year",
      annualEvolution: "Monthly evolution",
      annualEmptyTitle: "No activity this year",
      annualEmptyDesc: "Log income or expenses to see your annual summary.",

      prevYear: "Previous year",
      nextYear: "Next year",
    },
  },
  pt: {
    reports: {
      heatmapTitle: "Mapa de gasto diário",
      heatmapSubtitle: "Seus gastos dia a dia ao longo do ano",
      heatmapTotal: "Total do ano",
      activeDays: "Dias com gasto",
      avgPerDay: "Média por dia",
      heatmapLess: "Menos",
      heatmapMore: "Mais",
      heatmapHint: "Toque em um dia para ver quanto gastou.",
      heatmapNoSpend: "Sem gastos nesse dia",
      heatmapSelectDay: "Escolha um dia no mapa para ver o detalhe.",
      heatmapEmptyTitle: "Sem gastos neste ano",
      heatmapEmptyDesc: "Quando registrar gastos, verá aqui seu mapa de atividade.",

      annualTitle: "Visão anual",
      annualSubtitle: "Receitas, despesas e saldo dos 12 meses",
      yearIncome: "Receitas do ano",
      yearExpense: "Despesas do ano",
      yearBalance: "Saldo do ano",
      annualEvolution: "Evolução mensal",
      annualEmptyTitle: "Sem movimentos neste ano",
      annualEmptyDesc: "Registre receitas ou despesas para ver seu resumo anual.",

      prevYear: "Ano anterior",
      nextYear: "Próximo ano",
    },
  },
};
