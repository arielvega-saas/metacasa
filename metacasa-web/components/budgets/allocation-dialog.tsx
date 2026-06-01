"use client";

import * as React from "react";
import { toast } from "sonner";
import { Plus, Pencil } from "lucide-react";
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
import { saveAllocation } from "@/lib/actions/budgets";
import { parseMoney, symbolFor } from "@/lib/money";
import { useT } from "@/components/i18n/locale-provider";

interface AllocationDialogProps {
  periodId: string;
  currency: string;
  /** Categorías de gasto disponibles (de getCategories). */
  categories: string[];
  /** Categorías que ya tienen un sobre (para no duplicar al crear). */
  assignedCategories: string[];
  /** Si se pasa, el diálogo edita ese sobre; si no, crea uno nuevo. */
  edit?: { category: string; allocated: number };
  /** Trigger custom (ej. ítem de menú). Por defecto, un botón. */
  trigger?: React.ReactNode;
  /** Modo controlado (ej. abierto desde un menú externo). */
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  /** Oculta el trigger interno (cuando se controla desde afuera). */
  hideTrigger?: boolean;
}

/** Diálogo para crear o editar la asignación de un sobre (categoría + monto). */
export function AllocationDialog({
  periodId,
  currency,
  categories,
  assignedCategories,
  edit,
  trigger,
  open: controlledOpen,
  onOpenChange,
  hideTrigger,
}: AllocationDialogProps) {
  const t = useT();
  const isEdit = Boolean(edit);
  const [uncontrolledOpen, setUncontrolledOpen] = React.useState(false);
  const isControlled = controlledOpen !== undefined;
  const open = isControlled ? controlledOpen : uncontrolledOpen;
  const setOpen = React.useCallback(
    (o: boolean) => {
      if (isControlled) onOpenChange?.(o);
      else setUncontrolledOpen(o);
    },
    [isControlled, onOpenChange],
  );
  const [category, setCategory] = React.useState(edit?.category ?? "");
  const [amount, setAmount] = React.useState(
    edit ? String(edit.allocated) : "",
  );
  const [pending, startTransition] = React.useTransition();

  // Al crear, ocultamos categorías que ya tienen sobre. Al editar, fijamos la propia.
  const options = isEdit
    ? [edit!.category]
    : categories.filter((c) => !assignedCategories.includes(c));

  function reset() {
    setCategory(edit?.category ?? "");
    setAmount(edit ? String(edit.allocated) : "");
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const value = parseMoney(amount);
    if (!category) {
      toast.error(t("budgets.pickCategory"));
      return;
    }
    if (!(value >= 0)) {
      toast.error(t("budgets.invalidAmount"));
      return;
    }
    startTransition(async () => {
      try {
        await saveAllocation({
          periodId,
          category,
          allocated: value,
          currency,
        });
        toast.success(
          isEdit ? t("budgets.envelopeUpdated") : t("budgets.envelopeCreated"),
        );
        setOpen(false);
        if (!isEdit) reset();
      } catch (err) {
        toast.error(err instanceof Error ? err.message : t("budgets.saveError"));
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
      {!hideTrigger && (
        <DialogTrigger asChild>
          {trigger ?? (
            <Button size="sm">
              <Plus className="size-4" />
              {t("budgets.newEnvelope")}
            </Button>
          )}
        </DialogTrigger>
      )}

      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {isEdit ? (
              <Pencil className="text-primary size-4" />
            ) : (
              <Plus className="text-primary size-4" />
            )}
            {isEdit ? t("budgets.editEnvelopeTitle") : t("budgets.newEnvelope")}
          </DialogTitle>
          <DialogDescription>
            {isEdit
              ? t("budgets.editEnvelopeDescription")
              : t("budgets.newEnvelopeDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="alloc-category">{t("budgets.categoryLabel")}</Label>
            <Select
              value={category}
              onValueChange={setCategory}
              disabled={isEdit}
            >
              <SelectTrigger id="alloc-category">
                <SelectValue placeholder={t("budgets.categoryPlaceholder")} />
              </SelectTrigger>
              <SelectContent>
                {options.length === 0 ? (
                  <div className="text-text-dim px-3 py-2 text-sm">
                    {t("budgets.allCategoriesAssigned")}
                  </div>
                ) : (
                  options.map((c) => (
                    <SelectItem key={c} value={c}>
                      {c}
                    </SelectItem>
                  ))
                )}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="alloc-amount">{t("budgets.amountLabel")}</Label>
            <div className="relative">
              <span className="text-text-muted pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                {symbolFor(currency)}
              </span>
              <Input
                id="alloc-amount"
                inputMode="decimal"
                placeholder="0"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="tnum pl-12"
                autoFocus
              />
            </div>
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
              {pending
                ? t("budgets.saving")
                : isEdit
                  ? t("common.saveChanges")
                  : t("budgets.createEnvelope")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
