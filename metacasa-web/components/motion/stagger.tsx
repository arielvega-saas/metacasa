"use client";

import type * as React from "react";
import { motion, useReducedMotion } from "framer-motion";
import { cn } from "@/lib/utils";

/** Segundos entre la entrada de un ítem y el siguiente. */
const STEP = 0.04;

/**
 * Envoltorio de UN ítem de una grilla/lista que entra escalonado: fade + 8px
 * hacia arriba, con `index * 40 ms` de retraso. Sobrio a propósito — es una app
 * de plata: la animación tiene que dar sensación de solidez, no de fuegos
 * artificiales.
 *
 * Se envuelve ítem por ítem (en vez de la grilla entera con
 * `React.Children.toArray`) para que los hijos sigan siendo Server Components
 * puros: el wrapper es lo único que viaja al bundle del cliente.
 *
 * Reduced motion: el server NO puede conocer la preferencia del usuario, así
 * que el `initial` —lo único que llega al HTML— es SIEMPRE el mismo; si no,
 * habría mismatch de hidratación. Lo que se gatea es la transición: con
 * `prefers-reduced-motion` dura 0 y sin delay, o sea que el ítem aparece
 * directamente en su estado final, sin movimiento perceptible.
 */
export function StaggerItem({
  index = 0,
  className,
  children,
}: {
  /** Posición en la grilla (define el retraso). */
  index?: number;
  className?: string;
  children: React.ReactNode;
}) {
  const reduceMotion = useReducedMotion();

  return (
    <motion.div
      // `h-full` + hijo a `h-full`: sin esto el wrapper estira con la fila de la
      // grilla pero la Card de adentro se queda con su alto natural.
      className={cn("h-full [&>*]:h-full", className)}
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={
        reduceMotion
          ? { duration: 0 }
          : { duration: 0.32, delay: index * STEP, ease: [0.22, 1, 0.36, 1] }
      }
    >
      {children}
    </motion.div>
  );
}
