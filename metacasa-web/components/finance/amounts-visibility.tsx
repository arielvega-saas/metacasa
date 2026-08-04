"use client";

import { useSyncExternalStore } from "react";
import {
  BALANCE_PRIVACY_ATTR,
  BALANCE_PRIVACY_COOKIE,
  BALANCE_PRIVACY_MAX_AGE,
} from "@/lib/balance-privacy";

/**
 * Visibilidad global de montos ("modo ojito").
 *
 * **La preferencia vive en una COOKIE, no en `localStorage`.** Antes era localStorage con
 * `getServerSnapshot() = false`, y esa combinación tenía un agujero: el servidor renderizaba los
 * montos VISIBLES en cada carga y recién se ocultaban al hidratar. La función existía y filtraba
 * exactamente lo que tenía que tapar — alguien mirando la pantalla veía los saldos durante el
 * primer paint. El `false` del server snapshot no era el bug: era el parche correcto a un bug de
 * diseño, porque con localStorage el servidor no puede saber la preferencia.
 *
 * Con cookie, el layout marca `<html data-hide-balances>` y el CSS oculta antes de que corra JS.
 * Es la misma decisión que ya se había tomado para el tema (`lib/theme.ts`), por la misma razón.
 *
 * Este store queda para lo que SÍ necesita ser reactivo dentro de la sesión: el ícono del botón
 * y el `title` de los montos, que hay que quitar cuando están ocultos — un tooltip con el monto
 * exacto sería una filtración por la puerta de atrás, y el CSS no puede borrar un atributo.
 *
 * Sigue siendo un store externo y no un Context porque `<Amount>` es una hoja usada en 30
 * pantallas que cuelgan del layout: no hay un provider único que las envuelva.
 */

let hidden = false;
const listeners = new Set<() => void>();

function emit() {
  for (const l of listeners) l();
}

function readCookie(): boolean {
  if (typeof document === "undefined") return false;
  return document.cookie
    .split("; ")
    .some((c) => c === `${BALANCE_PRIVACY_COOKIE}=1`);
}

if (typeof window !== "undefined") {
  // El valor inicial sale del atributo que YA puso el servidor, no de la cookie: así el store
  // arranca diciendo exactamente lo mismo que se está viendo en pantalla.
  hidden = document.documentElement.hasAttribute(BALANCE_PRIVACY_ATTR);
  // Otra pestaña puede haberlo cambiado. `storage` no dispara para cookies, así que
  // resincronizamos cuando la pestaña vuelve a estar visible.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") syncFromCookie();
  });
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function getSnapshot(): boolean {
  return hidden;
}

/**
 * En SSR devolvemos `false`, pero acá ya no importa como antes: el ocultamiento visual no
 * depende de este valor, lo hace el CSS. Esto sólo afecta al ícono del botón y al `title`,
 * que se corrigen al hidratar sin que se vea ningún monto de más.
 */
function getServerSnapshot(): boolean {
  return false;
}

/** Suscripción reactiva al estado "ocultar montos". */
export function useAmountsHidden(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

/**
 * Define el estado y lo persiste.
 *
 * Escribe la cookie y toca el `<html>` en el acto, sin esperar el round-trip de la server
 * action: el usuario tocó "ocultar" y los montos tienen que desaparecer YA. La action corre
 * después, sólo para que el próximo render del servidor arranque con el valor correcto.
 */
export function setAmountsHidden(next: boolean): void {
  hidden = next;
  if (typeof document !== "undefined") {
    document.cookie = [
      `${BALANCE_PRIVACY_COOKIE}=${next ? "1" : "0"}`,
      "path=/",
      `max-age=${BALANCE_PRIVACY_MAX_AGE}`,
      "samesite=lax",
    ].join("; ");
    document.documentElement.toggleAttribute(BALANCE_PRIVACY_ATTR, next);
  }
  emit();
}

/** Alterna el estado actual. */
export function toggleAmountsHidden(): void {
  setAmountsHidden(!hidden);
}

/** Re-lee la cookie por si otra pestaña la cambió. */
export function syncFromCookie(): void {
  const v = readCookie();
  if (v !== hidden) {
    hidden = v;
    document.documentElement.toggleAttribute(BALANCE_PRIVACY_ATTR, v);
    emit();
  }
}
