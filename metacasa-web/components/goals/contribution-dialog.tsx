"use client";

import * as React from "react";
import { toast } from "sonner";
import { HandCoins } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { addContributionAction } from "@/lib/actions/goals";
import { parseMoney, symbolFor, formatMoney } from "@/lib/money";
import { useT } from "@/components/i18n/locale-provider";

interface ContributionDialogProps {
  goalId: string;
  goalName: string;
  currency: string;
  /** Cuánto falta para llegar al objetivo (sugerencia de monto). */
  remaining: number;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/**
 * Diálogo para sumar una contribución a una meta. Solo inserta la contribución:
 * el trigger de DB actualiza `current_amount` y autocompleta la meta.
 */
export function ContributionDialog({
  goalId,
  goalName,
  currency,
  remaining,
  open,
  onOpenChange,
}: ContributionDialogProps) {
  const t = useT();
  const [amount, setAmount] = React.useState("");
  const [pending, startTransition] = React.useTransition();

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const value = parseMoney(amount);
    if (!(value > 0)) {
      toast.error(t("goals.contributionPositive"));
      return;
    }
    startTransition(async () => {
      try {
        await addContributionAction({ goalId, amount: value });
        toast.success(t("goals.contributionAdded"));
        setAmount("");
        onOpenChange(false);
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("goals.contributionError"),
        );
      }
    });
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        onOpenChange(o);
        if (!o) setAmount("");
      }}
    >
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <HandCoins className="text-primary size-4" />
            {t("goals.contributeTitle")}
          </DialogTitle>
          <DialogDescription>
            {t("goals.contributeDescriptionPrefix")}
            <span className="text-foreground font-medium">{goalName}</span>.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="contrib-amount">
              {t("goals.contributionAmountLabel")}
            </Label>
            <div className="relative">
              <span className="text-text-muted pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                {symbolFor(currency)}
              </span>
              <Input
                id="contrib-amount"
                inputMode="decimal"
                placeholder="0"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="tnum pl-12"
                autoFocus
              />
            </div>
            {remaining > 0 && (
              <button
                type="button"
                onClick={() => setAmount(String(remaining))}
                className="text-primary text-xs font-medium hover:underline"
              >
                {t("goals.completeWith", {
                  amount: formatMoney(remaining, currency),
                })}
              </button>
            )}
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="ghost"
              onClick={() => onOpenChange(false)}
              disabled={pending}
            >
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={pending}>
              {pending ? t("goals.saving") : t("goals.addContribution")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
