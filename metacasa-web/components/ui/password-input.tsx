"use client";

import * as React from "react";
import { Eye, EyeOff } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * Input de contraseña con botón "ojito" para mostrar/ocultar (como las webs
 * profesionales). Mismo estilo que `Input`, con padding derecho para el botón.
 */
const PasswordInput = React.forwardRef<
  HTMLInputElement,
  Omit<React.ComponentProps<"input">, "type">
>(({ className, ...props }, ref) => {
  const [show, setShow] = React.useState(false);
  return (
    <div className="relative">
      <input
        ref={ref}
        type={show ? "text" : "password"}
        className={cn(
          "bg-inset flex h-11 w-full rounded-[var(--radius-md)] border border-input py-2 pl-3.5 pr-11 text-sm",
          "text-foreground placeholder:text-text-dim transition-colors outline-none",
          "focus-visible:border-ring/70 focus-visible:ring-2 focus-visible:ring-ring/25",
          "disabled:cursor-not-allowed disabled:opacity-50",
          className,
        )}
        {...props}
      />
      <button
        type="button"
        onClick={() => setShow((s) => !s)}
        aria-label={show ? "Ocultar contraseña" : "Mostrar contraseña"}
        tabIndex={-1}
        className="text-text-muted hover:text-foreground absolute right-3 top-1/2 -translate-y-1/2 transition-colors"
      >
        {show ? <EyeOff className="size-[18px]" /> : <Eye className="size-[18px]" />}
      </button>
    </div>
  );
});
PasswordInput.displayName = "PasswordInput";

export { PasswordInput };
