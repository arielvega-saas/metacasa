"use client";

import * as React from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { isToday, isYesterday } from "date-fns";
import { toast } from "sonner";
import {
  MoreVertical,
  Pencil,
  Trash2,
  Wallet,
  Loader2,
  ArrowLeftRight,
} from "lucide-react";
import { Amount } from "@/components/finance/amount";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { EmptyState } from "@/components/ui/empty-state";
import { ExportButton } from "@/components/export/export-button";
import { QuickAddBar } from "@/components/templates/quick-add-bar";
import { TransactionFormDialog } from "./transaction-form-dialog";
import type { TransactionTemplate } from "@/lib/db/templates";
import { cn } from "@/lib/utils";
import { formatMoney } from "@/lib/money";
import { TX_TYPE } from "@/lib/constants";
import { deleteTransactionAction } from "@/lib/actions/transactions";
import { useT, useLocale } from "@/components/i18n/locale-provider";
import { formatWeekdayLong } from "@/lib/i18n/dates";
import type { Locale } from "@/lib/i18n/config";
import type { Tables } from "@/lib/database.types";

type TFn = ReturnType<typeof useT>;

type Tx = Tables<"transactions">;
type AccountOption = { id: string; name: string };

interface Props {
  rows: Tx[];
  currency: string;
  accounts: AccountOption[];
  categories: { gastos: string[]; ingresos: string[] };
  /** Si la URL trae ?new=1, abrimos el form de alta automáticamente. */
  openNew: boolean;
  /** Atajos rápidos del hogar para la barra de quick-add (puede venir vacía). */
  templates?: TransactionTemplate[];
}

/** Etiqueta legible del grupo de fecha (Hoy / Ayer / "lunes, 5 de mayo"). */
function dateLabel(iso: string, t: TFn, locale: Locale): string {
  const d = new Date(iso);
  if (isToday(d)) return t("transactions.today");
  if (isYesterday(d)) return t("transactions.yesterday");
  return formatWeekdayLong(d, locale);
}

/** Clave de agrupación por día (YYYY-MM-DD). */
function dayKey(iso: string): string {
  return String(iso).slice(0, 10);
}

/** Params de filtro que se llevan a la exportación (NO `page` ni `new`). */
const EXPORT_FILTER_KEYS = [
  "type",
  "category",
  "account",
  "from",
  "to",
  "q",
  "min",
  "max",
] as const;

/**
 * Arma la URL de exportación a Excel con los MISMOS filtros activos en la URL,
 * para que el archivo coincida con lo que se ve en pantalla. Excluye paginación.
 */
function buildExportHref(params: URLSearchParams): string {
  const out = new URLSearchParams();
  for (const k of EXPORT_FILTER_KEYS) {
    const v = params.get(k);
    if (v) out.set(k, v);
  }
  const qs = out.toString();
  return `/api/export/transactions${qs ? `?${qs}` : ""}`;
}

/**
 * Lista premium de movimientos, agrupada por día. Cada fila muestra categoría,
 * cuenta, nota y monto con color por tipo, más un menú para editar/eliminar.
 * Hostea el diálogo de form (alta/edición) y la confirmación de borrado.
 */
export function TransactionList({ rows, currency, accounts, categories, openNew, templates = [] }: Props) {
  const t = useT();
  const locale = useLocale();
  const router = useRouter();
  const searchParams = useSearchParams();
  const exportHref = React.useMemo(
    () => buildExportHref(new URLSearchParams(searchParams.toString())),
    [searchParams],
  );
  const [formOpen, setFormOpen] = React.useState(openNew);
  const [editing, setEditing] = React.useState<Tx | null>(null);
  const [toDelete, setToDelete] = React.useState<Tx | null>(null);
  const [deleting, startDelete] = React.useTransition();

  // Abrir el form cuando la URL pasa a ?new=1 por navegación (no solo en carga
  // inicial). Los botones "Nueva transacción" (header, topbar, FAB mobile)
  // navegan a ?new=1; sin esto el diálogo no abría al clickearlos.
  React.useEffect(() => {
    if (openNew) {
      setEditing(null);
      setFormOpen(true);
    }
  }, [openNew]);

  // Mapa id→nombre para resolver la cuenta de cada movimiento.
  const accountName = React.useMemo(() => {
    const m = new Map<string, string>();
    for (const a of accounts) m.set(a.id, a.name);
    return m;
  }, [accounts]);

  // Agrupa las filas por día preservando el orden (ya vienen desc por fecha).
  const groups = React.useMemo(() => {
    const map = new Map<string, Tx[]>();
    for (const tx of rows) {
      const key = dayKey(tx.date);
      const arr = map.get(key);
      if (arr) arr.push(tx);
      else map.set(key, [tx]);
    }
    return Array.from(map.entries());
  }, [rows]);

  function openCreate() {
    setEditing(null);
    setFormOpen(true);
  }

  function openEdit(tx: Tx) {
    setEditing(tx);
    setFormOpen(true);
  }

  // Al cerrar el form, limpiamos ?new=1 de la URL si estaba.
  function handleFormOpenChange(open: boolean) {
    setFormOpen(open);
    if (!open && openNew) {
      router.replace("/transactions", { scroll: false });
    }
  }

  function confirmDelete() {
    if (!toDelete) return;
    const id = toDelete.id;
    startDelete(async () => {
      try {
        await deleteTransactionAction(id);
        toast.success(t("transactions.deleted"));
        setToDelete(null);
        router.refresh();
      } catch (err) {
        toast.error(err instanceof Error ? err.message : t("transactions.deleteError"));
      }
    });
  }

  if (rows.length === 0) {
    return (
      <>
        {templates.length > 0 && (
          <div className="mb-4">
            <QuickAddBar templates={templates} currency={currency} />
          </div>
        )}
        <EmptyState
          icon={ArrowLeftRight}
          title={t("transactions.emptyTitle")}
          description={t("transactions.emptyDescription")}
          action={<Button onClick={openCreate}>{t("transactions.new")}</Button>}
        />
        <TransactionFormDialog
          open={formOpen}
          onOpenChange={handleFormOpenChange}
          baseCurrency={currency}
          categories={categories}
          accounts={accounts}
          editing={editing}
        />
      </>
    );
  }

  return (
    <>
      {/* Atajos rápidos (quick-add): aplica una plantilla y crea el movimiento de hoy. */}
      {templates.length > 0 && (
        <div className="mb-4">
          <QuickAddBar templates={templates} currency={currency} />
        </div>
      )}

      {/* Barra de acciones de la lista: exportar el filtro actual a Excel. */}
      <div className="mb-3 flex items-center justify-end">
        <ExportButton
          href={exportHref}
          label={t("exportTools.actions.exportExcel")}
          pendingLabel={t("exportTools.actions.exporting")}
        />
      </div>

      <div className="bg-card hairline overflow-hidden rounded-[var(--radius-xl)]">
        {groups.map(([day, txs]) => (
          <div key={day}>
            {/* Encabezado de grupo por día */}
            <div className="bg-surface/60 flex items-center justify-between px-4 py-2 sm:px-5">
              <span className="text-text-muted text-xs font-semibold capitalize tracking-wide">
                {dateLabel(day, t, locale)}
              </span>
              <span className="text-text-dim text-xs">
                {txs.length === 1
                  ? t("transactions.count", { count: txs.length })
                  : t("transactions.countPlural", { count: txs.length })}
              </span>
            </div>

            <ul className="divide-y divide-border">
              {txs.map((tx) => {
                const isIncome = tx.type === TX_TYPE.INCOME;
                const acc = tx.account_id ? accountName.get(tx.account_id) : null;
                const letter = (tx.category || "?").charAt(0).toUpperCase();
                // Si el movimiento tiene moneda original distinta a la base,
                // lo señalamos para dar contexto multi-moneda.
                const foreign =
                  tx.currency_original &&
                  tx.currency_original.toUpperCase() !== currency.toUpperCase();

                return (
                  <li
                    key={tx.id}
                    className="hover:bg-white/[0.02] flex items-center gap-3 px-4 py-3 transition-colors sm:px-5"
                  >
                    {/* Avatar inicial con color por tipo */}
                    <span
                      className={cn(
                        "flex size-10 shrink-0 items-center justify-center rounded-full text-sm font-semibold",
                        isIncome ? "bg-income/12 text-income" : "bg-expense/12 text-expense",
                      )}
                      aria-hidden
                    >
                      {letter}
                    </span>

                    {/* Categoría + meta (cuenta / nota) */}
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="truncate text-sm font-medium text-foreground">
                          {tx.category || t("transactions.noCategory")}
                        </p>
                        {acc && (
                          <Badge variant="neutral" className="hidden sm:inline-flex">
                            <Wallet className="size-3" /> {acc}
                          </Badge>
                        )}
                      </div>
                      <p className="text-text-muted truncate text-xs">
                        {tx.note?.trim() || (acc ? acc : t("transactions.noNote"))}
                      </p>
                    </div>

                    {/* Monto (+ equivalente en moneda original si aplica) */}
                    <div className="shrink-0 text-right">
                      <Amount
                        value={Number(tx.amount)}
                        currency={currency}
                        kind={isIncome ? "ingreso" : "gasto"}
                        className="text-sm font-semibold"
                      />
                      {foreign && (
                        <p className="text-text-dim tnum text-[11px]">
                          {formatMoney(
                            Number(tx.amount_original ?? tx.amount),
                            tx.currency_original!,
                            "precise",
                          )}
                        </p>
                      )}
                    </div>

                    {/* Acciones por fila */}
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="size-10 min-h-11 min-w-11 shrink-0"
                          aria-label={t("transactions.rowActions")}
                        >
                          <MoreVertical className="size-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent>
                        <DropdownMenuItem onClick={() => openEdit(tx)}>
                          <Pencil /> {t("common.edit")}
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem destructive onClick={() => setToDelete(tx)}>
                          <Trash2 /> {t("common.delete")}
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </div>

      {/* Form de alta / edición */}
      <TransactionFormDialog
        open={formOpen}
        onOpenChange={handleFormOpenChange}
        baseCurrency={currency}
        categories={categories}
        accounts={accounts}
        editing={editing}
      />

      {/* Confirmación de borrado */}
      <Dialog open={Boolean(toDelete)} onOpenChange={(o) => !o && setToDelete(null)}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>{t("transactions.deleteTitle")}</DialogTitle>
            <DialogDescription>
              {toDelete ? (
                <>
                  {t("transactions.deleteConfirmPrefix")}
                  <span className="text-foreground font-medium">
                    {toDelete.category || t("transactions.deleteThis")}
                  </span>
                  {t("transactions.deleteConfirmSuffix", {
                    amount: formatMoney(Number(toDelete.amount), currency),
                  })}
                </>
              ) : null}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setToDelete(null)} disabled={deleting}>
              {t("common.cancel")}
            </Button>
            <Button variant="destructive" onClick={confirmDelete} disabled={deleting}>
              {deleting && <Loader2 className="size-4 animate-spin" />}
              {t("common.delete")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
