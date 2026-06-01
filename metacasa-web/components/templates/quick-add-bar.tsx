"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Zap, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { formatMoney } from "@/lib/money";
import { TX_TYPE } from "@/lib/constants";
import { applyTemplate } from "@/lib/actions/templates";
import { useT } from "@/components/i18n/locale-provider";
import type { TransactionTemplate } from "@/lib/db/templates";

interface QuickAddBarProps {
  templates: TransactionTemplate[];
  /** Moneda base del hogar (fallback si el atajo no trae moneda). */
  currency: string;
}

/**
 * Barra horizontal de atajos rápidos. SELF-CONTAINED: recibe las plantillas por
 * props y, al tocar un chip, aplica la plantilla (crea el movimiento de HOY) y
 * refresca. Se monta en la página de Movimientos sobre la lista. Si no hay
 * plantillas, no renderiza nada (no ocupa espacio).
 */
export function QuickAddBar({ templates, currency }: QuickAddBarProps) {
  const t = useT();
  const router = useRouter();
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [, startTransition] = useTransition();

  if (templates.length === 0) return null;

  function apply(tpl: TransactionTemplate) {
    if (pendingId) return;
    setPendingId(tpl.id);
    startTransition(async () => {
      try {
        await applyTemplate(tpl.id);
        toast.success(t("templates.applied"), { description: tpl.name });
        router.refresh();
      } catch (err) {
        toast.error(t("templates.applyError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      } finally {
        setPendingId(null);
      }
    });
  }

  return (
    <div className="space-y-2">
      <div className="text-text-muted flex items-center gap-1.5 text-xs font-semibold">
        <Zap className="size-3.5" /> {t("templates.quickAddTitle")}
      </div>
      <div className="flex gap-2 overflow-x-auto pb-1 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {templates.map((tpl) => {
          const isIncome = tpl.type === TX_TYPE.INCOME;
          const busy = pendingId === tpl.id;
          return (
            <button
              key={tpl.id}
              type="button"
              onClick={() => apply(tpl)}
              disabled={Boolean(pendingId)}
              aria-label={t("templates.applyHint")}
              title={tpl.name}
              className={cn(
                "flex min-h-11 shrink-0 items-center gap-2 rounded-[var(--radius-lg)] px-3 py-2 text-left transition-colors disabled:opacity-60",
                isIncome
                  ? "bg-income/12 text-income hover:bg-income/20"
                  : "bg-expense/12 text-expense hover:bg-expense/20",
              )}
            >
              <span className="text-base leading-none" aria-hidden>
                {busy ? (
                  <Loader2 className="size-4 animate-spin" />
                ) : tpl.emoji?.trim() ? (
                  tpl.emoji
                ) : isIncome ? (
                  "+"
                ) : (
                  "−"
                )}
              </span>
              <span className="min-w-0">
                <span className="block max-w-[8rem] truncate text-xs font-semibold">
                  {tpl.name}
                </span>
                <span className="tnum block text-[11px] opacity-80">
                  {formatMoney(Number(tpl.amount), tpl.currency || currency, "compact")}
                </span>
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
