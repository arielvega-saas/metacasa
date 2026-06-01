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
import { archiveAccount } from "@/lib/actions/accounts";
import { useT } from "@/components/i18n/locale-provider";

interface ArchiveAccountDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  accountId: string;
  accountName: string;
}

/**
 * Confirmación de archivado (soft-delete). No borramos: la cuenta deja de
 * mostrarse pero su historial de movimientos se conserva.
 */
export function ArchiveAccountDialog({
  open,
  onOpenChange,
  accountId,
  accountName,
}: ArchiveAccountDialogProps) {
  const router = useRouter();
  const t = useT();
  const [pending, startTransition] = useTransition();

  function onConfirm() {
    startTransition(async () => {
      try {
        await archiveAccount(accountId);
        toast.success(t("accounts.archived"));
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(t("accounts.archiveError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{t("accounts.archiveTitle")}</DialogTitle>
          <DialogDescription>
            {t("accounts.archiveDescriptionPrefix")}
            <span className="text-foreground font-medium">{accountName}</span>
            {t("accounts.archiveDescriptionSuffix")}
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
            {t("accounts.archive")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
