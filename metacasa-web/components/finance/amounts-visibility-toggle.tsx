"use client";

import { useEffect, useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/components/i18n/locale-provider";
import {
  useAmountsHidden,
  toggleAmountsHidden,
} from "@/components/finance/amounts-visibility";
import { setBalancesHidden } from "@/lib/actions/balance-privacy";

/**
 * Botón de la topbar para ocultar/mostrar montos (modo privacidad).
 * Lee del store global y persiste en localStorage.
 */
export function AmountsVisibilityToggle({
  className,
  initialHidden = false,
}: {
  className?: string;
  /** Valor leído de la cookie en el servidor: evita que el ícono parpadee al hidratar. */
  initialHidden?: boolean;
}) {
  const t = useT();
  const store = useAmountsHidden();
  const [hydrated, setHydrated] = useState(false);
  useEffect(() => setHydrated(true), []);
  const hidden = hydrated ? store : initialHidden;
  const label = hidden ? t("privacy.showAmounts") : t("privacy.hideAmounts");

  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      onClick={() => {
        toggleAmountsHidden();
        // Persiste para el próximo render del servidor. La UI ya cambió en `toggleAmountsHidden`.
        void setBalancesHidden(!hidden);
      }}
      aria-label={label}
      aria-pressed={hidden}
      title={label}
      className={className}
    >
      {hidden ? <EyeOff /> : <Eye />}
    </Button>
  );
}
