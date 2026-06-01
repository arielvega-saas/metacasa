"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { parseMoney, symbolFor } from "@/lib/money";
import {
  createDebt,
  updateDebt,
  type DebtInput,
} from "@/lib/actions/debts";
import { useT } from "@/components/i18n/locale-provider";
import type { Debt } from "@/lib/db/debts";

interface DebtDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Deuda a editar; si es undefined, el diálogo crea una nueva. */
  debt?: Debt;
  /** Moneda base del hogar (la deuda hereda esta moneda, como en iOS). */
  defaultCurrency: string;
}

/** Fecha de hoy en formato YYYY-MM-DD (para el default de inicio). */
function todayISO(): string {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

/**
 * Diálogo de alta/edición de deuda. Espeja `AddDebtView` de iOS
 * (`Features/Debts/AddDebtView.swift`): acreedor + montos + tasa + pago mensual
 * + fechas (inicio y vencimiento opcional) + categoría/nota. La moneda no se
 * elige: la deuda toma la moneda base del hogar.
 */
export function DebtDialog({
  open,
  onOpenChange,
  debt,
  defaultCurrency,
}: DebtDialogProps) {
  const router = useRouter();
  const t = useT();
  const fieldId = React.useId();
  const isEdit = Boolean(debt);

  const [creditor, setCreditor] = React.useState(debt?.creditor ?? "");
  const [originalAmount, setOriginalAmount] = React.useState(
    debt ? String(debt.original_amount) : "",
  );
  const [currentBalance, setCurrentBalance] = React.useState(
    debt ? String(debt.current_balance) : "",
  );
  const [annualRate, setAnnualRate] = React.useState(
    debt ? String(debt.annual_rate) : "",
  );
  const [monthlyPayment, setMonthlyPayment] = React.useState(
    debt?.monthly_payment != null ? String(debt.monthly_payment) : "",
  );
  const [startDate, setStartDate] = React.useState(
    debt?.start_date ?? todayISO(),
  );
  const [hasMaturity, setHasMaturity] = React.useState(
    Boolean(debt?.maturity_date),
  );
  const [maturityDate, setMaturityDate] = React.useState(
    debt?.maturity_date ?? "",
  );
  const [category, setCategory] = React.useState(debt?.category ?? "");
  const [note, setNote] = React.useState(debt?.note ?? "");

  const [pending, startTransition] = React.useTransition();
  const currency = debt?.currency || defaultCurrency;

  function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();

    // Si no se cargó el saldo actual, por defecto = monto original (como iOS).
    const original = parseMoney(originalAmount);
    const balanceRaw = currentBalance.trim();
    const balance = balanceRaw === "" ? original : parseMoney(balanceRaw);

    const input: DebtInput = {
      creditor,
      originalAmount: original,
      currentBalance: balance,
      annualRate: parseMoney(annualRate),
      monthlyPayment: monthlyPayment.trim() ? parseMoney(monthlyPayment) : null,
      startDate,
      maturityDate: hasMaturity && maturityDate ? maturityDate : null,
      category: category.trim() || null,
      note: note.trim() || null,
    };

    startTransition(async () => {
      try {
        if (isEdit && debt) {
          await updateDebt(debt.id, input);
          toast.success(t("debts.updated"));
        } else {
          await createDebt(input);
          toast.success(t("debts.created"));
        }
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(t("debts.saveError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {isEdit ? t("debts.dialogEditTitle") : t("debts.dialogCreateTitle")}
          </DialogTitle>
          <DialogDescription>
            {isEdit
              ? t("debts.dialogEditDescription")
              : t("debts.dialogCreateDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          {/* Acreedor */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-creditor`}>
              {t("debts.creditorLabel")}
            </Label>
            <Input
              id={`${fieldId}-creditor`}
              value={creditor}
              onChange={(e) => setCreditor(e.target.value)}
              placeholder={t("debts.creditorPlaceholder")}
              autoFocus
              required
            />
          </div>

          {/* Monto original + saldo actual */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-original`}>
                {t("debts.originalAmountLabel")}
              </Label>
              <div className="relative">
                <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id={`${fieldId}-original`}
                  inputMode="decimal"
                  value={originalAmount}
                  onChange={(e) => setOriginalAmount(e.target.value)}
                  placeholder="0"
                  className="pl-9 tnum"
                />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-balance`}>
                {t("debts.currentBalanceLabel")}
              </Label>
              <div className="relative">
                <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id={`${fieldId}-balance`}
                  inputMode="decimal"
                  value={currentBalance}
                  onChange={(e) => setCurrentBalance(e.target.value)}
                  placeholder="0"
                  className="pl-9 tnum"
                />
              </div>
            </div>
          </div>

          {/* Tasa anual + pago mensual */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-rate`}>
                {t("debts.annualRateLabel")}
              </Label>
              <div className="relative">
                <Input
                  id={`${fieldId}-rate`}
                  inputMode="decimal"
                  value={annualRate}
                  onChange={(e) => setAnnualRate(e.target.value)}
                  placeholder="0"
                  className="pr-8 tnum"
                />
                <span className="text-text-dim pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-sm">
                  %
                </span>
              </div>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-monthly`}>
                {t("debts.monthlyPaymentLabel")}{" "}
                <span className="text-text-dim font-normal">
                  {t("debts.optional")}
                </span>
              </Label>
              <div className="relative">
                <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id={`${fieldId}-monthly`}
                  inputMode="decimal"
                  value={monthlyPayment}
                  onChange={(e) => setMonthlyPayment(e.target.value)}
                  placeholder="0"
                  className="pl-9 tnum"
                />
              </div>
            </div>
          </div>

          {/* Fecha de inicio */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-start`}>
              {t("debts.startDateLabel")}
            </Label>
            <Input
              id={`${fieldId}-start`}
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              className="tnum"
            />
          </div>

          {/* Vencimiento opcional */}
          <div className="flex items-center justify-between gap-3">
            <Label htmlFor={`${fieldId}-hasMaturity`} className="cursor-pointer">
              {t("debts.hasMaturityLabel")}
            </Label>
            <Switch
              id={`${fieldId}-hasMaturity`}
              checked={hasMaturity}
              onCheckedChange={setHasMaturity}
            />
          </div>
          {hasMaturity && (
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-maturity`}>
                {t("debts.maturityDateLabel")}
              </Label>
              <Input
                id={`${fieldId}-maturity`}
                type="date"
                value={maturityDate}
                min={startDate}
                onChange={(e) => setMaturityDate(e.target.value)}
                className="tnum"
              />
            </div>
          )}

          <Separator />

          {/* Categoría + nota (opcionales) */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-category`}>
              {t("debts.categoryLabel")}{" "}
              <span className="text-text-dim font-normal">
                {t("debts.optional")}
              </span>
            </Label>
            <Input
              id={`${fieldId}-category`}
              value={category}
              onChange={(e) => setCategory(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-note`}>
              {t("debts.noteLabel")}{" "}
              <span className="text-text-dim font-normal">
                {t("debts.optional")}
              </span>
            </Label>
            <Input
              id={`${fieldId}-note`}
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </div>

          <DialogFooter className="pt-2">
            <DialogClose asChild>
              <Button type="button" variant="ghost" disabled={pending}>
                {t("common.cancel")}
              </Button>
            </DialogClose>
            <Button type="submit" disabled={pending}>
              {pending && <Loader2 className="animate-spin" />}
              {isEdit ? t("common.saveChanges") : t("debts.createSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
