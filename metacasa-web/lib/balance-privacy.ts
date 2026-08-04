/**
 * Ocultar saldos ("modo ojito").
 *
 * Estándar absoluto en LatAm: Mercado Pago, Ualá, Nubank y Naranja X lo tienen todas. La app de
 * iOS ya lo tenía (`PrivacyManager.obfuscate`); la web era la única superficie donde tus números
 * quedaban a la vista de quien pasara por atrás.
 *
 * **La preferencia vive en una COOKIE, no en `localStorage`**, por la misma razón que el tema —
 * pero acá el motivo es más fuerte. Con `localStorage` el servidor no sabe nada, así que la
 * primera pintura muestra los montos REALES y recién al hidratar se ocultan. Ese parpadeo es
 * exactamente lo que la función existe para evitar: alguien mirando la pantalla ve el saldo. Con
 * cookie, el Server Component ya marca `<html>` y los montos nunca llegan a pintarse.
 *
 * Por eso el ocultamiento es **CSS sobre un atributo de `<html>`** y no lógica de React: el CSS
 * aplica en el primer paint, antes de que corra un solo byte de JS.
 *
 * Módulo PURO (sin `next/headers`, sin "use client"): lo importan el layout server, la server
 * action y el toggle client.
 */

export const BALANCE_PRIVACY_COOKIE = "mc_hide_balances";

/** Un año, igual que el tema: no es una preferencia que deba caducar sola. */
export const BALANCE_PRIVACY_MAX_AGE = 60 * 60 * 24 * 365;

/** Atributo en `<html>` que dispara el CSS. */
export const BALANCE_PRIVACY_ATTR = "data-hide-balances";

/**
 * Clase que va en cada monto que debe poder ocultarse.
 *
 * Se marca el monto, no el contenedor: dentro de una misma fila conviven cosas que se ocultan
 * (el importe) y cosas que no (la fecha, la categoría, el nombre del comercio). Ocultar la fila
 * entera dejaría la pantalla inutilizable en vez de privada.
 */
export const MONEY_CLASS = "mc-money";

export function isHidden(v: string | undefined | null): boolean {
  return v === "1";
}
