import type { LocaleModule } from "./types";

/**
 * Diccionario del área Exportación (Excel / PDF).
 * Namespace: exportTools.
 * - `actions`: labels de botones/menú en la UI (Movimientos y Reportes).
 * - `sheet`: nombres de hojas y encabezados de columna del Excel.
 * - `summary`: filas/labels del resumen (ingresos, gastos, balance, tasa).
 * - `pdf`: títulos de secciones del reporte PDF + pie de página.
 * - `file`: partes del nombre de archivo (kebab-case, sin acentos/espacios).
 * - `meta`: textos de metadatos del documento + estado vacío.
 */
export const exportTools: LocaleModule = {
  es: {
    exportTools: {
      actions: {
        export: "Exportar",
        exportExcel: "Exportar a Excel",
        exportPdf: "Exportar PDF",
        exportReportPdf: "Reporte PDF",
        exportReportExcel: "Resumen Excel",
        exporting: "Exportando…",
        menuLabel: "Opciones de exportación",
        downloadError: "No pudimos generar el archivo. Probá de nuevo.",
      },
      sheet: {
        transactions: "Movimientos",
        summary: "Resumen",
        report: "Reporte",
        colDate: "Fecha",
        colType: "Tipo",
        colCategory: "Categoría",
        colAccount: "Cuenta",
        colAmount: "Monto",
        colCurrency: "Moneda",
        colNote: "Nota",
        typeIncome: "Ingreso",
        typeExpense: "Gasto",
        noAccount: "Sin cuenta",
        noCategory: "Sin categoría",
      },
      summary: {
        title: "Resumen",
        income: "Ingresos",
        expense: "Gastos",
        balance: "Balance",
        savingsRate: "Tasa de ahorro",
        txCount: "Movimientos",
        total: "Total",
        period: "Período",
      },
      pdf: {
        brand: "Home Finance",
        reportTitle: "Reporte mensual",
        generatedOn: "Generado el {date}",
        kpiSectionTitle: "Resumen del mes",
        topCategoriesTitle: "Top categorías de gasto",
        topCategoriesPct: "%",
        topCategoriesAmount: "Monto",
        topCategoriesName: "Categoría",
        transactionsTitle: "Movimientos del mes",
        page: "Página {n} de {total}",
        confidential: "Documento confidencial · Solo para tu hogar",
      },
      file: {
        transactions: "home-finance-movimientos",
        report: "home-finance-reporte",
      },
      meta: {
        author: "Home Finance",
        subject: "Exportación de finanzas del hogar",
        empty: "No hay movimientos para el período seleccionado.",
      },
    },
  },

  en: {
    exportTools: {
      actions: {
        export: "Export",
        exportExcel: "Export to Excel",
        exportPdf: "Export PDF",
        exportReportPdf: "PDF report",
        exportReportExcel: "Excel summary",
        exporting: "Exporting…",
        menuLabel: "Export options",
        downloadError: "We couldn't generate the file. Please try again.",
      },
      sheet: {
        transactions: "Transactions",
        summary: "Summary",
        report: "Report",
        colDate: "Date",
        colType: "Type",
        colCategory: "Category",
        colAccount: "Account",
        colAmount: "Amount",
        colCurrency: "Currency",
        colNote: "Note",
        typeIncome: "Income",
        typeExpense: "Expense",
        noAccount: "No account",
        noCategory: "No category",
      },
      summary: {
        title: "Summary",
        income: "Income",
        expense: "Expenses",
        balance: "Balance",
        savingsRate: "Savings rate",
        txCount: "Transactions",
        total: "Total",
        period: "Period",
      },
      pdf: {
        brand: "Home Finance",
        reportTitle: "Monthly report",
        generatedOn: "Generated on {date}",
        kpiSectionTitle: "Month summary",
        topCategoriesTitle: "Top spending categories",
        topCategoriesPct: "%",
        topCategoriesAmount: "Amount",
        topCategoriesName: "Category",
        transactionsTitle: "Transactions this month",
        page: "Page {n} of {total}",
        confidential: "Confidential document · For your household only",
      },
      file: {
        transactions: "home-finance-transactions",
        report: "home-finance-report",
      },
      meta: {
        author: "Home Finance",
        subject: "Household finance export",
        empty: "There are no transactions for the selected period.",
      },
    },
  },

  pt: {
    exportTools: {
      actions: {
        export: "Exportar",
        exportExcel: "Exportar para Excel",
        exportPdf: "Exportar PDF",
        exportReportPdf: "Relatório PDF",
        exportReportExcel: "Resumo Excel",
        exporting: "Exportando…",
        menuLabel: "Opções de exportação",
        downloadError: "Não conseguimos gerar o arquivo. Tente de novo.",
      },
      sheet: {
        transactions: "Movimentações",
        summary: "Resumo",
        report: "Relatório",
        colDate: "Data",
        colType: "Tipo",
        colCategory: "Categoria",
        colAccount: "Conta",
        colAmount: "Valor",
        colCurrency: "Moeda",
        colNote: "Nota",
        typeIncome: "Receita",
        typeExpense: "Despesa",
        noAccount: "Sem conta",
        noCategory: "Sem categoria",
      },
      summary: {
        title: "Resumo",
        income: "Receitas",
        expense: "Despesas",
        balance: "Saldo",
        savingsRate: "Taxa de economia",
        txCount: "Movimentações",
        total: "Total",
        period: "Período",
      },
      pdf: {
        brand: "Home Finance",
        reportTitle: "Relatório mensal",
        generatedOn: "Gerado em {date}",
        kpiSectionTitle: "Resumo do mês",
        topCategoriesTitle: "Principais categorias de gasto",
        topCategoriesPct: "%",
        topCategoriesAmount: "Valor",
        topCategoriesName: "Categoria",
        transactionsTitle: "Movimentações do mês",
        page: "Página {n} de {total}",
        confidential: "Documento confidencial · Apenas para a sua casa",
      },
      file: {
        transactions: "home-finance-movimentacoes",
        report: "home-finance-relatorio",
      },
      meta: {
        author: "Home Finance",
        subject: "Exportação de finanças da casa",
        empty: "Não há movimentações para o período selecionado.",
      },
    },
  },
};
