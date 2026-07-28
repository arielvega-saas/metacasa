import type { LocaleModule } from "./types";

/**
 * Diccionario del área **Wallets LatAm** (Mercado Pago).
 * Namespaces: `wallets` (+ `nav.wallets` para el menú).
 *
 * `wallets.mp.*` NO es chrome de UI: son las descripciones que se guardan como
 * DATO en `wallet_movements.description` cuando Mercado Pago no manda una
 * (transferencias P2P). Van traducidas para que un usuario en EN/PT no reciba
 * su historial en español.
 */
export const wallets: LocaleModule = {
  es: {
    nav: { wallets: "Wallets" },
    wallets: {
      title: "Wallets",
      description:
        "Conectá tu billetera y traé los movimientos sin cargarlos a mano.",
      premiumRequired: "Las wallets son parte de Premium.",
      securityNote:
        "Tu token queda cifrado en el servidor. El navegador nunca lo ve, y podés desconectar la cuenta cuando quieras.",

      emptyTitle: "Todavía no conectaste ninguna wallet",
      emptyDescription:
        "Conectá Mercado Pago y traé tus pagos y transferencias en un toque. Vos elegís cuáles se convierten en movimientos.",
      connectMP: "Conectar Mercado Pago",
      connecting: "Redirigiendo…",
      comingSoon: "Ualá, Brubank y Naranja X: próximamente.",

      card: {
        connected: "Conectada",
        sandbox: "Modo prueba",
        lastSync: "Último sync: {when}",
        neverSynced: "Sin sincronizar todavía",
        sync: "Sincronizar",
        syncing: "Sincronizando…",
        disconnect: "Desconectar",
        actions: "Acciones de {name}",
        pendingOne: "1 movimiento sin importar",
        pendingOther: "{count} movimientos sin importar",
        allImported: "Todo importado",
      },

      movements: {
        title: "Movimientos sin importar",
        subtitle:
          "Elegí cuáles convertir en movimientos de tu hogar. La categoría viene sugerida por lo que ya venís categorizando.",
        empty: "No hay movimientos pendientes. Sincronizá para traer los últimos.",
        selectAll: "Seleccionar todo",
        clear: "Limpiar selección",
        importOne: "Importar 1 movimiento",
        importOther: "Importar {count} movimientos",
        importing: "Importando…",
        colDate: "Fecha",
        colDescription: "Descripción",
        colCategory: "Categoría sugerida",
        colAmount: "Monto",
        noSuggestion: "Sin sugerencia",
        confidence: "{pct}% de confianza",
        selectRow: "Seleccionar movimiento",
      },

      disconnect: {
        title: "¿Desconectar {name}?",
        body: "Se borra la credencial guardada y dejamos de sincronizar. Tus movimientos ya importados quedan intactos.",
        confirm: "Desconectar",
      },

      toast: {
        connected: "Wallet conectada.",
        connectError: "No pudimos conectar la wallet. Probá de nuevo.",
        syncedNone: "Sin movimientos nuevos.",
        syncedOne: "1 movimiento nuevo.",
        syncedOther: "{count} movimientos nuevos.",
        importedOne: "1 movimiento importado.",
        importedOther: "{count} movimientos importados.",
        importedNone: "No se importó ningún movimiento.",
        skippedNoRate:
          "{count} quedaron afuera: falta la cotización de su moneda en tu hogar.",
        disconnected: "Wallet desconectada.",
      },

      errors: {
        notConfigured: "Las wallets no están configuradas en este entorno.",
        invalidState:
          "La conexión venció o no coincide. Volvé a intentar desde Wallets.",
        oauthFailed: "Mercado Pago rechazó la conexión.",
        saveFailed: "No pudimos guardar la wallet.",
        notFound: "No encontramos esa wallet.",
        providerUnsupported: "Todavía no soportamos ese proveedor.",
        reconnect: "La conexión expiró. Reconectá tu cuenta de Mercado Pago.",
        syncFailed: "No pudimos sincronizar. Probá de nuevo en un rato.",
        importFailed: "No pudimos importar los movimientos.",
        disconnectFailed: "No pudimos desconectar la wallet.",
      },

      mp: {
        transferFrom: "Transferencia de {name}",
        transferReceived: "Transferencia recibida",
        transferTo: "Transferencia a {name}",
        transferSent: "Transferencia enviada",
        depositIn: "Depósito bancario",
        fundingOut: "Fondeo de cuenta",
        yieldIn: "Rendimiento MP",
        investmentOut: "Inversión MP",
        fallback: "Movimiento MP",
      },
    },
  },

  en: {
    nav: { wallets: "Wallets" },
    wallets: {
      title: "Wallets",
      description: "Connect your wallet and pull in activity without typing it.",
      premiumRequired: "Wallets are part of Premium.",
      securityNote:
        "Your token is encrypted on the server. The browser never sees it, and you can disconnect anytime.",

      emptyTitle: "No wallets connected yet",
      emptyDescription:
        "Connect Mercado Pago to pull in your payments and transfers. You decide which ones become transactions.",
      connectMP: "Connect Mercado Pago",
      connecting: "Redirecting…",
      comingSoon: "Ualá, Brubank and Naranja X: coming soon.",

      card: {
        connected: "Connected",
        sandbox: "Test mode",
        lastSync: "Last sync: {when}",
        neverSynced: "Not synced yet",
        sync: "Sync",
        syncing: "Syncing…",
        disconnect: "Disconnect",
        actions: "{name} actions",
        pendingOne: "1 activity item to import",
        pendingOther: "{count} activity items to import",
        allImported: "All imported",
      },

      movements: {
        title: "Activity to import",
        subtitle:
          "Pick what becomes a household transaction. Categories are suggested from how you already categorize.",
        empty: "Nothing pending. Sync to pull the latest activity.",
        selectAll: "Select all",
        clear: "Clear selection",
        importOne: "Import 1 item",
        importOther: "Import {count} items",
        importing: "Importing…",
        colDate: "Date",
        colDescription: "Description",
        colCategory: "Suggested category",
        colAmount: "Amount",
        noSuggestion: "No suggestion",
        confidence: "{pct}% confidence",
        selectRow: "Select item",
      },

      disconnect: {
        title: "Disconnect {name}?",
        body: "We delete the stored credential and stop syncing. Already imported transactions stay untouched.",
        confirm: "Disconnect",
      },

      toast: {
        connected: "Wallet connected.",
        connectError: "We couldn't connect the wallet. Try again.",
        syncedNone: "No new activity.",
        syncedOne: "1 new item.",
        syncedOther: "{count} new items.",
        importedOne: "1 item imported.",
        importedOther: "{count} items imported.",
        importedNone: "Nothing was imported.",
        skippedNoRate:
          "{count} were skipped: your household has no exchange rate for their currency.",
        disconnected: "Wallet disconnected.",
      },

      errors: {
        notConfigured: "Wallets aren't configured in this environment.",
        invalidState: "The connection expired or didn't match. Start again from Wallets.",
        oauthFailed: "Mercado Pago rejected the connection.",
        saveFailed: "We couldn't save the wallet.",
        notFound: "We couldn't find that wallet.",
        providerUnsupported: "That provider isn't supported yet.",
        reconnect: "The connection expired. Reconnect your Mercado Pago account.",
        syncFailed: "We couldn't sync. Try again in a bit.",
        importFailed: "We couldn't import the activity.",
        disconnectFailed: "We couldn't disconnect the wallet.",
      },

      mp: {
        transferFrom: "Transfer from {name}",
        transferReceived: "Transfer received",
        transferTo: "Transfer to {name}",
        transferSent: "Transfer sent",
        depositIn: "Bank deposit",
        fundingOut: "Account funding",
        yieldIn: "MP yield",
        investmentOut: "MP investment",
        fallback: "MP activity",
      },
    },
  },

  pt: {
    nav: { wallets: "Carteiras" },
    wallets: {
      title: "Carteiras",
      description:
        "Conecte sua carteira e traga a movimentação sem digitar nada.",
      premiumRequired: "As carteiras fazem parte do Premium.",
      securityNote:
        "Seu token fica criptografado no servidor. O navegador nunca o vê, e você pode desconectar quando quiser.",

      emptyTitle: "Nenhuma carteira conectada ainda",
      emptyDescription:
        "Conecte o Mercado Pago e traga seus pagamentos e transferências. Você escolhe quais viram transações.",
      connectMP: "Conectar Mercado Pago",
      connecting: "Redirecionando…",
      comingSoon: "Ualá, Brubank e Naranja X: em breve.",

      card: {
        connected: "Conectada",
        sandbox: "Modo teste",
        lastSync: "Última sincronização: {when}",
        neverSynced: "Ainda não sincronizada",
        sync: "Sincronizar",
        syncing: "Sincronizando…",
        disconnect: "Desconectar",
        actions: "Ações de {name}",
        pendingOne: "1 movimentação para importar",
        pendingOther: "{count} movimentações para importar",
        allImported: "Tudo importado",
      },

      movements: {
        title: "Movimentações para importar",
        subtitle:
          "Escolha o que vira transação da casa. A categoria é sugerida a partir do que você já categoriza.",
        empty: "Nada pendente. Sincronize para trazer as últimas movimentações.",
        selectAll: "Selecionar tudo",
        clear: "Limpar seleção",
        importOne: "Importar 1 movimentação",
        importOther: "Importar {count} movimentações",
        importing: "Importando…",
        colDate: "Data",
        colDescription: "Descrição",
        colCategory: "Categoria sugerida",
        colAmount: "Valor",
        noSuggestion: "Sem sugestão",
        confidence: "{pct}% de confiança",
        selectRow: "Selecionar movimentação",
      },

      disconnect: {
        title: "Desconectar {name}?",
        body: "A credencial salva é apagada e paramos de sincronizar. As transações já importadas continuam intactas.",
        confirm: "Desconectar",
      },

      toast: {
        connected: "Carteira conectada.",
        connectError: "Não conseguimos conectar a carteira. Tente de novo.",
        syncedNone: "Sem movimentações novas.",
        syncedOne: "1 movimentação nova.",
        syncedOther: "{count} movimentações novas.",
        importedOne: "1 movimentação importada.",
        importedOther: "{count} movimentações importadas.",
        importedNone: "Nenhuma movimentação foi importada.",
        skippedNoRate:
          "{count} ficaram de fora: falta a cotação da moeda delas na sua casa.",
        disconnected: "Carteira desconectada.",
      },

      errors: {
        notConfigured: "As carteiras não estão configuradas neste ambiente.",
        invalidState:
          "A conexão expirou ou não confere. Comece de novo em Carteiras.",
        oauthFailed: "O Mercado Pago recusou a conexão.",
        saveFailed: "Não conseguimos salvar a carteira.",
        notFound: "Não encontramos essa carteira.",
        providerUnsupported: "Ainda não damos suporte a esse provedor.",
        reconnect: "A conexão expirou. Reconecte sua conta do Mercado Pago.",
        syncFailed: "Não conseguimos sincronizar. Tente de novo daqui a pouco.",
        importFailed: "Não conseguimos importar as movimentações.",
        disconnectFailed: "Não conseguimos desconectar a carteira.",
      },

      mp: {
        transferFrom: "Transferência de {name}",
        transferReceived: "Transferência recebida",
        transferTo: "Transferência para {name}",
        transferSent: "Transferência enviada",
        depositIn: "Depósito bancário",
        fundingOut: "Aporte na conta",
        yieldIn: "Rendimento MP",
        investmentOut: "Investimento MP",
        fallback: "Movimentação MP",
      },
    },
  },
};
