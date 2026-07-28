"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { Command } from "cmdk";
import { Plus, CalendarClock, Search, CornerDownLeft } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { NAV, NAV_SECONDARY } from "@/components/layout/nav-items";
import { useT } from "@/components/i18n/locale-provider";

/**
 * Paleta de comandos ⌘K / Ctrl+K — Midnight Sage (vidrio + hairline).
 *
 * Grupos:
 *  - "Ir a": todas las rutas del sidebar (principal + secundaria) con su ícono.
 *  - "Acciones": alta rápida de movimiento (`/transactions?new=1`, query param
 *    soportado por la page) y de vencimiento (`/bills` — esa page NO soporta
 *    `?new=1`, así que vamos a la ruta pelada y el alta se abre desde ahí).
 *  - "Buscar": aparece al tipear y navega a `/transactions?q=<término>`, que es
 *    el parámetro de búsqueda real de la pantalla de movimientos.
 *
 * Se monta una sola vez en el layout de (app).
 */
export function CommandPalette() {
  const t = useT();
  const router = useRouter();
  const [open, setOpen] = React.useState(false);
  const [query, setQuery] = React.useState("");

  // ⌘K (mac) / Ctrl+K (win-linux). Alterna: si ya está abierta, cierra.
  React.useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.key.toLowerCase() === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((v) => !v);
      }
    }
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, []);

  function handleOpenChange(next: boolean) {
    setOpen(next);
    if (!next) setQuery("");
  }

  function go(href: string) {
    setOpen(false);
    setQuery("");
    router.push(href);
  }

  const trimmed = query.trim();

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="top-[12dvh] max-w-xl translate-y-0 gap-0 overflow-hidden p-0">
        {/* Título/descripción accesibles: la paleta es visualmente sólo el input. */}
        <DialogTitle className="sr-only">{t("palette.title")}</DialogTitle>
        <DialogDescription className="sr-only">
          {t("palette.description")}
        </DialogDescription>

        <Command
          label={t("palette.title")}
          className="flex max-h-[60dvh] flex-col"
        >
          <div className="flex items-center gap-2.5 border-b border-border px-4 py-3.5 pr-14">
            <Search className="text-text-dim size-4 shrink-0" />
            <Command.Input
              value={query}
              onValueChange={setQuery}
              placeholder={t("palette.placeholder")}
              className="placeholder:text-text-dim w-full bg-transparent text-sm text-foreground outline-none"
            />
          </div>

          {/*
            Sin `Command.Empty`: mientras haya término tipeado, el ítem de
            búsqueda va `forceMount` y siempre ofrece una salida ("buscar esto
            en movimientos"), así que la lista nunca queda realmente vacía.
          */}
          <Command.List className="overflow-y-auto overscroll-contain p-2">
            {/* Buscar el término tipeado en movimientos */}
            {trimmed.length > 0 && (
              <Command.Group
                forceMount
                heading={t("palette.groupSearch")}
                className="text-text-dim [&_[cmdk-group-heading]]:px-3 [&_[cmdk-group-heading]]:pb-1 [&_[cmdk-group-heading]]:pt-2 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wider"
              >
                <Command.Item
                  forceMount
                  value="__search_transactions__"
                  onSelect={() =>
                    go(`/transactions?q=${encodeURIComponent(trimmed)}`)
                  }
                  className="text-foreground data-[selected=true]:bg-primary/12 data-[selected=true]:text-primary flex cursor-pointer items-center gap-3 rounded-[var(--radius-md)] px-3 py-2.5 text-sm outline-none"
                >
                  <Search className="size-4 shrink-0 opacity-70" />
                  <span className="truncate">
                    {t("palette.searchTransactions", { q: trimmed })}
                  </span>
                  <CornerDownLeft className="text-text-dim ml-auto size-3.5 shrink-0" />
                </Command.Item>
              </Command.Group>
            )}

            <Command.Group
              heading={t("palette.groupActions")}
              className="text-text-dim [&_[cmdk-group-heading]]:px-3 [&_[cmdk-group-heading]]:pb-1 [&_[cmdk-group-heading]]:pt-2 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wider"
            >
              <PaletteItem
                icon={<Plus className="size-4 shrink-0 opacity-70" />}
                label={t("palette.newTransaction")}
                onSelect={() => go("/transactions?new=1")}
              />
              <PaletteItem
                icon={<CalendarClock className="size-4 shrink-0 opacity-70" />}
                label={t("palette.newBill")}
                onSelect={() => go("/bills")}
              />
            </Command.Group>

            <Command.Group
              heading={t("palette.groupNavigate")}
              className="text-text-dim [&_[cmdk-group-heading]]:px-3 [&_[cmdk-group-heading]]:pb-1 [&_[cmdk-group-heading]]:pt-2 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wider"
            >
              {[...NAV, ...NAV_SECONDARY].map((item) => {
                const Icon = item.icon;
                return (
                  <PaletteItem
                    key={item.href}
                    icon={<Icon className="size-4 shrink-0 opacity-70" />}
                    label={t(item.label)}
                    value={`${t(item.label)} ${item.href}`}
                    onSelect={() => go(item.href)}
                  />
                );
              })}
            </Command.Group>
          </Command.List>

          {/* Pie con los atajos, como en las paletas de escritorio. */}
          <div className="text-text-dim flex shrink-0 items-center gap-4 border-t border-border px-4 py-2.5 text-[11px]">
            <span className="flex items-center gap-1.5">
              <Kbd>↵</Kbd> {t("palette.openHint")}
            </span>
            <span className="flex items-center gap-1.5">
              <Kbd>esc</Kbd> {t("palette.closeHint")}
            </span>
          </div>
        </Command>
      </DialogContent>
    </Dialog>
  );
}

/** Tecla del pie de la paleta. */
function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="bg-inset text-text-muted hairline inline-flex min-w-5 items-center justify-center rounded-[6px] px-1.5 py-0.5 font-sans text-[10px] leading-none">
      {children}
    </kbd>
  );
}

/** Fila de la paleta con el estilo del tema (hover/selección sage). */
function PaletteItem({
  icon,
  label,
  value,
  onSelect,
}: {
  icon: React.ReactNode;
  label: string;
  value?: string;
  onSelect: () => void;
}) {
  return (
    <Command.Item
      value={value ?? label}
      onSelect={onSelect}
      className="text-foreground data-[selected=true]:bg-primary/12 data-[selected=true]:text-primary flex cursor-pointer items-center gap-3 rounded-[var(--radius-md)] px-3 py-2.5 text-sm outline-none"
    >
      {icon}
      <span className="truncate">{label}</span>
    </Command.Item>
  );
}
