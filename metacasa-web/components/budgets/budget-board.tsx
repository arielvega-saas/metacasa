"use client";

import { Wallet, TrendingUp, PiggyBank, Inbox } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { Amount } from "@/components/finance/amount";
import { SectionHeader } from "@/components/finance/section-header";
import { AllocationDialog } from "@/components/budgets/allocation-dialog";
import { AllocationRowMenu } from "@/components/budgets/allocation-row-menu";
import { useT } from "@/components/i18n/locale-provider";
import { formatMoney } from "@/lib/money";

/** Una asignación con sus métricas ya calculadas en el server. */
export interface AllocationRow {
  id: string;
  category: string;
  /** Monto asignado este período (sin rollover). */
  allocated: number;
  /** Rollover arrastrado del período anterior. */
  rollover: number;
  /** allocated + rollover. */
  budgeted: number;
  /** Gastado en la categoría dentro del período. */
  spent: number;
  /** budgeted - spent (saldo del sobre, vía RPC envelope_balance). */
  remaining: number;
  currency: string;
}

interface BudgetBoardProps {
  periodId: string;
  currency: string;
  /** Resumen del período. */
  readyToAssign: number;
  totalIncome: number;
  totalAllocated: number;
  /** Etiqueta del mes (ej. "mayo 2026"). */
  periodLabel: string;
  rows: AllocationRow[];
  /** Categorías de gasto disponibles (de getCategories). */
  categories: string[];
}

/** Color del progreso según % gastado: verde <80, champagne 80-100, coral >100. */
function progressTone(pct: number): { indicator: string } {
  if (pct > 100) return { indicator: "bg-expense" };
  if (pct >= 80) return { indicator: "bg-champagne" };
  return { indicator: "bg-primary" };
}

/** Tablero de presupuesto por sobres (envelope budgeting estilo YNAB). */
export function BudgetBoard({
  periodId,
  currency,
  readyToAssign,
  totalIncome,
  totalAllocated,
  periodLabel,
  rows,
  categories,
}: BudgetBoardProps) {
  const t = useT();
  const assignedCategories = rows.map((r) => r.category);
  const overAssigned = readyToAssign < 0;

  return (
    <div className="space-y-6">
      {/* Resumen del período: lo que falta asignar es el corazón del zero-based. */}
      <div className="grid gap-3 sm:gap-4 lg:grid-cols-3">
        <Card
          glass
          className="sage-glow border-primary/20 p-5"
          aria-live="polite"
        >
          <div className="flex items-center justify-between">
            <span className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {t("budgets.readyToAssign")}
            </span>
            <Inbox className="text-text-muted size-4" />
          </div>
          <div className="mt-2.5 text-[26px] leading-none sm:text-[28px]">
            <Amount
              value={readyToAssign}
              currency={currency}
              kind={overAssigned ? "gasto" : "balance"}
              serif
            />
          </div>
          <p className="text-text-dim mt-1.5 text-xs capitalize">
            {overAssigned
              ? t("budgets.overAssigned")
              : t("budgets.eachDollarAJob", { period: periodLabel })}
          </p>
        </Card>

        <Card className="p-5">
          <div className="flex items-center justify-between">
            <span className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {t("budgets.periodIncome")}
            </span>
            <TrendingUp className="text-text-muted size-4" />
          </div>
          <div className="mt-2.5 text-[26px] leading-none sm:text-[28px]">
            <Amount value={totalIncome} currency={currency} kind="ingreso" serif />
          </div>
          <p className="text-text-dim mt-1.5 text-xs">
            {t("budgets.recordedThisMonth")}
          </p>
        </Card>

        <Card className="p-5">
          <div className="flex items-center justify-between">
            <span className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
              {t("budgets.totalAssigned")}
            </span>
            <PiggyBank className="text-text-muted size-4" />
          </div>
          <div className="mt-2.5 text-[26px] leading-none sm:text-[28px]">
            <Amount value={totalAllocated} currency={currency} kind="balance" serif />
          </div>
          <p className="text-text-dim mt-1.5 text-xs">
            {rows.length === 1
              ? t("budgets.envelopeCountSuffixOne", { n: rows.length })
              : t("budgets.envelopeCountSuffixOther", { n: rows.length })}
          </p>
        </Card>
      </div>

      {/* Sobres por categoría */}
      <Card className="p-5">
        <SectionHeader
          title={t("budgets.envelopes")}
          subtitle={t("budgets.envelopesSubtitle")}
          action={
            <AllocationDialog
              periodId={periodId}
              currency={currency}
              categories={categories}
              assignedCategories={assignedCategories}
            />
          }
        />

        {rows.length === 0 ? (
          <EmptyState
            icon={Wallet}
            title={t("budgets.noEnvelopesTitle")}
            description={t("budgets.noEnvelopesDescription")}
            action={
              <AllocationDialog
                periodId={periodId}
                currency={currency}
                categories={categories}
                assignedCategories={assignedCategories}
              />
            }
          />
        ) : (
          <ul className="divide-y divide-border">
            {rows.map((row) => {
              const pct =
                row.budgeted > 0
                  ? Math.round((row.spent / row.budgeted) * 100)
                  : row.spent > 0
                    ? 100
                    : 0;
              const tone = progressTone(pct);
              const overspent = row.remaining < 0;

              return (
                <li key={row.id} className="py-3.5">
                  <div className="flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium">
                        {row.category}
                      </p>
                      <p className="text-text-muted text-xs">
                        {t("budgets.spentOf", {
                          spent: formatMoney(row.spent, currency),
                          budgeted: formatMoney(row.budgeted, currency),
                        })}
                        {row.rollover > 0 && (
                          <span className="text-text-dim">
                            {t("budgets.includesRollover", {
                              amount: formatMoney(row.rollover, currency),
                            })}
                          </span>
                        )}
                      </p>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="text-right">
                        <Amount
                          value={row.remaining}
                          currency={currency}
                          kind="balance"
                          className="text-sm font-semibold"
                        />
                        <p className="text-text-dim text-[11px]">
                          {overspent
                            ? t("budgets.overspentLabel")
                            : t("budgets.availableLabel")}
                        </p>
                      </div>
                      <AllocationRowMenu
                        allocationId={row.id}
                        periodId={periodId}
                        currency={currency}
                        category={row.category}
                        allocated={row.allocated}
                        categories={categories}
                      />
                    </div>
                  </div>

                  <div className="mt-2.5 flex items-center gap-3">
                    <Progress
                      value={Math.min(100, pct)}
                      indicatorClassName={tone.indicator}
                      className="flex-1"
                      aria-label={t("budgets.progressAria", {
                        pct,
                        category: row.category,
                      })}
                    />
                    {pct > 100 ? (
                      <Badge variant="expense" className="shrink-0">
                        {pct}%
                      </Badge>
                    ) : (
                      <span className="text-text-muted tnum w-10 shrink-0 text-right text-xs">
                        {pct}%
                      </span>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Card>
    </div>
  );
}
