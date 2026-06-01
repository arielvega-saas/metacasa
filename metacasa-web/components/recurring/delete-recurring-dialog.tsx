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
import { deleteRecurringAction } from "@/lib/actions/recurring";
import { useT } from "@/components/i18n/locale-provider";

interface DeleteRecurringDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  id: string;
  /** Etiqueta visible (categoría) del recurrente a eliminar. */
  label: string;
}

/** Confirmación de borrado de un recurrente. No afecta movimientos históricos. */
export function DeleteRecurringDialog({
  open,
  onOpenChange,
  id,
  label,
}: DeleteRecurringDialogProps) {
  const router = useRouter();
  const t = useT();
  const [pending, startTransition] = useTransition();

  function onConfirm() {
    startTransition(async () => {
      try {
        await deleteRecurringAction(id);
        toast.success(t("recurring.deleted"));
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(t("recurring.deleteError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t("recurring.deleteTitle")}</DialogTitle>
          <DialogDescription>
            {t("recurring.deleteDescriptionPrefix")}
            <span className="text-foreground font-medium">{label}</span>
            {t("recurring.deleteDescriptionSuffix")}
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
            {t("recurring.delete")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
