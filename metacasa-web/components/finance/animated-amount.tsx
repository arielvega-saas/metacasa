"use client";

import * as React from "react";
import { animate, useReducedMotion } from "framer-motion";
import { Amount, type AmountKind } from "@/components/finance/amount";
import { useAmountsHidden } from "@/components/finance/amounts-visibility";
import type { MoneyStyle } from "@/lib/money";

interface AnimatedAmountProps {
  value: number;
  currency?: string;
  kind?: AmountKind;
  serif?: boolean;
  showSign?: boolean;
  className?: string;
}

/**
 * Monto "hero" con contador animado: al montar cuenta desde 0 hasta el valor
 * real con un spring suave y sin rebote.
 *
 * Cuidados de layout (importante en una app de plata):
 *  - El estado inicial es el valor FINAL, así el HTML del server y el primer
 *    render del cliente coinciden (sin mismatch de hidratación) y sin JS el
 *    monto correcto queda igual en pantalla.
 *  - El estilo de formato se fija a partir del valor final (`precise` si tiene
 *    decimales, `compact` si no), que es exactamente lo que `Amount` resolvería
 *    con `auto`. Así la cantidad de dígitos decimales no cambia a mitad de la
 *    animación y, con `tnum` (tabular) heredado de `Amount`, el ancho no salta.
 *  - Con `prefers-reduced-motion` o con los montos ocultos (modo privacidad) no
 *    se anima nada: se pinta el valor final directo.
 */
export function AnimatedAmount({
  value,
  currency = "USD",
  kind = "neutral",
  serif = false,
  showSign = false,
  className,
}: AnimatedAmountProps) {
  const reduceMotion = useReducedMotion();
  const amountsHidden = useAmountsHidden();
  const [display, setDisplay] = React.useState(value);
  // Último valor al que ya contamos (null = todavía no contamos nada). Un
  // re-render con el MISMO valor no vuelve a contar — el efecto ni siquiera se
  // re-ejecuta porque `value` está en las deps. Cuando el valor cambia de
  // verdad (cambiás de mes, cargás un movimiento) el hero se vuelve a revelar
  // contando desde 0.
  const countedTo = React.useRef<number | null>(null);

  React.useEffect(() => {
    if (reduceMotion || amountsHidden) {
      countedTo.current = value;
      setDisplay(value);
      return;
    }
    const from = countedTo.current ?? 0;
    if (from === value) {
      setDisplay(value);
      return;
    }
    countedTo.current = value;
    const controls = animate(from, value, {
      type: "spring",
      duration: 0.9,
      bounce: 0,
      onUpdate: (v) => setDisplay(v),
      onComplete: () => setDisplay(value),
    });
    // Al limpiar devolvemos el ref a su valor previo: con `reactStrictMode` el
    // efecto se monta, se limpia y se vuelve a montar, y sin esto la animación
    // quedaría "ya hecha" y no se vería nunca en desarrollo.
    return () => {
      controls.stop();
      countedTo.current = from === 0 ? null : from;
    };
  }, [value, reduceMotion, amountsHidden]);

  const style: MoneyStyle =
    Math.abs(value % 1) > 0.0001 ? "precise" : "compact";

  return (
    <Amount
      value={display}
      currency={currency}
      kind={kind}
      serif={serif}
      showSign={showSign}
      style={style}
      className={className}
    />
  );
}
