import type { Locale } from "../config";

/** Árbol de mensajes anidado (clave → string o sub-árbol). */
export type Messages = { [key: string]: string | Messages };

/** Un módulo de diccionario por área: las 3 traducciones de ese namespace. */
export type LocaleModule = Record<Locale, Messages>;
