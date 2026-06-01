"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { settleDebt, deleteDebt } from "@/lib/actions/debts";
import { useT } from "@/components/i18n/locale-provider";

interface DebtDestructiveDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** "settle" marca saldada (status='settled', saldo 0); "delete" borra. */
  kind: "settle" | "delete";
  debtId: string;
  creditor: string;
}

/**
 * Confirmación destructiva de una deuda. Dos modos:
 *  - settle: paridad iOS `DebtService.settle` (status='settled', balance 0).
 *  - delete: paridad iOS `DebtService.delete` (borrado definitivo).
 */
export function DebtDestructiveDialog({
  open,
  onOpenChange,
  kind,
  debtId,
  creditor,
}: DebtDestructiveDialogProps) {
  const router = useRouter();
  const t = useT();
  const [pending, startTransition] = useTransition();

  const isSettle = kind === "settle";

  function onConfirm() {
    startTransition(async () => {
      try {
        if (isSettle) {
          await settleDebt(debtId);
          toast.success(t("debts.settled"));
        } else {
          await deleteDebt(debtId);
          toast.success(t("debts.deleted"));
        }
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(t(isSettle ? "debts.settleError" : "debts.deleteError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>
            {isSettle ? t("debts.settleTitle") : t("debts.deleteTitle")}
          </DialogTitle>
          <DialogDescription>
            {isSettle
              ? t("debts.settleDescriptionPrefix")
              : t("debts.deleteDescriptionPrefix")}
            <span className="text-foreground font-medium">{creditor}</span>
            {isSettle
              ? t("debts.settleDescriptionSuffix")
              : t("debts.deleteDescriptionSuffix")}
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
            variant={isSettle ? "default" : "destructive"}
            onClick={onConfirm}
            disabled={pending}
          >
            {pending && <Loader2 className="animate-spin" />}
            {isSettle ? t("debts.settle") : t("debts.delete")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
