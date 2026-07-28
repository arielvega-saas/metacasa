import type { LocaleModule } from "./types";

/**
 * Diccionario del PWA offline (ítem 4.8): la página `/~offline` que el service
 * worker sirve cuando no hay red. Namespace propio `offline`.
 *
 * Tono: honesto y corto. NO prometemos datos: justamente el punto es que
 * preferimos decir "no hay conexión" antes que mostrar saldos viejos.
 */
export const pwa: LocaleModule = {
  es: {
    offline: {
      metaTitle: "Sin conexión",
      title: "Estás sin conexión",
      body: "No pudimos conectarnos para traer tus datos. Para no mostrarte saldos viejos como si fueran de ahora, preferimos avisarte.",
      hint: "Revisá tu red y volvé a intentar: apenas vuelva la conexión, todo carga actualizado.",
      retry: "Reintentar",
      goHome: "Ir al inicio",
    },
  },
  en: {
    offline: {
      metaTitle: "Offline",
      title: "You're offline",
      body: "We couldn't reach the network to load your data. Rather than show you stale balances as if they were current, we'd rather tell you.",
      hint: "Check your connection and try again — everything loads fresh as soon as you're back online.",
      retry: "Try again",
      goHome: "Go home",
    },
  },
  pt: {
    offline: {
      metaTitle: "Sem conexão",
      title: "Você está sem conexão",
      body: "Não conseguimos acessar a rede para carregar seus dados. Em vez de mostrar saldos antigos como se fossem atuais, preferimos avisar.",
      hint: "Verifique sua conexão e tente de novo: assim que voltar, tudo carrega atualizado.",
      retry: "Tentar de novo",
      goHome: "Ir para o início",
    },
  },
};
