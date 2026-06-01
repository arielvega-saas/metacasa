import Link from "next/link";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { getT } from "@/lib/i18n/server";

/**
 * Navegador de AÑO server-rendered para las secciones anuales de Reportes
 * (heatmap + vista anual). Usa hrefs `?fy=` y PRESERVA el `?ym=` del mes para
 * no romper el flujo mensual del resto de la pantalla (ambos params conviven).
 *
 * Tope superior = año actual (paridad con iOS `SpendingHeatmapView`: no se
 * navega al futuro). El botón "siguiente" se deshabilita en el año actual.
 */
export async function YearSwitcher({ fy, ym }: { fy: number; ym?: string }) {
  const t = await getT();
  const maxYear = new Date().getFullYear();
  const atMax = fy >= maxYear;

  // Mantener el mes seleccionado en la URL al cambiar de año.
  const href = (year: number) => {
    const params = new URLSearchParams();
    params.set("fy", String(year));
    if (ym) params.set("ym", ym);
    return `?${params.toString()}`;
  };

  return (
    <div className="hairline bg-surface/60 flex items-center gap-1 rounded-full p-1">
      <Link
        href={href(fy - 1)}
        scroll={false}
        aria-label={t("reports.prevYear")}
        className="text-text-muted hover:bg-white/[0.06] hover:text-foreground flex size-7 items-center justify-center rounded-full transition-colors"
      >
        <ChevronLeft className="size-4" />
      </Link>
      <span className="font-num tnum min-w-[3.5rem] text-center text-sm font-medium">
        {fy}
      </span>
      {atMax ? (
        <span
          aria-disabled="true"
          className="text-text-dim/50 flex size-7 cursor-not-allowed items-center justify-center rounded-full"
        >
          <ChevronRight className="size-4" />
        </span>
      ) : (
        <Link
          href={href(fy + 1)}
          scroll={false}
          aria-label={t("reports.nextYear")}
          className="text-text-muted hover:bg-white/[0.06] hover:text-foreground flex size-7 items-center justify-center rounded-full transition-colors"
        >
          <ChevronRight className="size-4" />
        </Link>
      )}
    </div>
  );
}
