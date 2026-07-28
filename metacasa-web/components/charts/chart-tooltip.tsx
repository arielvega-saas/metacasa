"use client";

// Contenedor compartido para los tooltips custom de Recharts: el patrón de
// vidrio ("glass hairline") que usan FlowsChart y los charts de Reportes.
// Cada chart mantiene su propio extractor de datos (Recharts le pasa
// active/payload/label a `content`); acá vive solo la presentación.
import { cn } from "@/lib/utils";

export function ChartTooltip({
  title,
  capitalizeTitle = false,
  className,
  children,
}: {
  /** Título del tooltip (mes, categoría…). Si es null/undefined no se pinta. */
  title?: React.ReactNode;
  /** Capitaliza el título (labels de mes en minúscula: "may" → "May"). */
  capitalizeTitle?: boolean;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className={cn(
        "glass hairline rounded-[var(--radius-md)] px-3 py-2 text-xs shadow-xl",
        className,
      )}
    >
      {title != null && (
        <p
          className={cn(
            "mb-1 font-medium text-foreground",
            capitalizeTitle && "capitalize",
          )}
        >
          {title}
        </p>
      )}
      {children}
    </div>
  );
}

const TONE_CLASS = {
  income: "text-income",
  expense: "text-expense",
  muted: "text-text-muted",
  default: "text-foreground",
} as const;

/** Línea de valor dentro del tooltip, con tono semántico del tema. */
export function ChartTooltipRow({
  tone = "muted",
  children,
}: {
  tone?: keyof typeof TONE_CLASS;
  children: React.ReactNode;
}) {
  return <p className={TONE_CLASS[tone]}>{children}</p>;
}
