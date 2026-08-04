"use client";

import { useMemo, useOptimistic, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Plus,
  CalendarClock,
  MoreVertical,
  Pencil,
  Trash2,
  Check,
  RotateCcw,
  AlertTriangle,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
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
import { formatDayMonth, todayLocal } from "@/lib/i18n/dates";
import { BillDialog } from "@/components/bills/bill-dialog";
import { DeleteBillDialog } from "@/components/bills/delete-bill-dialog";
import { setBillStatusAction } from "@/lib/actions/bills";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import type { Bill } from "@/lib/db/bills";

export interface BillsViewProps {
  bills: Bill[];
  /** Categorías de gasto del hogar (para el alta). */
  categories: string[];
  currency: string;
}

type DialogState =
  | { mode: "closed" }
  | { mode: "create" }
  | { mode: "edit"; bill: Bill };

/**
 * Días hasta el vencimiento (en días-calendario UTC, sobre la fecha-sólo).
 * Espeja iOS `Bill.daysUntilDue` (diferencia de días entre hoy y due_date,
 * ambos al inicio del día). <0 = vencido, 0 = hoy.
 */
function daysUntilDue(dueDate: string): number {
  // "Hoy" tiene que ser el día del calendario DEL USUARIO. Con
  // `new Date().toISOString()` se tomaba el día UTC, y en Argentina a partir de
  // las 21 h eso ya es mañana: a esa hora un vencimiento de mañana pasaba a
  // contarse como "hoy" y uno de hoy como vencido. La resta sigue siendo
  // UTC contra UTC, que es lo correcto para contar días-calendario.
  const hoy = todayLocal();
  const [dy, dm, dd] = dueDate.split("-").map(Number);
  const today = Date.UTC(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
  const due = Date.UTC(dy, (dm ?? 1) - 1, dd ?? 1);
  return Math.round((due - today) / 86_400_000);
}

/**
 * Pantalla de Vencimientos. Agrupa en vencidos / próximos / pagados, y permite
 * marcar pagado/pendiente, editar y eliminar. "Marcar pagado" solo cambia el
 * estado (paridad iOS: no crea movimiento).
 */
export function BillsView({ bills, categories, currency }: BillsViewProps) {
  const t = useT();
  const [dialog, setDialog] = useState<DialogState>({ mode: "closed" });
  const [toDelete, setToDelete] = useState<Bill | null>(null);

  // Estado optimista del cambio pagado/pendiente. Lo tenemos ACÁ y no en la
  // card para que el vencimiento salte de sección (próximos → pagados) al
  // instante, no sólo cambie de badge. Si la server action falla, React
  // descarta el optimismo al cerrar la transición y vuelve a su sección.
  const [optimisticBills, applyStatus] = useOptimistic(
    bills,
    (state: Bill[], patch: { id: string; status: "paid" | "pending" }) =>
      state.map((b) => (b.id === patch.id ? { ...b, status: patch.status } : b)),
  );

  const { overdue, upcoming, paid } = useMemo(() => {
    const overdue: Bill[] = [];
    const upcoming: Bill[] = [];
    const paid: Bill[] = [];
    for (const b of optimisticBills) {
      if (b.status === "paid") paid.push(b);
      else if (daysUntilDue(b.due_date) < 0) overdue.push(b);
      else upcoming.push(b);
    }
    return { overdue, upcoming, paid };
  }, [optimisticBills]);

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("bills.title")}
        description={t("bills.headerDescription")}
        action={
          <Button onClick={() => setDialog({ mode: "create" })}>
            <Plus />
            {t("bills.new")}
          </Button>
        }
      />

      {optimisticBills.length === 0 ? (
        <EmptyState
          icon={CalendarClock}
          title={t("bills.emptyTitle")}
          description={t("bills.emptyDescription")}
          action={
            <Button onClick={() => setDialog({ mode: "create" })}>
              <Plus />
              {t("bills.emptyAction")}
            </Button>
          }
        />
      ) : (
        <div className="space-y-6">
          {overdue.length > 0 && (
            <BillSection
              title={t("bills.overdueSection")}
              bills={overdue}
              currency={currency}
              onEdit={(bill) => setDialog({ mode: "edit", bill })}
              onDelete={setToDelete}
              onOptimisticStatus={applyStatus}
            />
          )}
          {upcoming.length > 0 && (
            <BillSection
              title={t("bills.upcomingSection")}
              bills={upcoming}
              currency={currency}
              onEdit={(bill) => setDialog({ mode: "edit", bill })}
              onDelete={setToDelete}
              onOptimisticStatus={applyStatus}
            />
          )}
          {paid.length > 0 && (
            <BillSection
              title={t("bills.paidSection")}
              bills={paid}
              currency={currency}
              onEdit={(bill) => setDialog({ mode: "edit", bill })}
              onDelete={setToDelete}
              onOptimisticStatus={applyStatus}
            />
          )}
        </div>
      )}

      {dialog.mode !== "closed" && (
        <BillDialog
          open
          onOpenChange={(o) => !o && setDialog({ mode: "closed" })}
          bill={dialog.mode === "edit" ? dialog.bill : undefined}
          categories={categories}
          currency={currency}
        />
      )}

      {toDelete && (
        <DeleteBillDialog
          open
          onOpenChange={(o) => !o && setToDelete(null)}
          id={toDelete.id}
          title={toDelete.title}
        />
      )}
    </div>
  );
}

/** Sección con encabezado + grilla de cards de vencimientos. */
function BillSection({
  title,
  bills,
  currency,
  onEdit,
  onDelete,
  onOptimisticStatus,
}: {
  title: string;
  bills: Bill[];
  currency: string;
  onEdit: (bill: Bill) => void;
  onDelete: (bill: Bill) => void;
  onOptimisticStatus: (patch: { id: string; status: "paid" | "pending" }) => void;
}) {
  return (
    <section>
      <SectionHeader title={title} />
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-3">
        {bills.map((bill) => (
          <BillCard
            key={bill.id}
            bill={bill}
            currency={currency}
            onEdit={() => onEdit(bill)}
            onDelete={() => onDelete(bill)}
            onOptimisticStatus={onOptimisticStatus}
          />
        ))}
      </div>
    </section>
  );
}

/** Card individual de vencimiento con monto, fecha relativa, estado y acciones. */
function BillCard({
  bill,
  currency,
  onEdit,
  onDelete,
  onOptimisticStatus,
}: {
  bill: Bill;
  currency: string;
  onEdit: () => void;
  onDelete: () => void;
  onOptimisticStatus: (patch: { id: string; status: "paid" | "pending" }) => void;
}) {
  const t = useT();
  const locale = useLocale();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  const isPaid = bill.status === "paid";
  const days = daysUntilDue(bill.due_date);
  const isOverdue = !isPaid && days < 0;

  // Etiqueta relativa de la fecha (espeja la semántica de iOS UrgencyLevel).
  let dueText: string;
  if (isPaid) {
    dueText = formatDayMonth(bill.due_date, locale);
  } else if (days < 0) {
    dueText = t("bills.overdueByLabel", { days: Math.abs(days) });
  } else if (days === 0) {
    dueText = t("bills.dueTodayLabel");
  } else if (days <= 14) {
    dueText = t("bills.dueInLabel", { days });
  } else {
    dueText = t("bills.dueLabel", { date: formatDayMonth(bill.due_date, locale) });
  }

  function changeStatus(status: "paid" | "pending") {
    startTransition(async () => {
      // El dispatch optimista vive en BillsView pero se despacha desde acá,
      // dentro de esta transición: la card cambia de sección al instante.
      onOptimisticStatus({ id: bill.id, status });
      try {
        await setBillStatusAction(bill.id, status);
        toast.success(
          status === "paid" ? t("bills.markedPaid") : t("bills.markedPending"),
        );
        router.refresh();
      } catch (err) {
        // React revierte el estado optimista al cerrar la transición.
        toast.error(t("bills.statusError"), {
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
              (isPaid
                ? "bg-income/12 text-income"
                : isOverdue
                  ? "bg-expense/12 text-expense"
                  : "bg-primary/10 text-primary")
            }
          >
            {isOverdue ? (
              <AlertTriangle className="size-5" />
            ) : (
              <CalendarClock className="size-5" />
            )}
          </span>
          <div className="min-w-0">
            <p className="truncate font-semibold leading-tight">{bill.title}</p>
            {bill.category?.trim() && (
              <p className="text-text-muted truncate text-xs">{bill.category}</p>
            )}
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="text-text-muted -mr-2 -mt-1 size-10 min-h-11 min-w-11 shrink-0"
              aria-label={t("bills.cardActions", { title: bill.title })}
            >
              <MoreVertical className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            {isPaid ? (
              <DropdownMenuItem onSelect={() => changeStatus("pending")}>
                <RotateCcw />
                {t("bills.markPending")}
              </DropdownMenuItem>
            ) : (
              <DropdownMenuItem onSelect={() => changeStatus("paid")}>
                <Check />
                {t("bills.markPaid")}
              </DropdownMenuItem>
            )}
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

      <div className="mt-auto flex items-end justify-between gap-2">
        <div className="min-w-0">
          <Amount
            value={Number(bill.amount)}
            currency={bill.currency || currency}
            kind="neutral"
            className="text-lg font-semibold"
          />
          <p
            className={
              "mt-0.5 truncate text-xs " +
              (isOverdue ? "text-expense" : "text-text-muted")
            }
          >
            {dueText}
          </p>
        </div>
        <Badge
          variant={isPaid ? "income" : isOverdue ? "expense" : "neutral"}
          className="shrink-0"
        >
          {t(`bills.status.${bill.status}`)}
        </Badge>
      </div>

      {!isPaid && (
        <Button
          variant="secondary"
          size="sm"
          onClick={() => changeStatus("paid")}
          disabled={pending}
          className="w-full"
        >
          <Check className="size-4" />
          {t("bills.markPaid")}
        </Button>
      )}
    </Card>
  );
}
