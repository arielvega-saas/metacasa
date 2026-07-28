"use client";

import { motion, useReducedMotion } from "framer-motion";
import { cn } from "@/lib/utils";

interface AnimatedProgressBarProps {
  /** Progreso 0–100 (se clampea). */
  value: number;
  /** Etiqueta accesible del progreso. */
  label?: string;
  className?: string;
  trackClassName?: string;
  indicatorClassName?: string;
}

/**
 * Barra de progreso de metas que "crece" desde 0 cuando entra en viewport
 * (`whileInView` + `viewport.once`), no al montarse: si la meta está más abajo
 * en la página, la animación se ve cuando el usuario llega, no antes.
 *
 * Si el `value` cambia después (p.ej. una contribución optimista), la barra
 * anima hacia el nuevo porcentaje: el target de `whileInView` se re-evalúa en
 * cada render y `once` sólo apaga el observer, no el estado "en viewport".
 *
 * Reduced motion: se cambia `whileInView` por un `animate` con duración 0. Así
 * el ancho final se aplica apenas monta (sin depender del scroll y sin
 * movimiento). El `initial` es idéntico en ambos casos a propósito: es lo único
 * que llega al HTML del server, que no puede conocer la preferencia del usuario.
 */
export function AnimatedProgressBar({
  value,
  label,
  className,
  trackClassName,
  indicatorClassName,
}: AnimatedProgressBarProps) {
  const reduceMotion = useReducedMotion();
  const pct = Math.max(0, Math.min(100, Number.isFinite(value) ? value : 0));
  const target = { width: `${pct}%` };

  return (
    <div
      className={cn(
        "bg-inset h-2 w-full overflow-hidden rounded-full",
        trackClassName,
        className,
      )}
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(pct)}
      aria-label={label}
    >
      <motion.div
        className={cn("bg-primary h-full rounded-full", indicatorClassName)}
        initial={{ width: "0%" }}
        {...(reduceMotion
          ? { animate: target, transition: { duration: 0 } }
          : {
              whileInView: target,
              viewport: { once: true, amount: 0.5 },
              transition: { duration: 0.7, ease: [0.22, 1, 0.36, 1] },
            })}
      />
    </div>
  );
}
