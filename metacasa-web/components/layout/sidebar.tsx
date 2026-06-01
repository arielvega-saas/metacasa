"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Logo } from "@/components/brand/logo";
import { NAV, NAV_SECONDARY, type NavItem } from "./nav-items";
import { useT } from "@/components/i18n/locale-provider";
import { cn } from "@/lib/utils";

function NavLink({ item, active }: { item: NavItem; active: boolean }) {
  const t = useT();
  const Icon = item.icon;
  return (
    <Link
      href={item.href}
      className={cn(
        "group relative flex items-center gap-3 rounded-[var(--radius-md)] px-3 py-2.5 text-sm font-medium transition-colors",
        active
          ? "bg-white/[0.06] text-foreground"
          : "text-text-muted hover:bg-white/[0.04] hover:text-foreground",
      )}
    >
      {active && (
        <span className="bg-primary absolute left-0 top-1/2 h-5 w-1 -translate-y-1/2 rounded-r-full" />
      )}
      <Icon
        className={cn(
          "size-[18px] shrink-0",
          active ? "text-primary" : "text-text-muted group-hover:text-foreground",
        )}
      />
      {t(item.label)}
    </Link>
  );
}

export function Sidebar() {
  const pathname = usePathname();
  const isActive = (href: string) =>
    pathname === href || pathname.startsWith(href + "/");

  return (
    <aside className="bg-surface/30 hidden w-[252px] shrink-0 flex-col border-r border-border lg:flex">
      <div className="px-5 py-6">
        <Link href="/dashboard">
          <Logo />
        </Link>
      </div>

      <nav className="flex-1 space-y-1 px-3">
        {NAV.map((item) => (
          <NavLink key={item.href} item={item} active={isActive(item.href)} />
        ))}
      </nav>

      <div className="space-y-1 border-t border-border px-3 py-3">
        {NAV_SECONDARY.map((item) => (
          <NavLink key={item.href} item={item} active={isActive(item.href)} />
        ))}
      </div>
    </aside>
  );
}
