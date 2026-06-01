"use client";

import { useEffect } from "react";

/**
 * Aplica preferencias locales (localStorage) al cargar cualquier pantalla:
 * - Reducir animaciones → `<html data-reduce-motion="1">` (regla global en globals.css).
 *
 * Se monta en la topbar (presente en todas las páginas de la app) para que la
 * preferencia valga en toda la sesión, no solo cuando se abre Preferencias.
 * No renderiza nada.
 */
export function PreferencesBootstrap() {
  useEffect(() => {
    try {
      const reduceMotion =
        window.localStorage.getItem("mc_pref_reduce_motion") === "1";
      if (reduceMotion) {
        document.documentElement.dataset.reduceMotion = "1";
      }
    } catch {
      /* ignore */
    }
  }, []);
  return null;
}
