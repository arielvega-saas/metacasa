"use client";

import * as React from "react";
import { toast } from "sonner";
import { MoreHorizontal, Pencil, Trash2 } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
} from "@/components/ui/dropdown-menu";
import { AllocationDialog } from "@/components/budgets/allocation-dialog";
import { removeAllocation } from "@/lib/actions/budgets";
import { useT } from "@/components/i18n/locale-provider";

interface AllocationRowMenuProps {
  allocationId: string;
  periodId: string;
  currency: string;
  category: string;
  allocated: number;
  categories: string[];
}

/** Menú contextual de un sobre: editar (reabre el diálogo) o eliminar. */
export function AllocationRowMenu({
  allocationId,
  periodId,
  currency,
  category,
  allocated,
  categories,
}: AllocationRowMenuProps) {
  const t = useT();
  const [editOpen, setEditOpen] = React.useState(false);
  const [pending, startTransition] = React.useTransition();

  function handleDelete() {
    startTransition(async () => {
      try {
        await removeAllocation(allocationId, periodId);
        toast.success(t("budgets.envelopeDeleted"));
      } catch (err) {
        toast.error(
          err instanceof Error ? err.message : t("budgets.deleteEnvelopeError"),
        );
      }
    });
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button
            type="button"
            disabled={pending}
            aria-label={t("budgets.rowActions", { category })}
            className="text-text-muted hover:text-foreground hover:bg-tint-2 flex size-8 items-center justify-center rounded-[var(--radius-md)] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring/40 disabled:opacity-50"
          >
            <MoreHorizontal className="size-4" />
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent>
          <DropdownMenuItem onSelect={() => setEditOpen(true)}>
            <Pencil />
            {t("budgets.editAllocation")}
          </DropdownMenuItem>
          <DropdownMenuItem destructive onSelect={handleDelete}>
            <Trash2 />
            {t("budgets.deleteEnvelope")}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      {/* Diálogo de edición controlado desde el menú. */}
      <AllocationDialog
        periodId={periodId}
        currency={currency}
        categories={categories}
        assignedCategories={[]}
        edit={{ category, allocated }}
        open={editOpen}
        onOpenChange={setEditOpen}
        hideTrigger
      />
    </>
  );
}
