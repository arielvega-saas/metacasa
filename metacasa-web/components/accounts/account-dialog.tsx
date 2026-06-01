"use client";

import { useState, useTransition, useId, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { SUPPORTED_CURRENCIES } from "@/lib/constants";
import { parseMoney, symbolFor } from "@/lib/money";
import {
  createAccount,
  updateAccount,
  type AccountInput,
  type CreditCardInput,
} from "@/lib/actions/accounts";
import { useT } from "@/components/i18n/locale-provider";
import type { Account, CreditCard } from "@/lib/db/accounts";

/** Orden de aparición de los tipos en el Select. */
const TYPE_ORDER = [
  "checking",
  "savings",
  "cash",
  "credit_card",
  "investment",
  "loan",
  "other",
] as const;

/** Paleta sage premium para teñir la cuenta (chips de color opcionales). */
const COLOR_SWATCHES = [
  "#B8D4C2", // sage (marca)
  "#E7D3A1", // champagne
  "#7FB3A0", // sage saturado
  "#9DB4FF", // periwinkle
  "#E6A4A0", // coral suave
  "#C9A8E0", // lavanda
] as const;

interface AccountDialogProps {
  /** Controla la apertura desde el padre (lista). */
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Cuenta a editar; si es undefined, el diálogo crea una nueva. */
  account?: Account;
  /** Detalle de tarjeta existente (solo en edición de una tarjeta). */
  creditCard?: CreditCard | null;
  /** Moneda por defecto del hogar (para alta). */
  defaultCurrency: string;
}

/**
 * Diálogo de alta/edición de cuenta. Cuando el tipo es `credit_card` muestra
 * campos extra (límite, día de cierre y de vencimiento) que se guardan en
 * `credit_cards`. Sin estado servidor: delega en las server actions.
 */
export function AccountDialog({
  open,
  onOpenChange,
  account,
  creditCard,
  defaultCurrency,
}: AccountDialogProps) {
  const router = useRouter();
  const t = useT();
  const fieldId = useId();
  const isEdit = Boolean(account);

  // Estado controlado del formulario, inicializado desde la cuenta a editar.
  const [name, setName] = useState(account?.name ?? "");
  const [type, setType] = useState<string>(account?.type ?? "checking");
  const [currency, setCurrency] = useState(
    account?.currency ?? defaultCurrency,
  );
  const [startingBalance, setStartingBalance] = useState(
    account ? String(account.starting_balance) : "",
  );
  const [institution, setInstitution] = useState(account?.institution ?? "");
  const [color, setColor] = useState<string | null>(account?.color ?? null);

  // Campos exclusivos de tarjeta de crédito.
  const [creditLimit, setCreditLimit] = useState(
    creditCard ? String(creditCard.credit_limit) : "",
  );
  const [statementDay, setStatementDay] = useState(
    creditCard ? String(creditCard.statement_day) : "",
  );
  const [dueDay, setDueDay] = useState(
    creditCard ? String(creditCard.due_day) : "",
  );

  const [pending, startTransition] = useTransition();
  const isCard = type === "credit_card";

  function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!name.trim()) {
      toast.error(t("accounts.nameRequired"));
      return;
    }

    const base: AccountInput = {
      name,
      type: type as AccountInput["type"],
      currency,
      startingBalance: parseMoney(startingBalance),
      institution: institution.trim() || null,
      color,
    };

    // Solo armamos el payload de tarjeta si el tipo lo requiere.
    let card: CreditCardInput | undefined;
    if (isCard) {
      card = {
        creditLimit: parseMoney(creditLimit),
        statementDay: Number(statementDay) || 1,
        dueDay: Number(dueDay) || 1,
      };
    }

    startTransition(async () => {
      try {
        if (isEdit && account) {
          await updateAccount(account.id, base, card);
          toast.success(t("accounts.updated"));
        } else {
          await createAccount(base, card);
          toast.success(t("accounts.created"));
        }
        // Refrescar ANTES de cerrar: el padre monta este diálogo de forma
        // condicional ({dialog.mode !== "closed" && ...}); cerrar lo desmonta y
        // abortaría el refresh si fuera después. Con este orden la lista se
        // actualiza sin recargar.
        router.refresh();
        onOpenChange(false);
      } catch (err) {
        toast.error(t("accounts.saveError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {isEdit
              ? t("accounts.dialogEditTitle")
              : t("accounts.dialogCreateTitle")}
          </DialogTitle>
          <DialogDescription>
            {isEdit
              ? t("accounts.dialogEditDescription")
              : t("accounts.dialogCreateDescription")}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={onSubmit} className="space-y-4">
          {/* Nombre */}
          <div className="space-y-1.5">
            <Label htmlFor={`${fieldId}-name`}>{t("accounts.nameLabel")}</Label>
            <Input
              id={`${fieldId}-name`}
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder={t("accounts.namePlaceholder")}
              autoFocus
              required
            />
          </div>

          {/* Tipo + Moneda */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-type`}>{t("accounts.typeLabel")}</Label>
              <Select value={type} onValueChange={setType}>
                <SelectTrigger id={`${fieldId}-type`}>
                  <SelectValue placeholder={t("accounts.typePlaceholder")} />
                </SelectTrigger>
                <SelectContent>
                  {TYPE_ORDER.map((ty) => (
                    <SelectItem key={ty} value={ty}>
                      {t(`domain.accountTypes.${ty}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-currency`}>
                {t("accounts.currencyLabel")}
              </Label>
              <Select value={currency} onValueChange={setCurrency}>
                <SelectTrigger id={`${fieldId}-currency`}>
                  <SelectValue placeholder={t("accounts.currencyPlaceholder")} />
                </SelectTrigger>
                <SelectContent>
                  {SUPPORTED_CURRENCIES.map((c) => (
                    <SelectItem key={c.code} value={c.code}>
                      {c.code} — {t(`domain.currencies.${c.code}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Saldo inicial + Institución */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-balance`}>
                {isCard
                  ? t("accounts.currentBalanceLabel")
                  : t("accounts.startingBalanceLabel")}
              </Label>
              <div className="relative">
                <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                  {symbolFor(currency)}
                </span>
                <Input
                  id={`${fieldId}-balance`}
                  inputMode="decimal"
                  value={startingBalance}
                  onChange={(e) => setStartingBalance(e.target.value)}
                  placeholder="0"
                  className="pl-9 tnum"
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor={`${fieldId}-institution`}>
                {t("accounts.institutionLabel")}{" "}
                <span className="text-text-dim font-normal">
                  {t("accounts.optional")}
                </span>
              </Label>
              <Input
                id={`${fieldId}-institution`}
                value={institution}
                onChange={(e) => setInstitution(e.target.value)}
                placeholder={t("accounts.institutionPlaceholder")}
              />
            </div>
          </div>

          {/* Color (opcional) */}
          <div className="space-y-1.5">
            <Label>
              {t("accounts.colorLabel")}{" "}
              <span className="text-text-dim font-normal">
                {t("accounts.optional")}
              </span>
            </Label>
            <div className="flex flex-wrap items-center gap-2">
              {COLOR_SWATCHES.map((c) => {
                const selected = color === c;
                return (
                  <button
                    key={c}
                    type="button"
                    aria-label={t("accounts.colorSwatch", { color: c })}
                    aria-pressed={selected}
                    onClick={() => setColor(selected ? null : c)}
                    className={
                      "size-7 rounded-full ring-offset-2 ring-offset-card transition-all " +
                      (selected
                        ? "ring-2 ring-ring scale-110"
                        : "hover:scale-110")
                    }
                    style={{ backgroundColor: c }}
                  />
                );
              })}
              {color && (
                <button
                  type="button"
                  onClick={() => setColor(null)}
                  className="text-text-dim hover:text-foreground text-xs underline-offset-2 hover:underline"
                >
                  {t("accounts.removeColor")}
                </button>
              )}
            </div>
          </div>

          {/* Campos extra de tarjeta de crédito */}
          {isCard && (
            <>
              <Separator />
              <p className="text-text-muted text-[13px] font-medium">
                {t("accounts.cardDetail")}
              </p>
              <div className="space-y-1.5">
                <Label htmlFor={`${fieldId}-limit`}>
                  {t("accounts.creditLimitLabel")}
                </Label>
                <div className="relative">
                  <span className="text-text-dim pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-sm">
                    {symbolFor(currency)}
                  </span>
                  <Input
                    id={`${fieldId}-limit`}
                    inputMode="decimal"
                    value={creditLimit}
                    onChange={(e) => setCreditLimit(e.target.value)}
                    placeholder="0"
                    className="pl-9 tnum"
                  />
                </div>
              </div>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label htmlFor={`${fieldId}-statement`}>
                    {t("accounts.statementDayLabel")}
                  </Label>
                  <Input
                    id={`${fieldId}-statement`}
                    type="number"
                    min={1}
                    max={31}
                    value={statementDay}
                    onChange={(e) => setStatementDay(e.target.value)}
                    placeholder={t("accounts.dayRangePlaceholder")}
                    className="tnum"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor={`${fieldId}-due`}>
                    {t("accounts.dueDayLabel")}
                  </Label>
                  <Input
                    id={`${fieldId}-due`}
                    type="number"
                    min={1}
                    max={31}
                    value={dueDay}
                    onChange={(e) => setDueDay(e.target.value)}
                    placeholder={t("accounts.dayRangePlaceholder")}
                    className="tnum"
                  />
                </div>
              </div>
            </>
          )}

          <DialogFooter className="pt-2">
            <DialogClose asChild>
              <Button type="button" variant="ghost" disabled={pending}>
                {t("common.cancel")}
              </Button>
            </DialogClose>
            <Button type="submit" disabled={pending}>
              {pending && <Loader2 className="animate-spin" />}
              {isEdit ? t("common.saveChanges") : t("accounts.createSubmit")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
