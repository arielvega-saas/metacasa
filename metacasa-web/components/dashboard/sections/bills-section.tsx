import { CalendarClock } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { upcomingBills } from "@/lib/db/bills";
import { formatMoney } from "@/lib/money";
import { getT, getLocale } from "@/lib/i18n/server";
import { formatDayMonth } from "@/lib/i18n/dates";

/** Próximos vencimientos del hogar. Sección async propia. */
export async function BillsSection({
  householdId,
  currency,
  limit = 4,
}: {
  householdId: string;
  currency: string;
  limit?: number;
}) {
  const supabase = await createClient();
  const [bills, t, locale] = await Promise.all([
    upcomingBills(supabase, householdId, limit),
    getT(),
    getLocale(),
  ]);

  if (bills.length === 0) {
    return (
      <p className="text-text-dim py-2 text-sm">{t("dashboard.billsEmpty")}</p>
    );
  }

  return (
    <div className="divide-y divide-border">
      {bills.map((b) => (
        <div key={b.id} className="flex items-center gap-3 py-2.5">
          <span className="bg-champagne/12 text-champagne flex size-9 items-center justify-center rounded-[var(--radius-md)]">
            <CalendarClock className="size-[18px]" />
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium">{b.title}</p>
            <p className="text-text-muted text-xs">
              {formatDayMonth(b.due_date, locale)}
            </p>
          </div>
          <span className="tnum text-sm font-semibold">
            {formatMoney(Number(b.amount), b.currency || currency)}
          </span>
        </div>
      ))}
    </div>
  );
}
