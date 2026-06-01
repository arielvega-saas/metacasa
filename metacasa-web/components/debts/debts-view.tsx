"use client";

import * as React from "react";
import { Plus, Landmark } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Amount } from "@/components/finance/amount";
import { PageHeader } from "@/components/layout/page-header";
import { SectionHeader } from "@/components/finance/section-header";
import { DebtCard } from "@/components/debts/debt-card";
import { DebtDialog } from "@/components/debts/debt-dialog";
import { DebtDestructiveDialog } from "@/components/debts/debt-destructive-dialog";
import { useT } from "@/components/i18n/locale-provider";
import type { Debt, DebtTotals } from "@/lib/db/debts";
import { formatMoney } from "@/lib/money";

type DebtTab = "active" | "settled" | "all";

export interface DebtsViewProps {
  /** Deudas del hogar (activas + saldadas), ordenadas por created_at desc. */
  debts: Debt[];
  /** Moneda base del hogar. */
  currency: string;
  /** Totales de deuda activa ya consolidados a base con FX (calculados en la page). */
  debtTotals: DebtTotals;
  /** Net worth ya consolidado a moneda base (calculado en la page). */
  assets: number;
  liabilities: number;
  net: number;
  /** `true` si alguna moneda quedó fuera del net worth por faltar su tasa FX. */
  hasUnconvertedNetWorth: boolean;
}

/** Estado del diálogo de deuda: cerrado | crear | editar. */
type DialogState =
  | { mode: "closed" }
  | { mode: "create" }
  | { mode: "edit"; debt: Debt };

/** Estado del diálogo destructivo (saldar / eliminar). */
type DestructiveState =
  | { kind: "none" }
  | { kind: "settle"; debt: Debt }
  | { kind: "delete"; debt: Debt };

/**
 * Pantalla de Deudas. El server component pasa los datos + el net worth; acá
 * manejamos las tabs (activas/saldadas/todas) y los diálogos de alta/edición/
 * saldado/borrado. El total de deuda se consolida a moneda base con las tasas
 * del hogar (mismo criterio que el net worth y que iOS `DebtsListView`).
 */
export function DebtsView({
  debts,
  currency,
  debtTotals: totals,
  assets,
  liabilities,
  net,
  hasUnconvertedNetWorth,
}: DebtsViewProps) {
  const t = useT();
  const [tab, setTab] = React.useState<DebtTab>("active");
  const [dialog, setDialog] = React.useState<DialogState>({ mode: "closed" });
  const [destructive, setDestructive] = React.useState<DestructiveState>({
    kind: "none",
  });

  const active = debts.filter((d) => d.status !== "settled");
  const settled = debts.filter((d) => d.status === "settled");
  const visible = tab === "active" ? active : tab === "settled" ? settled : debts;

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("debts.title")}
        description={t("debts.headerDescription")}
        action={
          <Button onClick={() => setDialog({ mode: "create" })}>
            <Plus />
            {t("debts.new")}
          </Button>
        }
      />

      {/* Patrimonio neto (assets/liabilities/net consolidados en la page) */}
      <Card className="sage-glow p-5 sm:p-6">
        <p className="text-text-muted text-sm">{t("netWorth.title")}</p>
        <Amount
          value={net}
          currency={currency}
          kind="balance"
          serif
          className="mt-1.5 block text-3xl sm:text-4xl"
        />
        <div className="mt-4 grid grid-cols-2 gap-3">
          <div className="rounded-[var(--radius-md)] bg-white/[0.04] p-3">
            <p className="text-text-dim text-[11px] uppercase tracking-wider">
              {t("netWorth.assets")}
            </p>
            <Amount
              value={assets}
              currency={currency}
              kind="ingreso"
              className="mt-0.5 block text-base font-semibold"
            />
          </div>
          <div className="rounded-[var(--radius-md)] bg-white/[0.04] p-3">
            <p className="text-text-dim text-[11px] uppercase tracking-wider">
              {t("netWorth.liabilities")}
            </p>
            <Amount
              value={liabilities}
              currency={currency}
              kind="gasto"
              className="mt-0.5 block text-base font-semibold"
            />
          </div>
        </div>
        {hasUnconvertedNetWorth && (
          <p className="text-text-dim mt-3 text-xs">
            {t("netWorth.mixedCurrencies", { currency })}
          </p>
        )}
      </Card>

      {debts.length === 0 ? (
        <EmptyState
          icon={Landmark}
          title={t("debts.emptyTitle")}
          description={t("debts.emptyDescription")}
          action={
            <Button onClick={() => setDialog({ mode: "create" })}>
              <Plus />
              {t("debts.emptyAction")}
            </Button>
          }
        />
      ) : (
        <>
          {/* Deuda total activa + compromiso mensual */}
          <Card className="p-5 sm:p-6">
            <p className="text-text-muted text-sm">{t("debts.totalLabel")}</p>
            <div className="mt-1.5 flex flex-wrap items-end gap-x-3 gap-y-1">
              <Amount
                value={totals.totalBalance}
                currency={currency}
                kind="gasto"
                serif
                className="text-2xl sm:text-3xl"
              />
              <span className="text-text-dim pb-1 text-xs">
                {active.length}{" "}
                {active.length === 1
                  ? t("debts.countOne")
                  : t("debts.countOther")}
              </span>
            </div>
            {totals.monthlyCommitment > 0 && (
              <p className="text-text-muted mt-2 text-sm">
                {t("debts.totalMonthly")}:{" "}
                <span className="text-foreground font-medium">
                  {formatMoney(totals.monthlyCommitment, currency)}
                </span>
              </p>
            )}
            {totals.hasUnconverted && (
              <p className="text-text-dim mt-2 text-xs">
                {t("debts.mixedCurrencies", { currency })}
              </p>
            )}
          </Card>

          {/* Tabs + grilla de deudas */}
          <section>
            <SectionHeader title={t("debts.yourDebts")} />
            <Tabs value={tab} onValueChange={(v) => setTab(v as DebtTab)}>
              <TabsList>
                <TabsTrigger value="active">
                  {t("debts.tabActive", { n: active.length })}
                </TabsTrigger>
                <TabsTrigger value="settled">
                  {t("debts.tabSettled", { n: settled.length })}
                </TabsTrigger>
                <TabsTrigger value="all">
                  {t("debts.tabAll", { n: debts.length })}
                </TabsTrigger>
              </TabsList>

              <TabsContent value={tab}>
                {visible.length === 0 ? (
                  <EmptyState
                    icon={Landmark}
                    title={
                      tab === "settled"
                        ? t("debts.emptySettledTitle")
                        : t("debts.emptyActiveTitle")
                    }
                    description={
                      tab === "settled"
                        ? t("debts.emptySettledDescription")
                        : undefined
                    }
                  />
                ) : (
                  <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-3">
                    {visible.map((debt) => (
                      <DebtCard
                        key={debt.id}
                        debt={debt}
                        baseCurrency={currency}
                        onEdit={() => setDialog({ mode: "edit", debt })}
                        onSettle={() =>
                          setDestructive({ kind: "settle", debt })
                        }
                        onDelete={() =>
                          setDestructive({ kind: "delete", debt })
                        }
                      />
                    ))}
                  </div>
                )}
              </TabsContent>
            </Tabs>
          </section>
        </>
      )}

      {/* Diálogo alta/edición (montado por estado para resetear el form) */}
      {dialog.mode !== "closed" && (
        <DebtDialog
          open
          onOpenChange={(o) => !o && setDialog({ mode: "closed" })}
          debt={dialog.mode === "edit" ? dialog.debt : undefined}
          defaultCurrency={currency}
        />
      )}

      {/* Diálogo destructivo (saldar / eliminar) */}
      {destructive.kind !== "none" && (
        <DebtDestructiveDialog
          open
          onOpenChange={(o) => !o && setDestructive({ kind: "none" })}
          kind={destructive.kind}
          debtId={destructive.debt.id}
          creditor={destructive.debt.creditor}
        />
      )}
    </div>
  );
}
