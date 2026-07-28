import type { LocaleModule } from "./types";

/**
 * Diccionario de la **paleta de comandos** (⌘K / Ctrl+K).
 * Namespace único: `palette`. Las etiquetas de las rutas se reusan del
 * namespace `nav` (las mismas del sidebar), así no se duplican traducciones.
 *
 * ES = rioplatense (vos). EN/PT = fintech profesional.
 */
export const palette: LocaleModule = {
  es: {
    palette: {
      title: "Paleta de comandos",
      description: "Buscá una pantalla, una acción o un movimiento.",
      placeholder: "Buscar pantallas, acciones o movimientos…",
      groupNavigate: "Ir a",
      groupActions: "Acciones",
      groupSearch: "Buscar",
      newTransaction: "Nueva transacción",
      newBill: "Nuevo vencimiento",
      searchTransactions: "Buscar “{q}” en movimientos",
      openHint: "para abrir",
      closeHint: "para cerrar",
    },
  },
  en: {
    palette: {
      title: "Command palette",
      description: "Search for a screen, an action or a transaction.",
      placeholder: "Search screens, actions or transactions…",
      groupNavigate: "Go to",
      groupActions: "Actions",
      groupSearch: "Search",
      newTransaction: "New transaction",
      newBill: "New bill",
      searchTransactions: "Search “{q}” in transactions",
      openHint: "to open",
      closeHint: "to close",
    },
  },
  pt: {
    palette: {
      title: "Paleta de comandos",
      description: "Busque uma tela, uma ação ou uma movimentação.",
      placeholder: "Buscar telas, ações ou movimentações…",
      groupNavigate: "Ir para",
      groupActions: "Ações",
      groupSearch: "Buscar",
      newTransaction: "Nova transação",
      newBill: "Novo vencimento",
      searchTransactions: "Buscar “{q}” em movimentações",
      openHint: "para abrir",
      closeHint: "para fechar",
    },
  },
};
