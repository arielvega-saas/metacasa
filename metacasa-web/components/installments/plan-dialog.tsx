"use client";

import * as React from "react";
import { toast } from "sonner";
import { Plus, Loader2 } from "lucide-react";
import {
  Dialog,
  DialogTrigger,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { createPlan } from "@/lib/actions/installments";
import { parseMoney, symbolFor, formatMoney } from "@/lib/money";
import { SUPPORTED_CURRENCIES } from "@/lib/constants";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import { formatMonthShort } from "@/lib/i18n/dates";

interface PlanDialogProps {
  defaultCurrency: string;
  /** Cuentas activas del hogar (para asociar el plan, opcional). */
  accounts: { id: string; name: string }[];
  trigger?: React.ReactNode;
}

const NO_ACCOUNT = "__none__";

/** Diálogo para crear un plan en cuotas. Espeja `AddInstallmentPlanView` (iOS). */
export function PlanDialog({ defaultCurrency, accounts, trigger }: PlanDialogProps) {
  const t = useT();
  const locale = useLocale();
  const [open, setOpen] = React.useState(false);

  const now = new Date();
  const [name, setName] = React.useState("");
  const [total, setTotal] = React.useState("");
  const [installments, setInstallments] = React.useState("12");
  const [currency, setCurrency] = React.useState(defaultCurrency);
  const [month, setMonth] = React.useState(now.getMonth() + 1); // 1-12
  const [year, setYear] = React.useState(now.getFullYear());
  const [category, setCategory] = React.useState("");
  const [accountId, setAccountId] = React.useState<string>(NO_ACCOUNT);
  const [note, setNote] = React.useState("");
  const [pending, startTransition] = React.useTransition();

  // Años seleccionables: del actual hasta +6 (cubre planes largos).
  const years = React.useMemo(
    () => Array.from({ length: 7 }, (_, i) => now.getFullYear() + i),
    [now],
  );

  // Monto por cuota en vivo (reparto parejo), para feedback al usuario.
  const totalValue = parseMoney(total);
  const count = Math.max(0, Math.trunc(Number(installments) || 0));
  const perInstallment = count > 0 ? totalValue / count : 0;

  function reset() {
    setName("");
    setTotal("");
    setInstallments("12");
    setCurrency(defaultCurrency);
    setMonth(now.getMonth() + 1);
    setYear(now.getFullYear());
    setCategory("");
    setAccountId(NO_ACCOUNT);
    setNote("");
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) {
      toast.error(t("installments.nameRequired"));
      return;
    }
    if (!(totalValue > 0)) {
      toast.error(t("installments.amountRequired"));
      return;
    }
    if (!(count >= 1)) {
      toast.error(t("installments.installmentsRequired"));
      return;
    }

    startTransition(async () => {
      try {
        await createPlan({
          name,
          totalAmount: totalValue,
          totalInstallments: count,
          currency,
          startYear: year,
          startMonth: month,
          category: category || null,
          accountId: accountId === NO_ACCOUNT ? null : accountId,
          note: note || null,
        });
        toast.success(t("installments.created"));
        setOpen(false);
        reset();
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("installments.saveError"),
        );
      }
    });
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) reset();
      }}
    >
      <DialogTrigger asChild>
        {trigger ?? (
          <Button>
            <Plus />
            {t("installments.new")}
          </Button>
        )}
      </DialogTrigger>

      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Plus className="text-primary size-4" />
            {t("installments.dialogCreateTitle")}
          </DialogTitle>
          <DialogDescription>
            {t("installments.dialogCreateDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="plan-name">{t("installments.nameLabel")}</Label>
            <Input
              id="plan-name"
              placeholder={t("installments.namePlaceholder")}
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={80}
              autoFocus
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="plan-total">{t("installments.totalAmountLabel")}</Label>
              <div className="relative">
                <span className="text-text-muted pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id="plan-total"
                  inputMode="decimal"
                  placeholder="0"
                  value={total}
                  onChange={(e) => setTotal(e.target.value)}
                  className="tnum pl-12"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="plan-currency">{t("installments.currencyLabel")}</Label>
              <Select value={currency} onValueChange={setCurrency}>
                <SelectTrigger id="plan-currency">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {SUPPORTED_CURRENCIES.map((c) => (
                    <SelectItem key={c.code} value={c.code}>
                      {c.code} · {t(`domain.currencies.${c.code}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="plan-installments">
              {t("installments.installmentsCountLabel")}
            </Label>
            <Input
              id="plan-installments"
              inputMode="numeric"
              placeholder="12"
              value={installments}
              onChange={(e) =>
                setInstallments(e.target.value.replace(/[^\d]/g, ""))
              }
              className="tnum"
            />
            {perInstallment > 0 && (
              <p className="text-text-dim text-xs">
                {t("installments.perInstallmentHint", {
                  amount: formatMoney(perInstallment, currency),
                })}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label>{t("installments.startLabel")}</Label>
            <div className="grid grid-cols-2 gap-3">
              <Select
                value={String(month)}
                onValueChange={(v) => setMonth(Number(v))}
              >
                <SelectTrigger aria-label={t("installments.monthLabel")}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {Array.from({ length: 12 }, (_, i) => i + 1).map((m) => (
                    <SelectItem key={m} value={String(m)}>
                      {formatMonthShort(year, m, locale)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Select
                value={String(year)}
                onValueChange={(v) => setYear(Number(v))}
              >
                <SelectTrigger aria-label={t("installments.yearLabel")}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {years.map((y) => (
                    <SelectItem key={y} value={String(y)}>
                      {y}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="plan-category">
                {t("installments.categoryLabel")}{" "}
                <span className="text-text-dim font-normal">
                  {t("installments.optional")}
                </span>
              </Label>
              <Input
                id="plan-category"
                placeholder={t("installments.categoryPlaceholder")}
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                maxLength={40}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="plan-account">
                {t("installments.accountLabel")}{" "}
                <span className="text-text-dim font-normal">
                  {t("installments.optional")}
                </span>
              </Label>
              <Select value={accountId} onValueChange={setAccountId}>
                <SelectTrigger id="plan-account">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={NO_ACCOUNT}>
                    {t("installments.accountPlaceholder")}
                  </SelectItem>
                  {accounts.map((a) => (
                    <SelectItem key={a.id} value={a.id}>
                      {a.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="plan-note">
              {t("installments.noteLabel")}{" "}
              <span className="text-text-dim font-normal">
                {t("installments.optional")}
              </span>
            </Label>
            <Input
              id="plan-note"
              placeholder={t("installments.notePlaceholder")}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={120}
            />
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="ghost"
              onClick={() => setOpen(false)}
              disabled={pending}
            >
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={pending}>
              {pending && <Loader2 className="animate-spin" />}
              {pending ? t("installments.saving") : t("installments.createSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
