"use client";

// Calculadora de interés compuesto — port de iOS `CompoundInterestCalculatorView.swift`.
// Matemática en `lib/tools/calc.ts` (computeCompound + milestonePoints).
import { useMemo, useState } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  Line,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { ArrowUpRight, Info, TrendingUp } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Amount } from "@/components/finance/amount";
import { useT } from "@/components/i18n/locale-provider";
import { parseMoney, formatMoney } from "@/lib/money";
import { CHART } from "@/components/reports/chart-tokens";
import { computeCompound, milestonePoints } from "@/lib/tools/calc";

function ChartTooltip({ active, payload, label, currency, t }: any) {
  if (!active || !payload?.length) return null;
  const balance = payload.find((p: any) => p.dataKey === "balance")?.value ?? 0;
  const contributed = payload.find((p: any) => p.dataKey === "contributed")?.value ?? 0;
  const yrs = Math.round(Number(label) / 12);
  return (
    <div className="glass hairline rounded-[var(--radius-md)] px-3 py-2 text-xs shadow-xl">
      <p className="mb-1 font-medium text-foreground">
        {t("tools.ci.yearLabelOther", { n: yrs })}
      </p>
      <p className="text-income">
        {t("tools.ci.legendBalance")}: {formatMoney(balance, currency, "compact")}
      </p>
      <p className="text-text-muted">
        {t("tools.ci.legendContributed")}: {formatMoney(contributed, currency, "compact")}
      </p>
    </div>
  );
}

export function CompoundInterestCalculator({ currency }: { currency: string }) {
  const t = useT();
  // Defaults iOS L23-26.
  const [principalStr, setPrincipalStr] = useState("10000");
  const [monthlyStr, setMonthlyStr] = useState("500");
  const [yearsStr, setYearsStr] = useState("10");
  const [rateStr, setRateStr] = useState("8");

  const principal = parseMoney(principalStr);
  const monthlyContribution = parseMoney(monthlyStr);
  const years = parseInt(yearsStr, 10) || 0;
  const annualRatePct = Number(rateStr.replace(",", ".")) || 0;

  const result = useMemo(
    () => computeCompound({ principal, monthlyContribution, years, annualRatePct }),
    [principal, monthlyContribution, years, annualRatePct],
  );
  const milestones = useMemo(() => milestonePoints(result, years), [result, years]);

  // Misma guarda que iOS L85: necesita meses y tasa para mostrar proyección.
  const hasResult = result.months > 0 && annualRatePct > 0;
  // Etiquetas X cada ~months/6, igual que iOS (chartXAxis stride).
  const tickStep = Math.max(1, Math.floor(result.months / 6));
  const xTicks = useMemo(() => {
    const ticks: number[] = [];
    for (let m = 0; m <= result.months; m += tickStep) ticks.push(m);
    return ticks;
  }, [result.months, tickStep]);

  return (
    <div className="space-y-6">
      {/* ── Intro ── */}
      <Card className="p-5 sm:p-6">
        <div className="flex items-center gap-2">
          <TrendingUp className="text-primary size-5" />
          <h2 className="text-base font-semibold">{t("tools.ci.title")}</h2>
        </div>
        <p className="text-text-muted mt-2 text-sm">{t("tools.ci.intro")}</p>
      </Card>

      {/* ── Inputs ── */}
      <Card className="grid gap-5 p-5 sm:grid-cols-2 sm:p-6">
        <InputRow
          id="ci-principal"
          label={t("tools.ci.principal")}
          hint={t("tools.ci.principalHint")}
          value={principalStr}
          onChange={setPrincipalStr}
          suffix={currency}
        />
        <InputRow
          id="ci-monthly"
          label={t("tools.ci.monthly")}
          hint={t("tools.ci.monthlyHint")}
          value={monthlyStr}
          onChange={setMonthlyStr}
          suffix={currency}
        />
        <InputRow
          id="ci-years"
          label={t("tools.ci.years")}
          hint={t("tools.ci.yearsHint")}
          value={yearsStr}
          onChange={setYearsStr}
          suffix={t("tools.ci.unitYears")}
          inputMode="numeric"
        />
        <InputRow
          id="ci-rate"
          label={t("tools.ci.rate")}
          hint={t("tools.ci.rateHint")}
          value={rateStr}
          onChange={setRateStr}
          suffix="% TEA"
        />
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
              <h2 className="text-base font-semibold">{t("tools.ci.result")}</h2>
              <div className="flex items-start justify-between gap-3">
                <div className="space-y-1">
                  <p className="text-text-muted text-[13px]">{t("tools.ci.final")}</p>
                  <Amount
                    value={result.finalBalance}
                    currency={currency}
                    kind="ingreso"
                    serif
                    className="text-3xl sm:text-4xl"
                  />
                </div>
                <ArrowUpRight className="text-income size-8 shrink-0" />
              </div>

              <div className="border-border border-t" />

              <div className="flex flex-wrap items-end justify-between gap-4">
                <div className="space-y-1">
                  <p className="text-text-muted text-[13px]">{t("tools.ci.contributed")}</p>
                  <Amount
                    value={result.totalContributed}
                    currency={currency}
                    kind="neutral"
                    serif
                    className="text-2xl"
                  />
                </div>
                <div className="space-y-1 text-right">
                  <p className="text-text-muted text-[13px]">{t("tools.ci.interestEarned")}</p>
                  <Amount
                    value={result.interestEarned}
                    currency={currency}
                    kind="ingreso"
                    serif
                    className="text-primary text-2xl"
                  />
                </div>
              </div>
            </div>
          </Card>

          {/* ── Chart ── */}
          <Card className="space-y-3 p-5 sm:p-6">
            <h2 className="text-base font-semibold">{t("tools.ci.chartTitle")}</h2>
            <div className="h-[260px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart
                  data={result.projection}
                  margin={{ top: 8, right: 8, bottom: 0, left: 8 }}
                >
                  <defs>
                    <linearGradient id="ci-balance" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={CHART.sage} stopOpacity={0.4} />
                      <stop offset="100%" stopColor={CHART.sage} stopOpacity={0.05} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid vertical={false} stroke={CHART.grid} />
                  <XAxis
                    dataKey="month"
                    type="number"
                    domain={[0, result.months]}
                    ticks={xTicks}
                    tickFormatter={(m: number) => `${Math.round(m / 12)}a`}
                    axisLine={false}
                    tickLine={false}
                    tick={{ fill: CHART.axis, fontSize: 12 }}
                    dy={8}
                  />
                  <YAxis
                    axisLine={false}
                    tickLine={false}
                    tick={{ fill: CHART.axis, fontSize: 11 }}
                    width={48}
                    tickFormatter={(v: number) => formatMoney(v, currency, "abbreviated")}
                  />
                  <Tooltip
                    cursor={{ stroke: CHART.cursor }}
                    content={<ChartTooltip currency={currency} t={t} />}
                  />
                  {/* Balance (área sage). */}
                  <Area
                    type="monotone"
                    dataKey="balance"
                    stroke={CHART.sage}
                    strokeWidth={2}
                    fill="url(#ci-balance)"
                    dot={false}
                    activeDot={{ r: 4, fill: CHART.sage, strokeWidth: 0 }}
                  />
                  {/* Aportado (línea punteada gris) — igual que iOS L264-271. */}
                  <Line
                    type="monotone"
                    dataKey="contributed"
                    stroke={CHART.axis}
                    strokeWidth={1}
                    strokeDasharray="3 3"
                    dot={false}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
            <div className="text-text-muted flex items-center gap-4 text-xs">
              <span className="flex items-center gap-1.5">
                <span className="size-2 rounded-full" style={{ background: CHART.sage }} />
                {t("tools.ci.legendBalance")}
              </span>
              <span className="flex items-center gap-1.5">
                <span className="size-2 rounded-full" style={{ background: CHART.axis }} />
                {t("tools.ci.legendContributed")}
              </span>
            </div>
          </Card>

          {/* ── Milestones ── */}
          {milestones.length > 0 && (
            <Card className="space-y-3 p-5 sm:p-6">
              <h2 className="text-base font-semibold">{t("tools.ci.milestones")}</h2>
              <div className="divide-border divide-y">
                {milestones.map((p) => {
                  const yrs = Math.round(p.month / 12);
                  return (
                    <div key={p.month} className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0">
                      <span className="text-text-muted text-[13px]">
                        {t(yrs === 1 ? "tools.ci.yearLabelOne" : "tools.ci.yearLabelOther", {
                          n: yrs,
                        })}
                      </span>
                      <Amount
                        value={p.balance}
                        currency={currency}
                        kind="neutral"
                        serif
                        style="compact"
                      />
                    </div>
                  );
                })}
              </div>
            </Card>
          )}

          {/* ── Disclaimer ── */}
          <div className="bg-inset text-text-muted flex items-start gap-2 rounded-[var(--radius-md)] p-3 text-xs">
            <Info className="mt-0.5 size-3.5 shrink-0" />
            <p>{t("tools.ci.disclaimer")}</p>
          </div>
        </>
      ) : (
        <p className="text-text-muted px-1 text-sm">{t("tools.ci.enterInputs")}</p>
      )}
    </div>
  );
}

function InputRow({
  id,
  label,
  hint,
  value,
  onChange,
  suffix,
  inputMode = "decimal",
}: {
  id: string;
  label: string;
  hint: string;
  value: string;
  onChange: (v: string) => void;
  suffix: string;
  inputMode?: "decimal" | "numeric";
}) {
  return (
    <div className="space-y-1.5">
      <Label htmlFor={id}>{label}</Label>
      <div className="bg-inset flex items-center gap-2 rounded-[var(--radius-md)] border border-input px-3.5">
        <input
          id={id}
          inputMode={inputMode}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="text-foreground placeholder:text-text-dim h-11 w-full bg-transparent text-base font-num outline-none tnum"
        />
        <span className="text-text-muted shrink-0 text-xs font-semibold">{suffix}</span>
      </div>
      <p className="text-text-dim text-xs">{hint}</p>
    </div>
  );
}
