/**
 * Tema visual de la web (claro / oscuro / sistema).
 *
 * La preferencia vive en una COOKIE (`mc_theme`), no en localStorage: así el
 * Server Component ya renderiza `<html>` con la clase correcta y no hay flash
 * de tema equivocado en la primera pintura.
 *
 * Estados:
 *  - `system` (default): sigue `prefers-color-scheme` del SO.
 *  - `light` / `dark`: forzado por el usuario.
 *
 * Módulo PURO (sin `next/headers`, sin "use client"): lo importan el layout
 * server, la server action y el componente client del toggle.
 */

export const THEMES = ["system", "light", "dark"] as const;
export type Theme = (typeof THEMES)[number];

export const DEFAULT_THEME: Theme = "system";
export const THEME_COOKIE = "mc_theme";

/** Un año: la preferencia de tema no debería caducar en una sesión normal. */
export const THEME_COOKIE_MAX_AGE = 60 * 60 * 24 * 365;

export function isTheme(v: string | undefined | null): v is Theme {
  return !!v && (THEMES as readonly string[]).includes(v);
}

/**
 * Clase que va en `<html>` para una preferencia dada.
 *
 * `system` devuelve "" a propósito: el servidor no puede saber qué prefiere el
 * SO del visitante, así que renderiza el default histórico (oscuro, que es el
 * `:root` de globals.css) y el script inline lo corrige antes del primer paint.
 */
export function themeClass(theme: Theme): "" | "light" | "dark" {
  return theme === "system" ? "" : theme;
}

/** Resuelve `system` a un tema concreto según la preferencia del SO. */
export function resolveTheme(theme: Theme, prefersDark: boolean): "light" | "dark" {
  if (theme === "light" || theme === "dark") return theme;
  return prefersDark ? "dark" : "light";
}

/**
 * Script inline que se inyecta en `<head>` ANTES del `<body>`.
 *
 * Corre de forma síncrona, antes de que el navegador pinte nada, así que
 * cambiar la clase acá no produce flash. Hace dos cosas:
 *  1. Resuelve `system` contra `prefers-color-scheme` y aplica la clase.
 *  2. Si la preferencia es `system`, escucha cambios del SO para reaccionar en
 *     caliente sin recargar.
 *
 * `theme` se interpola en el string: SIEMPRE validar con `isTheme()` antes de
 * llamar a esta función (sólo entran "system" | "light" | "dark", nunca input
 * del usuario sin filtrar).
 */
export function themeInitScript(theme: Theme): string {
  return `(function(){try{var p=${JSON.stringify(theme)};var r=document.documentElement;var m=window.matchMedia("(prefers-color-scheme: dark)");function a(){var t=p==="system"?(m.matches?"dark":"light"):p;r.classList.toggle("dark",t==="dark");r.classList.toggle("light",t==="light")}a();if(p==="system"){m.addEventListener?m.addEventListener("change",a):m.addListener(a)}}catch(e){}})()`;
}
