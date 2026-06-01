"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Play } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/components/i18n/locale-provider";
import { runDueRecurring } from "@/lib/actions/recurring-run";

/**
 * Botón "Ejecutar pendientes": materializa los recurrentes vencidos del hogar
 * activo como movimientos reales (server action `runDueRecurring`, idempotente).
 * Toast con el resultado y refresh para reflejar las nuevas próximas fechas.
 */
export function RunDueButton({ variant = "secondary" }: { variant?: "secondary" | "outline" }) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function onClick() {
    startTransition(async () => {
      try {
        const { created } = await runDueRecurring();
        if (created === 0) toast.info(t("recurring.ranNone"));
        else if (created === 1) toast.success(t("recurring.ranOne"));
        else toast.success(t("recurring.ranMany", { count: created }));
        router.refresh();
      } catch (err) {
        toast.error(t("recurring.runError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Button variant={variant} onClick={onClick} disabled={pending}>
      <Play />
      {t("recurring.runDue")}
    </Button>
  );
}
