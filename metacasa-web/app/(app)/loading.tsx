import { Skeleton } from "@/components/ui/skeleton";

/**
 * Loading UI compartido de todas las rutas de (app). Next lo muestra al
 * instante mientras el Server Component de la página resuelve sus queries —
 * sin esto, la navegación queda congelada sin feedback hasta que el server
 * termina. Replica el esqueleto típico de una página: header + grid de KPIs
 * + dos cards grandes.
 */
export default function AppLoading() {
  return (
    <div className="space-y-8" aria-busy="true" aria-live="polite">
      {/* PageHeader: título + descripción + acción */}
      <div className="flex items-end justify-between gap-4">
        <div className="space-y-2">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-4 w-72 max-w-[60vw]" />
        </div>
        <Skeleton className="h-10 w-32 rounded-[var(--radius-md)]" />
      </div>

      {/* Grid de KPI cards */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div
            key={i}
            className="hairline space-y-3 rounded-[var(--radius-xl)] bg-card p-5"
          >
            <Skeleton className="h-3.5 w-20" />
            <Skeleton className="h-7 w-28" />
            <Skeleton className="h-3 w-16" />
          </div>
        ))}
      </div>

      {/* Dos cards grandes (chart + lista) */}
      <div className="grid gap-4 lg:grid-cols-2">
        {Array.from({ length: 2 }).map((_, i) => (
          <div
            key={i}
            className="hairline space-y-4 rounded-[var(--radius-xl)] bg-card p-5"
          >
            <Skeleton className="h-4 w-36" />
            <Skeleton className="h-48 w-full rounded-[var(--radius-lg)]" />
          </div>
        ))}
      </div>
    </div>
  );
}
