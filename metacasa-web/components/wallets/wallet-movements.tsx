"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ArrowDownLeft, ArrowUpRight, Loader2, Inbox } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Amount } from "@/components/finance/amount";
import { SectionHeader } from "@/components/finance/section-header";
import { useT } from "@/components/i18n/locale-provider";
import { cn } from "@/lib/utils";
import { TX_TYPE } from "@/lib/constants";
import { importWalletMovements } from "@/lib/actions/wallets";
import type { PendingMovement } from "@/components/wallets/types";

export interface WalletMovementsProps {
  walletId: string;
  movements: PendingMovement[];
  /** Moneda de la wallet, por si el movimiento no trae la suya. */
  fallbackCurrency: string;
}

/**
 * Bandeja de movimientos sincronizados y todavía sin importar. El usuario tilda
 * los que quiere convertir en transacciones reales del hogar; la categoría que
 * se muestra es la que `suggest_category` aprendió de sus propios movimientos.
 */
export function WalletMovements({
  walletId,
  movements,
  fallbackCurrency,
}: WalletMovementsProps) {
  const t = useT();
  const router = useRouter();
  const [selected, setSelected] = React.useState<Set<string>>(new Set());
  const [importing, startImport] = React.useTransition();

  // Si la lista cambia (sync/refresh), descartamos las selecciones ya inexistentes.
  React.useEffect(() => {
    setSelected((prev) => {
      const alive = new Set(movements.map((m) => m.id));
      const next = new Set([...prev].filter((id) => alive.has(id)));
      return next.size === prev.size ? prev : next;
    });
  }, [movements]);

  if (movements.length === 0) {
    return (
      <div className="text-text-muted flex items-center gap-2 text-sm">
        <Inbox className="size-4 shrink-0" />
        {t("wallets.movements.empty")}
      </div>
    );
  }

  const allSelected = selected.size === movements.length;

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll() {
    setSelected(allSelected ? new Set() : new Set(movements.map((m) => m.id)));
  }

  function onImport() {
    const ids = [...selected];
    if (ids.length === 0) return;
    startImport(async () => {
      try {
        const { imported, skippedNoRate } = await importWalletMovements(
          walletId,
          ids,
        );
        if (imported === 0) {
          toast.warning(t("wallets.toast.importedNone"));
        } else {
          toast.success(
            imported === 1
              ? t("wallets.toast.importedOne")
              : t("wallets.toast.importedOther", { count: imported }),
          );
        }
        if (skippedNoRate > 0) {
          toast.warning(
            t("wallets.toast.skippedNoRate", { count: skippedNoRate }),
          );
        }
        setSelected(new Set());
        router.refresh();
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("wallets.errors.importFailed"),
        );
      }
    });
  }

  return (
    <div className="space-y-3">
      <SectionHeader
        title={t("wallets.movements.title")}
        subtitle={t("wallets.movements.subtitle")}
        action={
          <Button variant="ghost" size="sm" onClick={toggleAll}>
            {allSelected
              ? t("wallets.movements.clear")
              : t("wallets.movements.selectAll")}
          </Button>
        }
      />

      <div className="hairline overflow-x-auto rounded-[var(--radius-lg)]">
        <table className="w-full min-w-[38rem] text-sm">
          <thead className="text-text-dim text-left text-[11px] uppercase tracking-wider">
            <tr className="border-b border-border">
              <th className="w-10 px-3 py-2.5" />
              <th className="px-3 py-2.5 font-medium">
                {t("wallets.movements.colDate")}
              </th>
              <th className="px-3 py-2.5 font-medium">
                {t("wallets.movements.colDescription")}
              </th>
              <th className="px-3 py-2.5 font-medium">
                {t("wallets.movements.colCategory")}
              </th>
              <th className="px-3 py-2.5 text-right font-medium">
                {t("wallets.movements.colAmount")}
              </th>
            </tr>
          </thead>
          <tbody>
            {movements.map((m) => {
              const checked = selected.has(m.id);
              const isIncome = m.type === TX_TYPE.INCOME;
              return (
                <tr
                  key={m.id}
                  className={cn(
                    "border-b border-border/60 transition-colors last:border-0",
                    checked ? "bg-tint-1" : "opacity-80",
                  )}
                >
                  <td className="px-3 py-2.5">
                    <input
                      type="checkbox"
                      className="accent-primary size-4 cursor-pointer"
                      checked={checked}
                      onChange={() => toggle(m.id)}
                      aria-label={t("wallets.movements.selectRow")}
                    />
                  </td>
                  <td className="text-text-muted whitespace-nowrap px-3 py-2.5">
                    {m.dateLabel}
                  </td>
                  <td className="max-w-[16rem] px-3 py-2.5">
                    <span className="flex items-center gap-1.5">
                      {isIncome ? (
                        <ArrowDownLeft className="text-income size-3.5 shrink-0" />
                      ) : (
                        <ArrowUpRight className="text-expense size-3.5 shrink-0" />
                      )}
                      <span className="truncate">{m.description}</span>
                    </span>
                  </td>
                  <td className="px-3 py-2.5">
                    {m.suggestedCategory ? (
                      <span className="flex flex-wrap items-center gap-1.5">
                        <Badge variant="neutral">{m.suggestedCategory}</Badge>
                        {m.confidence != null && (
                          <span className="text-text-dim text-[11px]">
                            {t("wallets.movements.confidence", {
                              pct: m.confidence,
                            })}
                          </span>
                        )}
                      </span>
                    ) : (
                      <span className="text-text-dim text-xs">
                        {t("wallets.movements.noSuggestion")}
                      </span>
                    )}
                  </td>
                  <td className="whitespace-nowrap px-3 py-2.5 text-right">
                    <Amount
                      value={m.amount}
                      currency={m.currency || fallbackCurrency}
                      kind={isIncome ? "ingreso" : "gasto"}
                      className="text-sm font-semibold"
                    />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="flex justify-end">
        <Button
          onClick={onImport}
          disabled={importing || selected.size === 0}
        >
          {importing && <Loader2 className="animate-spin" />}
          {importing
            ? t("wallets.movements.importing")
            : selected.size === 1
              ? t("wallets.movements.importOne")
              : t("wallets.movements.importOther", { count: selected.size })}
        </Button>
      </div>
    </div>
  );
}
