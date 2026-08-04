"use client";

import * as React from "react";
import { Check, Minus } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * Checkbox on-brand.
 *
 * Es un `<input type="checkbox">` real con la caja dibujada encima, no un `div`
 * con `role="checkbox"`: así se lleva gratis el foco, la barra espaciadora, el
 * form association y el anuncio del lector de pantalla. El input queda con
 * `sr-only` + `peer`, y la caja reacciona por `peer-*`.
 *
 * `indeterminate` no es un atributo de HTML, sólo una propiedad del DOM, así que
 * se aplica por ref.
 */
interface Props extends Omit<React.ComponentPropsWithoutRef<"input">, "type"> {
  indeterminate?: boolean;
}

const Checkbox = React.forwardRef<HTMLInputElement, Props>(
  ({ className, indeterminate = false, ...props }, forwardedRef) => {
    const innerRef = React.useRef<HTMLInputElement>(null);
    React.useImperativeHandle(forwardedRef, () => innerRef.current!, []);

    React.useEffect(() => {
      if (innerRef.current) innerRef.current.indeterminate = indeterminate;
    }, [indeterminate]);

    return (
      <span className={cn("relative inline-flex shrink-0", className)}>
        <input ref={innerRef} type="checkbox" className="peer sr-only" {...props} />
        <span
          aria-hidden
          className={cn(
            "pointer-events-none flex size-[18px] items-center justify-center rounded-[6px] border transition-colors",
            "border-border bg-transparent",
            "peer-checked:border-primary peer-checked:bg-primary",
            "peer-indeterminate:border-primary peer-indeterminate:bg-primary",
            "peer-focus-visible:ring-ring/40 peer-focus-visible:ring-2 peer-focus-visible:ring-offset-1",
            "peer-disabled:opacity-40",
            // El tilde va en un DESCENDIENTE del hermano, no en un hermano: `peer-checked:`
            // solo alcanza hermanos directos del input, así que hay que bajar con `[&_svg]`.
            "[&_svg]:opacity-0 peer-checked:[&_svg]:opacity-100 peer-indeterminate:[&_svg]:opacity-100",
          )}
        >
          {indeterminate ? (
            <Minus className="text-background size-3" strokeWidth={3} />
          ) : (
            <Check className="text-background size-3" strokeWidth={3} />
          )}
        </span>
      </span>
    );
  },
);
Checkbox.displayName = "Checkbox";

export { Checkbox };
