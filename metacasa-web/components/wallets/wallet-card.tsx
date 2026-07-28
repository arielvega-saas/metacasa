"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Loader2,
  MoreVertical,
  RefreshCw,
  Unplug,
  WalletCards,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Amount } from "@/components/finance/amount";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu";
import { useT } from "@/components/i18n/locale-provider";
import { syncWallet, disconnectWallet } from "@/lib/actions/wallets";
import { WalletMovements } from "@/components/wallets/wallet-movements";
import type { WalletBlockData } from "@/components/wallets/types";

/**
 * Card de una wallet conectada: estado, sincronización, desconexión y la
 * bandeja de movimientos pendientes de importar.
 */
export function WalletCard({ wallet }: { wallet: WalletBlockData }) {
  const t = useT();
  const router = useRouter();
  const [syncing, startSync] = React.useTransition();
  const [confirmOpen, setConfirmOpen] = React.useState(false);

  const pendingCount = wallet.pending.length;

  function onSync() {
    startSync(async () => {
      try {
        const { created } = await syncWallet(wallet.id);
        toast.success(
          created === 0
            ? t("wallets.toast.syncedNone")
            : created === 1
              ? t("wallets.toast.syncedOne")
              : t("wallets.toast.syncedOther", { count: created }),
        );
        router.refresh();
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("wallets.errors.syncFailed"),
        );
      }
    });
  }

  return (
    <Card className="overflow-hidden">
      <div className="flex flex-wrap items-start justify-between gap-3 p-5">
        <div className="flex min-w-0 items-center gap-3">
          <span className="bg-primary/10 text-primary flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)]">
            <WalletCards className="size-5" />
          </span>
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <p className="truncate font-semibold leading-tight">
                {wallet.name}
              </p>
              <Badge variant="default">{t("wallets.card.connected")}</Badge>
              {wallet.sandbox && (
                <Badge variant="warning">{t("wallets.card.sandbox")}</Badge>
              )}
            </div>
            <p className="text-text-muted mt-0.5 truncate text-xs">
              {wallet.lastSyncLabel
                ? t("wallets.card.lastSync", { when: wallet.lastSyncLabel })
                : t("wallets.card.neverSynced")}
              {" · "}
              {pendingCount === 0
                ? t("wallets.card.allImported")
                : pendingCount === 1
                  ? t("wallets.card.pendingOne")
                  : t("wallets.card.pendingOther", { count: pendingCount })}
            </p>
          </div>
        </div>

        <div className="flex shrink-0 items-center gap-2">
          {wallet.balance != null && (
            <Amount
              value={wallet.balance}
              currency={wallet.currency}
              kind="balance"
              className="mr-1 text-base font-semibold"
            />
          )}
          <Button
            variant="secondary"
            size="sm"
            onClick={onSync}
            disabled={syncing}
          >
            {syncing ? (
              <Loader2 className="animate-spin" />
            ) : (
              <RefreshCw />
            )}
            {syncing ? t("wallets.card.syncing") : t("wallets.card.sync")}
          </Button>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="text-text-muted size-10 min-h-11 min-w-11"
                aria-label={t("wallets.card.actions", { name: wallet.name })}
              >
                <MoreVertical className="size-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent>
              <DropdownMenuItem
                destructive
                onSelect={() => setConfirmOpen(true)}
              >
                <Unplug />
                {t("wallets.card.disconnect")}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      <div className="border-t border-border p-5">
        <WalletMovements
          walletId={wallet.id}
          movements={wallet.pending}
          fallbackCurrency={wallet.currency}
        />
      </div>

      <DisconnectDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        walletId={wallet.id}
        walletName={wallet.name}
      />
    </Card>
  );
}

/** Confirmación de desconexión: borra la credencial, conserva el historial. */
function DisconnectDialog({
  open,
  onOpenChange,
  walletId,
  walletName,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  walletId: string;
  walletName: string;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = React.useTransition();

  function onConfirm() {
    startTransition(async () => {
      try {
        await disconnectWallet(walletId);
        toast.success(t("wallets.toast.disconnected"));
        router.refresh();
        onOpenChange(false);
      } catch (err) {
        toast.error(
          err instanceof Error
            ? err.message
            : t("wallets.errors.disconnectFailed"),
        );
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>
            {t("wallets.disconnect.title", { name: walletName })}
          </DialogTitle>
          <DialogDescription>{t("wallets.disconnect.body")}</DialogDescription>
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
            {t("wallets.disconnect.confirm")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
