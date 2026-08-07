/**
 * Definición de las tools que el asistente web puede ejecutar (formato Anthropic
 * Messages API).
 *
 * PARIDAD CON iOS — fuente canónica:
 *   ../metacasa-ios/MetaCasa/Core/AI/Providers/AnthropicToolBuilder.swift
 *   ../metacasa-ios/MetaCasa/Core/AI/Tools/AIToolDefinitions.swift
 *
 * Nombres, descripciones y parámetros están portados 1:1 de ahí para que el
 * mismo modelo se comporte igual en la app y en la web. iOS expone 22 tools;
 * acá arrancamos con las 5 que la web ya puede resolver server-side con RLS
 * (movimientos + cuentas). El resto del contexto financiero (resumen del mes,
 * top categorías, vencimientos, metas) ya viaja inyectado en el system prompt,
 * así que no hace falta una tool para leerlo.
 *
 * Dos desviaciones deliberadas respecto de iOS, documentadas para que no se
 * lean como olvido:
 *  - `subcategory` (add/update_transaction): la web escribe vía
 *    `lib/db/transactions.ts`, que no persiste esa columna. Declarar el campo
 *    sería prometerle al modelo algo que se descarta en silencio.
 *  - `includeInactive` (get_accounts): la web sólo lee cuentas activas
 *    (`listAccounts` filtra `is_active`). Mismo criterio.
 */

/** Nodo de JSON Schema soportado por la Messages API (subset que usamos). */
export type ToolSchemaProperty = {
  type: "string" | "number" | "integer" | "boolean";
  description: string;
  enum?: string[];
};

/** Tool en el formato que espera Anthropic (y que el proxy pasa tal cual). */
export interface AnthropicTool {
  name: string;
  description: string;
  input_schema: {
    type: "object";
    properties: Record<string, ToolSchemaProperty>;
    required: string[];
  };
}

/** Nombres válidos de tool. El dispatcher hace exhaustive switch sobre esto. */
export const TOOL_NAMES = [
  "query_transactions",
  "add_transaction",
  "update_transaction",
  "delete_transaction",
  "get_accounts",
] as const;

export type ToolName = (typeof TOOL_NAMES)[number];

/** Type guard: ¿el `name` que devolvió el modelo es una tool que conocemos? */
export function isKnownTool(name: string): name is ToolName {
  return (TOOL_NAMES as readonly string[]).includes(name);
}

const str = (description: string): ToolSchemaProperty => ({ type: "string", description });
const num = (description: string): ToolSchemaProperty => ({ type: "number", description });
const int = (description: string): ToolSchemaProperty => ({ type: "integer", description });

/**
 * Tools disponibles para el asistente web.
 *
 * NOTA DE SEGURIDAD: ninguna tool recibe `householdId` ni `userId`. El hogar
 * activo y el usuario los resuelve el servidor (`resolveActiveHousehold` +
 * `auth.getUser`) en cada request; el modelo no puede elegir sobre qué hogar
 * escribe. Ver `lib/ai/dispatch.ts`.
 */
export const ASSISTANT_TOOLS: AnthropicTool[] = [
  {
    name: "query_transactions",
    description:
      "Search and filter the user's transactions by category, date range, type, amount, or note. Use to answer questions about spending, income, specific purchases, or merchants. Returns the matching transactions WITH their UUIDs — call this first when you need an id for update_transaction or delete_transaction. It also returns income/expense totals aggregated over the ENTIRE filter (not just the listed rows), with transfers between the user's own accounts excluded: use those totals to answer 'how much did I spend/earn', never add up the listed rows yourself.",
    input_schema: {
      type: "object",
      properties: {
        category: str("Filter by category name (e.g. 'Supermercado', 'Transporte')"),
        dateFrom: str("Start date in yyyy-MM-dd format"),
        dateTo: str("End date in yyyy-MM-dd format"),
        type: {
          type: "string",
          description: "Filter by type: 'GASTO' for expenses or 'INGRESO' for income",
          enum: ["GASTO", "INGRESO"],
        },
        noteContains: str("Search in transaction notes (merchant name, description)"),
        amountMin: num("Minimum amount"),
        amountMax: num("Maximum amount"),
        limit: int(
          "Max transactions to LIST (default 20, max 50). It does not affect the totals, which always cover the whole filter",
        ),
      },
      required: [],
    },
  },
  {
    name: "add_transaction",
    description:
      "Create a new expense or income transaction in the user's household. Always confirm the details with the user in plain language BEFORE calling this tool. Amounts are in the household's base currency.",
    input_schema: {
      type: "object",
      properties: {
        type: {
          type: "string",
          description: "Transaction type: 'GASTO' for expense, 'INGRESO' for income",
          enum: ["GASTO", "INGRESO"],
        },
        amount: num("Amount as a positive number, in the household base currency"),
        category: str("Category name (e.g. 'Supermercado', 'Sueldo')"),
        note: str("Optional note or merchant name"),
        date: str("Date in yyyy-MM-dd format. Today if omitted."),
      },
      required: ["type", "amount", "category"],
    },
  },
  {
    name: "update_transaction",
    description:
      "Modify an existing transaction. First use query_transactions to find it and get its UUID. Only the fields you provide are changed; the rest stay as they were. Confirm with the user before calling.",
    input_schema: {
      type: "object",
      properties: {
        transactionId: str("UUID of the transaction to update"),
        amount: num("New amount (positive number)"),
        category: str("New category"),
        note: str("New note"),
        date: str("New date in yyyy-MM-dd"),
        type: {
          type: "string",
          description: "New type: 'GASTO' or 'INGRESO'",
          enum: ["GASTO", "INGRESO"],
        },
      },
      required: ["transactionId"],
    },
  },
  {
    name: "delete_transaction",
    description:
      "Delete a transaction by its UUID. Use query_transactions first to find the exact one, and ALWAYS get an explicit confirmation from the user before calling this tool — deleting cannot be undone.",
    input_schema: {
      type: "object",
      properties: {
        transactionId: str("UUID of the transaction to delete"),
      },
      required: ["transactionId"],
    },
  },
  {
    name: "get_accounts",
    description:
      "List the household's financial accounts with their type and current balance: checking, savings, cash, credit cards, investments, loans.",
    input_schema: {
      type: "object",
      properties: {},
      required: [],
    },
  },
];
