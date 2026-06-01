"use client";

import * as React from "react";
import { toast } from "sonner";
import { Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { createMonthlyPeriod } from "@/lib/actions/budgets";
import { useT } from "@/components/i18n/locale-provider";

/** CTA para iniciar el presupuesto del mes actual cuando todavía no existe. */
export function CreatePeriodButton() {
  const t = useT();
  const [pending, startTransition] = React.useTransition();

  function handleClick() {
    startTransition(async () => {
      try {
        await createMonthlyPeriod();
        toast.success(t("budgets.periodCreated"));
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("budgets.periodCreateError"),
        );
      }
    });
  }

  return (
    <Button onClick={handleClick} disabled={pending} size="lg">
      <Sparkles className="size-4" />
      {pending ? t("budgets.creating") : t("budgets.startPeriod")}
    </Button>
  );
}
