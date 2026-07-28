import { Card } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

/**
 * Fallbacks de las secciones del dashboard que se transmiten con `<Suspense>`.
 * Cada uno replica el layout real (misma grilla, mismo alto, mismos radios)
 * para que al llegar los datos NO haya salto de layout.
 */

/** Fila de sparklines (2 cards de 7 días). */
export function SparklinesSkeleton() {
  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4">
      {[0, 1].map((i) => (
        <Card key={i} className="p-5">
          <div className="flex items-center justify-between gap-3">
            <Skeleton className="h-3 w-28" />
            <Skeleton className="h-4 w-20" />
          </div>
          <Skeleton className="mt-3 h-10 w-full" />
        </Card>
      ))}
    </div>
  );
}

/**
 * Insights proactivos de gasto (encabezado + 2 cards). La sección puede
 * resolverse en "no hay nada que decir" y desaparecer: mostramos sólo 2 cards
 * para que el hueco reservado sea chico.
 */
export function InsightsSkeleton() {
  return (
    <div>
      <div className="mb-3 space-y-1.5">
        <Skeleton className="h-4 w-40" />
        <Skeleton className="h-3 w-56" />
      </div>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4">
        {[0, 1].map((i) => (
          <Card key={i} className="flex items-start gap-3 p-4 sm:p-5">
            <Skeleton className="size-9 shrink-0 rounded-[var(--radius-md)]" />
            <div className="min-w-0 flex-1 space-y-2">
              <div className="flex items-center justify-between gap-2">
                <Skeleton className="h-3.5 w-24" />
                <Skeleton className="h-3.5 w-16" />
              </div>
              <Skeleton className="h-3 w-full" />
              <Skeleton className="h-3 w-3/5" />
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

/** Patrimonio neto + ahorro/inversión + salud financiera. */
export function OverviewSkeleton() {
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <Card className="space-y-4 p-5">
        <Skeleton className="h-3.5 w-32" />
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-3 w-full" />
        <Skeleton className="h-3 w-2/3" />
      </Card>
      <div className="grid gap-4 lg:col-span-2 lg:grid-cols-2">
        {[0, 1].map((i) => (
          <Card key={i} className="space-y-4 p-5">
            <Skeleton className="h-3.5 w-28" />
            <Skeleton className="h-16 w-full" />
            <Skeleton className="h-3 w-1/2" />
          </Card>
        ))}
      </div>
    </div>
  );
}

/** Gráfico de flujos (misma altura que el chart real: 240px). */
export function FlowsChartSkeleton() {
  return <Skeleton className="h-[240px] w-full rounded-[var(--radius-lg)]" />;
}

/** Lista de filas (movimientos recientes / vencimientos). */
export function RowsSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="divide-y divide-border">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-3 py-2.5">
          <Skeleton className="size-9 shrink-0 rounded-[var(--radius-md)]" />
          <div className="min-w-0 flex-1 space-y-1.5">
            <Skeleton className="h-3.5 w-2/5" />
            <Skeleton className="h-3 w-1/4" />
          </div>
          <Skeleton className="h-4 w-16 shrink-0" />
        </div>
      ))}
    </div>
  );
}

/** Barras de progreso de metas. */
export function GoalsSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="space-y-3.5">
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i}>
          <div className="mb-1.5 flex items-center justify-between">
            <Skeleton className="h-3.5 w-28" />
            <Skeleton className="h-3 w-8" />
          </div>
          <Skeleton className="h-2 w-full rounded-full" />
        </div>
      ))}
    </div>
  );
}
