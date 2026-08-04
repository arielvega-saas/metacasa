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
import { Checkbox } from "@/components/ui/checkbox";
import { ExportButton } from "@/components/export/export-button";
import { QuickAddBar } from "@/components/templates/quick-add-bar";
import { TransactionFormDialog } from "./transaction-form-dialog";
import { BulkActionsBar } from "./bulk-actions-bar";
import { useListShortcuts } from "./use-list-shortcuts";
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

/**
 * Convierte `YYYY-MM-DD` en una fecha a medianoche **local**.
 *
 * `new Date("2026-08-03")` NO hace esto: el string de sólo-fecha lo interpreta el
 * runtime como medianoche **UTC**, y al formatearlo en un huso negativo —toda
 * LatAm— retrocede un día. Los movimientos se agrupaban bajo el día anterior: uno
 * cargado hoy aparecía como "Ayer", y los del lunes bajo "domingo".
 */
function parseDayLocal(iso: string): Date {
  const [y, m, d] = String(iso).slice(0, 10).split("-").map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

/** Etiqueta legible del grupo de fecha (Hoy / Ayer / "lunes, 5 de mayo"). */
function dateLabel(iso: string, t: TFn, locale: Locale): string {
  const d = parseDayLocal(iso);
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

  // Borrado optimista: la fila desaparece apenas confirmás, sin esperar el
  // round-trip a Supabase. Si la server action falla, React descarta el estado
  // optimista al terminar la transición y la fila vuelve sola (+ toast).
  const [visibleRows, removeRowOptimistic] = React.useOptimistic(
    rows,
    (state: Tx[], deletedId: string) => state.filter((r) => r.id !== deletedId),
  );

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
  // Cada grupo lleva el índice global de su primera fila: los atajos de teclado
  // numeran sobre `visibleRows`, que es plano, y así el offset no hay que
  // recalcularlo buscando en el array al pintar cada fila.
  const groups = React.useMemo(() => {
    const map = new Map<string, Tx[]>();
    for (const tx of visibleRows) {
      const key = dayKey(tx.date);
      const arr = map.get(key);
      if (arr) arr.push(tx);
      else map.set(key, [tx]);
    }
    let offset = 0;
    return Array.from(map.entries()).map(([day, txs]) => {
      const grupo = { day, txs, offset };
      offset += txs.length;
      return grupo;
    });
  }, [visibleRows]);

  // Selección múltiple. Se guarda por id (no por índice) para que sobreviva a
  // que la lista se reordene o a un borrado optimista.
  const [selected, setSelected] = React.useState<Set<string>>(() => new Set());

  // Si una fila deja de existir (borrado, cambio de filtro), su id no puede
  // quedar seleccionado: la barra contaría movimientos que ya no están.
  React.useEffect(() => {
    setSelected((prev) => {
      if (prev.size === 0) return prev;
      const vivos = new Set(visibleRows.map((r) => r.id));
      const next = new Set([...prev].filter((id) => vivos.has(id)));
      return next.size === prev.size ? prev : next;
    });
  }, [visibleRows]);

  const toggleOne = React.useCallback((id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  const setMany = React.useCallback((ids: string[], on: boolean) => {
    setSelected((prev) => {
      const next = new Set(prev);
      for (const id of ids) {
        if (on) next.add(id);
        else next.delete(id);
      }
      return next;
    });
  }, []);

  const clearSelection = React.useCallback(() => setSelected(new Set()), []);

  const allIds = React.useMemo(() => visibleRows.map((r) => r.id), [visibleRows]);
  const allSelected = selected.size > 0 && selected.size === allIds.length;
  const someSelected = selected.size > 0 && !allSelected;

  // Atajos de teclado. El índice es sobre `visibleRows`, que es el mismo orden en
  // que se pintan los grupos por día, así que numerar las filas al renderizar
  // alcanza para que ↑/↓ y el resaltado coincidan.
  const { activeIndex, setActiveIndex } = useListShortcuts({
    count: visibleRows.length,
    searchInputId: "flt-q",
    onNew: openCreate,
    onOpen: (i) => {
      const tx = visibleRows[i];
      if (tx) openEdit(tx);
    },
    onToggleSelect: (i) => {
      const tx = visibleRows[i];
      if (tx) toggleOne(tx.id);
    },
    onClearSelection: clearSelection,
  });

  // Traer a la vista la fila activa cuando se navega con el teclado.
  React.useEffect(() => {
    if (activeIndex < 0) return;
    const el = document.querySelector<HTMLElement>(`[data-tx-index="${activeIndex}"]`);
    el?.scrollIntoView({ block: "nearest" });
  }, [activeIndex]);

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
    // Cerramos el diálogo ya: la confirmación visual es que la fila se va.
    setToDelete(null);
    startDelete(async () => {
      removeRowOptimistic(id);
      try {
        await deleteTransactionAction(id);
        toast.success(t("transactions.deleted"));
        router.refresh();
      } catch (err) {
        // Al salir de la transición React revierte el estado optimista y la
        // fila reaparece: sólo hace falta avisar por qué.
        toast.error(err instanceof Error ? err.message : t("transactions.deleteError"));
      }
    });
  }

  if (visibleRows.length === 0) {
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

      {/* Barra de acciones de la lista: seleccionar todo + exportar el filtro actual. */}
      <div className="mb-3 flex items-center justify-between gap-3">
        <label className="text-text-muted flex cursor-pointer items-center gap-2 text-xs">
          <Checkbox
            checked={allSelected}
            indeterminate={someSelected}
            onChange={(e) => setMany(allIds, e.target.checked)}
            aria-label={t("transactions.selectAll")}
          />
          {t("transactions.selectAll")}
        </label>
        <ExportButton
          href={exportHref}
          label={t("exportTools.actions.exportExcel")}
          pendingLabel={t("exportTools.actions.exporting")}
        />
      </div>

      <div className="bg-card hairline overflow-hidden rounded-[var(--radius-xl)]">
        {groups.map(({ day, txs, offset }) => {
          const dayIds = txs.map((tx) => tx.id);
          const dayAllSelected = dayIds.every((id) => selected.has(id));
          const daySomeSelected = !dayAllSelected && dayIds.some((id) => selected.has(id));
          return (
          <div key={day}>
            {/* Encabezado de grupo por día */}
            <div className="bg-surface/60 flex items-center justify-between px-4 py-2 sm:px-5">
              <label className="flex cursor-pointer items-center gap-2">
                <Checkbox
                  checked={dayAllSelected}
                  indeterminate={daySomeSelected}
                  onChange={(e) => setMany(dayIds, e.target.checked)}
                  aria-label={t("transactions.selectDay")}
                />
                <span className="text-text-muted text-xs font-semibold capitalize tracking-wide">
                  {dateLabel(day, t, locale)}
                </span>
              </label>
              <span className="text-text-dim text-xs">
                {txs.length === 1
                  ? t("transactions.count", { count: txs.length })
                  : t("transactions.countPlural", { count: txs.length })}
              </span>
            </div>

            <ul className="divide-y divide-border">
              {txs.map((tx, i) => {
                const index = offset + i;
                const isActive = index === activeIndex;
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
                    data-tx-index={index}
                    onMouseEnter={() => setActiveIndex(index)}
                    className={cn(
                      "hover:bg-tint-1 flex items-center gap-3 px-4 py-3 transition-colors sm:px-5",
                      selected.has(tx.id) && "bg-tint-1",
                      isActive && "ring-ring/40 relative z-10 ring-2 ring-inset",
                    )}
                  >
                    <Checkbox
                      checked={selected.has(tx.id)}
                      onChange={() => toggleOne(tx.id)}
                      aria-label={t("transactions.selectRow")}
                    />

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
          );
        })}
      </div>

      <BulkActionsBar
        ids={[...selected]}
        accounts={accounts}
        categories={categories}
        onClear={clearSelection}
      />

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
