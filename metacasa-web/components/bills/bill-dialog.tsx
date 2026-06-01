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
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { SUPPORTED_CURRENCIES } from "@/lib/constants";
import { parseMoney, symbolFor } from "@/lib/money";
import {
  createBillAction,
  updateBillAction,
  type BillFormInput,
} from "@/lib/actions/bills";
import { FREQUENCIES, type Frequency } from "@/lib/db/recurring";
import { useT } from "@/components/i18n/locale-provider";
import type { Bill } from "@/lib/db/bills";

const NO_RECURRENCE = "__none__";

/** Hoy en formato YYYY-MM-DD (zona local), default del input de fecha. */
function todayISO(): string {
  const d = new Date();
  const off = d.getTimezoneOffset();
  return new Date(d.getTime() - off * 60_000).toISOString().slice(0, 10);
}

interface BillDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Vencimiento a editar; si es undefined, crea uno nuevo. */
  bill?: Bill;
  /** Categorías de gasto del hogar (para el selector). */
  categories: string[];
  /** Moneda base del hogar (default en alta). */
  currency: string;
}

/**
 * Diálogo de alta/edición de vencimiento. Título, monto, moneda, categoría,
 * fecha de vencimiento, días de aviso y recurrencia opcional. Delega en las
 * server actions, que setean el trío FX (sin conversión: fx=1).
 */
export function BillDialog({
  open,
  onOpenChange,
  bill,
  categories,
  currency,
}: BillDialogProps) {
  const router = useRouter();
  const t = useT();
  const fieldId = useId();
  const isEdit = Boolean(bill);

  const [title, setTitle] = useState(bill?.title ?? "");
  const [amount, setAmount] = useState(bill ? String(bill.amount) : "");
  const [category, setCategory] = useState(bill?.category ?? "");
  const [billCurrency, setBillCurrency] = useState(bill?.currency ?? currency);
  const [dueDate, setDueDate] = useState(bill?.due_date ?? todayISO());
  const [reminderDays, setReminderDays] = useState(
    bill?.reminder_days != null ? String(bill.reminder_days) : "3",
  );
  const [recurrence, setRecurrence] = useState<string>(
    bill?.recurrence_type ?? NO_RECURRENCE,
  );

  const [pending, startTransition] = useTransition();

  function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!title.trim()) {
      toast.error(t("bills.titleRequired"));
      return;
    }
    const parsedAmount = parseMoney(amount);
    if (parsedAmount <= 0) {
      toast.error(t("bills.amountRequired"));
      return;
    }

    const form: BillFormInput = {
      title: title.trim(),
      amount: parsedAmount,
      category: category.trim(),
      dueDate,
      currency: billCurrency,
      reminderDays: Number(reminderDays) || 0,
      recurrenceType: recurrence === NO_RECURRENCE ? null : recurrence,
    };

    startTransition(async () => {
      try {
        if (isEdit && bill) {
          await updateBillAction(bill.id, form);
          toast.success(t("bills.updated"));
        } else {
          await createBillAction(form);
          toast.success(t("bills.created"));
        }
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(t("bills.saveError"), {
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
            {isEdit ? t("bills.dialogEditTitle") : t("bills.dialogCreateTitle")}
          </DialogTitle>
          <DialogDescription>
            {isEdit
              ? t("bills.dialogEditDescription")
              : t("bills.dialogCreateDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          {/* Título */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-title`}>{t("bills.titleLabel")}</Label>
            <Input
              id={`${fieldId}-title`}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder={t("bills.titlePlaceholder")}
              autoFocus
              required
            />
          </div>

          {/* Monto + moneda */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-amount`}>{t("bills.amountLabel")}</Label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(billCurrency)}
                </span>
                <Input
                  id={`${fieldId}-amount`}
                  inputMode="decimal"
                  autoComplete="off"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="0"
                  className="pl-10 tnum"
                />
              </div>
              <Select value={billCurrency} onValueChange={setBillCurrency}>
                <SelectTrigger
                  className="w-28 shrink-0"
                  aria-label={t("bills.currencyLabel")}
                >
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {SUPPORTED_CURRENCIES.map((c) => (
                    <SelectItem key={c.code} value={c.code}>
                      {c.code}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Categoría + fecha */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label>{t("bills.categoryLabel")}</Label>
              <Select value={category} onValueChange={setCategory}>
                <SelectTrigger aria-label={t("bills.categoryLabel")}>
                  <SelectValue placeholder={t("bills.categoryPlaceholder")} />
                </SelectTrigger>
                <SelectContent>
                  {categories.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-due`}>{t("bills.dueDateLabel")}</Label>
              <Input
                id={`${fieldId}-due`}
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                required
              />
            </div>
          </div>

          {/* Recordatorio + recurrencia */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-reminder`}>
                {t("bills.reminderLabel")}
              </Label>
              <Input
                id={`${fieldId}-reminder`}
                type="number"
                min={0}
                max={60}
                value={reminderDays}
                onChange={(e) => setReminderDays(e.target.value)}
                className="tnum"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-recurrence`}>
                {t("bills.recurrenceLabel")}
              </Label>
              <Select value={recurrence} onValueChange={setRecurrence}>
                <SelectTrigger id={`${fieldId}-recurrence`}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={NO_RECURRENCE}>
                    {t("bills.recurrenceNone")}
                  </SelectItem>
                  {FREQUENCIES.map((f) => (
                    <SelectItem key={f} value={f}>
                      {t(`recurring.freq.${f as Frequency}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <DialogFooter className="pt-2">
            <DialogClose asChild>
              <Button type="button" variant="ghost" disabled={pending}>
                {t("common.cancel")}
              </Button>
            </DialogClose>
            <Button type="submit" disabled={pending}>
              {pending && <Loader2 className="animate-spin" />}
              {isEdit ? t("common.saveChanges") : t("bills.createSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
