"use client";

import * as React from "react";
import { toast } from "sonner";
import { Loader2, Tag, Wallet, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
  SelectGroup,
  SelectLabel,
} from "@/components/ui/select";
import { bulkRecategorizeAction, bulkSetAccountAction } from "@/lib/actions/transactions";
import { useT } from "@/components/i18n/locale-provider";

type AccountOption = { id: string; name: string };

interface Props {
  /** Ids seleccionados. La barra sólo se muestra si hay al menos uno. */
  ids: string[];
  accounts: AccountOption[];
  categories: { gastos: string[]; ingresos: string[] };
  onClear: () => void;
}

/** Valor centinela del select de cuenta para "sin cuenta" (no se puede usar ""). */
const NO_ACCOUNT = "__none__";

/**
 * Barra de acciones en lote. Aparece anclada abajo cuando hay movimientos
 * seleccionados y ofrece los dos verbos que sólo tienen sentido con teclado y
 * mouse: recategorizar en masa y mover de cuenta en masa.
 *
 * El caso que la justifica: importás el resumen de la tarjeta y quedan 40
 * movimientos del súper sin categoría. Hasta ahora había que abrir uno por uno.
 */
export function BulkActionsBar({ ids, accounts, categories, onClear }: Props) {
  const t = useT();
  const [pending, startTransition] = React.useTransition();

  const count = ids.length;
  if (count === 0) return null;

  function run(apply: () => Promise<{ updated: number; skippedTransfers: number }>) {
    startTransition(async () => {
      try {
        const { updated, skippedTransfers } = await apply();
        toast.success(
          updated === 1
            ? t("transactions.bulkDone", { count: updated })
            : t("transactions.bulkDonePlural", { count: updated }),
        );
        if (skippedTransfers > 0) {
          // No es un error: es una regla del dominio. Se dice explícitamente para
          // que el total no parezca un bug ("seleccioné 12 y dice 10").
          toast.warning(
            skippedTransfers === 1
              ? t("transactions.bulkSkippedTransfers", { count: skippedTransfers })
              : t("transactions.bulkSkippedTransfersPlural", { count: skippedTransfers }),
          );
        }
        onClear();
      } catch (err) {
        toast.error(err instanceof Error ? err.message : t("transactions.bulkError"));
      }
    });
  }

  return (
    <div
      role="region"
      aria-label={t("transactions.bulkRecategorize")}
      className="fixed inset-x-0 bottom-0 z-40 px-4 pb-[max(1rem,env(safe-area-inset-bottom))] sm:px-6"
    >
      <div className="bg-card hairline mx-auto flex max-w-3xl flex-wrap items-center gap-2 rounded-[var(--radius-xl)] p-3 shadow-lg">
        <span className="text-sm font-medium" aria-live="polite">
          {count === 1
            ? t("transactions.bulkSelected", { count })
            : t("transactions.bulkSelectedPlural", { count })}
        </span>

        <div className="ml-auto flex flex-wrap items-center gap-2">
          <Select
            disabled={pending}
            onValueChange={(category) => run(() => bulkRecategorizeAction(ids, category))}
          >
            <SelectTrigger className="w-[190px]" aria-label={t("transactions.bulkRecategorize")}>
              <Tag className="size-4" />
              <SelectValue placeholder={t("transactions.bulkChooseCategory")} />
            </SelectTrigger>
            <SelectContent>
              <SelectGroup>
                <SelectLabel>{t("transactions.expense")}</SelectLabel>
                {categories.gastos.map((c) => (
                  <SelectItem key={`g-${c}`} value={c}>
                    {c}
                  </SelectItem>
                ))}
              </SelectGroup>
              <SelectGroup>
                <SelectLabel>{t("transactions.income")}</SelectLabel>
                {categories.ingresos.map((c) => (
                  <SelectItem key={`i-${c}`} value={c}>
                    {c}
                  </SelectItem>
                ))}
              </SelectGroup>
            </SelectContent>
          </Select>

          <Select
            disabled={pending}
            onValueChange={(value) =>
              run(() => bulkSetAccountAction(ids, value === NO_ACCOUNT ? null : value))
            }
          >
            <SelectTrigger className="w-[190px]" aria-label={t("transactions.bulkMoveAccount")}>
              <Wallet className="size-4" />
              <SelectValue placeholder={t("transactions.bulkChooseAccount")} />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={NO_ACCOUNT}>{t("transactions.noAccount")}</SelectItem>
              {accounts.map((a) => (
                <SelectItem key={a.id} value={a.id}>
                  {a.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          {pending ? (
            <span className="text-text-muted flex items-center gap-2 text-sm">
              <Loader2 className="size-4 animate-spin" />
              {t("transactions.bulkApplying")}
            </span>
          ) : (
            <Button variant="ghost" size="sm" onClick={onClear}>
              <X className="size-4" />
              {t("transactions.bulkClear")}
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
