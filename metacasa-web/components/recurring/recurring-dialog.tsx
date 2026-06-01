"use client";

import { useState, useTransition, useId, type FormEvent } from "react";
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
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
  SelectGroup,
  SelectLabel,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { parseMoney, symbolFor } from "@/lib/money";
import { TX_TYPE, type TxType } from "@/lib/constants";
import {
  createRecurringAction,
  updateRecurringAction,
  type RecurringFormInput,
} from "@/lib/actions/recurring";
import { FREQUENCIES, type Frequency } from "@/lib/db/recurring";
import { useT } from "@/components/i18n/locale-provider";
import type { RecurringTransaction } from "@/lib/db/recurring";

type AccountOption = { id: string; name: string };
const NO_ACCOUNT = "__none__";

/** Hoy en formato YYYY-MM-DD (zona local), default del input de fecha. */
function todayISO(): string {
  const d = new Date();
  const off = d.getTimezoneOffset();
  return new Date(d.getTime() - off * 60_000).toISOString().slice(0, 10);
}

interface RecurringDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Recurrente a editar; si es undefined, crea uno nuevo. */
  recurring?: RecurringTransaction;
  categories: { gastos: string[]; ingresos: string[] };
  accounts: AccountOption[];
  /** Moneda base del hogar (símbolo del input de monto). */
  currency: string;
}

/**
 * Diálogo de alta/edición de recurrente. Toggle gasto/ingreso, monto, categoría,
 * cuenta (opcional, por nombre — el schema guarda `account` como texto), frecuencia,
 * fecha de inicio y fecha de fin opcional. Delega en las server actions.
 */
export function RecurringDialog({
  open,
  onOpenChange,
  recurring,
  categories,
  accounts,
  currency,
}: RecurringDialogProps) {
  const router = useRouter();
  const t = useT();
  const fieldId = useId();
  const isEdit = Boolean(recurring);

  const [type, setType] = useState<TxType>(
    recurring?.type === TX_TYPE.INCOME ? TX_TYPE.INCOME : TX_TYPE.EXPENSE,
  );
  const [amount, setAmount] = useState(
    recurring ? String(recurring.amount) : "",
  );
  const [category, setCategory] = useState(recurring?.category ?? "");
  // El schema guarda `account` como texto (nombre). Mapeamos al id si coincide.
  const initialAccountId =
    accounts.find((a) => a.name === recurring?.account)?.id ?? NO_ACCOUNT;
  const [accountId, setAccountId] = useState<string>(initialAccountId);
  const [frequency, setFrequency] = useState<Frequency>(
    (recurring?.frequency as Frequency) ?? "monthly",
  );
  const [startDate, setStartDate] = useState(
    recurring?.start_date ?? todayISO(),
  );
  const [endDate, setEndDate] = useState(recurring?.end_date ?? "");
  const [note, setNote] = useState(recurring?.note ?? "");

  const [pending, startTransition] = useTransition();
  const isIncome = type === TX_TYPE.INCOME;
  const catOptions = isIncome ? categories.ingresos : categories.gastos;

  function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const parsedAmount = parseMoney(amount);
    if (parsedAmount <= 0 || !category.trim()) {
      toast.error(t("recurring.nameRequired"));
      return;
    }

    const accountName =
      accountId === NO_ACCOUNT
        ? null
        : (accounts.find((a) => a.id === accountId)?.name ?? null);

    const form: RecurringFormInput = {
      type,
      amount: parsedAmount,
      category: category.trim(),
      account: accountName,
      frequency,
      startDate,
      endDate: endDate || null,
      note: note.trim() || null,
    };

    startTransition(async () => {
      try {
        if (isEdit && recurring) {
          await updateRecurringAction(recurring.id, form);
          toast.success(t("recurring.updated"));
        } else {
          await createRecurringAction(form);
          toast.success(t("recurring.created"));
        }
        // Refrescar ANTES de cerrar: el padre monta este diálogo de forma
        // condicional ({dialog.mode !== "closed" && ...}); cerrar lo desmonta y
        // abortaría el refresh si fuera después. Con este orden la lista se
        // actualiza sin recargar.
        router.refresh();
        onOpenChange(false);
      } catch (err) {
        toast.error(t("recurring.saveError"), {
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
            {isEdit
              ? t("recurring.dialogEditTitle")
              : t("recurring.dialogCreateTitle")}
          </DialogTitle>
          <DialogDescription>
            {isEdit
              ? t("recurring.dialogEditDescription")
              : t("recurring.dialogCreateDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          {/* Toggle gasto / ingreso */}
          <div
            className="bg-inset hairline grid grid-cols-2 gap-1 rounded-[var(--radius-md)] p-1"
            role="group"
            aria-label={t("recurring.amountLabel")}
          >
            <button
              type="button"
              onClick={() => {
                setType(TX_TYPE.EXPENSE);
                setCategory("");
              }}
              aria-pressed={!isIncome}
              className={cn(
                "h-9 min-h-11 rounded-[var(--radius-sm)] text-[13px] font-semibold transition-colors",
                !isIncome
                  ? "bg-expense/15 text-expense"
                  : "text-text-muted hover:text-foreground",
              )}
            >
              {t("recurring.expenseToggle")}
            </button>
            <button
              type="button"
              onClick={() => {
                setType(TX_TYPE.INCOME);
                setCategory("");
              }}
              aria-pressed={isIncome}
              className={cn(
                "h-9 min-h-11 rounded-[var(--radius-sm)] text-[13px] font-semibold transition-colors",
                isIncome
                  ? "bg-income/15 text-income"
                  : "text-text-muted hover:text-foreground",
              )}
            >
              {t("recurring.incomeToggle")}
            </button>
          </div>

          {/* Monto */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-amount`}>
              {t("recurring.amountLabel")}
            </Label>
            <div className="relative">
              <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                {symbolFor(currency)}
              </span>
              <Input
                id={`${fieldId}-amount`}
                inputMode="decimal"
                autoComplete="off"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0"
                className="pl-9 tnum"
                autoFocus
              />
            </div>
          </div>

          {/* Categoría */}
          <div className="space-y-1.5">
            <Label>{t("recurring.categoryLabel")}</Label>
            <Select value={category} onValueChange={setCategory}>
              <SelectTrigger aria-label={t("recurring.categoryLabel")}>
                <SelectValue placeholder={t("recurring.categoryPlaceholder")} />
              </SelectTrigger>
              <SelectContent>
                <SelectGroup>
                  <SelectLabel>
                    {isIncome
                      ? t("recurring.incomeToggle")
                      : t("recurring.expenseToggle")}
                  </SelectLabel>
                  {catOptions.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))}
                </SelectGroup>
              </SelectContent>
            </Select>
          </div>

          {/* Frecuencia + cuenta */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-freq`}>
                {t("recurring.frequencyLabel")}
              </Label>
              <Select
                value={frequency}
                onValueChange={(v) => setFrequency(v as Frequency)}
              >
                <SelectTrigger id={`${fieldId}-freq`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {FREQUENCIES.map((f) => (
                    <SelectItem key={f} value={f}>
                      {t(`recurring.freq.${f}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-account`}>
                {t("recurring.accountLabel")}{" "}
                <span className="text-text-dim font-normal">
                  {t("recurring.accountOptional")}
                </span>
              </Label>
              <Select value={accountId} onValueChange={setAccountId}>
                <SelectTrigger id={`${fieldId}-account`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={NO_ACCOUNT}>
                    {t("recurring.accountPlaceholder")}
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

          {/* Fecha de inicio + fin */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-start`}>
                {t("recurring.startDateLabel")}
              </Label>
              <Input
                id={`${fieldId}-start`}
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                required
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-end`}>
                {t("recurring.endDateLabel")}{" "}
                <span className="text-text-dim font-normal">
                  {t("recurring.optional")}
                </span>
              </Label>
              <Input
                id={`${fieldId}-end`}
                type="date"
                value={endDate}
                min={startDate}
                onChange={(e) => setEndDate(e.target.value)}
              />
            </div>
          </div>

          {/* Nota */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-note`}>
              {t("recurring.noteLabel")}{" "}
              <span className="text-text-dim font-normal">
                {t("recurring.optional")}
              </span>
            </Label>
            <Input
              id={`${fieldId}-note`}
              autoComplete="off"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder={t("recurring.notePlaceholder")}
              maxLength={140}
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
              {isEdit ? t("common.saveChanges") : t("recurring.createSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
