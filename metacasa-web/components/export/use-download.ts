"use client";

import * as React from "react";
import { toast } from "sonner";
import { useT } from "@/components/i18n/locale-provider";

/**
 * Hook de descarga: hace fetch a una ruta de exportación, lee el blob y dispara
 * la descarga en el navegador. Expone `pending` para feedback de UI y maneja
 * errores con un toast localizado (incluye 401 → la ruta devuelve JSON de error).
 *
 * Preferimos fetch→blob→ancla temporal sobre un `<a download>` directo para
 * poder mostrar estado de carga y capturar errores del server (la respuesta de
 * error es `application/json`, no el archivo).
 */
export function useDownload(): {
  pending: boolean;
  download: (url: string, fallbackName?: string) => void;
} {
  const t = useT();
  const [pending, setPending] = React.useState(false);
  // Evita dobles clics y descargas en paralelo del mismo botón.
  const inFlight = React.useRef(false);

  const download = React.useCallback(
    (url: string, fallbackName?: string) => {
      if (inFlight.current) return;
      inFlight.current = true;
      setPending(true);

      (async () => {
        try {
          const res = await fetch(url, { cache: "no-store" });
          if (!res.ok) throw new Error(`HTTP ${res.status}`);

          // Nombre de archivo: respetamos el del header del server si vino.
          const cd = res.headers.get("Content-Disposition") ?? "";
          const match = /filename="?([^"]+)"?/i.exec(cd);
          const filename = match?.[1] ?? fallbackName ?? "export";

          const blob = await res.blob();
          const objectUrl = URL.createObjectURL(blob);
          const a = document.createElement("a");
          a.href = objectUrl;
          a.download = filename;
          document.body.appendChild(a);
          a.click();
          a.remove();
          // Liberar el object URL en el siguiente tick (Safari necesita el delay).
          setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
        } catch {
          toast.error(t("exportTools.actions.downloadError"));
        } finally {
          inFlight.current = false;
          setPending(false);
        }
      })();
    },
    [t],
  );

  return { pending, download };
}
