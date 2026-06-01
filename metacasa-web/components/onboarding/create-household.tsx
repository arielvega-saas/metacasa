"use client";

import { useState, useTransition, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import { Logo } from "@/components/brand/logo";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { createHousehold } from "@/lib/actions/household";
import { SUPPORTED_CURRENCIES } from "@/lib/constants";
import { useT } from "@/components/i18n/locale-provider";

/** Onboarding mínimo: el usuario no tiene ningún hogar todavía. */
export function CreateHouseholdGate() {
  const t = useT();
  const router = useRouter();
  const [name, setName] = useState(t("onboarding.defaultHouseholdName"));
  const [currency, setCurrency] = useState("USD");
  const [pending, startTransition] = useTransition();

  function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    startTransition(async () => {
      try {
        await createHousehold(name, currency);
        toast.success(t("onboarding.householdCreated"));
        router.refresh();
      } catch (err) {
        toast.error(t("onboarding.householdCreateError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <div className="flex min-h-dvh items-center justify-center px-6 py-12">
      <Card className="w-full max-w-md p-7 sm:p-8">
        <Logo className="mb-6" />
        <h1 className="text-2xl font-semibold tracking-tight">
          {t("onboarding.createHouseholdTitle")}
        </h1>
        <p className="text-text-muted mt-1.5 text-sm">
          {t("onboarding.createHouseholdSubtitle")}
        </p>

        <form onSubmit={onSubmit} className="mt-6 space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="hh-name">{t("onboarding.householdNameLabel")}</Label>
            <Input
              id="hh-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder={t("onboarding.defaultHouseholdName")}
              required
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="hh-currency">{t("onboarding.currencyLabel")}</Label>
            <Select value={currency} onValueChange={setCurrency}>
              <SelectTrigger id="hh-currency">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {SUPPORTED_CURRENCIES.map((c) => (
                  <SelectItem key={c.code} value={c.code}>
                    {c.code} — {t(`domain.currencies.${c.code}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <Button type="submit" size="lg" className="w-full" disabled={pending}>
            {pending && <Loader2 className="animate-spin" />}
            {t("onboarding.createHousehold")}
          </Button>
        </form>
      </Card>
    </div>
  );
}
