import { TransactionRow } from "@/components/finance/transaction-row";
import { createClient } from "@/lib/supabase/server";
import { listTransactions } from "@/lib/db/transactions";
import { getT } from "@/lib/i18n/server";

/** Últimos movimientos del hogar. Sección async propia (query paginada). */
export async function RecentSection({
  householdId,
  currency,
  limit = 6,
}: {
  householdId: string;
  currency: string;
  limit?: number;
}) {
  const supabase = await createClient();
  const [recent, t] = await Promise.all([
    listTransactions(supabase, { householdId, limit }),
    getT(),
  ]);

  if (recent.rows.length === 0) {
    return (
      <p className="text-text-dim py-8 text-center text-sm">
        {t("dashboard.recentEmpty")}
      </p>
    );
  }

  return (
    <div className="divide-y divide-border">
      {recent.rows.map((tx) => (
        <TransactionRow key={tx.id} tx={tx} currency={currency} />
      ))}
    </div>
  );
}
