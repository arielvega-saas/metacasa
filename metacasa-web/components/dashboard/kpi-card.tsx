import type { LucideIcon } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Amount, type AmountKind } from "@/components/finance/amount";
import { AnimatedAmount } from "@/components/finance/animated-amount";
import { cn } from "@/lib/utils";

export function KpiCard({
  label,
  value,
  currency,
  kind = "neutral",
  icon: Icon,
  hint,
  highlight = false,
  animateValue = false,
}: {
  label: string;
  value: number;
  currency: string;
  kind?: AmountKind;
  icon?: LucideIcon;
  hint?: string;
  highlight?: boolean;
  /** Cuenta el monto desde 0 al montar (reservado para el KPI hero). */
  animateValue?: boolean;
}) {
  const Value = animateValue ? AnimatedAmount : Amount;
  return (
    <Card
      glass={highlight}
      className={cn("p-5", highlight && "sage-glow border-primary/20")}
    >
      <div className="flex items-center justify-between">
        <span className="text-text-muted text-[11px] font-semibold uppercase tracking-wider">
          {label}
        </span>
        {Icon && <Icon className="text-text-muted size-4" />}
      </div>
      <div className="mt-2.5 text-[26px] leading-none sm:text-[28px]">
        <Value value={value} currency={currency} kind={kind} serif />
      </div>
      {hint && <p className="text-text-dim mt-1.5 text-xs">{hint}</p>}
    </Card>
  );
}
