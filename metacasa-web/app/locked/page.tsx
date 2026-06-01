import Link from "next/link";
import type { Metadata } from "next";
import { Sparkles, RefreshCw, Check } from "lucide-react";
import { Logo } from "@/components/brand/logo";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ManageSubscriptionCTA } from "@/components/app-links/manage-subscription-cta";
import { signOut } from "@/lib/actions/auth";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("locked.metaTitle") };
}

export default async function LockedPage() {
  const t = await getT();
  const PERKS = [
    t("locked.perk1"),
    t("locked.perk2"),
    t("locked.perk3"),
    t("locked.perk4"),
  ];
  return (
    <div className="bg-aurora flex min-h-dvh items-center justify-center px-6 py-12">
      <Card glass className="w-full max-w-md p-8 sage-glow">
        <Logo className="mb-7" />

        <span className="bg-primary/12 text-primary mb-5 inline-flex size-12 items-center justify-center rounded-2xl">
          <Sparkles className="size-6" />
        </span>

        <h1 className="text-2xl font-semibold tracking-tight">
          {t("locked.title")}
        </h1>
        <p className="text-text-muted mt-2 text-sm leading-relaxed">
          {t("locked.body")}
        </p>

        <ul className="mt-6 space-y-2.5">
          {PERKS.map((p) => (
            <li key={p} className="flex items-start gap-2.5 text-sm">
              <Check className="text-primary mt-0.5 size-4 shrink-0" />
              <span className="text-foreground/90">{p}</span>
            </li>
          ))}
        </ul>

        <div className="mt-7 space-y-2.5">
          <ManageSubscriptionCTA variant="subscribe" size="lg" />
          <Button asChild variant="secondary" size="lg" className="w-full">
            <Link href="/dashboard">
              <RefreshCw className="size-4" /> {t("locked.alreadySubscribed")}
            </Link>
          </Button>
        </div>

        <form action={signOut} className="mt-5 text-center">
          <button
            type="submit"
            className="text-text-muted hover:text-foreground text-sm transition-colors"
          >
            {t("nav.signOut")}
          </button>
        </form>
      </Card>
    </div>
  );
}
