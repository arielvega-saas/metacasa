"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Plus,
  Zap,
  Pencil,
  Trash2,
  Loader2,
  ArrowDownLeft,
  ArrowUpRight,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { Amount } from "@/components/finance/amount";
import { PageHeader } from "@/components/layout/page-header";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogFooter,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { TemplateDialog } from "@/components/templates/template-dialog";
import { cn } from "@/lib/utils";
import { TX_TYPE } from "@/lib/constants";
import { applyTemplate, deleteTemplate } from "@/lib/actions/templates";
import { useT } from "@/components/i18n/locale-provider";
import type { TransactionTemplate } from "@/lib/db/templates";

export interface TemplatesViewProps {
  templates: TransactionTemplate[];
  categories: { gastos: string[]; ingresos: string[] };
  currency: string;
}

type DialogState =
  | { mode: "closed" }
  | { mode: "create" }
  | { mode: "edit"; item: TransactionTemplate };

/**
 * Pantalla de Atajos rápidos (plantillas). Grid de tarjetas: tocar una aplica la
 * plantilla y crea el movimiento de HOY (toast "movimiento creado"). El modo
 * "Administrar" revela los botones de editar/eliminar por tarjeta y el alta.
 */
export function TemplatesView({
  templates,
  categories,
  currency,
}: TemplatesViewProps) {
  const t = useT();
  const [dialog, setDialog] = useState<DialogState>({ mode: "closed" });
  const [toDelete, setToDelete] = useState<TransactionTemplate | null>(null);
  const [manage, setManage] = useState(false);

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("templates.title")}
        description={t("templates.description")}
        action={
          <div className="flex items-center gap-2">
            {templates.length > 0 && (
              <Button
                variant="ghost"
                onClick={() => setManage((m) => !m)}
                aria-pressed={manage}
              >
                {manage ? t("templates.done") : t("templates.manage")}
              </Button>
            )}
            <Button onClick={() => setDialog({ mode: "create" })}>
              <Plus />
              {t("templates.new")}
            </Button>
          </div>
        }
      />

      {templates.length === 0 ? (
        <EmptyState
          icon={Zap}
          title={t("templates.emptyTitle")}
          description={t("templates.emptyDescription")}
          action={
            <Button onClick={() => setDialog({ mode: "create" })}>
              <Plus />
              {t("templates.emptyAction")}
            </Button>
          }
        />
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-4">
          {templates.map((item) => (
            <TemplateCard
              key={item.id}
              item={item}
              currency={currency}
              manage={manage}
              onEdit={() => setDialog({ mode: "edit", item })}
              onDelete={() => setToDelete(item)}
            />
          ))}
        </div>
      )}

      {dialog.mode !== "closed" && (
        <TemplateDialog
          open
          onOpenChange={(o) => !o && setDialog({ mode: "closed" })}
          template={dialog.mode === "edit" ? dialog.item : undefined}
          categories={categories}
          currency={currency}
        />
      )}

      {toDelete && (
        <DeleteTemplateDialog
          item={toDelete}
          onClose={() => setToDelete(null)}
        />
      )}
    </div>
  );
}

/**
 * Tarjeta individual de atajo. En modo normal, toda la tarjeta es un botón que
 * aplica la plantilla (crea el movimiento de hoy). En modo "Administrar",
 * aparecen los controles de editar/eliminar y el tap deja de aplicar.
 */
function TemplateCard({
  item,
  currency,
  manage,
  onEdit,
  onDelete,
}: {
  item: TransactionTemplate;
  currency: string;
  manage: boolean;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const isIncome = item.type === TX_TYPE.INCOME;
  const Icon = isIncome ? ArrowDownLeft : ArrowUpRight;

  function apply() {
    if (manage || pending) return;
    startTransition(async () => {
      try {
        await applyTemplate(item.id);
        toast.success(t("templates.applied"), { description: item.name });
        router.refresh();
      } catch (err) {
        toast.error(t("templates.applyError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Card
      className={cn(
        "relative flex min-h-[8rem] flex-col gap-2 p-4 transition-colors",
        !manage &&
          "cursor-pointer hover:bg-white/[0.03] focus-within:ring-2 focus-within:ring-sage/40",
        pending && "opacity-60",
      )}
    >
      {/* La tarjeta entera es accionable cuando no estamos administrando. */}
      {!manage ? (
        <button
          type="button"
          onClick={apply}
          disabled={pending}
          aria-label={t("templates.applyHint")}
          className="absolute inset-0 z-0 rounded-[inherit]"
        />
      ) : null}

      <div className="pointer-events-none relative z-10 flex items-start justify-between gap-2">
        <span
          className={cn(
            "flex size-10 shrink-0 items-center justify-center rounded-[var(--radius-md)] text-lg",
            isIncome ? "bg-income/12 text-income" : "bg-expense/12 text-expense",
          )}
          aria-hidden
        >
          {item.emoji?.trim() ? item.emoji : <Icon className="size-5" />}
        </span>
        {pending && (
          <Loader2 className="text-text-muted size-4 animate-spin" aria-hidden />
        )}
      </div>

      <div className="pointer-events-none relative z-10 min-w-0">
        <p className="truncate text-sm font-semibold leading-tight">
          {item.name}
        </p>
        <p className="text-text-muted truncate text-xs">{item.category}</p>
      </div>

      <div className="pointer-events-none relative z-10 mt-auto flex items-center justify-between gap-2">
        <Amount
          value={Number(item.amount)}
          currency={item.currency || currency}
          kind={isIncome ? "ingreso" : "gasto"}
          className="text-sm font-semibold"
        />
        <Badge variant={isIncome ? "income" : "expense"} className="shrink-0">
          {isIncome ? t("templates.incomeToggle") : t("templates.expenseToggle")}
        </Badge>
      </div>

      {/* Controles de administración (por encima del botón de aplicar). */}
      {manage && (
        <div className="relative z-10 mt-1 flex items-center gap-2 border-t border-border pt-2">
          <Button
            variant="ghost"
            size="sm"
            className="h-9 min-h-11 flex-1"
            onClick={onEdit}
          >
            <Pencil className="size-4" /> {t("common.edit")}
          </Button>
          <Button
            variant="ghost"
            size="sm"
            className="text-expense hover:text-expense h-9 min-h-11 flex-1"
            onClick={onDelete}
          >
            <Trash2 className="size-4" /> {t("common.delete")}
          </Button>
        </div>
      )}
    </Card>
  );
}

/** Confirmación de borrado de un atajo. */
function DeleteTemplateDialog({
  item,
  onClose,
}: {
  item: TransactionTemplate;
  onClose: () => void;
}) {
  const t = useT();
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  function confirm() {
    startTransition(async () => {
      try {
        await deleteTemplate(item.id);
        toast.success(t("templates.deleted"));
        onClose();
        router.refresh();
      } catch (err) {
        toast.error(t("templates.deleteError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t("templates.deleteTitle")}</DialogTitle>
          <DialogDescription>
            {t("templates.deleteConfirm", { name: item.name })}
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="ghost" onClick={onClose} disabled={pending}>
            {t("common.cancel")}
          </Button>
          <Button variant="destructive" onClick={confirm} disabled={pending}>
            {pending && <Loader2 className="size-4 animate-spin" />}
            {t("common.delete")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
