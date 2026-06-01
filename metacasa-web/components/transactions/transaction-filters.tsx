"use client";

import * as React from "react";
import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { Search, X, SlidersHorizontal } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
  SelectGroup,
  SelectLabel,
} from "@/components/ui/select";
import { TX_TYPE } from "@/lib/constants";
import { useT } from "@/components/i18n/locale-provider";

type AccountOption = { id: string; name: string };

interface Props {
  categories: { gastos: string[]; ingresos: string[] };
  accounts: AccountOption[];
}

// Valores "todos" para los selects (Radix Select no admite value="").
const ALL = "__all__";

/**
 * Barra de filtros avanzados. Actualiza la URL (searchParams) sin recargar
 * toda la pantalla; el server component re-fetchea con los nuevos filtros.
 * La búsqueda de texto se aplica con debounce para no spamear navegaciones.
 */
export function TransactionFilters({ categories, accounts }: Props) {
  const t = useT();
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();

  const type = params.get("type") ?? ALL;
  const category = params.get("category") ?? ALL;
  const account = params.get("account") ?? ALL;
  const from = params.get("from") ?? "";
  const to = params.get("to") ?? "";
  const initialQuery = params.get("q") ?? "";
  const initialMin = params.get("min") ?? "";
  const initialMax = params.get("max") ?? "";

  const [query, setQuery] = React.useState(initialQuery);
  const [min, setMin] = React.useState(initialMin);
  const [max, setMax] = React.useState(initialMax);

  // Mantiene los inputs sincronizados si la URL cambia desde afuera (ej. limpiar).
  React.useEffect(() => {
    setQuery(initialQuery);
  }, [initialQuery]);
  React.useEffect(() => {
    setMin(initialMin);
  }, [initialMin]);
  React.useEffect(() => {
    setMax(initialMax);
  }, [initialMax]);

  // Aplica un cambio de filtro: muta searchParams y resetea la página a 1.
  const apply = React.useCallback(
    (patch: Record<string, string | null>) => {
      const next = new URLSearchParams(params.toString());
      for (const [key, value] of Object.entries(patch)) {
        if (value === null || value === "" || value === ALL) next.delete(key);
        else next.set(key, value);
      }
      next.delete("page"); // cualquier cambio de filtro vuelve a la página 1
      const qs = next.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [params, pathname, router],
  );

  // Debounce de la búsqueda de texto (350 ms).
  React.useEffect(() => {
    if (query === initialQuery) return;
    const t = setTimeout(() => apply({ q: query || null }), 350);
    return () => clearTimeout(t);
  }, [query, initialQuery, apply]);

  // Debounce de los montos mín./máx. (400 ms). Sólo aplica valores numéricos.
  React.useEffect(() => {
    if (min === initialMin) return;
    const t = setTimeout(() => apply({ min: min.trim() || null }), 400);
    return () => clearTimeout(t);
  }, [min, initialMin, apply]);
  React.useEffect(() => {
    if (max === initialMax) return;
    const t = setTimeout(() => apply({ max: max.trim() || null }), 400);
    return () => clearTimeout(t);
  }, [max, initialMax, apply]);

  // Presets de fecha: setean from/to (formato YYYY-MM-DD) de una sola vez.
  const ymd = (d: Date) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(
      d.getDate(),
    ).padStart(2, "0")}`;

  const applyPreset = React.useCallback(
    (preset: "thisMonth" | "lastMonth" | "thisWeek" | "all") => {
      if (preset === "all") {
        apply({ from: null, to: null });
        return;
      }
      const now = new Date();
      let start: Date;
      let end: Date;
      if (preset === "thisMonth") {
        start = new Date(now.getFullYear(), now.getMonth(), 1);
        end = new Date(now.getFullYear(), now.getMonth() + 1, 0);
      } else if (preset === "lastMonth") {
        start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        end = new Date(now.getFullYear(), now.getMonth(), 0);
      } else {
        // thisWeek: lunes a domingo de la semana actual.
        const day = now.getDay(); // 0 = domingo
        const mondayOffset = day === 0 ? -6 : 1 - day;
        start = new Date(now.getFullYear(), now.getMonth(), now.getDate() + mondayOffset);
        end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 6);
      }
      apply({ from: ymd(start), to: ymd(end) });
    },
    [apply],
  );

  // Las categorías a mostrar dependen del tipo elegido.
  const catOptions =
    type === TX_TYPE.INCOME
      ? categories.ingresos
      : type === TX_TYPE.EXPENSE
        ? categories.gastos
        : [...categories.gastos, ...categories.ingresos];

  const hasActiveFilters =
    type !== ALL ||
    category !== ALL ||
    account !== ALL ||
    Boolean(from) ||
    Boolean(to) ||
    Boolean(initialQuery) ||
    Boolean(initialMin) ||
    Boolean(initialMax);

  function clearAll() {
    setQuery("");
    setMin("");
    setMax("");
    router.replace(pathname, { scroll: false });
  }

  return (
    <div className="bg-card hairline rounded-[var(--radius-xl)] p-4">
      <div className="mb-3 flex items-center justify-between">
        <span className="text-text-muted inline-flex items-center gap-2 text-[13px] font-medium">
          <SlidersHorizontal className="size-4" /> {t("transactions.filters")}
        </span>
        {hasActiveFilters && (
          <Button variant="ghost" size="sm" onClick={clearAll} className="h-8 px-2.5 text-xs">
            <X className="size-3.5" /> {t("transactions.clearFilters")}
          </Button>
        )}
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-12">
        {/* Búsqueda por nota */}
        <div className="space-y-1.5 lg:col-span-4">
          <Label htmlFor="flt-q">{t("transactions.searchLabel")}</Label>
          <div className="relative">
            <Search className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2" />
            <Input
              id="flt-q"
              placeholder={t("transactions.searchPlaceholder")}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              className="pl-10"
              autoComplete="off"
            />
          </div>
        </div>

        {/* Tipo */}
        <div className="space-y-1.5 lg:col-span-2">
          <Label>{t("transactions.typeLabel")}</Label>
          <Select
            value={type}
            onValueChange={(v) =>
              // Al cambiar el tipo, reseteamos la categoría (no aplica cruzada).
              apply({ type: v, category: null })
            }
          >
            <SelectTrigger aria-label={t("transactions.typeLabel")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL}>{t("transactions.typeAll")}</SelectItem>
              <SelectItem value={TX_TYPE.INCOME}>{t("transactions.income")}</SelectItem>
              <SelectItem value={TX_TYPE.EXPENSE}>{t("transactions.expense")}</SelectItem>
            </SelectContent>
          </Select>
        </div>

        {/* Categoría */}
        <div className="space-y-1.5 lg:col-span-3">
          <Label>{t("transactions.categoryLabel")}</Label>
          <Select value={category} onValueChange={(v) => apply({ category: v })}>
            <SelectTrigger aria-label={t("transactions.categoryLabel")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL}>{t("transactions.categoryAll")}</SelectItem>
              {catOptions.length > 0 && (
                <SelectGroup>
                  <SelectLabel>{t("transactions.categoriesGroup")}</SelectLabel>
                  {catOptions.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))}
                </SelectGroup>
              )}
            </SelectContent>
          </Select>
        </div>

        {/* Cuenta */}
        <div className="space-y-1.5 lg:col-span-3">
          <Label>{t("transactions.accountLabel")}</Label>
          <Select value={account} onValueChange={(v) => apply({ account: v })}>
            <SelectTrigger aria-label={t("transactions.accountLabel")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ALL}>{t("transactions.accountAll")}</SelectItem>
              {accounts.length > 0 && (
                <SelectGroup>
                  <SelectLabel>{t("transactions.accountsGroup")}</SelectLabel>
                  {accounts.map((a) => (
                    <SelectItem key={a.id} value={a.id}>
                      {a.name}
                    </SelectItem>
                  ))}
                </SelectGroup>
              )}
            </SelectContent>
          </Select>
        </div>

        {/* Rango de fechas */}
        <div className="space-y-1.5 lg:col-span-3">
          <Label htmlFor="flt-from">{t("transactions.fromLabel")}</Label>
          <Input
            id="flt-from"
            type="date"
            value={from}
            max={to || undefined}
            onChange={(e) => apply({ from: e.target.value || null })}
          />
        </div>
        <div className="space-y-1.5 lg:col-span-3">
          <Label htmlFor="flt-to">{t("transactions.toLabel")}</Label>
          <Input
            id="flt-to"
            type="date"
            value={to}
            min={from || undefined}
            onChange={(e) => apply({ to: e.target.value || null })}
          />
        </div>

        {/* Monto mínimo / máximo (sobre el monto del movimiento) */}
        <div className="space-y-1.5 lg:col-span-3">
          <Label htmlFor="flt-min">{t("transactions.amountMinLabel")}</Label>
          <Input
            id="flt-min"
            type="number"
            inputMode="decimal"
            min={0}
            step="any"
            placeholder={t("transactions.amountPlaceholder")}
            value={min}
            onChange={(e) => setMin(e.target.value)}
          />
        </div>
        <div className="space-y-1.5 lg:col-span-3">
          <Label htmlFor="flt-max">{t("transactions.amountMaxLabel")}</Label>
          <Input
            id="flt-max"
            type="number"
            inputMode="decimal"
            min={0}
            step="any"
            placeholder={t("transactions.amountPlaceholder")}
            value={max}
            onChange={(e) => setMax(e.target.value)}
          />
        </div>

        {/* Presets de período rápido */}
        <div className="space-y-1.5 lg:col-span-6">
          <Label>{t("transactions.datePresetsLabel")}</Label>
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="h-8 px-3 text-xs"
              onClick={() => applyPreset("thisMonth")}
            >
              {t("transactions.presetThisMonth")}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="h-8 px-3 text-xs"
              onClick={() => applyPreset("lastMonth")}
            >
              {t("transactions.presetLastMonth")}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="h-8 px-3 text-xs"
              onClick={() => applyPreset("thisWeek")}
            >
              {t("transactions.presetThisWeek")}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className="h-8 px-3 text-xs"
              onClick={() => applyPreset("all")}
            >
              {t("transactions.presetAllTime")}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
