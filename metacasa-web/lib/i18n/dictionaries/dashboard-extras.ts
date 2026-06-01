import type { LocaleModule } from "./types";

/**
 * Diccionario de los widgets EXTRA del dashboard + el botón de ejecutar
 * recurrentes. Namespaces: `dashboard` (claves NUEVAS, deep-merge ADITIVO sobre
 * `dashboard-tx.ts`) y `recurring` (un par de claves nuevas para el run).
 *
 * Paridad iOS `HomeView`: sparklines de ingreso/gasto, Savings/Investment split
 * (`SavingsInvestmentCard`), Health Score (`HealthScoreCard` + `reports.health`).
 * Las claves son nuevas (`sparklineIncome`, `savingsSplit`, `runRecurring`, …)
 * para no colisionar con las existentes.
 */
export const dashboardExtras: LocaleModule = {
  es: {
    dashboard: {
      // Sparklines (tendencia de los últimos 7 días)
      sparklineIncome: "Ingresos · últimos 7 días",
      sparklineExpense: "Gastos · últimos 7 días",
      sparklineEmpty: "Sin movimientos en 7 días",
      // Patrimonio neto (montado en el dashboard)
      netWorthTitle: "Patrimonio neto",
      // Savings / Investment split
      savingsSplit: "Ahorro e inversión",
      savingsSplitSubtitle: "Sobre tus ingresos del mes",
      savingsLabel: "Ahorro",
      investmentLabel: "Inversión",
      savingsSplitEmpty: "Registrá ingresos este mes para ver tu reparto.",
      savingsSplitUnset:
        "Configurá tus porcentajes de ahorro e inversión para ver el reparto.",
      // Health Score
      healthTitle: "Salud financiera",
      healthExcellent: "Excelente",
      healthGood: "Buena",
      healthFair: "Aceptable",
      healthPoor: "A mejorar",
      healthStreak: "🔥 {days} días seguidos",
      healthHint: "Ahorro, gasto vs ingreso y constancia",
      // Auto-ejecución de recurrentes
      runRecurring: "Ejecutar pendientes",
      recurringRan: "Se registraron {count} movimientos recurrentes",
      recurringNoneDue: "No hay recurrentes pendientes",
      recurringRunError: "No pudimos ejecutar los recurrentes",
    },
    recurring: {
      runDue: "Ejecutar pendientes",
      runDueHint: "Registra los recurrentes vencidos como movimientos reales.",
      ranOne: "Se registró 1 movimiento recurrente",
      ranMany: "Se registraron {count} movimientos recurrentes",
      ranNone: "No hay recurrentes pendientes",
      runError: "No pudimos ejecutar los recurrentes",
    },
  },
  en: {
    dashboard: {
      sparklineIncome: "Income · last 7 days",
      sparklineExpense: "Expenses · last 7 days",
      sparklineEmpty: "No activity in 7 days",
      netWorthTitle: "Net worth",
      savingsSplit: "Savings & investment",
      savingsSplitSubtitle: "Based on this month's income",
      savingsLabel: "Savings",
      investmentLabel: "Investment",
      savingsSplitEmpty: "Record income this month to see your split.",
      savingsSplitUnset:
        "Set your savings and investment percentages to see the split.",
      healthTitle: "Financial health",
      healthExcellent: "Excellent",
      healthGood: "Good",
      healthFair: "Fair",
      healthPoor: "Needs work",
      healthStreak: "🔥 {days}-day streak",
      healthHint: "Savings, spend vs income and consistency",
      runRecurring: "Run due",
      recurringRan: "{count} recurring transactions recorded",
      recurringNoneDue: "No recurring items due",
      recurringRunError: "We couldn't run the recurring items",
    },
    recurring: {
      runDue: "Run due",
      runDueHint: "Record overdue recurring items as real transactions.",
      ranOne: "1 recurring transaction recorded",
      ranMany: "{count} recurring transactions recorded",
      ranNone: "No recurring items due",
      runError: "We couldn't run the recurring items",
    },
  },
  pt: {
    dashboard: {
      sparklineIncome: "Receitas · últimos 7 dias",
      sparklineExpense: "Despesas · últimos 7 dias",
      sparklineEmpty: "Sem movimentações em 7 dias",
      netWorthTitle: "Patrimônio líquido",
      savingsSplit: "Poupança e investimento",
      savingsSplitSubtitle: "Sobre suas receitas do mês",
      savingsLabel: "Poupança",
      investmentLabel: "Investimento",
      savingsSplitEmpty: "Registre receitas neste mês para ver sua divisão.",
      savingsSplitUnset:
        "Configure seus percentuais de poupança e investimento para ver a divisão.",
      healthTitle: "Saúde financeira",
      healthExcellent: "Excelente",
      healthGood: "Boa",
      healthFair: "Razoável",
      healthPoor: "A melhorar",
      healthStreak: "🔥 {days} dias seguidos",
      healthHint: "Poupança, gasto vs receita e consistência",
      runRecurring: "Executar pendentes",
      recurringRan: "{count} transações recorrentes registradas",
      recurringNoneDue: "Nenhum recorrente pendente",
      recurringRunError: "Não foi possível executar os recorrentes",
    },
    recurring: {
      runDue: "Executar pendentes",
      runDueHint: "Registra os recorrentes vencidos como transações reais.",
      ranOne: "1 transação recorrente registrada",
      ranMany: "{count} transações recorrentes registradas",
      ranNone: "Nenhum recorrente pendente",
      runError: "Não foi possível executar os recorrentes",
    },
  },
};
