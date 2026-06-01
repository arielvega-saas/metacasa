import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listPlans, listPayments } from "@/lib/db/installments";
import { listAccounts } from "@/lib/db/accounts";
import { InstallmentsView } from "@/components/installments/installments-view";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("installments.title") };
}

/**
 * Pantalla de Cuotas (server component): resuelve el hogar activo, trae los
 * planes con su progreso ya calculado, el cronograma de cada plan (para los
 * diálogos) y las cuentas activas (para el selector del alta). Delega la
 * UI/diálogos al view client.
 */
export default async function InstallmentsPage() {
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return <p className="text-text-muted">{t("installments.needHousehold")}</p>;
  }

  const plans = await listPlans(supabase, active.id);
  // Cronograma por plan: una query por plan, en paralelo. Volumen acotado
  // (un hogar tiene pocos planes activos); lo pasamos al view para los diálogos.
  const schedules = Object.fromEntries(
    await Promise.all(
      plans.map(
        async (p) => [p.id, await listPayments(supabase, p.id)] as const,
      ),
    ),
  );
  const accounts = await listAccounts(supabase, active.id);

  return (
    <InstallmentsView
      plans={plans}
      schedules={schedules}
      accounts={accounts.map((a) => ({ id: a.id, name: a.name }))}
      currency={active.default_currency}
    />
  );
}
