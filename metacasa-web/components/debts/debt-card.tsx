"use client";

import * as React from "react";
import {
  MoreVertical,
  Pencil,
  CheckCircle2,
  Trash2,
  Percent,
  CalendarClock,
  Landmark,
} from "lucide-react";
import { format } from "date-fns";
import { parseDayLocal } from "@/lib/i18n/dates";
import { es, enUS, ptBR } from "date-fns/locale";
import type { Locale as DateFnsLocale } from "date-fns";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Amount } from "@/components/finance/amount";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import { formatMoney, formatNumber } from "@/lib/money";
import type { Locale } from "@/lib/i18n/config";
import {
  debtProgress,
  estimatedMonthsToPayoff,
  daysUntilMaturity,
  type Debt,
} from "@/lib/db/debts";

const DATE_LOCALES: Record<Locale, DateFnsLocale> = { es, en: enUS, pt: ptBR };

interface DebtCardProps {
  debt: Debt;
  baseCurrency: string;
  onEdit: () => void;
  onSettle: () => void;
  onDelete: () => void;
}

/**
 * Card de una deuda: acreedor, saldo actual vs original, tasa anual, pago
 * mensual, barra de progreso (% saldado) y vencimiento. Espeja `DebtRow` de iOS
 * (`Features/Debts/DebtsListView.swift`): progreso = (original − saldo)/original.
 */
export function DebtCard({
  debt,
  baseCurrency,
  onEdit,
  onSettle,
  onDelete,
}: DebtCardProps) {
  const t = useT();
  const locale = useLocale();

  const currency = debt.currency || baseCurrency;
  const original = Number(debt.original_amount);
  const balance = Number(debt.current_balance);
  const rate = Number(debt.annual_rate);
  const monthly =
    debt.monthly_payment != null ? Number(debt.monthly_payment) : null;
  const isSettled = debt.status === "settled";

  const ratio = debtProgress(debt);
  const pct = Math.round(ratio * 100);
  const months = estimatedMonthsToPayoff(debt);
  const days = daysUntilMaturity(debt);

  return (
    <Card
      className={`flex flex-col gap-3 p-5${
        isSettled ? " border-income/25" : ""
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <span className="bg-primary/10 text-primary flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)]">
            <Landmark className="size-5" />
          </span>
          <div className="min-w-0">
            <p className="truncate font-semibold leading-tight">
              {debt.creditor}
            </p>
            <p className="text-text-muted flex items-center gap-1 truncate text-xs">
              <Percent className="size-3 shrink-0" />
              {t("debts.annualRate", { rate: formatNumber(rate, 2) })}
              {debt.category ? ` · ${debt.category}` : ""}
            </p>
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="text-text-muted -mr-2 -mt-1 size-10 min-h-11 min-w-11 shrink-0"
              aria-label={t("debts.cardActions", { creditor: debt.creditor })}
            >
              <MoreVertical className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            <DropdownMenuItem onSelect={onEdit}>
              <Pencil />
              {t("common.edit")}
            </DropdownMenuItem>
            {!isSettled && (
              <DropdownMenuItem onSelect={onSettle}>
                <CheckCircle2 />
                {t("debts.settle")}
              </DropdownMenuItem>
            )}
            <DropdownMenuItem destructive onSelect={onDelete}>
              <Trash2 />
              {t("debts.delete")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Saldo actual vs original */}
      <div className="flex items-end justify-between gap-2">
        <div>
          <p className="text-text-dim text-[11px] uppercase tracking-wider">
            {t("debts.balanceLabel")}
          </p>
          <Amount
            value={balance}
            currency={currency}
            kind="gasto"
            className="text-lg font-semibold"
          />
        </div>
        <span className="text-text-muted shrink-0 text-xs">
          {t("debts.ofOriginal", { original: formatMoney(original, currency) })}
        </span>
      </div>

      {/* Progreso saldado */}
      <div className="flex items-center gap-3">
        <Progress
          value={pct}
          indicatorClassName={isSettled ? "bg-income" : "bg-primary"}
          className="flex-1"
          aria-label={t("debts.progressAria", { pct, creditor: debt.creditor })}
        />
        <span className="text-foreground tnum w-10 shrink-0 text-right text-xs font-semibold">
          {pct}%
        </span>
      </div>

      <div className="flex items-center justify-between gap-2 text-xs">
        <span className="text-text-muted">{t("debts.paid")}</span>
        {isSettled ? (
          <Badge variant="income" className="gap-1">
            <CheckCircle2 className="size-3" />
            {t("debts.settledBadge")}
          </Badge>
        ) : monthly != null ? (
          <span className="text-text-muted">
            {t("debts.monthlyPayment", {
              amount: formatMoney(monthly, currency),
            })}
          </span>
        ) : null}
      </div>

      {/* Proyección de pago + vencimiento (solo deudas activas) */}
      {!isSettled && (months != null || debt.maturity_date) && (
        <div className="text-text-dim flex flex-wrap items-center gap-x-3 gap-y-1 border-t border-border pt-2.5 text-[11px]">
          {months != null ? (
            <span className="flex items-center gap-1">
              <CalendarClock className="size-3" />
              {months === 1
                ? t("debts.monthsLeftOne", { n: months })
                : t("debts.monthsLeftOther", { n: months })}
            </span>
          ) : monthly != null ? (
            <span>{t("debts.neverPayoff")}</span>
          ) : null}

          {debt.maturity_date && (
            <span
              className={
                days != null && days < 0 ? "text-expense font-medium" : ""
              }
            >
              {days != null && days < 0
                ? t("debts.overdue")
                : t("debts.maturity", {
                    date: format(
                      parseDayLocal(debt.maturity_date),
                      "d MMM yyyy",
                      { locale: DATE_LOCALES[locale] },
                    ),
                  })}
            </span>
          )}
        </div>
      )}
    </Card>
  );
}
