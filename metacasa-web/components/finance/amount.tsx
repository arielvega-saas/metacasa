"use client";

import { cn } from "@/lib/utils";
import { formatMoney, type MoneyStyle } from "@/lib/money";
import { MONEY_CLASS } from "@/lib/balance-privacy";
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
  // Sólo para el `title`: el ocultamiento visual lo hace el CSS, en el primer paint.
  const oculto = useAmountsHidden();

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

  // El modo privacidad lo aplica el CSS sobre `MONEY_CLASS`, no este componente.
  //
  // Antes se decidía acá con un store de `localStorage`, y `getServerSnapshot()` devolvía
  // `false` para no romper la hidratación. O sea: en CADA carga el servidor renderizaba los
  // montos VISIBLES y recién se ocultaban al hidratar. La función existía y filtraba
  // exactamente lo que tenía que tapar — alguien mirando la pantalla veía los saldos.
  //
  // Ahora el servidor marca `<html data-hide-balances>` desde la cookie y el CSS oculta en el
  // primer paint, antes de que corra JS.
  return (
    <span
      className={cn(MONEY_CLASS, "tnum", serif && "font-num", color, className)}
      // Sin `title` cuando está oculto: un tooltip con el monto exacto sería una filtración
      // por la puerta de atrás. Es lo único que el CSS no puede resolver, porque no puede
      // borrar un atributo — por eso este componente sigue leyendo el estado.
      title={oculto ? undefined : formatMoney(Math.abs(value), currency, "precise")}
    >
      {sign}
      {formatMoney(Math.abs(value), currency, style)}
    </span>
  );
}
