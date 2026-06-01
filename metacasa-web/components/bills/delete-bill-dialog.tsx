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
import { deleteBillAction } from "@/lib/actions/bills";
import { useT } from "@/components/i18n/locale-provider";

interface DeleteBillDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  id: string;
  /** Título visible del vencimiento a eliminar. */
  title: string;
}

/** Confirmación de borrado de un vencimiento. */
export function DeleteBillDialog({
  open,
  onOpenChange,
  id,
  title,
}: DeleteBillDialogProps) {
  const router = useRouter();
  const t = useT();
  const [pending, startTransition] = useTransition();

  function onConfirm() {
    startTransition(async () => {
      try {
        await deleteBillAction(id);
        toast.success(t("bills.deleted"));
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(t("bills.deleteError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t("bills.deleteTitle")}</DialogTitle>
          <DialogDescription>
            {t("bills.deleteDescriptionPrefix")}
            <span className="text-foreground font-medium">{title}</span>
            {t("bills.deleteDescriptionSuffix")}
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
            {t("bills.delete")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
