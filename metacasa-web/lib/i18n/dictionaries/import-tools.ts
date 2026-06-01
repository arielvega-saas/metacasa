import type { LocaleModule } from "./types";

/**
 * Importación masiva de movimientos desde Excel/CSV con mapeo de columnas por IA.
 * Namespace: `importTools` (toda la copy del flujo). Además agrega la clave de
 * navegación `nav.import`: el `deepMerge` del diccionario la funde dentro del
 * árbol `nav` existente (definido en auth-nav.ts), así `t("nav.import")` resuelve
 * sin tocar ese módulo.
 */
export const importTools: LocaleModule = {
  es: {
    nav: { import: "Importar" },
    importTools: {
      // Página
      metaTitle: "Importar movimientos",
      title: "Importar movimientos",
      description:
        "Subí un Excel o CSV (export de tu banco, tu propia planilla, etc.) y la IA reconoce las columnas por vos.",
      // Pasos (stepper)
      step1: "Subir archivo",
      step2: "Mapear columnas",
      step3: "Revisar",
      step4: "Confirmar",
      stepOf: "Paso {current} de {total}",
      // Sin hogar
      noHouseholdTitle: "Primero creá un hogar",
      noHouseholdDescription:
        "Necesitás un hogar activo para importar movimientos.",
      // Paso 1 — upload
      uploadTitle: "Subí tu planilla",
      uploadHint: "Arrastrá un archivo acá o hacé clic para elegirlo.",
      uploadFormats: "Formatos: .xlsx o .csv · hasta 5 MB · 2000 filas máx.",
      uploadButton: "Elegir archivo",
      uploadChange: "Cambiar archivo",
      uploading: "Leyendo el archivo…",
      parseError: "No pudimos leer el archivo. Revisá el formato e intentá de nuevo.",
      fileTooLargeError: "El archivo es muy grande (máximo 5 MB).",
      fileTypeError: "Formato no soportado. Subí un .xlsx o un .csv.",
      emptyFileError: "El archivo no tiene filas con datos.",
      truncatedNote:
        "El archivo tenía más de {max} filas. Importaremos las primeras {max}.",
      rowsDetected: "{count} filas detectadas · {cols} columnas",
      // Paso 2 — mapeo
      mappingTitle: "Confirmá el mapeo de columnas",
      mappingDescription:
        "La IA asoció cada columna de tu planilla con un campo. Corregí lo que haga falta.",
      mappingLoading: "La IA está analizando tus columnas…",
      mappingAiFailed:
        "La IA no está disponible ahora; armamos un mapeo automático que podés ajustar.",
      mappingHeuristicNote: "Mapeo automático (sin IA). Revisalo con cuidado.",
      fieldDate: "Fecha",
      fieldAmount: "Monto",
      fieldType: "Tipo (gasto/ingreso)",
      fieldCategory: "Categoría",
      fieldAccount: "Cuenta",
      fieldNote: "Nota / descripción",
      columnNone: "— Ninguna —",
      columnLabel: "Columna “{name}”",
      unnamedColumn: "Columna {index}",
      typeFromSign:
        "El tipo se deduce del signo del monto (negativo = gasto).",
      typeFromColumn: "El tipo viene de una columna de la planilla.",
      dateFormatLabel: "Formato de fecha detectado",
      targetAccountLabel: "Cuenta destino",
      targetAccountHint:
        "Las filas sin cuenta propia se asignan acá. Dejala vacía para no asignar cuenta.",
      noAccountOption: "Sin cuenta",
      noAccountsYet: "Este hogar todavía no tiene cuentas.",
      defaultCategoryLabel: "Categoría por defecto",
      defaultCategoryHint:
        "Se usa cuando una fila no tiene categoría o no coincide con ninguna tuya.",
      mappingNeedDateAmount:
        "Necesitamos al menos las columnas de Fecha y Monto para continuar.",
      analyzeAgain: "Volver a analizar",
      continueToPreview: "Ver vista previa",
      // Paso 3 — preview
      previewTitle: "Revisá los movimientos",
      previewDescription:
        "Destildá las filas que no quieras importar. Las filas con errores ya quedaron fuera.",
      colDate: "Fecha",
      colType: "Tipo",
      colCategory: "Categoría",
      colAccount: "Cuenta",
      colAmount: "Monto",
      colNote: "Nota",
      typeExpense: "Gasto",
      typeIncome: "Ingreso",
      selectedCount: "{selected} de {total} seleccionadas",
      invalidRowsNote: "{count} filas con datos inválidos se omitieron.",
      rowErrorDate: "Fecha inválida",
      rowErrorAmount: "Monto inválido",
      rowErrorEmpty: "Fila vacía",
      selectAll: "Seleccionar todo",
      deselectAll: "Quitar todo",
      noValidRows:
        "No hay filas válidas para importar. Revisá el mapeo del paso anterior.",
      backToMapping: "Volver al mapeo",
      importSelected: "Importar {count} movimientos",
      importOne: "Importar 1 movimiento",
      // Paso 4 — resultado
      importing: "Importando movimientos…",
      successTitle: "¡Importación lista!",
      successBody: "Se importaron {inserted} movimientos a tu hogar.",
      partialBody:
        "Se importaron {inserted} movimientos. {skipped} se omitieron por datos inválidos.",
      nothingImported:
        "No se importó ningún movimiento. Revisá los datos e intentá de nuevo.",
      viewTransactions: "Ver movimientos",
      importMore: "Importar otro archivo",
      importError: "No pudimos completar la importación. Probá de nuevo.",
      rateLimitError:
        "Llegaste al límite de consultas a la IA por hoy. El mapeo automático sigue disponible.",
      genericError: "Algo salió mal. Probá de nuevo en un momento.",
    },
  },
  en: {
    nav: { import: "Import" },
    importTools: {
      metaTitle: "Import transactions",
      title: "Import transactions",
      description:
        "Upload an Excel or CSV (bank export, your own spreadsheet, etc.) and the AI maps the columns for you.",
      step1: "Upload file",
      step2: "Map columns",
      step3: "Review",
      step4: "Confirm",
      stepOf: "Step {current} of {total}",
      noHouseholdTitle: "Create a household first",
      noHouseholdDescription:
        "You need an active household to import transactions.",
      uploadTitle: "Upload your spreadsheet",
      uploadHint: "Drag a file here or click to choose one.",
      uploadFormats: "Formats: .xlsx or .csv · up to 5 MB · 2000 rows max.",
      uploadButton: "Choose file",
      uploadChange: "Change file",
      uploading: "Reading the file…",
      parseError: "We couldn't read the file. Check the format and try again.",
      fileTooLargeError: "The file is too large (5 MB max).",
      fileTypeError: "Unsupported format. Upload a .xlsx or .csv.",
      emptyFileError: "The file has no data rows.",
      truncatedNote:
        "The file had more than {max} rows. We'll import the first {max}.",
      rowsDetected: "{count} rows detected · {cols} columns",
      mappingTitle: "Confirm the column mapping",
      mappingDescription:
        "The AI matched each spreadsheet column to a field. Fix anything that's off.",
      mappingLoading: "The AI is analyzing your columns…",
      mappingAiFailed:
        "The AI isn't available right now; we built an automatic mapping you can adjust.",
      mappingHeuristicNote: "Automatic mapping (no AI). Review it carefully.",
      fieldDate: "Date",
      fieldAmount: "Amount",
      fieldType: "Type (expense/income)",
      fieldCategory: "Category",
      fieldAccount: "Account",
      fieldNote: "Note / description",
      columnNone: "— None —",
      columnLabel: "Column “{name}”",
      unnamedColumn: "Column {index}",
      typeFromSign: "Type is inferred from the amount sign (negative = expense).",
      typeFromColumn: "Type comes from a spreadsheet column.",
      dateFormatLabel: "Detected date format",
      targetAccountLabel: "Target account",
      targetAccountHint:
        "Rows without their own account are assigned here. Leave empty to assign no account.",
      noAccountOption: "No account",
      noAccountsYet: "This household has no accounts yet.",
      defaultCategoryLabel: "Fallback category",
      defaultCategoryHint:
        "Used when a row has no category or doesn't match any of yours.",
      mappingNeedDateAmount:
        "We need at least the Date and Amount columns to continue.",
      analyzeAgain: "Analyze again",
      continueToPreview: "See preview",
      previewTitle: "Review the transactions",
      previewDescription:
        "Uncheck rows you don't want to import. Rows with errors are already excluded.",
      colDate: "Date",
      colType: "Type",
      colCategory: "Category",
      colAccount: "Account",
      colAmount: "Amount",
      colNote: "Note",
      typeExpense: "Expense",
      typeIncome: "Income",
      selectedCount: "{selected} of {total} selected",
      invalidRowsNote: "{count} rows with invalid data were skipped.",
      rowErrorDate: "Invalid date",
      rowErrorAmount: "Invalid amount",
      rowErrorEmpty: "Empty row",
      selectAll: "Select all",
      deselectAll: "Clear all",
      noValidRows:
        "No valid rows to import. Review the mapping in the previous step.",
      backToMapping: "Back to mapping",
      importSelected: "Import {count} transactions",
      importOne: "Import 1 transaction",
      importing: "Importing transactions…",
      successTitle: "Import complete!",
      successBody: "{inserted} transactions were imported into your household.",
      partialBody:
        "{inserted} transactions were imported. {skipped} were skipped due to invalid data.",
      nothingImported:
        "No transactions were imported. Check the data and try again.",
      viewTransactions: "View transactions",
      importMore: "Import another file",
      importError: "We couldn't finish the import. Please try again.",
      rateLimitError:
        "You've hit today's AI request limit. Automatic mapping still works.",
      genericError: "Something went wrong. Try again in a moment.",
    },
  },
  pt: {
    nav: { import: "Importar" },
    importTools: {
      metaTitle: "Importar movimentações",
      title: "Importar movimentações",
      description:
        "Envie um Excel ou CSV (extrato do banco, sua própria planilha, etc.) e a IA mapeia as colunas para você.",
      step1: "Enviar arquivo",
      step2: "Mapear colunas",
      step3: "Revisar",
      step4: "Confirmar",
      stepOf: "Passo {current} de {total}",
      noHouseholdTitle: "Crie uma casa primeiro",
      noHouseholdDescription:
        "Você precisa de uma casa ativa para importar movimentações.",
      uploadTitle: "Envie sua planilha",
      uploadHint: "Arraste um arquivo aqui ou clique para escolher.",
      uploadFormats: "Formatos: .xlsx ou .csv · até 5 MB · 2000 linhas máx.",
      uploadButton: "Escolher arquivo",
      uploadChange: "Trocar arquivo",
      uploading: "Lendo o arquivo…",
      parseError: "Não foi possível ler o arquivo. Verifique o formato e tente de novo.",
      fileTooLargeError: "O arquivo é muito grande (máximo 5 MB).",
      fileTypeError: "Formato não suportado. Envie um .xlsx ou .csv.",
      emptyFileError: "O arquivo não tem linhas com dados.",
      truncatedNote:
        "O arquivo tinha mais de {max} linhas. Vamos importar as primeiras {max}.",
      rowsDetected: "{count} linhas detectadas · {cols} colunas",
      mappingTitle: "Confirme o mapeamento das colunas",
      mappingDescription:
        "A IA associou cada coluna da planilha a um campo. Corrija o que for preciso.",
      mappingLoading: "A IA está analisando suas colunas…",
      mappingAiFailed:
        "A IA não está disponível agora; montamos um mapeamento automático que você pode ajustar.",
      mappingHeuristicNote: "Mapeamento automático (sem IA). Revise com atenção.",
      fieldDate: "Data",
      fieldAmount: "Valor",
      fieldType: "Tipo (despesa/receita)",
      fieldCategory: "Categoria",
      fieldAccount: "Conta",
      fieldNote: "Nota / descrição",
      columnNone: "— Nenhuma —",
      columnLabel: "Coluna “{name}”",
      unnamedColumn: "Coluna {index}",
      typeFromSign: "O tipo é deduzido do sinal do valor (negativo = despesa).",
      typeFromColumn: "O tipo vem de uma coluna da planilha.",
      dateFormatLabel: "Formato de data detectado",
      targetAccountLabel: "Conta de destino",
      targetAccountHint:
        "Linhas sem conta própria são atribuídas aqui. Deixe vazio para não atribuir conta.",
      noAccountOption: "Sem conta",
      noAccountsYet: "Esta casa ainda não tem contas.",
      defaultCategoryLabel: "Categoria padrão",
      defaultCategoryHint:
        "Usada quando uma linha não tem categoria ou não combina com nenhuma das suas.",
      mappingNeedDateAmount:
        "Precisamos pelo menos das colunas de Data e Valor para continuar.",
      analyzeAgain: "Analisar de novo",
      continueToPreview: "Ver pré-visualização",
      previewTitle: "Revise as movimentações",
      previewDescription:
        "Desmarque as linhas que não quer importar. Linhas com erros já ficaram de fora.",
      colDate: "Data",
      colType: "Tipo",
      colCategory: "Categoria",
      colAccount: "Conta",
      colAmount: "Valor",
      colNote: "Nota",
      typeExpense: "Despesa",
      typeIncome: "Receita",
      selectedCount: "{selected} de {total} selecionadas",
      invalidRowsNote: "{count} linhas com dados inválidos foram ignoradas.",
      rowErrorDate: "Data inválida",
      rowErrorAmount: "Valor inválido",
      rowErrorEmpty: "Linha vazia",
      selectAll: "Selecionar tudo",
      deselectAll: "Limpar tudo",
      noValidRows:
        "Nenhuma linha válida para importar. Revise o mapeamento no passo anterior.",
      backToMapping: "Voltar ao mapeamento",
      importSelected: "Importar {count} movimentações",
      importOne: "Importar 1 movimentação",
      importing: "Importando movimentações…",
      successTitle: "Importação concluída!",
      successBody: "{inserted} movimentações foram importadas para sua casa.",
      partialBody:
        "{inserted} movimentações foram importadas. {skipped} foram ignoradas por dados inválidos.",
      nothingImported:
        "Nenhuma movimentação foi importada. Verifique os dados e tente de novo.",
      viewTransactions: "Ver movimentações",
      importMore: "Importar outro arquivo",
      importError: "Não foi possível concluir a importação. Tente de novo.",
      rateLimitError:
        "Você atingiu o limite de consultas à IA de hoje. O mapeamento automático continua disponível.",
      genericError: "Algo deu errado. Tente de novo em instantes.",
    },
  },
};
