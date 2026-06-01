import type { LocaleModule } from "./types";

/**
 * Diccionario del área **Estrategia / Waterfall** del presupuesto.
 * Namespace único: `strategy`. Vive DENTRO de la pantalla de Presupuesto
 * (sin entrada de nav propia).
 *
 * Semántica espejada de iOS (`Features/Budget/PlanEditorView.swift`,
 * `WaterfallBudgetView.swift`, `Core/WaterfallCalculator.swift`).
 * ES = tono rioplatense (vos). EN/PT = fintech profesional.
 */
export const strategy: LocaleModule = {
  es: {
    strategy: {
      // Card
      title: "Estrategia del hogar",
      subtitle: "Cómo se reparte cada peso de tus ingresos del mes.",
      edit: "Editar estrategia",
      // Cascada
      income: "Ingresos del mes",
      savings: "Ahorro",
      investment: "Inversión",
      remainder: "Disponible para repartir",
      remainderHint:
        "Lo que queda tras ahorro e inversión, listo para tus cuentas y sobres.",
      distribution: "Distribución",
      // Modos de distribución
      modeEqual: "Equitativa",
      modeProportional: "Proporcional",
      modeCustom: "Personalizada",
      modeEqualHint: "El remanente se divide en partes iguales entre las cuentas personales.",
      modeProportionalHint:
        "Cada cuenta recibe según cuánto ingreso aportó al hogar.",
      modeCustomHint:
        "Vos definís el monto exacto para cada cuenta personal.",
      // Inclusiones
      inclusions: "Qué se descuenta antes de repartir",
      inclusionsHint:
        "Activá lo que querés restar de tus ingresos antes de calcular ahorro, inversión y remanente.",
      includeBills: "Vencimientos del mes",
      includeInstallments: "Cuotas del mes",
      includeDebts: "Pagos de deuda",
      // Dialog
      dialogTitle: "Editar estrategia",
      dialogDescription:
        "Definí qué porcentaje va a ahorro e inversión y cómo se reparte el resto.",
      percentages: "Ahorro e inversión",
      savingsPctLabel: "Ahorro (%)",
      investmentPctLabel: "Inversión (%)",
      distributionMode: "Modo de distribución",
      preview: "Vista previa con tus ingresos del mes",
      // Estado
      noIncomeHint:
        "Todavía no registraste ingresos este mes; los porcentajes se aplican cuando los cargues.",
      readOnlyHint: "Solo el propietario o un administrador puede editar la estrategia.",
      saved: "Estrategia actualizada",
      saving: "Guardando…",
      // Errores (usados por la server action)
      permissionError:
        "Solo el propietario o un administrador puede cambiar la estrategia.",
      invalidPct: "Los porcentajes deben estar entre 0 y 100.",
      sumTooHigh: "El ahorro más la inversión no pueden superar el 100 %.",
      invalidMode: "Modo de distribución no válido.",
      saveError: "No se pudo guardar la estrategia.",
    },
  },
  en: {
    strategy: {
      title: "Household strategy",
      subtitle: "How every dollar of this month's income gets allocated.",
      edit: "Edit strategy",
      income: "Income this month",
      savings: "Savings",
      investment: "Investment",
      remainder: "Left to distribute",
      remainderHint:
        "What's left after savings and investment, ready for your accounts and envelopes.",
      distribution: "Distribution",
      modeEqual: "Equal",
      modeProportional: "Proportional",
      modeCustom: "Custom",
      modeEqualHint: "The remainder is split evenly across personal accounts.",
      modeProportionalHint:
        "Each account gets a share based on how much income it brought in.",
      modeCustomHint: "You set the exact amount for each personal account.",
      inclusions: "What's deducted before distributing",
      inclusionsHint:
        "Turn on what you want subtracted from income before computing savings, investment and the remainder.",
      includeBills: "Bills due this month",
      includeInstallments: "Installments this month",
      includeDebts: "Debt payments",
      dialogTitle: "Edit strategy",
      dialogDescription:
        "Set how much goes to savings and investment, and how the rest is split.",
      percentages: "Savings & investment",
      savingsPctLabel: "Savings (%)",
      investmentPctLabel: "Investment (%)",
      distributionMode: "Distribution mode",
      preview: "Preview with this month's income",
      noIncomeHint:
        "No income recorded this month yet; the percentages apply once you add some.",
      readOnlyHint: "Only the owner or an admin can edit the strategy.",
      saved: "Strategy updated",
      saving: "Saving…",
      permissionError: "Only the owner or an admin can change the strategy.",
      invalidPct: "Percentages must be between 0 and 100.",
      sumTooHigh: "Savings plus investment can't exceed 100%.",
      invalidMode: "Invalid distribution mode.",
      saveError: "Couldn't save the strategy.",
    },
  },
  pt: {
    strategy: {
      title: "Estratégia da casa",
      subtitle: "Como cada real da renda deste mês é distribuído.",
      edit: "Editar estratégia",
      income: "Renda do mês",
      savings: "Poupança",
      investment: "Investimento",
      remainder: "Disponível para distribuir",
      remainderHint:
        "O que sobra após poupança e investimento, pronto para suas contas e envelopes.",
      distribution: "Distribuição",
      modeEqual: "Igualitária",
      modeProportional: "Proporcional",
      modeCustom: "Personalizada",
      modeEqualHint:
        "O restante é dividido igualmente entre as contas pessoais.",
      modeProportionalHint:
        "Cada conta recebe conforme quanto de renda trouxe para a casa.",
      modeCustomHint: "Você define o valor exato de cada conta pessoal.",
      inclusions: "O que é descontado antes de distribuir",
      inclusionsHint:
        "Ative o que quer subtrair da renda antes de calcular poupança, investimento e o restante.",
      includeBills: "Contas a vencer no mês",
      includeInstallments: "Parcelas do mês",
      includeDebts: "Pagamentos de dívida",
      dialogTitle: "Editar estratégia",
      dialogDescription:
        "Defina quanto vai para poupança e investimento e como o restante é dividido.",
      percentages: "Poupança e investimento",
      savingsPctLabel: "Poupança (%)",
      investmentPctLabel: "Investimento (%)",
      distributionMode: "Modo de distribuição",
      preview: "Prévia com a renda deste mês",
      noIncomeHint:
        "Nenhuma renda registrada neste mês ainda; os percentuais se aplicam quando você adicionar.",
      readOnlyHint: "Apenas o proprietário ou um administrador pode editar a estratégia.",
      saved: "Estratégia atualizada",
      saving: "Salvando…",
      permissionError:
        "Apenas o proprietário ou um administrador pode alterar a estratégia.",
      invalidPct: "Os percentuais devem estar entre 0 e 100.",
      sumTooHigh: "Poupança mais investimento não podem ultrapassar 100%.",
      invalidMode: "Modo de distribuição inválido.",
      saveError: "Não foi possível salvar a estratégia.",
    },
  },
};
