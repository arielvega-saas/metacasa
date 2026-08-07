import { NetWorthCard } from "@/components/dashboard/net-worth-card";
import { SavingsSplitCard } from "@/components/dashboard/savings-split-card";
import { HealthScoreCard } from "@/components/dashboard/health-score-card";
import { createClient } from "@/lib/supabase/server";
import { listDebts, debtTotals } from "@/lib/db/debts";
import {
  getHouseholdSplitStrategy,
  getActiveTxDays,
} from "@/lib/db/dashboard-extras";
import { computeHealthScore, computeStreak } from "@/lib/health";
import { getToday } from "@/lib/today-server";
import type { FXRateMap } from "@/lib/fx";

export interface OverviewSectionProps {
  householdId: string;
  currency: string;
  /** Tasas FX del hogar ya parseadas por la page (no se vuelven a leer). */
  fxRates: FXRateMap;
  /** Σ saldos de cuenta POSITIVOS consolidados a base (ya calculado con las cuentas del shell). */
  assets: number;
  /** Σ |saldos de cuenta NEGATIVOS| consolidados a base. */
  negativeBalances: number;
  /** `true` si alguna cuenta quedó fuera por faltar su tasa FX. */
  accountsUnconverted: boolean;
  /** Ingresos/gastos del mes (ya fetcheados para los KPIs). */
  summary: { income: number; expense: number };
}

/**
 * Fila de "estado general": patrimonio neto + reparto ahorro/inversión + salud
 * financiera. Es una sola sección porque las tres cards comparten la misma
 * grilla y sus tres queries (deudas, estrategia, días activos) van en paralelo:
 * partirla en tres `<Suspense>` haría que la fila se arme a los saltos.
 *
 * NO refetchea cuentas ni el resumen del mes: los recibe por props del shell.
 */
export async function OverviewSection({
  householdId,
  currency,
  fxRates,
  assets,
  negativeBalances,
  accountsUnconverted,
  summary,
}: OverviewSectionProps) {
  const supabase = await createClient();
  const [debtList, splitStrategy, activeTxDays, today] = await Promise.all([
    listDebts(supabase, householdId, { includeSettled: false }),
    getHouseholdSplitStrategy(supabase, householdId),
    getActiveTxDays(supabase, householdId, 30),
    // Día del calendario del USUARIO: con el reloj UTC del server, entre las
    // 21:00 y las 24:00 en Argentina la racha arrancaba a contar en MAÑANA y
    // daba 0 aunque el usuario acabara de cargar un movimiento.
    getToday(),
  ]);

  // Patrimonio neto (paridad iOS `AccountBalanceService.netWorth` + `debtTotals`):
  //   liabilities = Σ deudas activas + Σ |saldos de cuenta negativos|
  // Si falta la tasa de alguna moneda, esa cuenta/deuda se omite y lo marcamos.
  const debts = debtTotals(debtList, currency, fxRates);
  const liabilities = debts.totalBalance + negativeBalances;
  const netWorth = assets - liabilities;

  // Health Score (0–100) + racha — paridad iOS `HomeViewModel`.
  const score = computeHealthScore(summary.income, summary.expense, activeTxDays);
  const streak = computeStreak(activeTxDays, today);

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <NetWorthCard
        assets={assets}
        liabilities={liabilities}
        net={netWorth}
        currency={currency}
        hasUnconverted={accountsUnconverted || debts.hasUnconverted}
      />
      <div className="grid gap-4 lg:col-span-2 lg:grid-cols-2">
        <SavingsSplitCard
          income={summary.income}
          savingsPercent={splitStrategy.savingsPercent}
          investmentPercent={splitStrategy.investmentPercent}
          configured={splitStrategy.configured}
          currency={currency}
        />
        <HealthScoreCard score={score} streak={streak} />
      </div>
    </div>
  );
}
