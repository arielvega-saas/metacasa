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
  CalendarClock,
  Target,
  ArrowRight,
  type LucideIcon,
} from "lucide-react";
import { Card } from "@/components/ui/card";
import { Amount } from "@/components/finance/amount";
import { KpiCard } from "@/components/dashboard/kpi-card";
import { MonthSwitcher } from "@/components/dashboard/month-switcher";
import { FlowsChart } from "@/components/dashboard/flows-chart";
import { StatSparkline } from "@/components/dashboard/stat-sparkline";
import { NetWorthCard } from "@/components/dashboard/net-worth-card";
import { SavingsSplitCard } from "@/components/dashboard/savings-split-card";
import { HealthScoreCard } from "@/components/dashboard/health-score-card";
import { RecurringAutorun } from "@/components/dashboard/recurring-autorun";
import { SectionHeader } from "@/components/finance/section-header";
import { TransactionRow } from "@/components/finance/transaction-row";
import { formatMoney } from "@/lib/money";
import { getT, getLocale } from "@/lib/i18n/server";
import { formatMonthYear, formatDayMonth } from "@/lib/i18n/dates";
import type { Tables } from "@/lib/database.types";

/** Colores del design system para los sparklines (sage = ingreso, coral = gasto). */
const SPARK_INCOME = "#9fc4ad";
const SPARK_EXPENSE = "#e8b4a6";

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
  flows: { month: string; income: number; expense: number }[];
  recent: Tables<"transactions">[];
  bills: Tables<"bills">[];
  goals: Tables<"goals">[];
  /** Patrimonio neto ya consolidado en moneda base (assets/liabilities/net). */
  netWorth: {
    assets: number;
    liabilities: number;
    net: number;
    hasUnconverted: boolean;
  };
  /** Series de 7 días para los sparklines de ingreso/gasto (último = hoy). */
  sparklines: { income: number[]; expense: number[]; days: number };
  /** Reparto ahorro/inversión sobre los ingresos del mes (paridad iOS). */
  savingsSplit: {
    income: number;
    savingsPercent: number;
    investmentPercent: number;
    configured: boolean;
  };
  /** Salud financiera (0–100) + racha de días. */
  health: { score: number; streak: number };
  /** Hogar activo (para el throttle del auto-run de recurrentes). */
  householdId: string;
}

/** Presentación del dashboard (sin acceso a datos: recibe todo por props). */
export async function DashboardView({
  name,
  ym,
  currency,
  totalBalance,
  summary,
  balanceDelta,
  accounts,
  flows,
  recent,
  bills,
  goals,
  netWorth,
  sparklines,
  savingsSplit,
  health,
  householdId,
}: DashboardData) {
  const t = await getT();
  const locale = await getLocale();
  const [year, month] = ym.split("-").map(Number);
  const hasSparkData =
    sparklines.income.some((v) => v > 0) || sparklines.expense.some((v) => v > 0);

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

      {/* KPIs */}
      <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
        <KpiCard
          label={t("dashboard.totalBalance")}
          value={totalBalance}
          currency={currency}
          kind="balance"
          highlight
          hint={
            accounts.length === 1
              ? t("dashboard.accountCount", { count: accounts.length })
              : t("dashboard.accountCountPlural", { count: accounts.length })
          }
        />
        <KpiCard
          label={t("dashboard.income")}
          value={summary.income}
          currency={currency}
          kind="ingreso"
          icon={ArrowDownLeft}
          hint={t("common.thisMonth")}
        />
        <KpiCard
          label={t("dashboard.expense")}
          value={summary.expense}
          currency={currency}
          kind="gasto"
          icon={ArrowUpRight}
          hint={t("common.thisMonth")}
        />
        <KpiCard
          label={t("dashboard.balance")}
          value={summary.balance}
          currency={currency}
          kind="balance"
          icon={Scale}
          hint={
            balanceDelta !== null
              ? balanceDelta >= 0
                ? t("dashboard.vsPrevMonthUp", { pct: Math.abs(balanceDelta) })
                : t("dashboard.vsPrevMonthDown", { pct: Math.abs(balanceDelta) })
              : t("dashboard.balanceFormula")
          }
        />
      </div>

      {/* Tendencia 7 días (sparklines) — paridad iOS StatsRow. Solo si hay data. */}
      {hasSparkData && (
        <div className="grid grid-cols-1 gap-3 sm:gap-4 sm:grid-cols-2">
          <Card className="p-5">
            <div className="flex items-center justify-between gap-3">
              <span className="text-text-muted flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider">
                <ArrowDownLeft className="text-income size-3.5" />
                {t("dashboard.sparklineIncome")}
              </span>
              <Amount
                value={sparklines.income.reduce((s, v) => s + v, 0)}
                currency={currency}
                kind="ingreso"
                className="text-sm font-semibold"
              />
            </div>
            <div className="mt-3">
              <StatSparkline values={sparklines.income} color={SPARK_INCOME} />
            </div>
          </Card>
          <Card className="p-5">
            <div className="flex items-center justify-between gap-3">
              <span className="text-text-muted flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider">
                <ArrowUpRight className="text-expense size-3.5" />
                {t("dashboard.sparklineExpense")}
              </span>
              <Amount
                value={sparklines.expense.reduce((s, v) => s + v, 0)}
                currency={currency}
                kind="gasto"
                className="text-sm font-semibold"
              />
            </div>
            <div className="mt-3">
              <StatSparkline values={sparklines.expense} color={SPARK_EXPENSE} />
            </div>
          </Card>
        </div>
      )}

      {/* Patrimonio neto + salud financiera + ahorro/inversión */}
      <div className="grid gap-4 lg:grid-cols-3">
        <NetWorthCard
          assets={netWorth.assets}
          liabilities={netWorth.liabilities}
          net={netWorth.net}
          currency={currency}
          hasUnconverted={netWorth.hasUnconverted}
        />
        <div className="grid gap-4 lg:col-span-2 lg:grid-cols-2">
          <SavingsSplitCard
            income={savingsSplit.income}
            savingsPercent={savingsSplit.savingsPercent}
            investmentPercent={savingsSplit.investmentPercent}
            configured={savingsSplit.configured}
            currency={currency}
          />
          <HealthScoreCard score={health.score} streak={health.streak} />
        </div>
      </div>

      {/* Gráfico + cuentas */}
      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="p-5 lg:col-span-2">
          <SectionHeader
            title={t("dashboard.flowsTitle")}
            subtitle={t("dashboard.flowsSubtitle")}
          />
          <FlowsChart
            data={flows}
            currency={currency}
            incomeLabel={t("dashboard.flowsIncome")}
            expenseLabel={t("dashboard.flowsExpense")}
            emptyLabel={t("dashboard.flowsEmpty")}
          />
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
          {recent.length === 0 ? (
            <EmptyState text={t("dashboard.recentEmpty")} />
          ) : (
            <div className="divide-y divide-border">
              {recent.map((tx) => (
                <TransactionRow key={tx.id} tx={tx} currency={currency} />
              ))}
            </div>
          )}
        </Card>

        <div className="space-y-4">
          <Card className="p-5">
            <SectionHeader title={t("dashboard.billsTitle")} />
            {bills.length === 0 ? (
              <EmptyState text={t("dashboard.billsEmpty")} compact />
            ) : (
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
            )}
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
            {goals.length === 0 ? (
              <EmptyState text={t("dashboard.goalsEmpty")} compact />
            ) : (
              <div className="space-y-3.5">
                {goals.map((g) => {
                  const pct = Math.min(
                    100,
                    Math.round((Number(g.current_amount) / Number(g.target_amount)) * 100) || 0,
                  );
                  return (
                    <div key={g.id}>
                      <div className="mb-1.5 flex items-center justify-between text-sm">
                        <span className="flex items-center gap-1.5 font-medium">
                          <Target className="text-primary size-3.5" />
                          {g.name}
                        </span>
                        <span className="text-text-muted text-xs">{pct}%</span>
                      </div>
                      <div className="bg-inset h-2 overflow-hidden rounded-full">
                        <div className="bg-primary h-full rounded-full" style={{ width: `${pct}%` }} />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
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
