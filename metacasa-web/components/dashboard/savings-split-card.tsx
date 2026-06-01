import { Banknote, TrendingUp } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Amount } from "@/components/finance/amount";
import { SectionHeader } from "@/components/finance/section-header";
import { getT } from "@/lib/i18n/server";

/**
 * Card de Ahorro/Inversión. SERVER COMPONENT puro (recibe todo por props).
 * Paridad con iOS `SavingsInvestmentCard`: aplica los porcentajes de la
 * estrategia del hogar sobre los INGRESOS del mes y muestra el reparto
 * ahorro/inversión + una barra de proporción.
 *
 * Honestidad de dato (regla del task): si no hay estrategia configurada o no hay
 * ingresos este mes, NO inventa números — muestra el estado correspondiente.
 */
export interface SavingsSplitCardProps {
  /** Ingresos del mes en moneda base (base del cálculo, igual que iOS). */
  income: number;
  /** % de ahorro configurado (0–100). */
  savingsPercent: number;
  /** % de inversión configurado (0–100). */
  investmentPercent: number;
  /** `false` si el hogar no configuró estrategia (muestra CTA). */
  configured: boolean;
  /** Moneda base del hogar (ISO). */
  currency: string;
}

export async function SavingsSplitCard({
  income,
  savingsPercent,
  investmentPercent,
  configured,
  currency,
}: SavingsSplitCardProps) {
  const t = await getT();

  const savingsAmount = Math.max(0, (income * savingsPercent) / 100);
  const investmentAmount = Math.max(0, (income * investmentPercent) / 100);
  const totalPct = savingsPercent + investmentPercent;

  return (
    <Card className="p-5">
      <SectionHeader
        title={t("dashboard.savingsSplit")}
        subtitle={t("dashboard.savingsSplitSubtitle")}
      />

      {!configured ? (
        <p className="text-text-dim py-2 text-sm">
          {t("dashboard.savingsSplitUnset")}
        </p>
      ) : income <= 0 ? (
        <p className="text-text-dim py-2 text-sm">
          {t("dashboard.savingsSplitEmpty")}
        </p>
      ) : (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-[var(--radius-md)] bg-white/[0.04] p-3">
              <p className="text-income flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider">
                <Banknote className="size-3.5" />
                {t("dashboard.savingsLabel")} · {savingsPercent}%
              </p>
              <Amount
                value={savingsAmount}
                currency={currency}
                kind="ingreso"
                className="mt-0.5 block text-base font-semibold"
              />
            </div>
            <div className="rounded-[var(--radius-md)] bg-white/[0.04] p-3">
              <p className="text-primary flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider">
                <TrendingUp className="size-3.5" />
                {t("dashboard.investmentLabel")} · {investmentPercent}%
              </p>
              <Amount
                value={investmentAmount}
                currency={currency}
                kind="balance"
                className="mt-0.5 block text-base font-semibold"
              />
            </div>
          </div>

          {/* Barra de proporción ahorro / inversión sobre el ingreso del mes. */}
          {totalPct > 0 && (
            <div className="bg-inset flex h-2 overflow-hidden rounded-full">
              {savingsPercent > 0 && (
                <div
                  className="bg-income h-full"
                  style={{ width: `${Math.min(100, savingsPercent)}%` }}
                />
              )}
              {investmentPercent > 0 && (
                <div
                  className="bg-primary h-full"
                  style={{ width: `${Math.min(100, investmentPercent)}%` }}
                />
              )}
            </div>
          )}
        </div>
      )}
    </Card>
  );
}
