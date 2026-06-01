"use client";

import { useSyncExternalStore } from "react";

/**
 * Visibilidad global de montos ("Ocultar montos" / privacy mode).
 *
 * Es un store externo a React (módulo singleton) en vez de un Context, porque
 * `<Amount>` es un componente hoja usado en muchísimas pantallas que cuelgan del
 * layout de la app: no hay un único provider que las envuelva sin tocar el
 * layout. Cualquier `<Amount>` y cualquier control (topbar / preferencias) se
 * suscriben al mismo store vía `useSyncExternalStore`, y persiste en localStorage.
 */

const STORAGE_KEY = "mc_pref_hide_amounts";

let hidden = false;
const listeners = new Set<() => void>();

function emit() {
  for (const l of listeners) l();
}

/** Lee el valor persistido (solo en cliente). Idempotente. */
function readPersisted(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return window.localStorage.getItem(STORAGE_KEY) === "1";
  } catch {
    return false;
  }
}

// Hidrata el valor inicial una sola vez en el cliente.
if (typeof window !== "undefined") {
  hidden = readPersisted();
  // Mantiene sincronía entre pestañas.
  window.addEventListener("storage", (e) => {
    if (e.key === STORAGE_KEY) {
      hidden = e.newValue === "1";
      emit();
    }
  });
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function getSnapshot(): boolean {
  return hidden;
}

/** En el server siempre devolvemos `false` para evitar mismatches de hidratación. */
function getServerSnapshot(): boolean {
  return false;
}

/** Suscripción reactiva al estado "ocultar montos". */
export function useAmountsHidden(): boolean {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

/** Define explícitamente el estado y lo persiste. */
export function setAmountsHidden(next: boolean): void {
  hidden = next;
  try {
    window.localStorage.setItem(STORAGE_KEY, next ? "1" : "0");
  } catch {
    /* ignore quota / privacy mode */
  }
  emit();
}

/** Alterna el estado actual. */
export function toggleAmountsHidden(): void {
  setAmountsHidden(!hidden);
}
