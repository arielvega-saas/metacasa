"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
  SelectGroup,
  SelectLabel,
} from "@/components/ui/select";
import { cn } from "@/lib/utils";
import { parseMoney, symbolFor, formatMoney } from "@/lib/money";
import { TX_TYPE, SUPPORTED_CURRENCIES, type TxType } from "@/lib/constants";
import { useT } from "@/components/i18n/locale-provider";
import {
  createTransactionAction,
  updateTransactionAction,
  type TxFormInput,
} from "@/lib/actions/transactions";
import type { Tables } from "@/lib/database.types";

type Tx = Tables<"transactions">;
type AccountOption = { id: string; name: string };

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Moneda base del hogar. */
  baseCurrency: string;
  categories: { gastos: string[]; ingresos: string[] };
  accounts: AccountOption[];
  /** Si viene, el form está en modo edición. */
  editing?: Tx | null;
}

const NO_ACCOUNT = "__none__";

/** Hoy en formato YYYY-MM-DD (zona local), default del input de fecha. */
function todayISO(): string {
  const d = new Date();
  const off = d.getTimezoneOffset();
  return new Date(d.getTime() - off * 60_000).toISOString().slice(0, 10);
}

/**
 * Diálogo para crear o editar un movimiento. Toggle gasto/ingreso, monto,
 * categoría, cuenta (opcional), fecha, nota y moneda (con tasa manual si
 * difiere de la base del hogar). Usa las server actions.
 */
export function TransactionFormDialog({
  open,
  onOpenChange,
  baseCurrency,
  categories,
  accounts,
  editing,
}: Props) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = React.useTransition();

  // Estado del formulario.
  const [type, setType] = React.useState<TxType>(TX_TYPE.EXPENSE);
  const [amount, setAmount] = React.useState("");
  const [category, setCategory] = React.useState("");
  const [accountId, setAccountId] = React.useState<string>(NO_ACCOUNT);
  const [date, setDate] = React.useState(todayISO());
  const [note, setNote] = React.useState("");
  const [currency, setCurrency] = React.useState(baseCurrency);
  const [fxRate, setFxRate] = React.useState("1");

  // (Re)inicializa el form cuando se abre o cambia el registro en edición.
  React.useEffect(() => {
    if (!open) return;
    if (editing) {
      setType(editing.type === TX_TYPE.INCOME ? TX_TYPE.INCOME : TX_TYPE.EXPENSE);
      setCategory(editing.category ?? "");
      setAccountId(editing.account_id ?? NO_ACCOUNT);
      setDate((editing.date ?? todayISO()).slice(0, 10));
      setNote(editing.note ?? "");
      const cur = editing.currency_original ?? baseCurrency;
      setCurrency(cur);
      setFxRate(String(editing.fx_rate_to_base ?? 1));
      // Mostramos el monto original (lo que cargó el usuario).
      const orig = editing.amount_original ?? editing.amount;
      setAmount(orig != null ? String(orig) : "");
    } else {
      setType(TX_TYPE.EXPENSE);
      setAmount("");
      setCategory("");
      setAccountId(NO_ACCOUNT);
      setDate(todayISO());
      setNote("");
      setCurrency(baseCurrency);
      setFxRate("1");
    }
  }, [open, editing, baseCurrency]);

  const isIncome = type === TX_TYPE.INCOME;
  const catOptions = isIncome ? categories.ingresos : categories.gastos;
  const differentCurrency = currency.toUpperCase() !== baseCurrency.toUpperCase();
  const parsedAmount = parseMoney(amount);
  const parsedRate = parseMoney(fxRate) || 1;
  // Vista previa del monto convertido a la moneda base.
  const baseEquivalent = differentCurrency ? parsedAmount * parsedRate : parsedAmount;

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (parsedAmount <= 0) {
      toast.error(t("transactions.invalidAmount"));
      return;
    }
    if (!category) {
      toast.error(t("transactions.pickCategory"));
      return;
    }

    const form: TxFormInput = {
      type,
      amount: parsedAmount,
      category,
      accountId: accountId === NO_ACCOUNT ? null : accountId,
      date,
      note: note.trim() || null,
      currency,
      fxRate: differentCurrency ? parsedRate : 1,
    };

    startTransition(async () => {
      try {
        if (editing) {
          await updateTransactionAction(editing.id, form);
          toast.success(t("transactions.updated"));
        } else {
          await createTransactionAction(form);
          toast.success(t("transactions.created"));
        }
        onOpenChange(false);
        router.refresh();
      } catch (err) {
        toast.error(err instanceof Error ? err.message : t("transactions.saveError"));
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {editing ? t("transactions.editTitle") : t("transactions.newTitle")}
          </DialogTitle>
          <DialogDescription>
            {editing
              ? t("transactions.editDescription")
              : t("transactions.newDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Toggle gasto / ingreso */}
          <div
            className="bg-inset hairline grid grid-cols-2 gap-1 rounded-[var(--radius-md)] p-1"
            role="group"
            aria-label={t("transactions.typeGroup")}
          >
            <button
              type="button"
              onClick={() => setType(TX_TYPE.EXPENSE)}
              aria-pressed={!isIncome}
              className={cn(
                "h-9 rounded-[var(--radius-sm)] text-[13px] font-semibold transition-colors",
                !isIncome ? "bg-expense/15 text-expense" : "text-text-muted hover:text-foreground",
              )}
            >
              {t("transactions.expenseToggle")}
            </button>
            <button
              type="button"
              onClick={() => setType(TX_TYPE.INCOME)}
              aria-pressed={isIncome}
              className={cn(
                "h-9 rounded-[var(--radius-sm)] text-[13px] font-semibold transition-colors",
                isIncome ? "bg-income/15 text-income" : "text-text-muted hover:text-foreground",
              )}
            >
              {t("transactions.incomeToggle")}
            </button>
          </div>

          {/* Monto + moneda */}
          <div className="space-y-1.5">
            <Label htmlFor="tx-amount">{t("transactions.amountLabel")}</Label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id="tx-amount"
                  inputMode="decimal"
                  autoComplete="off"
                  placeholder="0,00"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="pl-10"
                />
              </div>
              <Select value={currency} onValueChange={setCurrency}>
                <SelectTrigger className="w-28 shrink-0" aria-label={t("transactions.currencyLabel")}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectGroup>
                    <SelectLabel>{t("transactions.currencyLabel")}</SelectLabel>
                    {SUPPORTED_CURRENCIES.map((c) => (
                      <SelectItem key={c.code} value={c.code}>
                        {c.code}
                      </SelectItem>
                    ))}
                  </SelectGroup>
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Tasa manual: solo si la moneda difiere de la base */}
          {differentCurrency && (
            <div className="space-y-1.5">
              <Label htmlFor="tx-fx">
                {t("transactions.fxLabel", { currency: baseCurrency.toUpperCase() })}
              </Label>
              <Input
                id="tx-fx"
                inputMode="decimal"
                autoComplete="off"
                placeholder="1,00"
                value={fxRate}
                onChange={(e) => setFxRate(e.target.value)}
              />
              <p className="text-text-dim text-xs">
                {t("transactions.fxHint", {
                  amount: formatMoney(baseEquivalent, baseCurrency, "precise"),
                })}
              </p>
            </div>
          )}

          {/* Categoría */}
          <div className="space-y-1.5">
            <Label>{t("transactions.categoryLabel")}</Label>
            <Select value={category} onValueChange={setCategory}>
              <SelectTrigger aria-label={t("transactions.categoryLabel")}>
                <SelectValue placeholder={t("transactions.categoryPlaceholder")} />
              </SelectTrigger>
              <SelectContent>
                {catOptions.length === 0 ? (
                  <div className="text-text-dim px-3 py-2 text-sm">
                    {isIncome
                      ? t("transactions.noCategoriesIncome")
                      : t("transactions.noCategoriesExpense")}
                  </div>
                ) : (
                  <SelectGroup>
                    <SelectLabel>
                      {isIncome ? t("transactions.incomeGroup") : t("transactions.expenseGroup")}
                    </SelectLabel>
                    {catOptions.map((c) => (
                      <SelectItem key={c} value={c}>
                        {c}
                      </SelectItem>
                    ))}
                  </SelectGroup>
                )}
              </SelectContent>
            </Select>
          </div>

          {/* Cuenta (opcional) + fecha */}
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label>{t("transactions.accountOptionalLabel")}</Label>
              <Select value={accountId} onValueChange={setAccountId}>
                <SelectTrigger aria-label={t("transactions.accountLabel")}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={NO_ACCOUNT}>{t("transactions.noAccount")}</SelectItem>
                  {accounts.length > 0 && (
                    <SelectGroup>
                      <SelectLabel>{t("transactions.accountsGroup")}</SelectLabel>
                      {accounts.map((a) => (
                        <SelectItem key={a.id} value={a.id}>
                          {a.name}
                        </SelectItem>
                      ))}
                    </SelectGroup>
                  )}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="tx-date">{t("transactions.dateLabel")}</Label>
              <Input
                id="tx-date"
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
              />
            </div>
          </div>

          {/* Nota */}
          <div className="space-y-1.5">
            <Label htmlFor="tx-note">{t("transactions.noteLabel")}</Label>
            <Input
              id="tx-note"
              autoComplete="off"
              placeholder={t("transactions.notePlaceholder")}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={140}
            />
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="ghost"
              onClick={() => onOpenChange(false)}
              disabled={pending}
            >
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={pending}>
              {pending && <Loader2 className="size-4 animate-spin" />}
              {editing ? t("transactions.saveChanges") : t("transactions.createTx")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
