"use client";

import { useTransition } from "react";
import Link from "next/link";
import { LogOut, User, Smartphone, Loader2 } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import { signOut } from "@/lib/actions/auth";
import { useT } from "@/components/i18n/locale-provider";

function initials(name?: string | null, email?: string | null) {
  const base = (name || email || "?").trim();
  const parts = base.split(/[\s@.]+/).filter(Boolean);
  return (parts[0]?.[0] ?? "?").toUpperCase() + (parts[1]?.[0]?.toUpperCase() ?? "");
}

export function UserMenu({
  name,
  email,
}: {
  name?: string | null;
  email?: string | null;
}) {
  const t = useT();
  const [pending, startTransition] = useTransition();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        aria-label={t("nav.openAccountMenu")}
        className="bg-primary/15 text-primary hover:bg-primary/25 flex size-9 items-center justify-center rounded-full text-[13px] font-semibold outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring/40"
      >
        {initials(name, email)}
      </DropdownMenuTrigger>

      <DropdownMenuContent>
        <DropdownMenuLabel>
          <span className="block normal-case">
            <span className="text-foreground block text-sm font-semibold">
              {name || t("nav.myAccount")}
            </span>
            <span className="text-text-muted block truncate text-xs font-normal">
              {email}
            </span>
          </span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild>
          <Link href="/profile">
            <User /> {t("nav.profileSettings")}
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link href="/connect">
            <Smartphone /> {t("nav.connectWithApp")}
          </Link>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          destructive
          disabled={pending}
          onSelect={(e) => {
            e.preventDefault();
            startTransition(() => {
              void signOut();
            });
          }}
        >
          {pending ? <Loader2 className="animate-spin" /> : <LogOut />}
          {t("nav.signOut")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
