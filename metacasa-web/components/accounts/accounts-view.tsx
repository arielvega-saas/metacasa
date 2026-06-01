"use client";

import { useMemo, useState } from "react";
import { Plus, Wallet, MoreVertical, Pencil, Archive } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { Amount } from "@/components/finance/amount";
import { SectionHeader } from "@/components/finance/section-header";
import { PageHeader } from "@/components/layout/page-header";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu";
import { formatMoney } from "@/lib/money";
import { iconForType } from "@/components/accounts/account-icon";
import { AccountDialog } from "@/components/accounts/account-dialog";
import { ArchiveAccountDialog } from "@/components/accounts/archive-account-dialog";
import { useT } from "@/components/i18n/locale-provider";
import type { AccountWithBalance, CreditCard } from "@/lib/db/accounts";

export interface AccountsViewProps {
  /** Cuentas activas con saldo calculado. */
  accounts: AccountWithBalance[];
  /** Detalle de tarjetas indexado por account_id (1:1). */
  creditCards: Record<string, CreditCard>;
  /** Moneda base del hogar (para totalizar y como default en alta). */
  currency: string;
}

/** Estado del diálogo de cuenta: cerrado | crear | editar(cuenta). */
type DialogState =
  | { mode: "closed" }
  | { mode: "create" }
  | { mode: "edit"; account: AccountWithBalance };

/**
 * Pantalla de Cuentas. Server component pasa los datos; acá manejamos los
 * diálogos de alta/edición/archivado y la presentación premium en grilla.
 */
export function AccountsView({
  accounts,
  creditCards,
  currency,
}: AccountsViewProps) {
  const t = useT();
  const [dialog, setDialog] = useState<DialogState>({ mode: "closed" });
  const [toArchive, setToArchive] = useState<AccountWithBalance | null>(null);

  // Total agregado. Mezclar monedas distintas no es exacto, así que solo
  // mostramos el símbolo de la moneda base (es el saldo "consolidado" del hogar).
  const total = useMemo(
    () => accounts.reduce((sum, a) => sum + a.balance, 0),
    [accounts],
  );
  const mixedCurrencies = useMemo(
    () => new Set(accounts.map((a) => a.currency)).size > 1,
    [accounts],
  );

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("accounts.title")}
        description={t("accounts.headerDescription")}
        action={
          <Button onClick={() => setDialog({ mode: "create" })}>
            <Plus />
            {t("accounts.new")}
          </Button>
        }
      />

      {accounts.length === 0 ? (
        <EmptyState
          icon={Wallet}
          title={t("accounts.emptyTitle")}
          description={t("accounts.emptyDescription")}
          action={
            <Button onClick={() => setDialog({ mode: "create" })}>
              <Plus />
              {t("accounts.emptyAction")}
            </Button>
          }
        />
      ) : (
        <>
          {/* Saldo total consolidado */}
          <Card className="sage-glow p-5 sm:p-6">
            <p className="text-text-muted text-sm">{t("accounts.totalBalance")}</p>
            <div className="mt-1.5 flex flex-wrap items-end gap-x-3 gap-y-1">
              <Amount
                value={total}
                currency={currency}
                kind="balance"
                serif
                className="text-3xl sm:text-4xl"
              />
              <span className="text-text-dim pb-1 text-xs">
                {accounts.length}{" "}
                {accounts.length === 1
                  ? t("accounts.countOne")
                  : t("accounts.countOther")}
              </span>
            </div>
            {mixedCurrencies && (
              <p className="text-text-dim mt-2 text-xs">
                {t("accounts.mixedCurrencies", { currency })}
              </p>
            )}
          </Card>

          {/* Grilla de cuentas */}
          <section>
            <SectionHeader title={t("accounts.yourAccounts")} />
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-3">
              {accounts.map((account) => (
                <AccountCard
                  key={account.id}
                  account={account}
                  creditCard={creditCards[account.id] ?? null}
                  baseCurrency={currency}
                  onEdit={() => setDialog({ mode: "edit", account })}
                  onArchive={() => setToArchive(account)}
                />
              ))}
            </div>
          </section>
        </>
      )}

      {/* Diálogo alta/edición (montado según estado para resetear el form) */}
      {dialog.mode !== "closed" && (
        <AccountDialog
          open
          onOpenChange={(o) => !o && setDialog({ mode: "closed" })}
          account={dialog.mode === "edit" ? dialog.account : undefined}
          creditCard={
            dialog.mode === "edit"
              ? (creditCards[dialog.account.id] ?? null)
              : null
          }
          defaultCurrency={currency}
        />
      )}

      {/* Diálogo de archivado */}
      {toArchive && (
        <ArchiveAccountDialog
          open
          onOpenChange={(o) => !o && setToArchive(null)}
          accountId={toArchive.id}
          accountName={toArchive.name}
        />
      )}
    </div>
  );
}

/** Card individual de cuenta con ícono, metadatos, saldo y menú de acciones. */
function AccountCard({
  account,
  creditCard,
  baseCurrency,
  onEdit,
  onArchive,
}: {
  account: AccountWithBalance;
  creditCard: CreditCard | null;
  baseCurrency: string;
  onEdit: () => void;
  onArchive: () => void;
}) {
  const t = useT();
  const Icon = iconForType(account.type);
  const typeLabel = t(`domain.accountTypes.${account.type}`);
  const accountCurrency = account.currency || baseCurrency;

  // Para tarjetas mostramos el uso del crédito (saldo negativo = deuda).
  const isCard = account.type === "credit_card";
  const limit = creditCard ? Number(creditCard.credit_limit) : 0;
  const used = isCard ? Math.max(0, -account.balance) : 0;
  const usagePct =
    isCard && limit > 0 ? Math.min(100, Math.round((used / limit) * 100)) : null;

  // Color de acento opcional: si la cuenta lo define, lo usamos en el ícono.
  const accentStyle = account.color
    ? { color: account.color, backgroundColor: `${account.color}1f` }
    : undefined;

  return (
    <Card className="flex flex-col gap-3 p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-center gap-3">
          <span
            className="bg-primary/10 text-primary flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)]"
            style={accentStyle}
          >
            <Icon className="size-5" />
          </span>
          <div className="min-w-0">
            <p className="truncate font-semibold leading-tight">
              {account.name}
            </p>
            <p className="text-text-muted truncate text-xs">
              {account.institution
                ? `${account.institution} · ${typeLabel}`
                : typeLabel}
            </p>
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="text-text-muted -mr-2 -mt-1 size-10 min-h-11 min-w-11 shrink-0"
              aria-label={t("accounts.cardActions", { name: account.name })}
            >
              <MoreVertical className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent>
            <DropdownMenuItem onSelect={onEdit}>
              <Pencil />
              {t("common.edit")}
            </DropdownMenuItem>
            <DropdownMenuItem destructive onSelect={onArchive}>
              <Archive />
              {t("accounts.archive")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      <div className="mt-auto flex items-end justify-between gap-2">
        <div>
          <p className="text-text-dim text-[11px] uppercase tracking-wider">
            {isCard ? t("accounts.balanceLabel") : t("accounts.availableLabel")}
          </p>
          <Amount
            value={account.balance}
            currency={accountCurrency}
            kind="balance"
            className="text-lg font-semibold"
          />
        </div>
        <Badge variant="outline" className="shrink-0">
          {accountCurrency}
        </Badge>
      </div>

      {/* Uso de crédito para tarjetas con límite cargado */}
      {usagePct !== null && creditCard && (
        <div className="space-y-1.5">
          <div className="bg-inset h-1.5 overflow-hidden rounded-full">
            <div
              className="bg-primary h-full rounded-full"
              style={{ width: `${usagePct}%` }}
            />
          </div>
          <p className="text-text-dim text-[11px]">
            {t("accounts.creditUsage", {
              used: formatMoney(used, accountCurrency),
              limit: formatMoney(limit, accountCurrency),
              day: creditCard.due_day,
            })}
          </p>
        </div>
      )}
    </Card>
  );
}
