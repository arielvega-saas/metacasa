import { Amount } from "./amount";
import { cn } from "@/lib/utils";
import { getT, getLocale } from "@/lib/i18n/server";
import { formatDayMonth } from "@/lib/i18n/dates";
import type { Tables } from "@/lib/database.types";

type Tx = Tables<"transactions">;

export async function TransactionRow({
  tx,
  currency,
  className,
}: {
  tx: Tx;
  currency: string;
  className?: string;
}) {
  const t = await getT();
  const locale = await getLocale();
  const isIncome = tx.type === "INGRESO";
  const letter = (tx.category || "?").charAt(0).toUpperCase();

  return (
    <div className={cn("flex items-center gap-3 py-2.5", className)}>
      <span
        className={cn(
          "flex size-9 shrink-0 items-center justify-center rounded-full text-[13px] font-semibold",
          isIncome ? "bg-income/12 text-income" : "bg-expense/12 text-expense",
        )}
      >
        {letter}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-foreground">
          {tx.category || t("finance.noCategory")}
        </p>
        <p className="text-text-muted truncate text-xs">
          {tx.note?.trim() ? tx.note : formatDayMonth(tx.date, locale)}
        </p>
      </div>
      <Amount
        value={Number(tx.amount)}
        currency={currency}
        kind={isIncome ? "ingreso" : "gasto"}
        className="shrink-0 text-sm font-semibold"
      />
    </div>
  );
}
