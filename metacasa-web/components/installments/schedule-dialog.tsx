"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Check, Loader2, Circle } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  markInstallmentPaid,
  unmarkInstallmentPaid,
} from "@/lib/actions/installments";
import { formatMoney } from "@/lib/money";
import { formatMonthYear, intlLocale } from "@/lib/i18n/dates";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import type { InstallmentPayment } from "@/lib/db/installments";

interface ScheduleDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  planName: string;
  currency: string;
  payments: InstallmentPayment[];
}

/**
 * Cronograma de cuotas de un plan: lista cada cuota con su período y monto, y
 * permite marcar/desmarcar el pago. Espeja `InstallmentDetailView` (iOS):
 * marcar SOLO actualiza `paid`/`paid_at`, no crea ningún movimiento.
 */
export function ScheduleDialog({
  open,
  onOpenChange,
  planName,
  currency,
  payments,
}: ScheduleDialogProps) {
  const t = useT();
  const locale = useLocale();
  const router = useRouter();
  // Qué fila está mutando (para el spinner por-fila).
  const [pendingId, setPendingId] = React.useState<string | null>(null);
  const [isPending, startTransition] = React.useTransition();

  function toggle(p: InstallmentPayment) {
    setPendingId(p.id);
    startTransition(async () => {
      try {
        if (p.paid) await unmarkInstallmentPaid(p.id);
        else await markInstallmentPaid(p.id);
        toast.success(t("installments.paymentUpdated"));
        router.refresh();
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("installments.paymentError"),
        );
      } finally {
        setPendingId(null);
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {t("installments.scheduleTitle", { name: planName })}
          </DialogTitle>
          <DialogDescription>
            {t("installments.scheduleSubtitle")}
          </DialogDescription>
        </DialogHeader>

        <ul className="divide-y divide-border">
          {payments.map((p) => {
            const busy = isPending && pendingId === p.id;
            const paidDate = p.paid_at
              ? new Date(p.paid_at).toLocaleDateString(intlLocale(locale), {
                  day: "numeric",
                  month: "short",
                  year: "numeric",
                })
              : null;
            return (
              <li key={p.id} className="flex items-center gap-3 py-3">
                <button
                  type="button"
                  onClick={() => toggle(p)}
                  disabled={busy}
                  aria-pressed={Boolean(p.paid)}
                  aria-label={
                    p.paid ? t("installments.markUnpaid") : t("installments.markPaid")
                  }
                  className={`flex size-11 min-h-11 min-w-11 shrink-0 items-center justify-center rounded-full border transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/40 disabled:opacity-50 ${
                    p.paid
                      ? "border-income/40 bg-income/15 text-income"
                      : "border-border text-text-muted hover:bg-white/[0.05]"
                  }`}
                >
                  {busy ? (
                    <Loader2 className="size-4 animate-spin" />
                  ) : p.paid ? (
                    <Check className="size-4" />
                  ) : (
                    <Circle className="size-4" />
                  )}
                </button>

                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">
                    {t("installments.installmentLabel", {
                      number: p.installment_number,
                    })}
                  </p>
                  <p className="text-text-muted text-xs">
                    {formatMonthYear(p.period_year, p.period_month, locale)}
                    {paidDate
                      ? ` · ${t("installments.paidOn", { date: paidDate })}`
                      : ` · ${t("installments.pending")}`}
                  </p>
                </div>

                <span className="tnum text-foreground shrink-0 text-sm font-semibold">
                  {formatMoney(Number(p.amount), currency)}
                </span>
              </li>
            );
          })}
        </ul>
      </DialogContent>
    </Dialog>
  );
}
