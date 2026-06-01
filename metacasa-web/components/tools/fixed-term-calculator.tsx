"use client";

// Calculadora de Plazo Fijo — port de iOS `FixedTermCalculatorView.swift`.
// Matemática en `lib/tools/calc.ts` (computeFixedTerm). Sin estado server.
import { useMemo, useState } from "react";
import { ArrowUpRight, CalendarDays, CalendarClock, CheckCircle2, Hash, Info } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Amount } from "@/components/finance/amount";
import { useT } from "@/components/i18n/locale-provider";
import { parseMoney, formatMoney } from "@/lib/money";
import { computeFixedTerm, type TermUnit } from "@/lib/tools/calc";

// Presets de plazo por unidad (espeja `quickDurationOptions`, iOS L210-215).
const PRESETS: Record<TermUnit, number[]> = {
  days: [30, 60, 90, 180, 365],
  months: [1, 3, 6, 12, 24],
};
// Rango del slider (iOS L185): 7..1095 días | 1..36 meses.
const RANGE: Record<TermUnit, { min: number; max: number }> = {
  days: { min: 7, max: 1095 },
  months: { min: 1, max: 36 },
};

export function FixedTermCalculator({ currency }: { currency: string }) {
  const t = useT();
  const [capitalStr, setCapitalStr] = useState("");
  const [tnaStr, setTnaStr] = useState("120"); // default iOS L18
  const [unit, setUnit] = useState<TermUnit>("days");
  const [term, setTerm] = useState(30); // default iOS L19

  const capital = parseMoney(capitalStr);
  const tnaPct = Number(tnaStr.replace(",", ".")) || 0;

  const r = useMemo(
    () => computeFixedTerm({ capital, tnaPct, term, unit }),
    [capital, tnaPct, term, unit],
  );

  const hasResult = capital > 0 && tnaPct > 0;
  const range = RANGE[unit];

  // Al cambiar de unidad, recortamos el plazo al nuevo rango y caemos a un preset
  // razonable (igual sensación que el segmented + slider de iOS).
  function switchUnit(next: TermUnit) {
    if (next === unit) return;
    setUnit(next);
    setTerm(next === "days" ? 30 : 1);
  }

  return (
    <div className="space-y-6">
      {/* ── Inputs ── */}
      <Card className="space-y-5 p-5 sm:p-6">
        {/* Capital */}
        <div className="space-y-1.5">
          <Label htmlFor="ft-capital">{t("tools.ft.capital")}</Label>
          <div className="bg-inset flex items-center gap-2 rounded-[var(--radius-md)] border border-input px-3.5">
            <span className="text-text-muted shrink-0 rounded-full bg-white/[0.06] px-2 py-0.5 text-[11px] font-bold tnum">
              {currency}
            </span>
            <input
              id="ft-capital"
              inputMode="decimal"
              value={capitalStr}
              onChange={(e) => setCapitalStr(e.target.value)}
              placeholder="0"
              className="text-primary placeholder:text-text-dim h-12 w-full bg-transparent text-xl font-num font-bold outline-none"
            />
          </div>
          {capital > 0 && (
            <p className="text-income flex items-center gap-1.5 text-xs font-medium">
              <CheckCircle2 className="size-3.5" />
              {formatMoney(capital, currency, "auto")}
            </p>
          )}
        </div>

        {/* TNA */}
        <div className="space-y-1.5">
          <Label htmlFor="ft-tna">{t("tools.ft.tna")}</Label>
          <div className="bg-inset flex items-center gap-2 rounded-[var(--radius-md)] border border-input px-3.5">
            <input
              id="ft-tna"
              inputMode="decimal"
              value={tnaStr}
              onChange={(e) => setTnaStr(e.target.value)}
              placeholder="0"
              className="text-champagne placeholder:text-text-dim h-12 w-full bg-transparent text-xl font-num font-bold outline-none"
            />
            <span className="text-text-muted shrink-0 text-lg font-semibold">%</span>
          </div>
          <p className="text-text-dim text-xs">{t("tools.ft.tnaHint")}</p>
        </div>

        {/* Plazo */}
        <div className="space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <Label>{t("tools.ft.term")}</Label>
            {/* Toggle días / meses (segmented control). */}
            <div className="bg-inset hairline inline-flex rounded-[var(--radius-lg)] p-1">
              {(["days", "months"] as TermUnit[]).map((u) => (
                <button
                  key={u}
                  type="button"
                  onClick={() => switchUnit(u)}
                  aria-pressed={unit === u}
                  className={`min-h-9 rounded-[var(--radius-md)] px-3 text-[13px] font-semibold transition-colors ${
                    unit === u
                      ? "bg-white/[0.1] text-foreground"
                      : "text-text-muted hover:text-foreground"
                  }`}
                >
                  {u === "days" ? t("tools.ft.unitDays") : t("tools.ft.unitMonths")}
                </button>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-4">
            <span className="text-primary min-w-[3ch] text-2xl font-num font-bold tnum">
              {term}
            </span>
            <input
              type="range"
              min={range.min}
              max={range.max}
              step={1}
              value={term}
              onChange={(e) => setTerm(Number(e.target.value))}
              aria-label={t("tools.ft.term")}
              className="accent-[var(--mc-sage)] h-2 w-full cursor-pointer"
            />
          </div>

          {/* Presets rápidos. */}
          <div className="flex flex-wrap gap-2">
            {PRESETS[unit].map((p) => (
              <button
                key={p}
                type="button"
                onClick={() => setTerm(p)}
                className={`min-h-9 rounded-full px-3.5 text-xs font-bold transition-colors ${
                  term === p
                    ? "bg-primary text-primary-foreground"
                    : "bg-inset text-text-muted hairline hover:text-foreground"
                }`}
              >
                {unit === "days" ? `${p}d` : `${p}m`}
              </button>
            ))}
          </div>
        </div>
      </Card>

      {hasResult ? (
        <>
          {/* ── Resultado ── */}
          <Card className="relative overflow-hidden p-5 sm:p-6">
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 bg-gradient-to-br from-income/[0.12] via-primary/[0.08] to-transparent"
            />
            <div className="relative space-y-4">
              <h2 className="text-base font-semibold">{t("tools.ft.result")}</h2>
              <div className="flex items-start justify-between gap-3">
                <div className="space-y-1">
                  <p className="text-text-muted text-[13px]">{t("tools.ft.interest")}</p>
                  <Amount
                    value={r.interest}
                    currency={currency}
                    kind="ingreso"
                    serif
                    showSign
                    className="text-3xl sm:text-4xl"
                  />
                </div>
                <ArrowUpRight className="text-income size-8 shrink-0" />
              </div>

              <div className="border-border border-t" />

              <div className="flex flex-wrap items-end justify-between gap-4">
                <div className="space-y-1">
                  <p className="text-text-muted text-[13px]">{t("tools.ft.total")}</p>
                  <Amount
                    value={r.total}
                    currency={currency}
                    kind="neutral"
                    serif
                    className="text-2xl"
                  />
                </div>
                <div className="space-y-1 text-right">
                  <p className="text-text-muted text-[13px]" title={t("tools.ft.teaHint")}>
                    {t("tools.ft.tea")}
                  </p>
                  <p className="text-primary text-2xl font-num font-semibold tnum">
                    {r.teaPct.toFixed(1)}%
                  </p>
                </div>
              </div>
            </div>
          </Card>

          {/* ── Equivalencias ── */}
          <Card className="space-y-3 p-5 sm:p-6">
            <h2 className="text-base font-semibold">{t("tools.ft.equivalents")}</h2>
            <div className="flex items-center justify-between gap-3">
              <span className="text-text-muted flex items-center gap-2 text-sm font-medium">
                <CalendarDays className="text-primary size-4" />
                {t("tools.ft.perMonth")}
              </span>
              <Amount value={r.monthlyEquivalent} currency={currency} kind="ingreso" serif />
            </div>
            <div className="border-border border-t" />
            <div className="flex items-center justify-between gap-3">
              <span className="text-text-muted flex items-center gap-2 text-sm font-medium">
                <CalendarClock className="text-primary size-4" />
                {t("tools.ft.perDay")}
              </span>
              <Amount value={r.dailyEquivalent} currency={currency} kind="ingreso" serif />
            </div>
          </Card>

          {/* ── Disclaimer ── */}
          <div className="bg-inset text-text-muted flex items-start gap-2 rounded-[var(--radius-md)] p-3 text-xs">
            <Info className="mt-0.5 size-3.5 shrink-0" />
            <p>{t("tools.ft.disclaimer")}</p>
          </div>
        </>
      ) : (
        <Card className="flex flex-col items-center gap-3 p-8 text-center">
          <Hash className="text-primary/60 size-8" />
          <p className="font-medium">{t("tools.ft.hintTitle")}</p>
          <p className="text-text-muted max-w-xs text-sm">{t("tools.ft.hintBody")}</p>
        </Card>
      )}
    </div>
  );
}
