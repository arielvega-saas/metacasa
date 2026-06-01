import type { LocaleModule } from "./types";

/**
 * Diccionario de Plantillas (atajos rápidos / quick-add).
 * Namespace `templates` + la clave de navegación bajo `nav` (`nav.templates`),
 * que el deepMerge del índice fusiona con el resto de los módulos.
 *
 * Paridad iOS: la barra de atajos (`AddTransactionView.shortcutsBar` /
 * `HomeView.QuickShortcutsCarousel`) muestra emoji + nombre + monto; tocar un
 * atajo carga un movimiento. En la web, aplicar crea el movimiento de HOY.
 */
export const templates: LocaleModule = {
  es: {
    nav: { templates: "Atajos" },
    templates: {
      title: "Atajos rápidos",
      description:
        "Cargá movimientos frecuentes con un toque. Tocá un atajo y se crea el movimiento de hoy.",
      needHousehold: "Creá un hogar para usar atajos rápidos.",
      new: "Nuevo atajo",
      manage: "Administrar",
      done: "Listo",
      // Estado vacío
      emptyTitle: "Todavía no tenés atajos",
      emptyDescription:
        "Creá atajos para tus gastos e ingresos más frecuentes y cargalos al instante.",
      emptyAction: "Crear atajo",
      // Chips / acciones
      applyHint: "Tocá para cargar el movimiento de hoy",
      applied: "Movimiento creado",
      applyError: "No se pudo crear el movimiento",
      cardActions: "Acciones de {name}",
      // Quick-add (barra en Movimientos)
      quickAddTitle: "Atajos rápidos",
      // Diálogo
      dialogCreateTitle: "Nuevo atajo",
      dialogEditTitle: "Editar atajo",
      dialogCreateDescription:
        "Guardá un movimiento frecuente como atajo para cargarlo con un toque.",
      dialogEditDescription: "Modificá los datos de este atajo.",
      nameLabel: "Nombre",
      namePlaceholder: "Ej.: Café, Supermercado, Sueldo",
      emojiLabel: "Emoji",
      emojiOptional: "(opcional)",
      emojiPlaceholder: "🛒",
      amountLabel: "Monto",
      categoryLabel: "Categoría",
      categoryPlaceholder: "Elegí una categoría",
      noteLabel: "Nota",
      notePlaceholder: "Detalle del movimiento",
      optional: "(opcional)",
      expenseToggle: "Gasto",
      incomeToggle: "Ingreso",
      createSubmit: "Crear atajo",
      // Borrado
      deleteTitle: "Eliminar atajo",
      deleteConfirm: "¿Seguro que querés eliminar “{name}”?",
      deleted: "Atajo eliminado",
      created: "Atajo creado",
      updated: "Atajo actualizado",
      saveError: "No se pudo guardar el atajo",
      deleteError: "No se pudo eliminar el atajo",
      errors: {
        nameRequired: "Poné un nombre para el atajo.",
        missingId: "Falta el identificador del atajo.",
        notFound: "No se encontró el atajo.",
      },
    },
  },
  en: {
    nav: { templates: "Shortcuts" },
    templates: {
      title: "Quick shortcuts",
      description:
        "Log frequent transactions with one tap. Tap a shortcut and today's transaction is created.",
      needHousehold: "Create a household to use quick shortcuts.",
      new: "New shortcut",
      manage: "Manage",
      done: "Done",
      emptyTitle: "No shortcuts yet",
      emptyDescription:
        "Create shortcuts for your most frequent expenses and income to log them instantly.",
      emptyAction: "Create shortcut",
      applyHint: "Tap to create today's transaction",
      applied: "Transaction created",
      applyError: "Couldn't create the transaction",
      cardActions: "Actions for {name}",
      quickAddTitle: "Quick shortcuts",
      dialogCreateTitle: "New shortcut",
      dialogEditTitle: "Edit shortcut",
      dialogCreateDescription:
        "Save a frequent transaction as a shortcut to log it with one tap.",
      dialogEditDescription: "Edit this shortcut's details.",
      nameLabel: "Name",
      namePlaceholder: "e.g. Coffee, Groceries, Salary",
      emojiLabel: "Emoji",
      emojiOptional: "(optional)",
      emojiPlaceholder: "🛒",
      amountLabel: "Amount",
      categoryLabel: "Category",
      categoryPlaceholder: "Choose a category",
      noteLabel: "Note",
      notePlaceholder: "Transaction detail",
      optional: "(optional)",
      expenseToggle: "Expense",
      incomeToggle: "Income",
      createSubmit: "Create shortcut",
      deleteTitle: "Delete shortcut",
      deleteConfirm: "Are you sure you want to delete “{name}”?",
      deleted: "Shortcut deleted",
      created: "Shortcut created",
      updated: "Shortcut updated",
      saveError: "Couldn't save the shortcut",
      deleteError: "Couldn't delete the shortcut",
      errors: {
        nameRequired: "Enter a name for the shortcut.",
        missingId: "Shortcut identifier is missing.",
        notFound: "Shortcut not found.",
      },
    },
  },
  pt: {
    nav: { templates: "Atalhos" },
    templates: {
      title: "Atalhos rápidos",
      description:
        "Registre movimentações frequentes com um toque. Toque em um atalho e a movimentação de hoje é criada.",
      needHousehold: "Crie um lar para usar atalhos rápidos.",
      new: "Novo atalho",
      manage: "Gerenciar",
      done: "Concluído",
      emptyTitle: "Você ainda não tem atalhos",
      emptyDescription:
        "Crie atalhos para suas despesas e receitas mais frequentes e registre-as na hora.",
      emptyAction: "Criar atalho",
      applyHint: "Toque para criar a movimentação de hoje",
      applied: "Movimentação criada",
      applyError: "Não foi possível criar a movimentação",
      cardActions: "Ações de {name}",
      quickAddTitle: "Atalhos rápidos",
      dialogCreateTitle: "Novo atalho",
      dialogEditTitle: "Editar atalho",
      dialogCreateDescription:
        "Salve uma movimentação frequente como atalho para registrá-la com um toque.",
      dialogEditDescription: "Edite os dados deste atalho.",
      nameLabel: "Nome",
      namePlaceholder: "Ex.: Café, Mercado, Salário",
      emojiLabel: "Emoji",
      emojiOptional: "(opcional)",
      emojiPlaceholder: "🛒",
      amountLabel: "Valor",
      categoryLabel: "Categoria",
      categoryPlaceholder: "Escolha uma categoria",
      noteLabel: "Nota",
      notePlaceholder: "Detalhe da movimentação",
      optional: "(opcional)",
      expenseToggle: "Despesa",
      incomeToggle: "Receita",
      createSubmit: "Criar atalho",
      deleteTitle: "Excluir atalho",
      deleteConfirm: "Tem certeza de que deseja excluir “{name}”?",
      deleted: "Atalho excluído",
      created: "Atalho criado",
      updated: "Atalho atualizado",
      saveError: "Não foi possível salvar o atalho",
      deleteError: "Não foi possível excluir o atalho",
      errors: {
        nameRequired: "Insira um nome para o atalho.",
        missingId: "Falta o identificador do atalho.",
        notFound: "Atalho não encontrado.",
      },
    },
  },
};
