"use client";

import { useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import {
  Plus,
  Check,
  X,
  Pencil,
  Trash2,
  Loader2,
  TrendingDown,
  TrendingUp,
  RotateCcw,
  type LucideIcon,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { PageHeader } from "@/components/layout/page-header";
import { EmptyState } from "@/components/ui/empty-state";
import { cn } from "@/lib/utils";
import { saveCategories } from "@/lib/actions/categories";
import { useT } from "@/components/i18n/locale-provider";
import type { CategoryData } from "@/lib/db/categories";

/** Set por defecto razonable cuando el hogar no tiene categorías cargadas. */
export const DEFAULT_CATEGORIES: Required<
  Pick<CategoryData, "gastos" | "ingresos">
> = {
  gastos: [
    "Supermercado",
    "Alquiler",
    "Servicios",
    "Transporte",
    "Restaurantes",
    "Salud",
    "Ocio",
  ],
  ingresos: ["Sueldo", "Freelance", "Inversiones"],
};

/** Las dos colecciones editables. */
type Kind = "gastos" | "ingresos";

interface CategoriesViewProps {
  /** Categorías iniciales (ya con defaults aplicados en el server). */
  initial: { gastos: string[]; ingresos: string[] };
}

/**
 * Editor de categorías del hogar. Mantiene un borrador en cliente (agregar,
 * renombrar, eliminar) y persiste el jsonb completo con una sola server action.
 * El botón de guardar solo se habilita si hay cambios sin guardar.
 */
export function CategoriesView({ initial }: CategoriesViewProps) {
  const router = useRouter();
  const t = useT();
  const [gastos, setGastos] = useState<string[]>(initial.gastos);
  const [ingresos, setIngresos] = useState<string[]>(initial.ingresos);
  const [pending, startTransition] = useTransition();

  // Snapshot inicial para detectar cambios sin guardar (dirty state).
  const baseline = useRef(JSON.stringify(initial));
  const isDirty = useMemo(
    () => JSON.stringify({ gastos, ingresos }) !== baseline.current,
    [gastos, ingresos],
  );

  const setters: Record<Kind, (next: string[]) => void> = {
    gastos: setGastos,
    ingresos: setIngresos,
  };
  const lists: Record<Kind, string[]> = { gastos, ingresos };

  /** ¿El nombre ya existe en esa colección? (case-insensitive). */
  function exists(kind: Kind, name: string, exceptIndex?: number): boolean {
    const target = name.trim().toLowerCase();
    return lists[kind].some(
      (c, i) => i !== exceptIndex && c.toLowerCase() === target,
    );
  }

  function addCategory(kind: Kind, name: string): boolean {
    const clean = name.trim();
    if (!clean) return false;
    if (exists(kind, clean)) {
      toast.error(t("categories.duplicate"));
      return false;
    }
    setters[kind]([...lists[kind], clean]);
    return true;
  }

  function renameCategory(kind: Kind, index: number, name: string): boolean {
    const clean = name.trim();
    if (!clean) return false;
    if (exists(kind, clean, index)) {
      toast.error(t("categories.duplicate"));
      return false;
    }
    const next = [...lists[kind]];
    next[index] = clean;
    setters[kind](next);
    return true;
  }

  function removeCategory(kind: Kind, index: number) {
    setters[kind](lists[kind].filter((_, i) => i !== index));
  }

  function onSave() {
    startTransition(async () => {
      try {
        await saveCategories({ gastos, ingresos });
        baseline.current = JSON.stringify({ gastos, ingresos });
        toast.success(t("categories.saved"));
        router.refresh();
      } catch (err) {
        toast.error(t("categories.saveError"), {
          description: err instanceof Error ? err.message : undefined,
        });
      }
    });
  }

  function onResetDefaults() {
    setGastos(DEFAULT_CATEGORIES.gastos);
    setIngresos(DEFAULT_CATEGORIES.ingresos);
  }

  const empty = gastos.length === 0 && ingresos.length === 0;

  return (
    <div className="space-y-6">
      <PageHeader
        title={t("categories.title")}
        description={t("categories.headerDescription")}
        action={
          <Button onClick={onSave} disabled={!isDirty || pending}>
            {pending ? <Loader2 className="animate-spin" /> : <Check />}
            {t("common.saveChanges")}
          </Button>
        }
      />

      {empty ? (
        <EmptyState
          icon={TrendingDown}
          title={t("categories.emptyTitle")}
          description={t("categories.emptyDescription")}
          action={
            <Button variant="secondary" onClick={onResetDefaults}>
              <RotateCcw />
              {t("categories.useSuggested")}
            </Button>
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <CategorySection
            kind="gastos"
            title={t("categories.expenses")}
            kindLabel={t("categories.expenses").toLowerCase()}
            icon={TrendingDown}
            accent="expense"
            items={gastos}
            onAdd={(name) => addCategory("gastos", name)}
            onRename={(i, name) => renameCategory("gastos", i, name)}
            onRemove={(i) => removeCategory("gastos", i)}
          />
          <CategorySection
            kind="ingresos"
            title={t("categories.income")}
            kindLabel={t("categories.income").toLowerCase()}
            icon={TrendingUp}
            accent="income"
            items={ingresos}
            onAdd={(name) => addCategory("ingresos", name)}
            onRename={(i, name) => renameCategory("ingresos", i, name)}
            onRemove={(i) => removeCategory("ingresos", i)}
          />
        </div>
      )}

      {/* Recordatorio de cambios sin guardar */}
      {isDirty && !empty && (
        <p className="text-text-dim text-center text-xs">
          {t("categories.unsaved")}
        </p>
      )}
    </div>
  );
}

/** Una sección (Gastos o Ingresos) con su input de alta y la lista de chips. */
function CategorySection({
  title,
  kindLabel,
  icon: Icon,
  accent,
  items,
  onAdd,
  onRename,
  onRemove,
}: {
  kind: Kind;
  title: string;
  /** Etiqueta en minúscula para placeholders ("gastos"/"ingresos"). */
  kindLabel: string;
  icon: LucideIcon;
  /** Tinte semántico de la sección. */
  accent: "expense" | "income";
  items: string[];
  onAdd: (name: string) => boolean;
  onRename: (index: number, name: string) => boolean;
  onRemove: (index: number) => void;
}) {
  const t = useT();
  const [draft, setDraft] = useState("");

  function submitAdd() {
    if (onAdd(draft)) setDraft("");
  }

  const headerTint =
    accent === "expense"
      ? "bg-expense/12 text-expense"
      : "bg-income/12 text-income";

  return (
    <Card className="flex flex-col p-5">
      <div className="mb-4 flex items-center gap-2.5">
        <span
          className={cn(
            "flex size-8 items-center justify-center rounded-[var(--radius-md)]",
            headerTint,
          )}
        >
          <Icon className="size-[18px]" />
        </span>
        <h2 className="text-[15px] font-semibold">{title}</h2>
        <span className="text-text-dim ml-auto text-xs tnum">
          {items.length}
        </span>
      </div>

      {/* Alta rápida */}
      <div className="flex gap-2">
        <Input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              submitAdd();
            }
          }}
          placeholder={t("categories.addPlaceholder", { kind: kindLabel })}
          aria-label={t("categories.newAriaLabel", { kind: kindLabel })}
        />
        <Button
          type="button"
          variant="secondary"
          size="icon"
          onClick={submitAdd}
          disabled={!draft.trim()}
          aria-label={t("common.add")}
        >
          <Plus />
        </Button>
      </div>

      {/* Lista de categorías */}
      {items.length === 0 ? (
        <p className="text-text-dim mt-4 text-sm">
          {t("categories.sectionEmpty")}
        </p>
      ) : (
        <ul className="mt-4 space-y-1.5">
          {items.map((name, i) => (
            <CategoryRow
              key={`${name}-${i}`}
              name={name}
              onRename={(next) => onRename(i, next)}
              onRemove={() => onRemove(i)}
            />
          ))}
        </ul>
      )}
    </Card>
  );
}

/** Fila de categoría con renombrado inline y eliminación. */
function CategoryRow({
  name,
  onRename,
  onRemove,
}: {
  name: string;
  onRename: (next: string) => boolean;
  onRemove: () => void;
}) {
  const t = useT();
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(name);

  function commit() {
    if (value.trim() === name) {
      setEditing(false);
      return;
    }
    if (onRename(value)) setEditing(false);
  }

  function cancel() {
    setValue(name);
    setEditing(false);
  }

  if (editing) {
    return (
      <li className="flex items-center gap-2">
        <Input
          value={value}
          autoFocus
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              commit();
            } else if (e.key === "Escape") {
              cancel();
            }
          }}
          className="h-9"
          aria-label={t("categories.renameAria", { name })}
        />
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="text-income size-10 min-h-11 min-w-11 shrink-0"
          onClick={commit}
          aria-label={t("common.confirm")}
        >
          <Check />
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="text-text-muted size-10 min-h-11 min-w-11 shrink-0"
          onClick={cancel}
          aria-label={t("common.cancel")}
        >
          <X />
        </Button>
      </li>
    );
  }

  return (
    <li className="hairline bg-surface/50 group flex items-center gap-2 rounded-[var(--radius-md)] py-2 pl-3.5 pr-2 transition-colors hover:bg-surface">
      <span className="min-w-0 flex-1 truncate text-sm">{name}</span>
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="text-text-muted size-10 min-h-11 min-w-11 shrink-0 opacity-100 transition-opacity focus-visible:opacity-100 sm:opacity-0 sm:group-hover:opacity-100"
        onClick={() => {
          setValue(name);
          setEditing(true);
        }}
        aria-label={t("categories.renameAria", { name })}
      >
        <Pencil className="size-[15px]" />
      </Button>
      <Button
        type="button"
        variant="ghost"
        size="icon"
        className="text-text-muted hover:text-expense size-10 min-h-11 min-w-11 shrink-0 opacity-100 transition-opacity focus-visible:opacity-100 sm:opacity-0 sm:group-hover:opacity-100"
        onClick={onRemove}
        aria-label={t("categories.deleteAria", { name })}
      >
        <Trash2 className="size-[15px]" />
      </Button>
    </li>
  );
}
