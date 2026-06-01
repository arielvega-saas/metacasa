import Link from "next/link";
import { Plus } from "lucide-react";
import { Logo } from "@/components/brand/logo";
import { HouseholdSwitcher } from "./household-switcher";
import { UserMenu } from "./user-menu";
import { Button } from "@/components/ui/button";
import { AmountsVisibilityToggle } from "@/components/finance/amounts-visibility-toggle";
import { PreferencesBootstrap } from "@/components/finance/preferences-bootstrap";
import { getT } from "@/lib/i18n/server";

interface HouseholdLite {
  id: string;
  name: string;
  default_currency: string;
}

export async function Topbar({
  households,
  activeId,
  user,
}: {
  households: HouseholdLite[];
  activeId: string;
  user: { name?: string | null; email?: string | null };
}) {
  const t = await getT();
  return (
    <header className="glass sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-border px-4 sm:px-6">
      <div className="lg:hidden">
        <Logo markClassName="h-8 w-8" textClassName="hidden sm:inline" />
      </div>

      <div className="hidden lg:block">
        <HouseholdSwitcher households={households} activeId={activeId} />
      </div>

      <PreferencesBootstrap />

      <div className="flex-1" />

      <AmountsVisibilityToggle className="text-text-muted" />

      <Button asChild size="sm" className="hidden sm:inline-flex">
        <Link href="/transactions?new=1">
          <Plus className="size-4" /> {t("nav.newTransaction")}
        </Link>
      </Button>

      <div className="lg:hidden">
        <HouseholdSwitcher households={households} activeId={activeId} />
      </div>

      <UserMenu name={user.name} email={user.email} />
    </header>
  );
}
