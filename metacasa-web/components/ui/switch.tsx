"use client";

import * as React from "react";
import * as SwitchPrimitive from "@radix-ui/react-switch";
import { cn } from "@/lib/utils";

/**
 * Switch on-brand.
 *
 * El thumb es blanco a propósito en AMBOS temas (no es un color hardcodeado
 * olvidado): apagado va sobre `--mc-switch-track` → 13.2:1 en oscuro y 3.47:1
 * en claro; encendido cambia a `bg-background` sobre el sage → 11.9:1 en oscuro
 * y 5.50:1 en claro. Los cuatro estados pasan el 3:1 de WCAG 1.4.11.
 */
const Switch = React.forwardRef<
  React.ElementRef<typeof SwitchPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof SwitchPrimitive.Root>
>(({ className, ...props }, ref) => (
  <SwitchPrimitive.Root
    ref={ref}
    className={cn(
      "peer inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border border-transparent transition-colors outline-none",
      "focus-visible:ring-2 focus-visible:ring-ring/40 disabled:cursor-not-allowed disabled:opacity-50",
      "data-[state=checked]:bg-primary data-[state=unchecked]:bg-switch-track",
      className,
    )}
    {...props}
  >
    <SwitchPrimitive.Thumb
      className={cn(
        "pointer-events-none block size-5 rounded-full bg-white shadow-lg transition-transform",
        "data-[state=checked]:translate-x-5 data-[state=unchecked]:translate-x-0.5",
        "data-[state=checked]:bg-background",
      )}
    />
  </SwitchPrimitive.Root>
));
Switch.displayName = SwitchPrimitive.Root.displayName;

export { Switch };
