import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getAccessState, daysUntil } from "@/lib/access";
import { getT } from "@/lib/i18n/server";
import { resolveActiveHousehold } from "@/lib/household";
import { Sidebar } from "@/components/layout/sidebar";
import { MobileTabBar } from "@/components/layout/mobile-tab-bar";
import { Topbar } from "@/components/layout/topbar";
import { CreateHouseholdGate } from "@/components/onboarding/create-household";
import { AssistantWidget } from "@/components/assistant/assistant-widget";
import { Sparkles } from "lucide-react";
import Link from "next/link";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  // Gate de acceso: trial / active pasan; locked → paywall.
  const access = await getAccessState();
  if (access.state === "locked") redirect("/locked");

  const { households, active } = await resolveActiveHousehold(supabase);

  // Onboarding: el usuario aún no tiene hogar.
  if (!active) {
    return (
      <div className="bg-aurora min-h-dvh">
        <CreateHouseholdGate />
      </div>
    );
  }

  const trialDays = access.state === "trial" ? daysUntil(access.trial_ends_at) : 0;
  const t = await getT();

  return (
    <div className="flex min-h-dvh">
      <Sidebar />

      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar
          households={households.map((h) => ({
            id: h.id,
            name: h.name,
            default_currency: h.default_currency,
          }))}
          activeId={active.id}
          user={{
            name: (user.user_metadata?.display_name as string) ?? null,
            email: user.email,
          }}
        />

        {access.state === "trial" && (
          <Link
            href="/profile?section=plan"
            className="bg-primary/10 text-primary flex items-center justify-center gap-2 border-b border-border px-4 py-2 text-center text-[13px] font-medium transition-colors hover:bg-primary/15"
          >
            <Sparkles className="size-3.5" />
            {t(
              trialDays === 1 ? "shell.trialBannerOne" : "shell.trialBannerOther",
              { days: trialDays },
            )}
          </Link>
        )}

        <main className="mx-auto w-full max-w-6xl flex-1 px-4 pb-28 pt-6 sm:px-6 lg:pb-12">
          {children}
        </main>
      </div>

      <MobileTabBar />
      <AssistantWidget />
    </div>
  );
}
