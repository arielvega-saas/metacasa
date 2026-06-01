import type { Messages } from "./dictionaries/types";

/** Resuelve una clave con punto ("transactions.title") en el árbol. */
export function lookup(dict: Messages, key: string): string | undefined {
  const parts = key.split(".");
  let cur: string | Messages | undefined = dict;
  for (const p of parts) {
    if (cur && typeof cur === "object") cur = cur[p];
    else return undefined;
  }
  return typeof cur === "string" ? cur : undefined;
}

/** Reemplaza {placeholders} por variables. */
export function interpolate(
  template: string,
  vars?: Record<string, string | number>,
): string {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (_, k) =>
    vars[k] != null ? String(vars[k]) : `{${k}}`,
  );
}
