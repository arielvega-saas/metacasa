import type { LocaleModule } from "./types";

/**
 * Diccionario del área **Herramientas / Calculadoras financieras**.
 * Namespace único: `tools` (+ `nav.tools` para la etiqueta del menú).
 *
 * Paridad de copy con iOS (`Features/Tools/FixedTermCalculatorView.swift`,
 * `CompoundInterestCalculatorView.swift`). ES = tono rioplatense (vos);
 * EN/PT = fintech profesional.
 */
export const tools: LocaleModule = {
  es: {
    nav: { tools: "Herramientas" },
    tools: {
      // Hub
      title: "Herramientas",
      description: "Calculadoras para planificar tu plata. Pura matemática, sin guardar nada.",
      fixedTermCard: "Plazo fijo",
      fixedTermCardDesc: "Cuánto rinde tu capital a una TNA y plazo dados.",
      compoundCard: "Interés compuesto",
      compoundCardDesc: "Proyectá tu ahorro con aportes mensuales a lo largo de los años.",
      open: "Abrir",

      // Tabs
      tabFixedTerm: "Plazo fijo",
      tabCompound: "Interés compuesto",

      // ── Plazo fijo ──
      ft: {
        title: "Plazo fijo",
        subtitle: "Calculadora de rendimiento",
        capital: "Capital a invertir",
        tna: "TNA (Tasa Nominal Anual)",
        tnaHint: "Es la tasa anual que publica el banco, sin componer.",
        term: "Plazo",
        unitDays: "Días",
        unitMonths: "Meses",
        result: "Resultado",
        interest: "Interés ganado",
        total: "Total a cobrar",
        tea: "TEA",
        teaHint: "Tasa Efectiva Anual: lo que rendirías si reinvertís cada vencimiento.",
        equivalents: "Equivalencias",
        perMonth: "Por mes",
        perDay: "Por día",
        hintTitle: "Ingresá capital y TNA",
        hintBody: "Cargá el capital y la tasa para ver cuánto rinde tu plazo fijo.",
        disclaimer:
          "Cálculo estimado. No incluye retenciones impositivas ni comisiones, que varían por país y entidad.",
      },

      // ── Interés compuesto ──
      ci: {
        title: "Interés compuesto",
        intro:
          "Si depositás un capital hoy y le sumás un aporte cada mes durante varios años, mirá cuánto se transforma gracias al interés compuesto.",
        principal: "Capital inicial",
        principalHint: "Lo que ponés hoy para arrancar.",
        monthly: "Aporte mensual",
        monthlyHint: "Cuánto sumás cada mes.",
        years: "Plazo",
        yearsHint: "Horizonte de la inversión.",
        unitYears: "años",
        rate: "Tasa anual",
        rateHint: "Rendimiento anual estimado (TEA).",
        result: "Resultado",
        final: "Balance final",
        contributed: "Total aportado",
        interestEarned: "Interés ganado",
        chartTitle: "Evolución",
        legendBalance: "Balance",
        legendContributed: "Aportado",
        milestones: "Hitos",
        yearLabelOne: "Año {n}",
        yearLabelOther: "Año {n}",
        enterInputs: "Completá los datos y elegí una tasa para ver la proyección.",
        disclaimer:
          "Proyección estimada con composición mensual y tasa constante. El rendimiento real puede variar.",
      },
    },
  },
  en: {
    nav: { tools: "Tools" },
    tools: {
      title: "Tools",
      description: "Calculators to plan your money. Pure math — nothing is saved.",
      fixedTermCard: "Fixed-term deposit",
      fixedTermCardDesc: "How much your capital earns at a given rate and term.",
      compoundCard: "Compound interest",
      compoundCardDesc: "Project your savings with monthly contributions over the years.",
      open: "Open",

      tabFixedTerm: "Fixed-term",
      tabCompound: "Compound interest",

      ft: {
        title: "Fixed-term deposit",
        subtitle: "Yield calculator",
        capital: "Capital to invest",
        tna: "Nominal annual rate",
        tnaHint: "The yearly rate the bank quotes, before compounding.",
        term: "Term",
        unitDays: "Days",
        unitMonths: "Months",
        result: "Result",
        interest: "Interest earned",
        total: "Final total",
        tea: "Effective rate",
        teaHint: "Effective annual rate: what you'd earn if you roll over each maturity.",
        equivalents: "Equivalents",
        perMonth: "Per month",
        perDay: "Per day",
        hintTitle: "Enter capital and rate",
        hintBody: "Add the capital and the rate to see how much your deposit earns.",
        disclaimer:
          "Estimated calculation. Excludes taxes and fees, which vary by country and institution.",
      },

      ci: {
        title: "Compound interest",
        intro:
          "Deposit some capital today, add a contribution every month for a few years, and see how it grows thanks to compound interest.",
        principal: "Initial capital",
        principalHint: "What you put in today to start.",
        monthly: "Monthly contribution",
        monthlyHint: "How much you add each month.",
        years: "Term",
        yearsHint: "Investment horizon.",
        unitYears: "years",
        rate: "Annual rate",
        rateHint: "Estimated annual return (effective rate).",
        result: "Result",
        final: "Final balance",
        contributed: "Total contributed",
        interestEarned: "Interest earned",
        chartTitle: "Growth",
        legendBalance: "Balance",
        legendContributed: "Contributed",
        milestones: "Milestones",
        yearLabelOne: "Year {n}",
        yearLabelOther: "Year {n}",
        enterInputs: "Fill in the fields and pick a rate to see the projection.",
        disclaimer:
          "Estimated projection with monthly compounding and a constant rate. Actual returns may vary.",
      },
    },
  },
  pt: {
    nav: { tools: "Ferramentas" },
    tools: {
      title: "Ferramentas",
      description: "Calculadoras para planejar seu dinheiro. Pura matemática — nada é salvo.",
      fixedTermCard: "Renda fixa",
      fixedTermCardDesc: "Quanto seu capital rende a uma taxa e prazo dados.",
      compoundCard: "Juros compostos",
      compoundCardDesc: "Projete sua poupança com aportes mensais ao longo dos anos.",
      open: "Abrir",

      tabFixedTerm: "Renda fixa",
      tabCompound: "Juros compostos",

      ft: {
        title: "Renda fixa",
        subtitle: "Calculadora de rendimento",
        capital: "Capital a investir",
        tna: "Taxa nominal anual",
        tnaHint: "A taxa anual que o banco divulga, sem capitalização.",
        term: "Prazo",
        unitDays: "Dias",
        unitMonths: "Meses",
        result: "Resultado",
        interest: "Juros ganhos",
        total: "Total a receber",
        tea: "Taxa efetiva",
        teaHint: "Taxa efetiva anual: o que renderia se você reinvestir cada vencimento.",
        equivalents: "Equivalências",
        perMonth: "Por mês",
        perDay: "Por dia",
        hintTitle: "Informe capital e taxa",
        hintBody: "Adicione o capital e a taxa para ver quanto sua aplicação rende.",
        disclaimer:
          "Cálculo estimado. Não inclui impostos nem tarifas, que variam por país e instituição.",
      },

      ci: {
        title: "Juros compostos",
        intro:
          "Deposite um capital hoje, some um aporte todo mês por alguns anos e veja como cresce graças aos juros compostos.",
        principal: "Capital inicial",
        principalHint: "O que você coloca hoje para começar.",
        monthly: "Aporte mensal",
        monthlyHint: "Quanto você soma a cada mês.",
        years: "Prazo",
        yearsHint: "Horizonte do investimento.",
        unitYears: "anos",
        rate: "Taxa anual",
        rateHint: "Rendimento anual estimado (taxa efetiva).",
        result: "Resultado",
        final: "Saldo final",
        contributed: "Total aportado",
        interestEarned: "Juros ganhos",
        chartTitle: "Evolução",
        legendBalance: "Saldo",
        legendContributed: "Aportado",
        milestones: "Marcos",
        yearLabelOne: "Ano {n}",
        yearLabelOther: "Ano {n}",
        enterInputs: "Preencha os campos e escolha uma taxa para ver a projeção.",
        disclaimer:
          "Projeção estimada com capitalização mensal e taxa constante. O rendimento real pode variar.",
      },
    },
  },
};
