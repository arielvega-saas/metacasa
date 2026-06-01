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
  createTemplate,
  updateTemplate,
  type TemplateFormInput,
} from "@/lib/actions/templates";
import { useT } from "@/components/i18n/locale-provider";
import type { TransactionTemplate } from "@/lib/db/templates";

interface TemplateDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Plantilla a editar; si es undefined, crea una nueva. */
  template?: TransactionTemplate;
  categories: { gastos: string[]; ingresos: string[] };
  /** Moneda base del hogar (símbolo del input de monto + moneda del atajo). */
  currency: string;
}

/**
 * Diálogo de alta/edición de atajo (plantilla). Toggle gasto/ingreso, nombre,
 * emoji opcional, monto, categoría y nota opcional. Mismo layout que el resto de
 * los diálogos del producto (Recurrentes). Delega en las server actions.
 */
export function TemplateDialog({
  open,
  onOpenChange,
  template,
  categories,
  currency,
}: TemplateDialogProps) {
  const router = useRouter();
  const t = useT();
  const fieldId = useId();
  const isEdit = Boolean(template);

  const [type, setType] = useState<TxType>(
    template?.type === TX_TYPE.INCOME ? TX_TYPE.INCOME : TX_TYPE.EXPENSE,
  );
  const [name, setName] = useState(template?.name ?? "");
  const [emoji, setEmoji] = useState(template?.emoji ?? "");
  const [amount, setAmount] = useState(template ? String(template.amount) : "");
  const [category, setCategory] = useState(template?.category ?? "");
  const [note, setNote] = useState(template?.note ?? "");

  const [pending, startTransition] = useTransition();
  const isIncome = type === TX_TYPE.INCOME;
  const catOptions = isIncome ? categories.ingresos : categories.gastos;

  function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const parsedAmount = parseMoney(amount);
    if (!name.trim()) {
      toast.error(t("templates.errors.nameRequired"));
      return;
    }
    if (parsedAmount <= 0 || !category.trim()) {
      toast.error(t("templates.saveError"));
      return;
    }

    const form: TemplateFormInput = {
      name: name.trim(),
      emoji: emoji.trim() || null,
      type,
      amount: parsedAmount,
      currency,
      category: category.trim(),
      note: note.trim() || null,
    };

    startTransition(async () => {
      try {
        if (isEdit && template) {
          await updateTemplate(template.id, form);
          toast.success(t("templates.updated"));
        } else {
          await createTemplate(form);
          toast.success(t("templates.created"));
        }
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(t("templates.saveError"), {
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
              ? t("templates.dialogEditTitle")
              : t("templates.dialogCreateTitle")}
          </DialogTitle>
          <DialogDescription>
            {isEdit
              ? t("templates.dialogEditDescription")
              : t("templates.dialogCreateDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          {/* Toggle gasto / ingreso */}
          <div
            className="bg-inset hairline grid grid-cols-2 gap-1 rounded-[var(--radius-md)] p-1"
            role="group"
            aria-label={t("templates.amountLabel")}
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
              {t("templates.expenseToggle")}
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
              {t("templates.incomeToggle")}
            </button>
          </div>

          {/* Emoji + nombre */}
          <div className="grid grid-cols-[5rem_1fr] gap-3">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-emoji`}>
                {t("templates.emojiLabel")}
              </Label>
              <Input
                id={`${fieldId}-emoji`}
                autoComplete="off"
                value={emoji}
                onChange={(e) => setEmoji(e.target.value)}
                placeholder={t("templates.emojiPlaceholder")}
                maxLength={4}
                className="text-center text-lg"
                aria-label={t("templates.emojiLabel")}
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-name`}>
                {t("templates.nameLabel")}
              </Label>
              <Input
                id={`${fieldId}-name`}
                autoComplete="off"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder={t("templates.namePlaceholder")}
                maxLength={60}
                autoFocus
              />
            </div>
          </div>

          {/* Monto */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-amount`}>
              {t("templates.amountLabel")}
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
              />
            </div>
          </div>

          {/* Categoría */}
          <div className="space-y-1.5">
            <Label>{t("templates.categoryLabel")}</Label>
            <Select value={category} onValueChange={setCategory}>
              <SelectTrigger aria-label={t("templates.categoryLabel")}>
                <SelectValue placeholder={t("templates.categoryPlaceholder")} />
              </SelectTrigger>
              <SelectContent>
                <SelectGroup>
                  <SelectLabel>
                    {isIncome
                      ? t("templates.incomeToggle")
                      : t("templates.expenseToggle")}
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

          {/* Nota */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-note`}>
              {t("templates.noteLabel")}{" "}
              <span className="text-text-dim font-normal">
                {t("templates.optional")}
              </span>
            </Label>
            <Input
              id={`${fieldId}-note`}
              autoComplete="off"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder={t("templates.notePlaceholder")}
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
              {isEdit ? t("common.saveChanges") : t("templates.createSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
