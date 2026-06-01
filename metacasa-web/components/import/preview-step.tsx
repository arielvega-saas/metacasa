"use client";

import * as React from "react";
import { ArrowLeft, ArrowDownLeft, ArrowUpRight, Loader2, AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { formatMoney } from "@/lib/money";
import { TX_TYPE } from "@/lib/constants";
import { useT } from "@/components/i18n/locale-provider";
import { useLocale } from "@/components/i18n/locale-provider";
import { cn } from "@/lib/utils";
import type { ResolvedRow } from "./resolve";
import type { AccountOption } from "./types";

const DATE_TAG: Record<string, string> = { es: "es-AR", en: "en-US", pt: "pt-BR" };

interface Props {
  resolved: ResolvedRow[];
  baseCurrency: string;
  accounts: AccountOption[];
  /** Filas (índices originales) seleccionadas para importar. */
  selected: Set<number>;
  onToggle: (index: number) => void;
  onToggleAll: (select: boolean) => void;
  pending: boolean;
  onBack: () => void;
  onConfirm: () => void;
}

/** Paso 3: tabla editable de la importación; destildar filas + confirmar. */
export function PreviewStep({
  resolved,
  baseCurrency,
  accounts,
  selected,
  onToggle,
  onToggleAll,
  pending,
  onBack,
  onConfirm,
}: Props) {
  const t = useT();
  const locale = useLocale();
  const accountName = React.useMemo(() => {
    const m = new Map(accounts.map((a) => [a.id, a.name]));
    return (id: string | null) => (id ? (m.get(id) ?? "—") : "—");
  }, [accounts]);

  const validRows = resolved.filter((r) => r.error == null);
  const invalidCount = resolved.length - validRows.length;
  const selectedCount = validRows.filter((r) => selected.has(r.index)).length;
  const allSelected = validRows.length > 0 && selectedCount === validRows.length;

  const fmtDate = (iso: string | null) => {
    if (!iso) return "—";
    // iso es YYYY-MM-DD; renderizamos a mediodía UTC para no correr el día.
    return new Date(`${iso}T12:00:00.000Z`).toLocaleDateString(
      DATE_TAG[locale] ?? "en-US",
      { day: "2-digit", month: "short", year: "numeric" },
    );
  };

  if (validRows.length === 0) {
    return (
      <div className="space-y-5">
        <div className="bg-champagne/10 text-champagne flex items-start gap-2 rounded-[var(--radius-md)] px-4 py-3 text-sm">
          <AlertTriangle className="mt-0.5 size-4 shrink-0" />
          <span>{t("importTools.noValidRows")}</span>
        </div>
        <Button type="button" variant="ghost" onClick={onBack}>
          <ArrowLeft className="size-4" />
          {t("importTools.backToMapping")}
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Encabezado: counts + seleccionar/quitar todo */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="neutral">
            {t("importTools.selectedCount", {
              selected: selectedCount,
              total: validRows.length,
            })}
          </Badge>
          {invalidCount > 0 && (
            <Badge variant="warning">
              {t("importTools.invalidRowsNote", { count: invalidCount })}
            </Badge>
          )}
        </div>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={() => onToggleAll(!allSelected)}
        >
          {allSelected ? t("importTools.deselectAll") : t("importTools.selectAll")}
        </Button>
      </div>

      {/* Tabla de filas resueltas */}
      <div className="hairline overflow-x-auto rounded-[var(--radius-lg)]">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-text-dim border-b border-border text-left text-xs">
              <th className="w-10 px-3 py-2.5" />
              <th className="px-3 py-2.5 font-medium">{t("importTools.colDate")}</th>
              <th className="px-3 py-2.5 font-medium">{t("importTools.colType")}</th>
              <th className="px-3 py-2.5 font-medium">{t("importTools.colCategory")}</th>
              <th className="hidden px-3 py-2.5 font-medium sm:table-cell">
                {t("importTools.colAccount")}
              </th>
              <th className="px-3 py-2.5 text-right font-medium">
                {t("importTools.colAmount")}
              </th>
              <th className="hidden px-3 py-2.5 font-medium md:table-cell">
                {t("importTools.colNote")}
              </th>
            </tr>
          </thead>
          <tbody>
            {resolved.map((r) => {
              const invalid = r.error != null;
              const checked = !invalid && selected.has(r.index);
              const isIncome = r.type === TX_TYPE.INCOME;
              return (
                <tr
                  key={r.index}
                  className={cn(
                    "border-b border-border/60 last:border-0",
                    invalid && "opacity-50",
                    !invalid && !checked && "opacity-60",
                  )}
                >
                  <td className="px-3 py-2.5">
                    <input
                      type="checkbox"
                      className="accent-primary size-4 cursor-pointer disabled:cursor-not-allowed"
                      checked={checked}
                      disabled={invalid}
                      aria-label={`row-${r.index}`}
                      onChange={() => onToggle(r.index)}
                    />
                  </td>
                  <td className="text-text-muted whitespace-nowrap px-3 py-2.5">
                    {invalid && r.error === "date" ? (
                      <span className="text-expense text-xs">
                        {t("importTools.rowErrorDate")}
                      </span>
                    ) : (
                      fmtDate(r.date)
                    )}
                  </td>
                  <td className="px-3 py-2.5">
                    <span
                      className={cn(
                        "inline-flex items-center gap-1 text-xs font-medium",
                        isIncome ? "text-income" : "text-expense",
                      )}
                    >
                      {isIncome ? (
                        <ArrowDownLeft className="size-3.5" />
                      ) : (
                        <ArrowUpRight className="size-3.5" />
                      )}
                      {isIncome
                        ? t("importTools.typeIncome")
                        : t("importTools.typeExpense")}
                    </span>
                  </td>
                  <td className="text-text-muted px-3 py-2.5">{r.category}</td>
                  <td className="text-text-muted hidden px-3 py-2.5 sm:table-cell">
                    {accountName(r.accountId)}
                  </td>
                  <td className="px-3 py-2.5 text-right font-medium tabular-nums">
                    {invalid && r.error === "amount" ? (
                      <span className="text-expense text-xs">
                        {t("importTools.rowErrorAmount")}
                      </span>
                    ) : r.amount != null ? (
                      <span className={isIncome ? "text-income" : "text-foreground"}>
                        {formatMoney(r.amount, baseCurrency, "precise")}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="text-text-dim hidden max-w-[200px] truncate px-3 py-2.5 md:table-cell">
                    {r.note ?? ""}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
        <Button type="button" variant="ghost" onClick={onBack} disabled={pending}>
          <ArrowLeft className="size-4" />
          {t("importTools.backToMapping")}
        </Button>
        <Button
          type="button"
          onClick={onConfirm}
          disabled={pending || selectedCount === 0}
        >
          {pending && <Loader2 className="size-4 animate-spin" />}
          {selectedCount === 1
            ? t("importTools.importOne")
            : t("importTools.importSelected", { count: selectedCount })}
        </Button>
      </div>
    </div>
  );
}
