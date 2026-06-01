"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Home, ChevronsUpDown, Check, Loader2 } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import { setActiveHousehold } from "@/lib/actions/household";
import { useT } from "@/components/i18n/locale-provider";
import { cn } from "@/lib/utils";

interface HouseholdLite {
  id: string;
  name: string;
  default_currency: string;
}

export function HouseholdSwitcher({
  households,
  activeId,
}: {
  households: HouseholdLite[];
  activeId: string;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const active = households.find((h) => h.id === activeId) ?? households[0];

  function select(id: string) {
    if (id === activeId) return;
    startTransition(async () => {
      await setActiveHousehold(id);
      router.refresh();
    });
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="hairline bg-surface/60 hover:bg-surface flex items-center gap-2.5 rounded-[var(--radius-md)] px-3 py-2 text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring/40">
        <span className="bg-primary/12 text-primary flex size-7 items-center justify-center rounded-md">
          {pending ? (
            <Loader2 className="size-4 animate-spin" />
          ) : (
            <Home className="size-4" />
          )}
        </span>
        <span className="max-w-[10rem] truncate font-medium">{active?.name}</span>
        <ChevronsUpDown className="text-text-muted size-4" />
      </DropdownMenuTrigger>

      <DropdownMenuContent align="start" className="min-w-[15rem]">
        <DropdownMenuLabel>{t("nav.yourHouseholds")}</DropdownMenuLabel>
        {households.map((h) => (
          <DropdownMenuItem key={h.id} onSelect={() => select(h.id)}>
            <Home />
            <span className="flex-1 truncate">{h.name}</span>
            <span className="text-text-dim text-xs">{h.default_currency}</span>
            {h.id === activeId && <Check className="text-primary !size-4" />}
          </DropdownMenuItem>
        ))}
        <DropdownMenuSeparator />
        <DropdownMenuItem
          onSelect={() => router.push("/profile?section=household")}
          className={cn("text-text-muted")}
        >
          {t("nav.manageHousehold")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
