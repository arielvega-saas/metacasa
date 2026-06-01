"use client";

import * as React from "react";
import { Sparkles, Info, ArrowRight, ArrowLeft, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
  SelectGroup,
  SelectLabel,
} from "@/components/ui/select";
import { useT } from "@/components/i18n/locale-provider";
import { cn } from "@/lib/utils";
import type {
  AccountOption,
  ColumnMapping,
  FieldKey,
  MapResponse,
} from "./types";

const NONE = "__none__";
const NO_ACCOUNT = "__no_account__";

const FIELD_ORDER: FieldKey[] = [
  "date",
  "amount",
  "type",
  "category",
  "account",
  "note",
];

const FIELD_LABEL: Record<FieldKey, string> = {
  date: "importTools.fieldDate",
  amount: "importTools.fieldAmount",
  type: "importTools.fieldType",
  category: "importTools.fieldCategory",
  account: "importTools.fieldAccount",
  note: "importTools.fieldNote",
};

interface Props {
  headers: string[];
  mapResult: MapResponse | null;
  loading: boolean;
  accounts: AccountOption[];
  expenseCategories: string[];
  incomeCategories: string[];
  /** Estado inicial controlado por el padre (persiste al ir/volver). */
  initialMapping?: ColumnMapping;
  initialAccountId?: string | null;
  initialDefaultCategory?: string;
  onReanalyze: () => void;
  onBack: () => void;
  onContinue: (state: {
    mapping: ColumnMapping;
    targetAccountId: string | null;
    defaultCategory: string;
  }) => void;
}

/** Paso 2: mapeo editable columna→campo + cuenta destino + categoría fallback. */
export function MappingStep({
  headers,
  mapResult,
  loading,
  accounts,
  expenseCategories,
  incomeCategories,
  initialMapping,
  initialAccountId,
  initialDefaultCategory,
  onReanalyze,
  onBack,
  onContinue,
}: Props) {
  const t = useT();

  const [mapping, setMapping] = React.useState<ColumnMapping>(
    initialMapping ?? emptyMapping(),
  );
  const [accountId, setAccountId] = React.useState<string>(
    initialAccountId ?? accounts[0]?.id ?? NO_ACCOUNT,
  );
  const allCategories = React.useMemo(
    () => Array.from(new Set([...expenseCategories, ...incomeCategories])),
    [expenseCategories, incomeCategories],
  );
  const [defaultCategory, setDefaultCategory] = React.useState<string>(
    initialDefaultCategory ?? allCategories[0] ?? "",
  );
  const [showError, setShowError] = React.useState(false);

  // Cuando llega el resultado de la IA/heurística, adoptamos su mapeo (salvo que
  // el usuario ya venía de "volver" con un mapeo propio).
  const adoptedRef = React.useRef(false);
  React.useEffect(() => {
    if (mapResult && !adoptedRef.current && !initialMapping) {
      setMapping(mapResult.mapping);
      adoptedRef.current = true;
    }
  }, [mapResult, initialMapping]);

  const headerLabel = (i: number) =>
    headers[i]?.trim() || t("importTools.unnamedColumn", { index: i });

  const setField = (field: FieldKey, value: string) => {
    setMapping((m) => ({ ...m, [field]: value === NONE ? null : Number(value) }));
  };

  const canContinue = mapping.date != null && mapping.amount != null;

  const handleContinue = () => {
    if (!canContinue) {
      setShowError(true);
      return;
    }
    onContinue({
      mapping,
      targetAccountId: accountId === NO_ACCOUNT ? null : accountId,
      defaultCategory,
    });
  };

  if (loading) {
    return (
      <div className="bg-inset hairline flex flex-col items-center justify-center rounded-[var(--radius-xl)] px-6 py-16 text-center">
        <Loader2 className="text-primary size-7 animate-spin" />
        <p className="text-text-muted mt-4 text-sm">
          {t("importTools.mappingLoading")}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Aviso de origen del mapeo (IA / heurística / IA caída) */}
      {mapResult?.source === "ai" && !mapResult.aiError ? (
        <div className="bg-primary/10 text-primary flex items-start gap-2 rounded-[var(--radius-md)] px-4 py-3 text-sm">
          <Sparkles className="mt-0.5 size-4 shrink-0" />
          <span>{t("importTools.mappingDescription")}</span>
        </div>
      ) : (
        <div className="bg-champagne/10 text-champagne flex items-start gap-2 rounded-[var(--radius-md)] px-4 py-3 text-sm">
          <Info className="mt-0.5 size-4 shrink-0" />
          <span>
            {mapResult?.aiError === "rateLimit"
              ? t("importTools.rateLimitError")
              : mapResult?.aiError
                ? t("importTools.mappingAiFailed")
                : t("importTools.mappingHeuristicNote")}
          </span>
        </div>
      )}

      {/* Grilla de campos → columna */}
      <div className="grid gap-4 sm:grid-cols-2">
        {FIELD_ORDER.map((field) => (
          <div key={field} className="space-y-1.5">
            <Label>{t(FIELD_LABEL[field])}</Label>
            <Select
              value={mapping[field] == null ? NONE : String(mapping[field])}
              onValueChange={(v) => setField(field, v)}
            >
              <SelectTrigger aria-label={t(FIELD_LABEL[field])}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={NONE}>{t("importTools.columnNone")}</SelectItem>
                <SelectGroup>
                  {headers.map((_, i) => (
                    <SelectItem key={i} value={String(i)}>
                      {headerLabel(i)}
                    </SelectItem>
                  ))}
                </SelectGroup>
              </SelectContent>
            </Select>
          </div>
        ))}
      </div>

      {/* Cómo se determina el tipo */}
      <p className="text-text-dim text-xs">
        {mapping.type != null
          ? t("importTools.typeFromColumn")
          : t("importTools.typeFromSign")}
        {mapResult?.dateFormat
          ? ` · ${t("importTools.dateFormatLabel")}: ${mapResult.dateFormat}`
          : ""}
      </p>

      {/* Cuenta destino + categoría por defecto */}
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label>{t("importTools.targetAccountLabel")}</Label>
          <Select value={accountId} onValueChange={setAccountId}>
            <SelectTrigger aria-label={t("importTools.targetAccountLabel")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={NO_ACCOUNT}>
                {t("importTools.noAccountOption")}
              </SelectItem>
              {accounts.length > 0 && (
                <SelectGroup>
                  <SelectLabel>{t("importTools.targetAccountLabel")}</SelectLabel>
                  {accounts.map((a) => (
                    <SelectItem key={a.id} value={a.id}>
                      {a.name}
                    </SelectItem>
                  ))}
                </SelectGroup>
              )}
            </SelectContent>
          </Select>
          <p className="text-text-dim text-xs">
            {accounts.length === 0
              ? t("importTools.noAccountsYet")
              : t("importTools.targetAccountHint")}
          </p>
        </div>

        <div className="space-y-1.5">
          <Label>{t("importTools.defaultCategoryLabel")}</Label>
          <Select value={defaultCategory} onValueChange={setDefaultCategory}>
            <SelectTrigger aria-label={t("importTools.defaultCategoryLabel")}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectGroup>
                {allCategories.map((c) => (
                  <SelectItem key={c} value={c}>
                    {c}
                  </SelectItem>
                ))}
              </SelectGroup>
            </SelectContent>
          </Select>
          <p className="text-text-dim text-xs">
            {t("importTools.defaultCategoryHint")}
          </p>
        </div>
      </div>

      {showError && !canContinue && (
        <Badge variant="expense">{t("importTools.mappingNeedDateAmount")}</Badge>
      )}

      <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
        <Button type="button" variant="ghost" onClick={onBack}>
          <ArrowLeft className="size-4" />
          {t("importTools.step1")}
        </Button>
        <div className="flex items-center gap-2">
          <Button
            type="button"
            variant="secondary"
            onClick={() => {
              adoptedRef.current = false;
              onReanalyze();
            }}
          >
            <Sparkles className="size-4" />
            {t("importTools.analyzeAgain")}
          </Button>
          <Button
            type="button"
            onClick={handleContinue}
            className={cn(!canContinue && "opacity-60")}
          >
            {t("importTools.continueToPreview")}
            <ArrowRight className="size-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}

function emptyMapping(): ColumnMapping {
  return { date: null, amount: null, type: null, category: null, account: null, note: null };
}
