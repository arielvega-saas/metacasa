import type { LocaleModule } from "./types";

/**
 * Diccionario del área de Deudas + Patrimonio neto (net worth).
 * Namespaces: `debts` (pantalla/cards/diálogo/errores) y `netWorth` (header
 * card reutilizable). Además expone un `nav.debts` top-level que el diccionario
 * deep-mergea en el árbol `nav` compartido, así `t("nav.debts")` resuelve sin
 * tocar auth-nav.ts.
 *
 * ES = copy de la app (tono rioplatense vos). EN/PT = fintech profesional.
 * Semántica de campos espejada de iOS (`Features/Debts/*`, `Models/Debt.swift`).
 */
export const debts: LocaleModule = {
  es: {
    nav: { debts: "Deudas" },
    netWorth: {
      title: "Patrimonio neto",
      description:
        "Lo que tenés menos lo que debés, consolidado en {currency}.",
      assets: "Activos",
      liabilities: "Pasivos",
      net: "Patrimonio neto",
      mixedCurrencies:
        "Hay montos en otras monedas; el total usa tus tasas de cambio en {currency}.",
    },
    debts: {
      title: "Deudas",
      needHousehold: "Creá un hogar para empezar.",
      headerDescription:
        "Tus préstamos y créditos, con interés y proyección de pago.",
      new: "Nueva deuda",
      emptyTitle: "Todavía no tenés deudas cargadas",
      emptyDescription:
        "Agregá un préstamo o crédito para seguir tu saldo, el interés y cuánto te falta para saldarlo.",
      emptyAction: "Agregar deuda",
      // Total
      totalLabel: "Deuda total",
      totalMonthly: "Compromiso mensual",
      countOne: "deuda",
      countOther: "deudas",
      mixedCurrencies:
        "Tenés deudas en varias monedas; el total se muestra en {currency} con tus tasas de cambio.",
      // Card
      yourDebts: "Tus deudas",
      balanceLabel: "Saldo",
      ofOriginal: "de {original}",
      paid: "pagado",
      progressAria: "{pct}% saldado de la deuda con {creditor}",
      annualRate: "{rate}% anual",
      monthlyPayment: "Pago {amount}/mes",
      monthsLeftOne: "{n} mes restante",
      monthsLeftOther: "{n} meses restantes",
      neverPayoff: "El pago no cubre el interés",
      maturity: "Vence {date}",
      overdue: "Vencida",
      settledBadge: "Saldada",
      cardActions: "Acciones de {creditor}",
      // Tabs
      tabActive: "Activas ({n})",
      tabSettled: "Saldadas ({n})",
      tabAll: "Todas ({n})",
      emptyActiveTitle: "No tenés deudas activas",
      emptySettledTitle: "Todavía no saldaste ninguna deuda",
      emptySettledDescription:
        "Cuando marques una deuda como saldada, la vas a ver acá.",
      // Diálogo alta/edición
      dialogCreateTitle: "Nueva deuda",
      dialogEditTitle: "Editar deuda",
      dialogCreateDescription:
        "Cargá un préstamo o crédito para seguir su saldo e interés.",
      dialogEditDescription: "Actualizá los datos de la deuda.",
      creditorLabel: "Acreedor",
      creditorPlaceholder: "Ej. Banco, tarjeta, préstamo personal",
      originalAmountLabel: "Monto original",
      currentBalanceLabel: "Saldo actual",
      annualRateLabel: "Tasa anual",
      monthlyPaymentLabel: "Pago mensual",
      startDateLabel: "Fecha de inicio",
      hasMaturityLabel: "Tiene fecha de vencimiento",
      maturityDateLabel: "Fecha de vencimiento",
      categoryLabel: "Categoría",
      noteLabel: "Nota",
      optional: "(opcional)",
      createSubmit: "Crear deuda",
      // Toasts
      created: "Deuda creada",
      updated: "Deuda actualizada",
      saveError: "No pudimos guardar la deuda",
      // Saldar
      settle: "Marcar como saldada",
      settleTitle: "Saldar deuda",
      settleDescriptionPrefix: "Vas a marcar como saldada la deuda con ",
      settleDescriptionSuffix:
        ". El saldo pasará a cero y la deuda quedará archivada como saldada. Esta acción no se puede deshacer.",
      settled: "Deuda saldada",
      settleError: "No pudimos saldar la deuda",
      // Borrar
      delete: "Eliminar",
      deleteTitle: "Eliminar deuda",
      deleteDescriptionPrefix: "Vas a eliminar la deuda con ",
      deleteDescriptionSuffix:
        ". Se borrará por completo y no se puede deshacer.",
      deleted: "Deuda eliminada",
      deleteError: "No pudimos eliminar la deuda",
      // Errores de validación (server actions)
      errors: {
        creditorRequired: "Poné el nombre del acreedor.",
        originalPositive: "El monto original tiene que ser mayor a cero.",
        balanceNonNegative: "El saldo actual no puede ser negativo.",
        rateNonNegative: "La tasa no puede ser negativa.",
        paymentNonNegative: "El pago mensual no puede ser negativo.",
        invalidDate: "Ingresá una fecha válida.",
        maturityBeforeStart:
          "El vencimiento no puede ser anterior al inicio.",
      },
    },
  },

  en: {
    nav: { debts: "Debts" },
    netWorth: {
      title: "Net worth",
      description: "What you own minus what you owe, in {currency}.",
      assets: "Assets",
      liabilities: "Liabilities",
      net: "Net worth",
      mixedCurrencies:
        "Some amounts are in other currencies; the total uses your exchange rates in {currency}.",
    },
    debts: {
      title: "Debts",
      needHousehold: "Create a household to get started.",
      headerDescription:
        "Your loans and credit, with interest and a payoff projection.",
      new: "New debt",
      emptyTitle: "You don’t have any debts yet",
      emptyDescription:
        "Add a loan or credit line to track its balance, interest, and how much is left to pay off.",
      emptyAction: "Add debt",
      totalLabel: "Total debt",
      totalMonthly: "Monthly commitment",
      countOne: "debt",
      countOther: "debts",
      mixedCurrencies:
        "You have debts in several currencies; the total is shown in {currency} using your exchange rates.",
      yourDebts: "Your debts",
      balanceLabel: "Balance",
      ofOriginal: "of {original}",
      paid: "paid off",
      progressAria: "{pct}% paid off on the debt with {creditor}",
      annualRate: "{rate}% APR",
      monthlyPayment: "Paying {amount}/mo",
      monthsLeftOne: "{n} month left",
      monthsLeftOther: "{n} months left",
      neverPayoff: "Payment doesn’t cover interest",
      maturity: "Due {date}",
      overdue: "Overdue",
      settledBadge: "Settled",
      cardActions: "{creditor} actions",
      tabActive: "Active ({n})",
      tabSettled: "Settled ({n})",
      tabAll: "All ({n})",
      emptyActiveTitle: "You have no active debts",
      emptySettledTitle: "You haven’t settled any debts yet",
      emptySettledDescription:
        "When you mark a debt as settled, you’ll see it here.",
      dialogCreateTitle: "New debt",
      dialogEditTitle: "Edit debt",
      dialogCreateDescription:
        "Add a loan or credit line to track its balance and interest.",
      dialogEditDescription: "Update the debt details.",
      creditorLabel: "Creditor",
      creditorPlaceholder: "e.g. Bank, card, personal loan",
      originalAmountLabel: "Original amount",
      currentBalanceLabel: "Current balance",
      annualRateLabel: "Annual rate",
      monthlyPaymentLabel: "Monthly payment",
      startDateLabel: "Start date",
      hasMaturityLabel: "Has a maturity date",
      maturityDateLabel: "Maturity date",
      categoryLabel: "Category",
      noteLabel: "Note",
      optional: "(optional)",
      createSubmit: "Create debt",
      created: "Debt created",
      updated: "Debt updated",
      saveError: "We couldn’t save the debt",
      settle: "Mark as settled",
      settleTitle: "Settle debt",
      settleDescriptionPrefix: "You’re about to settle the debt with ",
      settleDescriptionSuffix:
        ". The balance will go to zero and the debt will be archived as settled. This can’t be undone.",
      settled: "Debt settled",
      settleError: "We couldn’t settle the debt",
      delete: "Delete",
      deleteTitle: "Delete debt",
      deleteDescriptionPrefix: "You’re about to delete the debt with ",
      deleteDescriptionSuffix:
        ". It will be removed completely and can’t be undone.",
      deleted: "Debt deleted",
      deleteError: "We couldn’t delete the debt",
      errors: {
        creditorRequired: "Enter the creditor’s name.",
        originalPositive: "The original amount must be greater than zero.",
        balanceNonNegative: "The current balance can’t be negative.",
        rateNonNegative: "The rate can’t be negative.",
        paymentNonNegative: "The monthly payment can’t be negative.",
        invalidDate: "Enter a valid date.",
        maturityBeforeStart: "Maturity can’t be earlier than the start date.",
      },
    },
  },

  pt: {
    nav: { debts: "Dívidas" },
    netWorth: {
      title: "Patrimônio líquido",
      description: "O que você tem menos o que deve, em {currency}.",
      assets: "Ativos",
      liabilities: "Passivos",
      net: "Patrimônio líquido",
      mixedCurrencies:
        "Há valores em outras moedas; o total usa suas taxas de câmbio em {currency}.",
    },
    debts: {
      title: "Dívidas",
      needHousehold: "Crie um lar para começar.",
      headerDescription:
        "Seus empréstimos e créditos, com juros e projeção de quitação.",
      new: "Nova dívida",
      emptyTitle: "Você ainda não tem dívidas cadastradas",
      emptyDescription:
        "Adicione um empréstimo ou crédito para acompanhar o saldo, os juros e quanto falta para quitar.",
      emptyAction: "Adicionar dívida",
      totalLabel: "Dívida total",
      totalMonthly: "Compromisso mensal",
      countOne: "dívida",
      countOther: "dívidas",
      mixedCurrencies:
        "Você tem dívidas em várias moedas; o total é exibido em {currency} com suas taxas de câmbio.",
      yourDebts: "Suas dívidas",
      balanceLabel: "Saldo",
      ofOriginal: "de {original}",
      paid: "quitado",
      progressAria: "{pct}% quitado da dívida com {creditor}",
      annualRate: "{rate}% ao ano",
      monthlyPayment: "Pagando {amount}/mês",
      monthsLeftOne: "{n} mês restante",
      monthsLeftOther: "{n} meses restantes",
      neverPayoff: "O pagamento não cobre os juros",
      maturity: "Vence {date}",
      overdue: "Vencida",
      settledBadge: "Quitada",
      cardActions: "Ações de {creditor}",
      tabActive: "Ativas ({n})",
      tabSettled: "Quitadas ({n})",
      tabAll: "Todas ({n})",
      emptyActiveTitle: "Você não tem dívidas ativas",
      emptySettledTitle: "Você ainda não quitou nenhuma dívida",
      emptySettledDescription:
        "Quando marcar uma dívida como quitada, ela aparecerá aqui.",
      dialogCreateTitle: "Nova dívida",
      dialogEditTitle: "Editar dívida",
      dialogCreateDescription:
        "Adicione um empréstimo ou crédito para acompanhar o saldo e os juros.",
      dialogEditDescription: "Atualize os dados da dívida.",
      creditorLabel: "Credor",
      creditorPlaceholder: "Ex.: Banco, cartão, empréstimo pessoal",
      originalAmountLabel: "Valor original",
      currentBalanceLabel: "Saldo atual",
      annualRateLabel: "Taxa anual",
      monthlyPaymentLabel: "Pagamento mensal",
      startDateLabel: "Data de início",
      hasMaturityLabel: "Tem data de vencimento",
      maturityDateLabel: "Data de vencimento",
      categoryLabel: "Categoria",
      noteLabel: "Nota",
      optional: "(opcional)",
      createSubmit: "Criar dívida",
      created: "Dívida criada",
      updated: "Dívida atualizada",
      saveError: "Não foi possível salvar a dívida",
      settle: "Marcar como quitada",
      settleTitle: "Quitar dívida",
      settleDescriptionPrefix: "Você vai marcar como quitada a dívida com ",
      settleDescriptionSuffix:
        ". O saldo irá a zero e a dívida será arquivada como quitada. Esta ação não pode ser desfeita.",
      settled: "Dívida quitada",
      settleError: "Não foi possível quitar a dívida",
      delete: "Excluir",
      deleteTitle: "Excluir dívida",
      deleteDescriptionPrefix: "Você vai excluir a dívida com ",
      deleteDescriptionSuffix:
        ". Ela será removida por completo e não pode ser desfeita.",
      deleted: "Dívida excluída",
      deleteError: "Não foi possível excluir a dívida",
      errors: {
        creditorRequired: "Informe o nome do credor.",
        originalPositive: "O valor original precisa ser maior que zero.",
        balanceNonNegative: "O saldo atual não pode ser negativo.",
        rateNonNegative: "A taxa não pode ser negativa.",
        paymentNonNegative: "O pagamento mensal não pode ser negativo.",
        invalidDate: "Informe uma data válida.",
        maturityBeforeStart:
          "O vencimento não pode ser anterior à data de início.",
      },
    },
  },
};
