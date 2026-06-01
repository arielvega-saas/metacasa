"use client";

import { cn } from "@/lib/utils";
import { formatMoney, type MoneyStyle } from "@/lib/money";
import { useAmountsHidden } from "@/components/finance/amounts-visibility";

export type AmountKind = "gasto" | "ingreso" | "balance" | "neutral";

interface AmountProps {
  value: number;
  currency?: string;
  /** Semántica de color/signo. `balance` colorea según el signo. */
  kind?: AmountKind;
  /** Usa la tipografía serif editorial (saldos hero). */
  serif?: boolean;
  style?: MoneyStyle;
  /** Muestra "+"/"−" explícito (útil en movimientos). */
  showSign?: boolean;
  className?: string;
}

/**
 * Etiqueta de dinero con semántica de color Midnight Sage:
 * ingreso = sage saturado, gasto = coral, balance = según signo.
 */
export function Amount({
  value,
  currency = "USD",
  kind = "neutral",
  serif = false,
  style = "auto",
  showSign = false,
  className,
}: AmountProps) {
  const amountsHidden = useAmountsHidden();

  const color =
    kind === "ingreso"
      ? "text-income"
      : kind === "gasto"
        ? "text-expense"
        : kind === "balance"
          ? value < 0
            ? "text-expense"
            : value > 0
              ? "text-income"
              : "text-foreground"
          : "text-foreground";

  let sign = "";
  if (kind === "gasto") sign = "−";
  else if (value < 0) sign = "−"; // balance/neutral negativos SIEMPRE llevan signo
  else if (showSign && value > 0) sign = "+";

  // Modo privacidad: enmascaramos los dígitos pero conservamos color y signo.
  if (amountsHidden) {
    return (
      <span
        className={cn("tnum", serif && "font-num", color, className)}
        aria-hidden="true"
      >
        {sign}
        ••••
      </span>
    );
  }

  return (
    <span
      className={cn("tnum", serif && "font-num", color, className)}
      title={formatMoney(Math.abs(value), currency, "precise")}
    >
      {sign}
      {formatMoney(Math.abs(value), currency, style)}
    </span>
  );
}
