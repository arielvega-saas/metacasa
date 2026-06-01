"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Plus,
  Repeat,
  MoreVertical,
  Pencil,
  Trash2,
  ArrowDownLeft,
  ArrowUpRight,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
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
import { formatDayMonth } from "@/lib/i18n/dates";
import { TX_TYPE } from "@/lib/constants";
import { RecurringDialog } from "@/components/recurring/recurring-dialog";
import { DeleteRecurringDialog } from "@/components/recurring/delete-recurring-dialog";
import { RunDueButton } from "@/components/recurring/run-due-button";
import { setRecurringActiveAction } from "@/lib/actions/recurring";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import type { RecurringTransaction, Frequency } from "@/lib/db/recurring";

type AccountOption = { id: string; name: string };

export interface RecurringViewProps {
  recurring: RecurringTransaction[];
  accounts: AccountOption[];
  categories: { gastos: string[]; ingresos: string[] };
  currency: string;
}

type DialogState =
  | { mode: "closed" }
  | { mode: "create" }
  | { mode: "edit"; item: RecurringTransaction };

/**
 * Pantalla de Recurrentes. Agrupa en activos / pausados, muestra frecuencia y
 * próxima fecha, y permite activar/pausar con un switch. El alta/edición y el
 * borrado van por diálogos.
 */
export function RecurringView({
  recurring,
  accounts,
  categories,
  currency,
}: RecurringViewProps) {
  const t = useT();
  const [dialog, setDialog] = useState<DialogState>({ mode: "closed" });
  const [toDelete, setToDelete] = useState<RecurringTransaction | null>(null);

  const { active, paused } = useMemo(() => {
    const active: RecurringTransaction[] = [];
    const paused: RecurringTransaction[] = [];
    for (const r of recurring) (r.active ? active : paused).push(r);
    return { active, paused };
  }, [recurring]);

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("recurring.title")}
        description={t("recurring.headerDescription")}
        action={
          <div className="flex flex-wrap items-center gap-2">
            <RunDueButton />
            <Button onClick={() => setDialog({ mode: "create" })}>
              <Plus />
              {t("recurring.new")}
            </Button>
          </div>
        }
      />

      {recurring.length === 0 ? (
        <EmptyState
          icon={Repeat}
          title={t("recurring.emptyTitle")}
          description={t("recurring.emptyDescription")}
          action={
            <Button onClick={() => setDialog({ mode: "create" })}>
              <Plus />
              {t("recurring.emptyAction")}
            </Button>
          }
        />
      ) : (
        <div className="space-y-6">
          {active.length > 0 && (
            <section>
              <SectionHeader title={t("recurring.activeSection")} />
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-3">
                {active.map((item) => (
                  <RecurringCard
                    key={item.id}
                    item={item}
                    currency={currency}
                    onEdit={() => setDialog({ mode: "edit", item })}
                    onDelete={() => setToDelete(item)}
                  />
                ))}
              </div>
            </section>
          )}

          {paused.length > 0 && (
            <section>
              <SectionHeader title={t("recurring.pausedSection")} />
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-3">
                {paused.map((item) => (
                  <RecurringCard
                    key={item.id}
                    item={item}
                    currency={currency}
                    onEdit={() => setDialog({ mode: "edit", item })}
                    onDelete={() => setToDelete(item)}
                  />
                ))}
              </div>
            </section>
          )}
        </div>
      )}

      {dialog.mode !== "closed" && (
        <RecurringDialog
          open
          onOpenChange={(o) => !o && setDialog({ mode: "closed" })}
          recurring={dialog.mode === "edit" ? dialog.item : undefined}
          accounts={accounts}
          categories={categories}
          currency={currency}
        />
      )}

      {toDelete && (
        <DeleteRecurringDialog
          open
          onOpenChange={(o) => !o && setToDelete(null)}
          id={toDelete.id}
          label={toDelete.category}
        />
      )}
    </div>
  );
}

/** Card individual de recurrente con tipo, monto, frecuencia, próxima fecha y toggle. */
function RecurringCard({
  item,
  currency,
  onEdit,
  onDelete,
}: {
  item: RecurringTransaction;
  currency: string;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const t = useT();
  const locale = useLocale();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  const isIncome = item.type === TX_TYPE.INCOME;
  const Icon = isIncome ? ArrowDownLeft : ArrowUpRight;

  function onToggle(next: boolean) {
    startTransition(async () => {
      try {
        await setRecurringActiveAction(item.id, next);
        toast.success(next ? t("recurring.activated") : t("recurring.paused"));
        router.refresh();
      } catch (err) {
        toast.error(t("recurring.toggleError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Card className="flex flex-col gap-3 p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <span
            className={
              "flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)] " +
              (isIncome ? "bg-income/12 text-income" : "bg-expense/12 text-expense")
            }
          >
            <Icon className="size-5" />
          </span>
          <div className="min-w-0">
            <p className="truncate font-semibold leading-tight">
              {item.category}
            </p>
            <p className="text-text-muted truncate text-xs">
              {t(`recurring.freq.${item.frequency as Frequency}`)}
              {item.account ? ` · ${item.account}` : ""}
            </p>
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="text-text-muted -mr-2 -mt-1 size-10 min-h-11 min-w-11 shrink-0"
              aria-label={t("recurring.cardActions", { name: item.category })}
            >
              <MoreVertical className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            <DropdownMenuItem onSelect={onEdit}>
              <Pencil />
              {t("common.edit")}
            </DropdownMenuItem>
            <DropdownMenuItem destructive onSelect={onDelete}>
              <Trash2 />
              {t("common.delete")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <div className="flex items-end justify-between gap-2">
        <Amount
          value={Number(item.amount)}
          currency={currency}
          kind={isIncome ? "ingreso" : "gasto"}
          className="text-lg font-semibold"
        />
        <Badge variant={isIncome ? "income" : "neutral"} className="shrink-0">
          {isIncome ? t("recurring.incomeToggle") : t("recurring.expenseToggle")}
        </Badge>
      </div>

      <div className="mt-auto flex items-center justify-between gap-2 border-t border-border pt-3">
        <div className="min-w-0">
          <p className="text-text-dim text-[11px] uppercase tracking-wider">
            {t("recurring.nextLabel")}
          </p>
          <p className="truncate text-sm font-medium">
            {item.next_date
              ? formatDayMonth(item.next_date, locale)
              : t("recurring.noNext")}
          </p>
          {item.end_date && (
            <p className="text-text-dim mt-0.5 text-[11px]">
              {t("recurring.endsLabel", {
                date: formatDayMonth(item.end_date, locale),
              })}
            </p>
          )}
        </div>
        <label className="flex shrink-0 items-center gap-2">
          <span className="text-text-muted text-xs">
            {t("recurring.activeToggle")}
          </span>
          <Switch
            checked={Boolean(item.active)}
            onCheckedChange={onToggle}
            disabled={pending}
            aria-label={t("recurring.activeToggle")}
          />
        </label>
      </div>
    </Card>
  );
}
