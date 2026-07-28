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
import { createGoalAction, updateGoalAction } from "@/lib/actions/goals";
import { parseMoney, symbolFor } from "@/lib/money";
import { SUPPORTED_CURRENCIES } from "@/lib/constants";
import { GOAL_ICONS, type GoalIconKey } from "@/components/goals/goal-icon";
import { useT } from "@/components/i18n/locale-provider";

interface GoalDialogProps {
  defaultCurrency: string;
  /** Si se pasa, edita esa meta; si no, crea una nueva. */
  edit?: {
    id: string;
    name: string;
    targetAmount: number;
    currency: string;
    targetDate: string | null;
    icon: string | null;
  };
  trigger?: React.ReactNode;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
  hideTrigger?: boolean;
}

/** Diálogo para crear o editar una meta de ahorro. */
export function GoalDialog({
  defaultCurrency,
  edit,
  trigger,
  open: controlledOpen,
  onOpenChange,
  hideTrigger,
}: GoalDialogProps) {
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

  const [name, setName] = React.useState(edit?.name ?? "");
  const [target, setTarget] = React.useState(
    edit ? String(edit.targetAmount) : "",
  );
  const [initial, setInitial] = React.useState("");
  const [currency, setCurrency] = React.useState(
    edit?.currency ?? defaultCurrency,
  );
  const [targetDate, setTargetDate] = React.useState(edit?.targetDate ?? "");
  const [icon, setIcon] = React.useState<string>(edit?.icon ?? "target");
  const [pending, startTransition] = React.useTransition();

  function reset() {
    setName(edit?.name ?? "");
    setTarget(edit ? String(edit.targetAmount) : "");
    setInitial("");
    setCurrency(edit?.currency ?? defaultCurrency);
    setTargetDate(edit?.targetDate ?? "");
    setIcon(edit?.icon ?? "target");
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const targetValue = parseMoney(target);
    if (!name.trim()) {
      toast.error(t("goals.nameRequired"));
      return;
    }
    if (!(targetValue > 0)) {
      toast.error(t("goals.targetRequired"));
      return;
    }

    startTransition(async () => {
      try {
        if (isEdit) {
          await updateGoalAction(edit!.id, {
            name,
            targetAmount: targetValue,
            currency,
            targetDate: targetDate || null,
            icon,
          });
          toast.success(t("goals.updated"));
        } else {
          await createGoalAction({
            name,
            targetAmount: targetValue,
            currentAmount: parseMoney(initial) || 0,
            currency,
            targetDate: targetDate || null,
            icon,
          });
          toast.success(t("goals.created"));
        }
        setOpen(false);
        if (!isEdit) reset();
      } catch (err) {
        toast.error(err instanceof Error ? err.message : t("goals.saveError"));
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
              {t("goals.newGoal")}
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
            {isEdit ? t("goals.editTitle") : t("goals.createTitle")}
          </DialogTitle>
          <DialogDescription>
            {isEdit ? t("goals.editDescription") : t("goals.createDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="goal-name">{t("goals.nameLabel")}</Label>
            <Input
              id="goal-name"
              placeholder={t("goals.namePlaceholder")}
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
            />
          </div>

          {/* Selector de ícono para personalizar la card. */}
          <div className="space-y-2">
            <Label>{t("goals.iconLabel")}</Label>
            <div className="flex flex-wrap gap-2">
              {(Object.keys(GOAL_ICONS) as GoalIconKey[]).map((key) => {
                const Icon = GOAL_ICONS[key];
                const selected = icon === key;
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => setIcon(key)}
                    aria-label={t("goals.iconAria", { icon: key })}
                    aria-pressed={selected}
                    className={`flex size-10 items-center justify-center rounded-[var(--radius-md)] border transition-colors ${
                      selected
                        ? "border-primary/60 bg-primary/15 text-primary"
                        : "border-border text-text-muted hover:bg-tint-2"
                    }`}
                  >
                    <Icon className="size-[18px]" />
                  </button>
                );
              })}
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="goal-target">{t("goals.targetLabel")}</Label>
              <div className="relative">
                <span className="text-text-muted pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id="goal-target"
                  inputMode="decimal"
                  placeholder="0"
                  value={target}
                  onChange={(e) => setTarget(e.target.value)}
                  className="tnum pl-12"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="goal-currency">{t("goals.currencyLabel")}</Label>
              <Select value={currency} onValueChange={setCurrency}>
                <SelectTrigger id="goal-currency">
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

          {/* Monto inicial solo al crear (al editar lo maneja el trigger de contribuciones). */}
          {!isEdit && (
            <div className="space-y-2">
              <Label htmlFor="goal-initial">
                {t("goals.initialLabel")}{" "}
                <span className="text-text-dim font-normal">
                  {t("goals.optional")}
                </span>
              </Label>
              <div className="relative">
                <span className="text-text-muted pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id="goal-initial"
                  inputMode="decimal"
                  placeholder="0"
                  value={initial}
                  onChange={(e) => setInitial(e.target.value)}
                  className="tnum pl-12"
                />
              </div>
              <p className="text-text-dim text-xs">{t("goals.initialHint")}</p>
            </div>
          )}

          <div className="space-y-2">
            <Label htmlFor="goal-date">
              {t("goals.targetDateLabel")}{" "}
              <span className="text-text-dim font-normal">
                {t("goals.optional")}
              </span>
            </Label>
            <Input
              id="goal-date"
              type="date"
              value={targetDate}
              onChange={(e) => setTargetDate(e.target.value)}
              className="tnum"
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
              {pending
                ? t("goals.saving")
                : isEdit
                  ? t("common.saveChanges")
                  : t("goals.createSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
