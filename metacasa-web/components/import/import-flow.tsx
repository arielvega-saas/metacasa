"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Card } from "@/components/ui/card";
import { useT } from "@/components/i18n/locale-provider";
import { cn } from "@/lib/utils";
import { importTransactions, type ImportResult, type ParsedTxInput } from "@/lib/actions/import";
import { UploadStep } from "./upload-step";
import { MappingStep } from "./mapping-step";
import { PreviewStep } from "./preview-step";
import { ResultStep } from "./result-step";
import { resolveRows, type ResolvedRow } from "./resolve";
import type {
  AccountOption,
  ColumnMapping,
  MapResponse,
  ParseResponse,
} from "./types";

type Step = 1 | 2 | 3 | 4;

interface Props {
  baseCurrency: string;
  accounts: AccountOption[];
  expenseCategories: string[];
  incomeCategories: string[];
}

/** Orquestador del flujo de importación en 4 pasos. */
export function ImportFlow({
  baseCurrency,
  accounts,
  expenseCategories,
  incomeCategories,
}: Props) {
  const t = useT();
  const router = useRouter();
  const [step, setStep] = React.useState<Step>(1);

  // Datos del parseo (paso 1).
  const [parsed, setParsed] = React.useState<ParseResponse | null>(null);

  // Mapeo (paso 2).
  const [mapResult, setMapResult] = React.useState<MapResponse | null>(null);
  const [mapLoading, setMapLoading] = React.useState(false);
  const [mapping, setMapping] = React.useState<ColumnMapping | undefined>();
  const [targetAccountId, setTargetAccountId] = React.useState<string | null>(
    accounts[0]?.id ?? null,
  );
  const [defaultCategory, setDefaultCategory] = React.useState<string>(
    [...expenseCategories, ...incomeCategories][0] ?? "",
  );

  // Preview (paso 3).
  const [resolved, setResolved] = React.useState<ResolvedRow[]>([]);
  const [selected, setSelected] = React.useState<Set<number>>(new Set());
  const [pending, startTransition] = React.useTransition();

  // Resultado (paso 4).
  const [result, setResult] = React.useState<ImportResult | null>(null);

  const validCategories = React.useMemo(
    () => new Set([...expenseCategories, ...incomeCategories]),
    [expenseCategories, incomeCategories],
  );
  const validAccountIds = React.useMemo(
    () => new Set(accounts.map((a) => a.id)),
    [accounts],
  );

  /** Pide el mapeo a la IA (con fallback heurístico en el server). */
  const requestMapping = React.useCallback(
    async (data: ParseResponse) => {
      setMapLoading(true);
      setMapResult(null);
      try {
        const res = await fetch("/api/import/map", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            headers: data.headers,
            sampleRows: data.rows.slice(0, 5),
          }),
        });
        if (res.status === 401) {
          toast.error(t("importTools.genericError"));
          // Igual seguimos: el usuario puede mapear a mano.
          setMapResult(null);
          return;
        }
        const json = (await res.json().catch(() => null)) as MapResponse | null;
        if (json?.mapping) {
          setMapResult(json);
          if (json.aiError === "rateLimit") {
            toast.message(t("importTools.rateLimitError"));
          }
        }
      } catch {
        // El server casi siempre degrada a heurística; si ni eso, mapeo a mano.
        setMapResult(null);
      } finally {
        setMapLoading(false);
      }
    },
    [t],
  );

  /** Paso 1 → 2: archivo parseado. */
  const handleParsed = (data: ParseResponse) => {
    setParsed(data);
    setMapping(undefined);
    if (data.truncated) {
      toast.message(t("importTools.truncatedNote", { max: data.maxRows }));
    }
    setStep(2);
    void requestMapping(data);
  };

  /** Paso 2 → 3: mapeo confirmado → resolver filas. */
  const handleMappingContinue = (state: {
    mapping: ColumnMapping;
    targetAccountId: string | null;
    defaultCategory: string;
  }) => {
    if (!parsed) return;
    setMapping(state.mapping);
    setTargetAccountId(state.targetAccountId);
    setDefaultCategory(state.defaultCategory);

    const rows = resolveRows(parsed.rows, {
      mapping: state.mapping,
      amountSign: mapResult?.amountSign ?? "negativeIsExpense",
      dateFormat: mapResult?.dateFormat ?? null,
      defaultCategory: state.defaultCategory,
      targetAccountId: state.targetAccountId,
      validCategories,
      validAccountIds,
    });
    setResolved(rows);
    // Por defecto, todas las filas válidas seleccionadas.
    setSelected(new Set(rows.filter((r) => r.error == null).map((r) => r.index)));
    setStep(3);
  };

  const toggleRow = (index: number) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  };

  const toggleAll = (select: boolean) => {
    if (select) {
      setSelected(new Set(resolved.filter((r) => r.error == null).map((r) => r.index)));
    } else {
      setSelected(new Set());
    }
  };

  /** Paso 3 → 4: confirmar importación. */
  const handleConfirm = () => {
    const rows: ParsedTxInput[] = resolved
      .filter((r) => r.error == null && selected.has(r.index) && r.date && r.amount != null)
      .map((r) => ({
        date: r.date as string,
        // Mandamos el monto ya resuelto como string; el server lo revalida.
        amount: String(r.amount),
        // El tipo lo recomputa el server, pero le pasamos una pista coherente.
        type: r.type,
        category: r.category,
        note: r.note ?? "",
        accountId: r.accountId,
      }));

    if (rows.length === 0) return;

    startTransition(async () => {
      try {
        const res = await importTransactions({
          rows,
          // El monto que mandamos ya es magnitud positiva; el tipo va explícito
          // por fila, así que no dependemos del signo acá.
          amountSign: "typeColumn",
          dateFormat: mapResult?.dateFormat ?? null,
          defaultCategory,
        });
        setResult(res);
        setStep(4);
        if (res.inserted > 0) {
          toast.success(
            res.skipped > 0
              ? t("importTools.partialBody", {
                  inserted: res.inserted,
                  skipped: res.skipped,
                })
              : t("importTools.successBody", { inserted: res.inserted }),
          );
          router.refresh();
        }
      } catch (err) {
        toast.error(err instanceof Error ? err.message : t("importTools.importError"));
      }
    });
  };

  /** Reinicia el flujo para importar otro archivo. */
  const reset = () => {
    setStep(1);
    setParsed(null);
    setMapResult(null);
    setMapping(undefined);
    setResolved([]);
    setSelected(new Set());
    setResult(null);
  };

  return (
    <div className="space-y-5">
      <Stepper step={step} />

      <Card className="p-5 sm:p-6">
        {step === 1 && <UploadStep onParsed={handleParsed} />}

        {step === 2 && parsed && (
          <MappingStep
            headers={parsed.headers}
            mapResult={mapResult}
            loading={mapLoading}
            accounts={accounts}
            expenseCategories={expenseCategories}
            incomeCategories={incomeCategories}
            initialMapping={mapping}
            initialAccountId={targetAccountId}
            initialDefaultCategory={defaultCategory}
            onReanalyze={() => parsed && requestMapping(parsed)}
            onBack={reset}
            onContinue={handleMappingContinue}
          />
        )}

        {step === 3 && (
          <PreviewStep
            resolved={resolved}
            baseCurrency={baseCurrency}
            accounts={accounts}
            selected={selected}
            onToggle={toggleRow}
            onToggleAll={toggleAll}
            pending={pending}
            onBack={() => setStep(2)}
            onConfirm={handleConfirm}
          />
        )}

        {step === 4 && result && (
          <ResultStep result={result} onImportMore={reset} />
        )}
      </Card>
    </div>
  );
}

/** Indicador de pasos (1..4) con la etapa activa resaltada. */
function Stepper({ step }: { step: Step }) {
  const t = useT();
  const STEPS = [
    t("importTools.step1"),
    t("importTools.step2"),
    t("importTools.step3"),
    t("importTools.step4"),
  ];
  return (
    <ol className="flex flex-wrap items-center gap-2 text-xs">
      {STEPS.map((label, i) => {
        const n = (i + 1) as Step;
        const active = n === step;
        const done = n < step;
        return (
          <li key={label} className="flex items-center gap-2">
            <span
              className={cn(
                "flex size-6 items-center justify-center rounded-full text-[11px] font-semibold transition-colors",
                active
                  ? "bg-primary text-primary-foreground"
                  : done
                    ? "bg-primary/20 text-primary"
                    : "bg-tint-2 text-text-dim",
              )}
            >
              {i + 1}
            </span>
            <span
              className={cn(
                "font-medium",
                active ? "text-foreground" : "text-text-dim",
              )}
            >
              {label}
            </span>
            {i < STEPS.length - 1 && (
              <span className="bg-border mx-1 h-px w-5 shrink-0" aria-hidden="true" />
            )}
          </li>
        );
      })}
    </ol>
  );
}
