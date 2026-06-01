"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Plus,
  CreditCard,
  MoreVertical,
  ListChecks,
  Trash2,
  Loader2,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { EmptyState } from "@/components/ui/empty-state";
import { Amount } from "@/components/finance/amount";
import { SectionHeader } from "@/components/finance/section-header";
import { PageHeader } from "@/components/layout/page-header";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { PlanDialog } from "@/components/installments/plan-dialog";
import { ScheduleDialog } from "@/components/installments/schedule-dialog";
import { deletePlan } from "@/lib/actions/installments";
import { formatMoney } from "@/lib/money";
import { formatMonthYear } from "@/lib/i18n/dates";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import type { PlanWithProgress, InstallmentPayment } from "@/lib/db/installments";

interface InstallmentsViewProps {
  plans: PlanWithProgress[];
  /** Cronograma por plan (plan.id → pagos), para el diálogo de cuotas. */
  schedules: Record<string, InstallmentPayment[]>;
  /** Cuentas activas del hogar (id + nombre) para el selector del alta. */
  accounts: { id: string; name: string }[];
  /** Moneda base del hogar (default del alta + total consolidado). */
  currency: string;
}

/**
 * Pantalla de Cuotas. Server component pasa planes con progreso; acá manejamos
 * el alta, el cronograma de pagos y el borrado, con presentación premium.
 */
export function InstallmentsView({
  plans,
  schedules,
  accounts,
  currency,
}: InstallmentsViewProps) {
  const t = useT();
  const [scheduleFor, setScheduleFor] = React.useState<PlanWithProgress | null>(
    null,
  );
  const [toDelete, setToDelete] = React.useState<PlanWithProgress | null>(null);

  const activePlans = plans.filter((p) => p.status === "active");
  // Total financiado y restante consolidados (moneda base, aproximado si hay mix).
  const totalFinanced = plans.reduce((s, p) => s + Number(p.total_amount), 0);
  const remainingTotal = plans.reduce((s, p) => s + p.remainingAmount, 0);
  const mixedCurrencies = new Set(plans.map((p) => p.currency)).size > 1;

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("installments.title")}
        description={t("installments.headerDescription")}
        action={<PlanDialog defaultCurrency={currency} accounts={accounts} />}
      />

      {plans.length === 0 ? (
        <EmptyState
          icon={CreditCard}
          title={t("installments.emptyTitle")}
          description={t("installments.emptyDescription")}
          action={
            <PlanDialog
              defaultCurrency={currency}
              accounts={accounts}
              trigger={
                <Button>
                  <Plus />
                  {t("installments.emptyAction")}
                </Button>
              }
            />
          }
        />
      ) : (
        <>
          {/* Resumen consolidado */}
          <Card className="sage-glow p-5 sm:p-6">
            <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3">
              <div>
                <p className="text-text-muted text-sm">
                  {t("installments.totalFinanced")}
                </p>
                <Amount
                  value={totalFinanced}
                  currency={currency}
                  kind="neutral"
                  serif
                  className="text-3xl sm:text-4xl"
                />
              </div>
              <div className="text-right">
                <p className="text-text-muted text-sm">
                  {t("installments.remainingTotal")}
                </p>
                <Amount
                  value={remainingTotal}
                  currency={currency}
                  kind="balance"
                  className="text-xl font-semibold"
                />
              </div>
            </div>
            <p className="text-text-dim mt-2 text-xs">
              {t(
                activePlans.length === 1
                  ? "installments.activePlansOne"
                  : "installments.activePlansOther",
                { count: activePlans.length },
              )}
            </p>
            {mixedCurrencies && (
              <p className="text-text-dim mt-1 text-xs">
                {t("installments.mixedCurrencies", { currency })}
              </p>
            )}
          </Card>

          {/* Grilla de planes */}
          <section>
            <SectionHeader title={t("installments.yourPlans")} />
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-3">
              {plans.map((plan) => (
                <PlanCard
                  key={plan.id}
                  plan={plan}
                  onViewSchedule={() => setScheduleFor(plan)}
                  onDelete={() => setToDelete(plan)}
                />
              ))}
            </div>
          </section>
        </>
      )}

      {/* Diálogo de cronograma de pagos */}
      {scheduleFor && (
        <ScheduleDialog
          open
          onOpenChange={(o) => !o && setScheduleFor(null)}
          planName={scheduleFor.name}
          currency={scheduleFor.currency}
          payments={schedules[scheduleFor.id] ?? []}
        />
      )}

      {/* Confirmación de borrado */}
      {toDelete && (
        <DeletePlanDialog
          open
          onOpenChange={(o) => !o && setToDelete(null)}
          planId={toDelete.id}
          planName={toDelete.name}
        />
      )}
    </div>
  );
}

/** Card individual de plan con progreso de cuotas, próxima cuota y acciones. */
function PlanCard({
  plan,
  onViewSchedule,
  onDelete,
}: {
  plan: PlanWithProgress;
  onViewSchedule: () => void;
  onDelete: () => void;
}) {
  const t = useT();
  const locale = useLocale();
  const done = plan.paidCount >= plan.total_installments;

  return (
    <Card className={`flex flex-col gap-3 p-5 ${done ? "border-primary/25 sage-glow" : ""}`}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <span className="bg-primary/10 text-primary flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)]">
            <CreditCard className="size-5" />
          </span>
          <div className="min-w-0">
            <p className="truncate font-semibold leading-tight">{plan.name}</p>
            <p className="text-text-muted truncate text-xs">
              {plan.category
                ? `${plan.category} · ${t("installments.monthlyAmount", {
                    amount: formatMoney(plan.monthlyAmount, plan.currency),
                  })}`
                : t("installments.monthlyAmount", {
                    amount: formatMoney(plan.monthlyAmount, plan.currency),
                  })}
            </p>
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="text-text-muted -mr-2 -mt-1 size-10 min-h-11 min-w-11 shrink-0"
              aria-label={t("installments.planActions", { name: plan.name })}
            >
              <MoreVertical className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            <DropdownMenuItem onSelect={onViewSchedule}>
              <ListChecks />
              {t("installments.viewSchedule")}
            </DropdownMenuItem>
            <DropdownMenuItem destructive onSelect={onDelete}>
              <Trash2 />
              {t("installments.delete")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Total + restante */}
      <div className="flex items-end justify-between gap-2">
        <Amount
          value={Number(plan.total_amount)}
          currency={plan.currency}
          kind="neutral"
          serif
          className="text-xl"
        />
        <Badge variant="outline" className="shrink-0">
          {plan.currency}
        </Badge>
      </div>

      {/* Progreso de cuotas */}
      <div className="space-y-1.5">
        <Progress
          value={plan.progressPct}
          indicatorClassName={done ? "bg-income" : "bg-primary"}
          aria-label={t("installments.progressAria", {
            pct: plan.progressPct,
            name: plan.name,
          })}
        />
        <div className="flex items-center justify-between gap-2">
          <span className="text-text-muted text-xs">
            {t("installments.progressLabel", {
              paid: plan.paidCount,
              total: plan.total_installments,
            })}
          </span>
          <span className="text-foreground tnum text-xs font-semibold">
            {plan.progressPct}%
          </span>
        </div>
      </div>

      {/* Próxima cuota / saldado */}
      <div className="mt-auto">
        {done ? (
          <Badge variant="income" className="gap-1">
            {t("installments.allPaid")}
          </Badge>
        ) : plan.nextDue ? (
          <p className="text-text-muted text-xs">
            {t("installments.nextDue", {
              period: formatMonthYear(
                plan.nextDue.year,
                plan.nextDue.month,
                locale,
              ),
            })}
          </p>
        ) : null}
      </div>
    </Card>
  );
}

/** Confirmación de borrado de un plan (y su ledger por cascada). */
function DeletePlanDialog({
  open,
  onOpenChange,
  planId,
  planName,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  planId: string;
  planName: string;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = React.useTransition();

  function onConfirm() {
    startTransition(async () => {
      try {
        await deletePlan(planId);
        toast.success(t("installments.deleted"));
        // Refrescar ANTES de cerrar: el padre monta este diálogo de forma
        // condicional ({toDelete && ...}); cerrar lo desmonta y abortaría el
        // refresh si fuera después. Con este orden la grilla se actualiza sola.
        router.refresh();
        onOpenChange(false);
      } catch (err) {
        toast.error(t("installments.deleteError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t("installments.deleteConfirmTitle")}</DialogTitle>
          <DialogDescription>
            {t("installments.deleteConfirmBody", { name: planName })}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter className="pt-2">
          <DialogClose asChild>
            <Button type="button" variant="ghost" disabled={pending}>
              {t("common.cancel")}
            </Button>
          </DialogClose>
          <Button
            type="button"
            variant="destructive"
            onClick={onConfirm}
            disabled={pending}
          >
            {pending && <Loader2 className="animate-spin" />}
            {t("installments.delete")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
