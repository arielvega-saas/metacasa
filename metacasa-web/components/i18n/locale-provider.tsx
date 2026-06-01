"use client";

import { createContext, useContext } from "react";
import type { Messages } from "@/lib/i18n/dictionaries/types";
import { DEFAULT_LOCALE, type Locale } from "@/lib/i18n/config";
import { lookup, interpolate } from "@/lib/i18n/lookup";

type Ctx = { locale: Locale; dict: Messages };
const LocaleCtx = createContext<Ctx>({ locale: DEFAULT_LOCALE, dict: {} });

/** Provee el diccionario del locale activo a los Client Components. */
export function LocaleProvider({
  locale,
  dict,
  children,
}: {
  locale: Locale;
  dict: Messages;
  children: React.ReactNode;
}) {
  return (
    <LocaleCtx.Provider value={{ locale, dict }}>{children}</LocaleCtx.Provider>
  );
}

/** `t()` para Client Components: `const t = useT(); t("nav.home")`. */
export function useT() {
  const { dict } = useContext(LocaleCtx);
  return (key: string, vars?: Record<string, string | number>) =>
    interpolate(lookup(dict, key) ?? key, vars);
}

export function useLocale(): Locale {
  return useContext(LocaleCtx).locale;
}
