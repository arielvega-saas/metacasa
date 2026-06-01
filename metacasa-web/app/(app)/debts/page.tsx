import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listDebts, debtTotals } from "@/lib/db/debts";
import { listAccountsWithBalance } from "@/lib/db/accounts";
import { parseFxRates, convertToBase } from "@/lib/fx";
import { DebtsView } from "@/components/debts/debts-view";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("debts.title") };
}

/**
 * Pantalla de Deudas (server component): resuelve el hogar activo, trae deudas y
 * cuentas (estas últimas read-only, solo para el net worth), calcula el
 * patrimonio neto consolidado a moneda base vía FX y delega la UI al view.
 */
export default async function DebtsPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return <p className="text-text-muted">{t("debts.needHousehold")}</p>;
  }

  const householdId = active.id;
  const currency = active.default_currency;
  const fxRates = parseFxRates(active.fx_rates);

  const [debts, accounts] = await Promise.all([
    listDebts(supabase, householdId),
    listAccountsWithBalance(supabase, householdId),
  ]);

  // Net worth (paridad iOS `AccountBalanceService.netWorth` + `debtTotals`):
  //   activos     = Σ saldos de cuenta POSITIVOS, consolidados a base vía FX
  //   pasivos     = Σ deudas activas + Σ |saldos de cuenta NEGATIVOS|, en base
  // Si falta la tasa de una moneda, esa fila se omite del agregado (mismo
  // criterio que el dashboard: no sumamos a ciegas en otra moneda).
  let assets = 0;
  let liabilities = 0;
  let hasUnconverted = false;

  for (const a of accounts) {
    const converted = convertToBase(
      a.balance,
      a.currency || currency,
      currency,
      fxRates,
    );
    if (converted == null) {
      hasUnconverted = true;
      continue;
    }
    if (converted >= 0) assets += converted;
    else liabilities += -converted;
  }

  const totals = debtTotals(debts, currency, fxRates);
  liabilities += totals.totalBalance;
  if (totals.hasUnconverted) hasUnconverted = true;

  const net = assets - liabilities;

  return (
    <DebtsView
      debts={debts}
      currency={currency}
      debtTotals={totals}
      assets={assets}
      liabilities={liabilities}
      net={net}
      hasUnconvertedNetWorth={hasUnconverted}
    />
  );
}
