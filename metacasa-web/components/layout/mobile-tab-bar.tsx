"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  ArrowLeftRight,
  PiggyBank,
  Menu,
  Plus,
  type LucideIcon,
} from "lucide-react";
import { useT } from "@/components/i18n/locale-provider";
import { cn } from "@/lib/utils";
import { NAV, NAV_SECONDARY, type NavItem } from "@/components/layout/nav-items";
import {
  Sheet,
  SheetContent,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";

/** Tabs primarias siempre visibles (links directos). */
const PRIMARY_TABS = [
  { href: "/dashboard", label: "nav.home", icon: LayoutDashboard },
  { href: "/transactions", label: "nav.transactions", icon: ArrowLeftRight },
  { href: "/budgets", label: "nav.budgets", icon: PiggyBank },
] as const;

export function MobileTabBar() {
  const t = useT();
  const pathname = usePathname();
  const [moreOpen, setMoreOpen] = React.useState(false);
  const isActive = (href: string) =>
    pathname === href || pathname.startsWith(href + "/");

  // El menú "Más" expone TODOS los destinos que no están en la barra primaria.
  const primaryHrefs = new Set<string>(PRIMARY_TABS.map((tab) => tab.href));
  const moreItems: NavItem[] = [...NAV, ...NAV_SECONDARY].filter(
    (item) => !primaryHrefs.has(item.href),
  );
  const moreActive = moreItems.some((item) => isActive(item.href));

  return (
    <>
      <nav className="glass fixed inset-x-0 bottom-0 z-40 flex items-center justify-around border-t border-border px-2 pb-[max(env(safe-area-inset-bottom),0.5rem)] pt-2 lg:hidden">
        {PRIMARY_TABS.slice(0, 2).map((tab) => (
          <Tab key={tab.href} {...tab} active={isActive(tab.href)} />
        ))}

        <Link
          href="/transactions?new=1"
          className="bg-primary text-primary-foreground -mt-6 flex size-12 items-center justify-center rounded-full shadow-lg shadow-elevation"
          aria-label={t("nav.newTransaction")}
        >
          <Plus className="size-6" />
        </Link>

        <Tab
          {...PRIMARY_TABS[2]}
          active={isActive(PRIMARY_TABS[2].href)}
        />

        {/* "Más" abre un sheet con el resto de la navegación. */}
        <button
          type="button"
          onClick={() => setMoreOpen(true)}
          aria-haspopup="dialog"
          aria-expanded={moreOpen}
          aria-label={t("nav.more")}
          className={cn(
            "flex min-h-[44px] w-16 flex-col items-center justify-center gap-0.5 py-1.5 text-[10px] font-medium transition-colors",
            moreActive ? "text-primary" : "text-text-muted",
          )}
        >
          <Menu className="size-5" />
          {t("nav.more")}
        </button>
      </nav>

      <Sheet open={moreOpen} onOpenChange={setMoreOpen}>
        <SheetContent side="bottom">
          <SheetTitle>{t("more.title")}</SheetTitle>
          <SheetDescription className="mb-2">
            {t("more.subtitle")}
          </SheetDescription>
          <ul className="grid grid-cols-2 gap-2">
            {moreItems.map((item) => {
              const Icon = item.icon;
              const active = isActive(item.href);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    onClick={() => setMoreOpen(false)}
                    className={cn(
                      "hairline flex min-h-[52px] items-center gap-3 rounded-[var(--radius-lg)] px-3.5 py-3 text-sm font-medium transition-colors",
                      active
                        ? "bg-primary/12 text-primary border-primary/30"
                        : "bg-surface/50 text-foreground hover:bg-surface",
                    )}
                  >
                    <Icon className="size-5 shrink-0" />
                    <span className="truncate">{t(item.label)}</span>
                  </Link>
                </li>
              );
            })}
          </ul>
        </SheetContent>
      </Sheet>
    </>
  );
}

function Tab({
  href,
  label,
  icon: Icon,
  active,
}: {
  href: string;
  label: string;
  icon: LucideIcon;
  active: boolean;
}) {
  const t = useT();
  return (
    <Link
      href={href}
      className={cn(
        "flex min-h-[44px] w-16 flex-col items-center justify-center gap-0.5 py-1.5 text-[10px] font-medium transition-colors",
        active ? "text-primary" : "text-text-muted",
      )}
    >
      <Icon className="size-5" />
      {t(label)}
    </Link>
  );
}
