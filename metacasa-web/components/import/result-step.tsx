"use client";

import Link from "next/link";
import { CheckCircle2, AlertTriangle, FileUp } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/components/i18n/locale-provider";
import type { ImportResult } from "@/lib/actions/import";

interface Props {
  result: ImportResult;
  onImportMore: () => void;
}

/** Paso 4: resultado de la importación (éxito total / parcial / nada). */
export function ResultStep({ result, onImportMore }: Props) {
  const t = useT();
  const ok = result.inserted > 0;
  const partial = ok && result.skipped > 0;

  return (
    <div className="flex flex-col items-center py-8 text-center">
      <span
        className={
          ok
            ? "bg-income/15 text-income flex size-14 items-center justify-center rounded-full"
            : "bg-champagne/15 text-champagne flex size-14 items-center justify-center rounded-full"
        }
      >
        {ok ? (
          <CheckCircle2 className="size-7" />
        ) : (
          <AlertTriangle className="size-7" />
        )}
      </span>

      <h2 className="mt-4 text-lg font-semibold">
        {ok ? t("importTools.successTitle") : t("importTools.nothingImported")}
      </h2>

      {ok && (
        <p className="text-text-muted mt-1 max-w-md text-sm">
          {partial
            ? t("importTools.partialBody", {
                inserted: result.inserted,
                skipped: result.skipped,
              })
            : t("importTools.successBody", { inserted: result.inserted })}
        </p>
      )}

      <div className="mt-6 flex flex-wrap items-center justify-center gap-2">
        {ok && (
          <Button asChild>
            <Link href="/transactions">{t("importTools.viewTransactions")}</Link>
          </Button>
        )}
        <Button type="button" variant={ok ? "secondary" : "default"} onClick={onImportMore}>
          <FileUp className="size-4" />
          {t("importTools.importMore")}
        </Button>
      </div>
    </div>
  );
}
