"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { useT } from "@/components/i18n/locale-provider";
import { runDueRecurring } from "@/lib/actions/recurring-run";

/**
 * Auto-ejecución de recurrentes al cargar el dashboard.
 *
 * DECISIÓN (documentada): correr la materialización dentro del render del RSC
 * (Server Component) es riesgoso — sería un efecto secundario en GET, se
 * dispararía en cada prefetch/refresh y rompería el modelo de cacheo de Next.
 * Por eso lo hacemos desde un efecto de CLIENTE, una sola vez al montar:
 *
 *  - Idempotencia real: `runDueRecurring` avanza `next_date`; si no hay nada
 *    vencido no crea nada. Aun si se llamara dos veces, la segunda no
 *    doble-postea (el candado es `next_date`).
 *  - Throttle "a lo sumo 1 vez por día": guardamos la fecha de la última corrida
 *    en localStorage por hogar. Si ya corrió hoy, ni siquiera llamamos al server.
 *  - StrictMode (dev) monta dos veces: un ref evita la doble llamada en el mismo
 *    mount.
 *  - Si materializó algo, refrescamos la ruta para que el dashboard muestre los
 *    movimientos nuevos, y avisamos con un toast discreto.
 *
 * Es un componente sin UI (devuelve null). Recibe `householdId` solo para
 * namespacing del flag de throttle (no lo manda al server: el server resuelve el
 * hogar activo por su cuenta).
 */
const STORAGE_PREFIX = "mc_recurring_autorun_";

export function RecurringAutorun({ householdId }: { householdId: string }) {
  const router = useRouter();
  const t = useT();
  const ran = useRef(false);

  useEffect(() => {
    if (ran.current) return;
    ran.current = true;

    const key = `${STORAGE_PREFIX}${householdId}`;
    const today = new Date().toISOString().slice(0, 10);

    let last: string | null = null;
    try {
      last = window.localStorage.getItem(key);
    } catch {
      /* modo privado / sin storage: seguimos igual (la acción es idempotente) */
    }
    if (last === today) return; // ya corrió hoy: no molestamos al server

    // Marcamos ANTES de await para que un re-render no relance la corrida; el
    // server es idempotente igual, esto solo evita llamadas redundantes.
    try {
      window.localStorage.setItem(key, today);
    } catch {
      /* ignore */
    }

    (async () => {
      try {
        const { created } = await runDueRecurring();
        if (created > 0) {
          toast.success(t("dashboard.recurringRan", { count: created }));
          router.refresh();
        }
      } catch {
        // Silencioso en auto-run: el botón manual reporta errores; acá no
        // bloqueamos el dashboard si falla (p.ej. sin sesión).
      }
    })();
  }, [householdId, router, t]);

  return null;
}
