"use client";

import { Eye, EyeOff } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/components/i18n/locale-provider";
import {
  useAmountsHidden,
  toggleAmountsHidden,
} from "@/components/finance/amounts-visibility";

/**
 * Botón de la topbar para ocultar/mostrar montos (modo privacidad).
 * Lee del store global y persiste en localStorage.
 */
export function AmountsVisibilityToggle({
  className,
}: {
  className?: string;
}) {
  const t = useT();
  const hidden = useAmountsHidden();
  const label = hidden ? t("privacy.showAmounts") : t("privacy.hideAmounts");

  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      onClick={() => toggleAmountsHidden()}
      aria-label={label}
      aria-pressed={hidden}
      title={label}
      className={className}
    >
      {hidden ? <EyeOff /> : <Eye />}
    </Button>
  );
}
