"use client";

import {
  ArrowDownCircle,
  PiggyBank,
  TrendingUp,
  ArrowRight,
  GitBranch,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Amount } from "@/components/finance/amount";
import { SectionHeader } from "@/components/finance/section-header";
import { StrategyDialog } from "@/components/budgets/strategy-dialog";
import { useT } from "@/components/i18n/locale-provider";
import {
  type HouseholdStrategy,
  type DistributionMode,
  computeWaterfall,
} from "@/lib/db/strategy";

interface StrategyCardProps {
  strategy: HouseholdStrategy;
  /** Ingreso del período seleccionado (mismo `total_income` que el board). */
  income: number;
  currency: string;
  /** Solo owner/admin ven el botón de editar. */
  canEdit: boolean;
}

const MODE_LABEL: Record<DistributionMode, string> = {
  equal: "strategy.modeEqual",
  proportional: "strategy.modeProportional",
  custom: "strategy.modeCustom",
};

/**
 * Card de Estrategia / Waterfall dentro de la pantalla de Presupuesto.
 *
 * Muestra la cascada del mes (ingreso → ahorro % → inversión % → remanente)
 * usando `computeWaterfall`, el MISMO motor portado de iOS
 * (`WaterfallCalculator.swift`). El ingreso es el `total_income` del período
 * (suma de INGRESO), idéntico a lo que iOS pasa como `totalIncome()`.
 *
 * Nota de alcance: el card surfacea la sub-cascada de porcentajes sobre el
 * ingreso. Las deducciones por gastos fijos / vencimientos / cuotas / deuda /
 * sobres compartidos NO se restan acá (viven en pantallas que esta tarea no
 * toca); el motor las soporta 1:1 y la app nativa sigue calculándolas completas.
 */
export function StrategyCard({
  strategy,
  income,
  currency,
  canEdit,
}: StrategyCardProps) {
  const t = useT();

  const result = computeWaterfall({ income }, strategy);

  return (
    <Card className="p-5">
      <SectionHeader
        title={t("strategy.title")}
        subtitle={t("strategy.subtitle")}
        action={
          <StrategyDialog
            strategy={strategy}
            income={income}
            currency={currency}
            canEdit={canEdit}
          />
        }
      />

      {/* Cascada: ingreso → ahorro → inversión → remanente */}
      <ol className="space-y-2.5">
        <li className="bg-income/[0.06] flex items-center justify-between gap-3 rounded-[var(--radius-lg)] px-3.5 py-3">
          <span className="flex items-center gap-2.5 text-sm">
            <ArrowDownCircle className="text-income size-4 shrink-0" />
            {t("strategy.income")}
          </span>
          <Amount value={result.totalIncome} currency={currency} kind="ingreso" />
        </li>

        <CascadeRow
          icon={<PiggyBank className="text-income size-4 shrink-0" />}
          label={t("strategy.savings")}
          pct={strategy.savingsPct}
          value={result.savingsAllocation}
          currency={currency}
        />

        <CascadeRow
          icon={<TrendingUp className="text-income size-4 shrink-0" />}
          label={t("strategy.investment")}
          pct={strategy.investmentPct}
          value={result.investmentAllocation}
          currency={currency}
        />

        <li className="bg-primary/[0.07] border-primary/20 flex items-center justify-between gap-3 rounded-[var(--radius-lg)] border px-3.5 py-3">
          <span className="flex items-center gap-2.5 text-sm font-semibold">
            <ArrowRight className="text-primary size-4 shrink-0" />
            {t("strategy.remainder")}
          </span>
          <Amount
            value={result.remainder}
            currency={currency}
            kind="balance"
            className="font-semibold"
          />
        </li>
      </ol>

      <p className="text-text-dim mt-2.5 text-xs">{t("strategy.remainderHint")}</p>

      {/* Modo de distribución del remanente */}
      <div className="mt-4 flex items-center justify-between gap-3 border-t border-border pt-4">
        <span className="text-text-muted flex items-center gap-2 text-sm">
          <GitBranch className="size-4 shrink-0" />
          {t("strategy.distribution")}
        </span>
        <Badge variant="neutral">
          {t(MODE_LABEL[strategy.distributionMode])}
        </Badge>
      </div>

      {income === 0 && (
        <p className="text-text-dim mt-3 text-xs">{t("strategy.noIncomeHint")}</p>
      )}
      {!canEdit && (
        <p className="text-text-dim mt-3 text-xs">{t("strategy.readOnlyHint")}</p>
      )}
    </Card>
  );
}

/** Fila de la cascada con su badge de porcentaje. */
function CascadeRow({
  icon,
  label,
  pct,
  value,
  currency,
}: {
  icon: React.ReactNode;
  label: string;
  pct: number;
  value: number;
  currency: string;
}) {
  return (
    <li className="flex items-center justify-between gap-3 px-3.5 py-1.5">
      <span className="flex items-center gap-2.5 text-sm">
        {icon}
        {label}
        <Badge variant="neutral" className="tnum">
          {Math.round(pct)}%
        </Badge>
      </span>
      <Amount value={value} currency={currency} kind="ingreso" />
    </li>
  );
}
