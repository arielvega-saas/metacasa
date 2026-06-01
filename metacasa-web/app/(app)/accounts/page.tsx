import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listAccountsWithBalance, listCreditCards } from "@/lib/db/accounts";
import { AccountsView } from "@/components/accounts/accounts-view";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("accounts.title") };
}

/**
 * Pantalla de Cuentas (server component): resuelve el hogar activo, trae las
 * cuentas con saldo y el detalle de tarjetas, y delega la UI/diálogos al view.
 */
export default async function AccountsPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return <p className="text-text-muted">{t("accounts.needHousehold")}</p>;
  }

  const accounts = await listAccountsWithBalance(supabase, active.id);
  // Detalle de tarjetas solo para las cuentas tipo credit_card (1 query).
  const cardAccountIds = accounts
    .filter((a) => a.type === "credit_card")
    .map((a) => a.id);
  const creditCards = await listCreditCards(supabase, cardAccountIds);

  return (
    <AccountsView
      accounts={accounts}
      creditCards={creditCards}
      currency={active.default_currency}
    />
  );
}
