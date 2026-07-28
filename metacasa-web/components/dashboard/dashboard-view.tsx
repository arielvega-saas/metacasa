import Link from "next/link";
import {
  Landmark,
  PiggyBank,
  Wallet,
  CreditCard,
  TrendingUp,
  HandCoins,
  Circle,
  ArrowDownLeft,
  ArrowUpRight,
  Scale,
  ArrowRight,
  type LucideIcon,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Amount } from "@/components/finance/amount";
import { KpiCard } from "@/components/dashboard/kpi-card";
import { MonthSwitcher } from "@/components/dashboard/month-switcher";
import { RecurringAutorun } from "@/components/dashboard/recurring-autorun";
import { StaggerItem } from "@/components/motion/stagger";
import { SectionHeader } from "@/components/finance/section-header";
import { getT, getLocale } from "@/lib/i18n/server";
import { formatMonthYear } from "@/lib/i18n/dates";
import type { Tables } from "@/lib/database.types";

const ACCOUNT_ICON: Record<string, LucideIcon> = {
  checking: Landmark,
  savings: PiggyBank,
  cash: Wallet,
  credit_card: CreditCard,
  investment: TrendingUp,
  loan: HandCoins,
  other: Circle,
};

export interface DashboardData {
  name: string;
  ym: string;
  currency: string;
  totalBalance: number;
  summary: { income: number; expense: number; balance: number };
  balanceDelta: number | null;
  accounts: (Tables<"accounts"> & { balance: number })[];
  /** Hogar activo (para el throttle del auto-run de recurrentes). */
  householdId: string;

  // ── Slots transmitidos con <Suspense> desde la page ──────────────────────
  /** Fila de sparklines de 7 días. */
  sparklinesSlot: React.ReactNode;
  /** Insights proactivos de gasto (puede resolverse en nada). */
  insightsSlot: React.ReactNode;
  /** Patrimonio neto + ahorro/inversión + salud financiera. */
  overviewSlot: React.ReactNode;
  /** Gráfico de flujos (va dentro de la card, cuyo header ya pinta el shell). */
  flowsSlot: React.ReactNode;
  /** Lista de movimientos recientes. */
  recentSlot: React.ReactNode;
  /** Próximos vencimientos. */
  billsSlot: React.ReactNode;
  /** Metas activas con su progreso. */
  goalsSlot: React.ReactNode;
}

/**
 * Shell del dashboard. Pinta de entrada lo que depende de las 3 queries rápidas
 * (cuentas con saldo + resumen del mes actual y del anterior): encabezado, KPIs
 * y la card de cuentas. Todo lo demás llega por `*Slot` ya envuelto en
 * `<Suspense>` por la page, así que el usuario ve el shell sin esperar a las
 * queries pesadas.
 *
 * Sin acceso a datos: recibe todo por props.
 */
export async function DashboardView({
  name,
  ym,
  currency,
  totalBalance,
  summary,
  balanceDelta,
  accounts,
  householdId,
  sparklinesSlot,
  insightsSlot,
  overviewSlot,
  flowsSlot,
  recentSlot,
  billsSlot,
  goalsSlot,
}: DashboardData) {
  const t = await getT();
  const locale = await getLocale();
  const [year, month] = ym.split("-").map(Number);

  return (
    <div className="space-y-6">
      {/* Encabezado */}
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">
            {t("dashboard.greeting", { name: name ? `, ${name}` : "" })}
          </h1>
          <p className="text-text-muted text-sm capitalize">
            {formatMonthYear(year, month, locale)}
          </p>
        </div>
        <MonthSwitcher ym={ym} />
      </div>

      {/* Auto-ejecución de recurrentes vencidos (cliente, idempotente, 1×/día). */}
      <RecurringAutorun householdId={householdId} />

      {/* KPIs — entran escalonados (40 ms) y los montos hero cuentan desde 0. */}
      <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <StaggerItem index={0}>
          <KpiCard
            label={t("dashboard.totalBalance")}
            value={totalBalance}
            currency={currency}
            kind="balance"
            highlight
            animateValue
            hint={
              accounts.length === 1
                ? t("dashboard.accountCount", { count: accounts.length })
                : t("dashboard.accountCountPlural", { count: accounts.length })
            }
          />
        </StaggerItem>
        <StaggerItem index={1}>
          <KpiCard
            label={t("dashboard.income")}
            value={summary.income}
            currency={currency}
            kind="ingreso"
            icon={ArrowDownLeft}
            hint={t("common.thisMonth")}
          />
        </StaggerItem>
        <StaggerItem index={2}>
          <KpiCard
            label={t("dashboard.expense")}
            value={summary.expense}
            currency={currency}
            kind="gasto"
            icon={ArrowUpRight}
            hint={t("common.thisMonth")}
          />
        </StaggerItem>
        <StaggerItem index={3}>
          <KpiCard
            label={t("dashboard.balance")}
            value={summary.balance}
            currency={currency}
            kind="balance"
            icon={Scale}
            animateValue
            hint={
              balanceDelta !== null
                ? balanceDelta >= 0
                  ? t("dashboard.vsPrevMonthUp", { pct: Math.abs(balanceDelta) })
                  : t("dashboard.vsPrevMonthDown", { pct: Math.abs(balanceDelta) })
                : t("dashboard.balanceFormula")
            }
          />
        </StaggerItem>
      </div>

      {/* Tendencia 7 días (sparklines) — paridad iOS StatsRow. */}
      {sparklinesSlot}

      {/* Insights proactivos de gasto: sólo aparece si hay algo que decir. */}
      {insightsSlot}

      {/* Patrimonio neto + salud financiera + ahorro/inversión */}
      {overviewSlot}

      {/* Gráfico + cuentas */}
      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="p-5 lg:col-span-2">
          <SectionHeader
            title={t("dashboard.flowsTitle")}
            subtitle={t("dashboard.flowsSubtitle")}
          />
          {flowsSlot}
        </Card>

        <Card className="p-5">
          <SectionHeader
            title={t("dashboard.accountsTitle")}
            action={
              <Link href="/accounts" className="text-primary text-xs font-medium hover:underline">
                {t("dashboard.seeAll")}
              </Link>
            }
          />
          {accounts.length === 0 ? (
            <EmptyState text={t("dashboard.accountsEmpty")} />
          ) : (
            <div className="divide-y divide-border">
              {accounts.slice(0, 5).map((a) => {
                const Icon = ACCOUNT_ICON[a.type] ?? Circle;
                return (
                  <div key={a.id} className="flex items-center gap-3 py-2.5">
                    <span className="bg-primary/10 text-primary flex size-9 items-center justify-center rounded-[var(--radius-md)]">
                      <Icon className="size-[18px]" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">{a.name}</p>
                      <p className="text-text-muted text-xs">
                        {t(`domain.accountTypes.${a.type}`)}
                      </p>
                    </div>
                    <Amount
                      value={a.balance}
                      currency={a.currency || currency}
                      kind="balance"
                      className="text-sm font-semibold"
                    />
                  </div>
                );
              })}
            </div>
          )}
        </Card>
      </div>

      {/* Movimientos recientes + (vencimientos / metas) */}
      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="p-5 lg:col-span-2">
          <SectionHeader
            title={t("dashboard.recentTitle")}
            action={
              <Link
                href="/transactions"
                className="text-primary inline-flex items-center gap-1 text-xs font-medium hover:underline"
              >
                {t("dashboard.seeAllM")} <ArrowRight className="size-3.5" />
              </Link>
            }
          />
          {recentSlot}
        </Card>

        <div className="space-y-4">
          <Card className="p-5">
            <SectionHeader title={t("dashboard.billsTitle")} />
            {billsSlot}
          </Card>

          <Card className="p-5">
            <SectionHeader
              title={t("dashboard.goalsTitle")}
              action={
                <Link href="/goals" className="text-primary text-xs font-medium hover:underline">
                  {t("dashboard.seeAll")}
                </Link>
              }
            />
            {goalsSlot}
          </Card>
        </div>
      </div>
    </div>
  );
}

function EmptyState({ text, compact }: { text: string; compact?: boolean }) {
  return (
    <p className={`text-text-dim text-sm ${compact ? "py-2" : "py-8 text-center"}`}>
      {text}
    </p>
  );
}
