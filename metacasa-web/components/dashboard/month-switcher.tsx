import Link from "next/link";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { getT, getLocale } from "@/lib/i18n/server";
import { formatMonthYear } from "@/lib/i18n/dates";

function shift(year: number, month: number, delta: number): string {
  const d = new Date(year, month - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

/** Navegador de mes server-rendered: usa hrefs `?ym=` que preservan el pathname. */
export async function MonthSwitcher({ ym }: { ym: string }) {
  const t = await getT();
  const locale = await getLocale();
  const [year, month] = ym.split("-").map(Number);
  const label = formatMonthYear(year, month, locale);

  return (
    <div className="hairline bg-surface/60 flex items-center gap-1 rounded-full p-1">
      <Link
        href={`?ym=${shift(year, month, -1)}`}
        scroll={false}
        aria-label={t("dashboard.prevMonth")}
        className="text-text-muted hover:bg-white/[0.06] hover:text-foreground flex size-7 items-center justify-center rounded-full transition-colors"
      >
        <ChevronLeft className="size-4" />
      </Link>
      <span className="min-w-[7.5rem] text-center text-sm font-medium capitalize">
        {label}
      </span>
      <Link
        href={`?ym=${shift(year, month, 1)}`}
        scroll={false}
        aria-label={t("dashboard.nextMonth")}
        className="text-text-muted hover:bg-white/[0.06] hover:text-foreground flex size-7 items-center justify-center rounded-full transition-colors"
      >
        <ChevronRight className="size-4" />
      </Link>
    </div>
  );
}
