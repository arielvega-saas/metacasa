"use client";

import * as React from "react";
import { toast } from "sonner";
import { SlidersHorizontal } from "lucide-react";
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
import { Switch } from "@/components/ui/switch";
import { Amount } from "@/components/finance/amount";
import { useT } from "@/components/i18n/locale-provider";
import { updateStrategy } from "@/lib/actions/strategy";
import {
  type HouseholdStrategy,
  type DistributionMode,
  DISTRIBUTION_MODES,
  computeWaterfall,
} from "@/lib/db/strategy";

interface StrategyDialogProps {
  strategy: HouseholdStrategy;
  /** Ingreso del período (para el preview en vivo de la cascada). */
  income: number;
  currency: string;
  /** Solo owner/admin pueden editar; si false, no se renderiza el trigger. */
  canEdit: boolean;
}

const MODE_LABEL: Record<DistributionMode, string> = {
  equal: "strategy.modeEqual",
  proportional: "strategy.modeProportional",
  custom: "strategy.modeCustom",
};

const MODE_HINT: Record<DistributionMode, string> = {
  equal: "strategy.modeEqualHint",
  proportional: "strategy.modeProportionalHint",
  custom: "strategy.modeCustomHint",
};

/**
 * Diálogo para editar la estrategia Waterfall. Mantiene un estado local y solo
 * persiste al confirmar (vía `updateStrategy`). El preview recalcula la cascada
 * en vivo con `computeWaterfall` (mismo motor que iOS), igual que el
 * PlanEditorView nativo.
 *
 * Conservador a propósito: NO edita `customAllocations` (requiere la lista de
 * cuentas personales, fuera del scope de esta pantalla). Esas claves se
 * preservan tal cual estaban, así no se corrompe el jsonb que usa la app.
 */
export function StrategyDialog({
  strategy,
  income,
  currency,
  canEdit,
}: StrategyDialogProps) {
  const t = useT();
  const [open, setOpen] = React.useState(false);
  const [savingsPct, setSavingsPct] = React.useState(strategy.savingsPct);
  const [investmentPct, setInvestmentPct] = React.useState(
    strategy.investmentPct,
  );
  const [mode, setMode] = React.useState<DistributionMode>(
    strategy.distributionMode,
  );
  const [includeBills, setIncludeBills] = React.useState(
    strategy.includeBillsInWaterfall,
  );
  const [includeInstallments, setIncludeInstallments] = React.useState(
    strategy.includeInstallmentsInWaterfall,
  );
  const [includeDebts, setIncludeDebts] = React.useState(
    strategy.includeDebtPaymentsInWaterfall,
  );
  const [pending, startTransition] = React.useTransition();

  // Reset al estado guardado cuando se (re)abre o cambia la estrategia base.
  const reset = React.useCallback(() => {
    setSavingsPct(strategy.savingsPct);
    setInvestmentPct(strategy.investmentPct);
    setMode(strategy.distributionMode);
    setIncludeBills(strategy.includeBillsInWaterfall);
    setIncludeInstallments(strategy.includeInstallmentsInWaterfall);
    setIncludeDebts(strategy.includeDebtPaymentsInWaterfall);
  }, [strategy]);

  // Preview en vivo: misma cascada que el card, con los valores editándose.
  const preview = computeWaterfall(
    { income },
    {
      ...strategy,
      savingsPct,
      investmentPct,
      distributionMode: mode,
      includeBillsInWaterfall: includeBills,
      includeInstallmentsInWaterfall: includeInstallments,
      includeDebtPaymentsInWaterfall: includeDebts,
    },
  );

  const sumOver = savingsPct + investmentPct > 100;

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (savingsPct < 0 || savingsPct > 100 || investmentPct < 0 || investmentPct > 100) {
      toast.error(t("strategy.invalidPct"));
      return;
    }
    if (sumOver) {
      toast.error(t("strategy.sumTooHigh"));
      return;
    }
    startTransition(async () => {
      try {
        await updateStrategy({
          savingsPct,
          investmentPct,
          distributionMode: mode,
          includeBillsInWaterfall: includeBills,
          includeInstallmentsInWaterfall: includeInstallments,
          includeDebtPaymentsInWaterfall: includeDebts,
          // Preservamos las allocations custom existentes (no se editan acá).
          customAllocations: strategy.customAllocations,
        });
        toast.success(t("strategy.saved"));
        setOpen(false);
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("strategy.saveError"),
        );
      }
    });
  }

  if (!canEdit) return null;

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (o) reset();
      }}
    >
      <DialogTrigger asChild>
        <Button size="sm" variant="secondary">
          <SlidersHorizontal className="size-4" />
          {t("strategy.edit")}
        </Button>
      </DialogTrigger>

      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <SlidersHorizontal className="text-primary size-4" />
            {t("strategy.dialogTitle")}
          </DialogTitle>
          <DialogDescription>
            {t("strategy.dialogDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Porcentajes */}
          <fieldset className="space-y-4">
            <legend className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {t("strategy.percentages")}
            </legend>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label htmlFor="strategy-savings">
                  {t("strategy.savingsPctLabel")}
                </Label>
                <Input
                  id="strategy-savings"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  max={100}
                  step={1}
                  value={Number.isFinite(savingsPct) ? savingsPct : 0}
                  onChange={(e) =>
                    setSavingsPct(
                      Math.min(100, Math.max(0, Number(e.target.value) || 0)),
                    )
                  }
                  className="tnum"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="strategy-investment">
                  {t("strategy.investmentPctLabel")}
                </Label>
                <Input
                  id="strategy-investment"
                  type="number"
                  inputMode="numeric"
                  min={0}
                  max={100}
                  step={1}
                  value={Number.isFinite(investmentPct) ? investmentPct : 0}
                  onChange={(e) =>
                    setInvestmentPct(
                      Math.min(100, Math.max(0, Number(e.target.value) || 0)),
                    )
                  }
                  className="tnum"
                />
              </div>
            </div>
            {sumOver && (
              <p className="text-expense text-xs">{t("strategy.sumTooHigh")}</p>
            )}
          </fieldset>

          {/* Modo de distribución */}
          <div className="space-y-2">
            <Label htmlFor="strategy-mode">
              {t("strategy.distributionMode")}
            </Label>
            <Select
              value={mode}
              onValueChange={(v) => setMode(v as DistributionMode)}
            >
              <SelectTrigger id="strategy-mode">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {DISTRIBUTION_MODES.map((m) => (
                  <SelectItem key={m} value={m}>
                    {t(MODE_LABEL[m])}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-text-dim text-xs">{t(MODE_HINT[mode])}</p>
          </div>

          {/* Inclusiones */}
          <fieldset className="space-y-3">
            <legend className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {t("strategy.inclusions")}
            </legend>
            <label
              htmlFor="strategy-bills"
              className="flex cursor-pointer items-center justify-between gap-3"
            >
              <span className="text-sm">{t("strategy.includeBills")}</span>
              <Switch
                id="strategy-bills"
                checked={includeBills}
                onCheckedChange={setIncludeBills}
              />
            </label>
            <label
              htmlFor="strategy-installments"
              className="flex cursor-pointer items-center justify-between gap-3"
            >
              <span className="text-sm">
                {t("strategy.includeInstallments")}
              </span>
              <Switch
                id="strategy-installments"
                checked={includeInstallments}
                onCheckedChange={setIncludeInstallments}
              />
            </label>
            <label
              htmlFor="strategy-debts"
              className="flex cursor-pointer items-center justify-between gap-3"
            >
              <span className="text-sm">{t("strategy.includeDebts")}</span>
              <Switch
                id="strategy-debts"
                checked={includeDebts}
                onCheckedChange={setIncludeDebts}
              />
            </label>
          </fieldset>

          {/* Preview en vivo */}
          <div className="hairline space-y-2 rounded-[var(--radius-lg)] bg-white/[0.03] p-4">
            <p className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {t("strategy.preview")}
            </p>
            <div className="flex items-center justify-between text-sm">
              <span className="text-income">{t("strategy.savings")}</span>
              <Amount
                value={preview.savingsAllocation}
                currency={currency}
                kind="ingreso"
              />
            </div>
            <div className="flex items-center justify-between text-sm">
              <span className="text-income">{t("strategy.investment")}</span>
              <Amount
                value={preview.investmentAllocation}
                currency={currency}
                kind="ingreso"
              />
            </div>
            <div className="flex items-center justify-between border-t border-border pt-2 text-sm font-semibold">
              <span>{t("strategy.remainder")}</span>
              <Amount
                value={preview.remainder}
                currency={currency}
                kind="balance"
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
            <Button type="submit" disabled={pending || sumOver}>
              {pending ? t("strategy.saving") : t("common.saveChanges")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
