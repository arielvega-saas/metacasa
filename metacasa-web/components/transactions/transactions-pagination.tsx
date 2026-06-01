"use client";

import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/components/i18n/locale-provider";

interface Props {
  page: number; // página actual (1-based)
  pageSize: number;
  total: number; // total de filas filtradas
}

/**
 * Paginación basada en searchParams (?page=N). Muestra el rango visible y
 * permite avanzar/retroceder sin recargar toda la pantalla.
 */
export function TransactionsPagination({ page, pageSize, total }: Props) {
  const t = useT();
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const to = Math.min(page * pageSize, total);

  function goTo(p: number) {
    const next = new URLSearchParams(params.toString());
    if (p <= 1) next.delete("page");
    else next.set("page", String(p));
    const qs = next.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  }

  if (total <= pageSize) {
    // Una sola página: mostramos solo el conteo, sin controles.
    return (
      <p className="text-text-dim text-center text-xs">
        {total === 1
          ? t("transactions.count", { count: total })
          : t("transactions.countPlural", { count: total })}
      </p>
    );
  }

  return (
    <div className="flex items-center justify-between gap-3">
      <p className="text-text-muted text-xs">
        {t("transactions.showing")}{" "}
        <span className="text-foreground tnum font-medium">{from}</span>–
        <span className="text-foreground tnum font-medium">{to}</span>{" "}
        {t("transactions.showingOf")}{" "}
        <span className="text-foreground tnum font-medium">{total}</span>
      </p>
      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => goTo(page - 1)}
          disabled={page <= 1}
          aria-label={t("transactions.prevPage")}
        >
          <ChevronLeft className="size-4" /> {t("transactions.prev")}
        </Button>
        <span className="text-text-muted tnum text-xs">
          {page} / {totalPages}
        </span>
        <Button
          variant="outline"
          size="sm"
          onClick={() => goTo(page + 1)}
          disabled={page >= totalPages}
          aria-label={t("transactions.nextPage")}
        >
          {t("transactions.next")} <ChevronRight className="size-4" />
        </Button>
      </div>
    </div>
  );
}
