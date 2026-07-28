"use client";

import { useEffect } from "react";
import Link from "next/link";
import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

/**
 * Error boundary compartido de (app). Sin esto, cualquier throw en un fetch
 * de un Server Component tiraba la app entera al error genérico de Next.
 * Copy en español fijo a propósito: el boundary debe ser autosuficiente
 * (si el error viniera del propio i18n, un boundary que depende de i18n
 * también se rompería).
 */
export default function AppError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Nunca loguear datos sensibles; message + digest alcanzan para diagnosticar.
    console.error("[app-error]", error.message, error.digest ?? "");
  }, [error]);

  return (
    <div className="flex min-h-[60dvh] items-center justify-center">
      <div className="hairline w-full max-w-md space-y-5 rounded-[var(--radius-xl)] bg-card p-8 text-center">
        <div className="mx-auto flex size-12 items-center justify-center rounded-full bg-expense/12">
          <AlertTriangle className="size-6 text-expense" aria-hidden />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold text-foreground">
            Algo salió mal
          </h2>
          <p className="text-sm text-text-muted">
            No pudimos cargar esta sección. Tus datos están a salvo — probá de
            nuevo en unos segundos.
          </p>
          {error.digest ? (
            <p className="tnum text-xs text-text-dim">Ref: {error.digest}</p>
          ) : null}
        </div>
        <div className="flex items-center justify-center gap-3">
          <Button onClick={reset}>Reintentar</Button>
          <Button variant="ghost" asChild>
            <Link href="/dashboard">Ir al inicio</Link>
          </Button>
        </div>
      </div>
    </div>
  );
}
