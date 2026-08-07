import type { Metadata } from "next";
import { Wallet } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import {
  getPeriodForMonth,
  listAllocations,
  envelopeBalance,
} from "@/lib/db/budget";
import { getCategories } from "@/lib/db/categories";
import { getStrategy } from "@/lib/db/strategy";
import { StrategyCard } from "@/components/budgets/strategy-card";
import { PageHeader } from "@/components/layout/page-header";
import { EmptyState } from "@/components/ui/empty-state";
import { Card } from "@/components/ui/card";
import { CreatePeriodButton } from "@/components/budgets/create-period-button";
import { BudgetBoard, type AllocationRow } from "@/components/budgets/budget-board";
import { MonthSwitcher } from "@/components/dashboard/month-switcher";
import { getT, getLocale } from "@/lib/i18n/server";
import { formatMonthYear } from "@/lib/i18n/dates";
import { getToday } from "@/lib/today-server";
import { resolveYm, splitYm } from "@/lib/today";

export const metadata: Metadata = { title: "Presupuesto" };

export default async function BudgetsPage({
  searchParams,
}: {
  searchParams: Promise<{ ym?: string }>;
}) {
  const sp = await searchParams;
  const supabase = await createClient();
  const t = await getT();
  const locale = await getLocale();
  const { active } = await resolveActiveHousehold(supabase);

  if (!active) {
    return (
      <>
        <PageHeader
          title={t("budgets.title")}
          description={t("budgets.headerDescriptionShort")}
        />
        <EmptyState
          icon={Wallet}
          title={t("budgets.needHouseholdTitle")}
          description={t("budgets.needHouseholdDescription")}
        />
      </>
    );
  }

  const householdId = active.id;
  const currency = active.default_currency;

  // Mes seleccionado vía `?ym=` (default: mes actual), como dashboard/reportes.
  // El "mes actual" es el del CALENDARIO DEL USUARIO (cookie `mc_tz`): con el
  // reloj UTC del server, el 31 a las 21:05 en Argentina esta pantalla ofrecía
  // crear el período del mes SIGUIENTE cuando todavía quedaban 3 horas del actual.
  const hoy = await getToday();
  const ym = resolveYm(sp.ym, hoy);
  const [year, month] = splitYm(ym);
  const periodLabel = formatMonthYear(year, month, locale);

  // Resuelve el período del MES seleccionado (no necesariamente el de hoy).
  const period = await getPeriodForMonth(supabase, householdId, ym, hoy);

  // Sin período para el mes elegido → CTA para crearlo (zero-based arranca acá).
  if (!period) {
    return (
      <>
        <PageHeader
          title={t("budgets.title")}
          description={t("budgets.headerDescription")}
          action={<MonthSwitcher ym={ym} />}
        />
        <Card glass className="sage-glow border-primary/20 p-8 text-center">
          <div className="mx-auto max-w-md space-y-4">
            <span className="bg-primary/12 text-primary mx-auto flex size-14 items-center justify-center rounded-full">
              <Wallet className="size-7" />
            </span>
            <div className="space-y-1.5">
              <h2 className="text-lg font-semibold tracking-tight">
                {t("budgets.noPeriodTitlePrefix")}
                <span className="capitalize">{periodLabel}</span>
              </h2>
              <p className="text-text-muted text-sm">
                {t("budgets.noPeriodDescription")}
              </p>
            </div>
            <CreatePeriodButton />
          </div>
        </Card>
      </>
    );
  }

  // Con período: traemos sobres + categorías + estrategia (Waterfall) y
  // calculamos métricas por sobre. La estrategia se muestra en su propio card.
  const [allocations, categoryData, strategy, { data: authUser }] =
    await Promise.all([
      listAllocations(supabase, period.id),
      getCategories(supabase, householdId),
      getStrategy(supabase, householdId),
      supabase.auth.getUser(),
    ]);

  // Solo owner/admin pueden editar la estrategia (mismo criterio que el resto
  // de las mutaciones de hogar). El guard real vive en la server action + RLS.
  let canEditStrategy = false;
  if (authUser?.user) {
    const { data: me } = await supabase
      .from("household_members")
      .select("role")
      .eq("household_id", householdId)
      .eq("user_id", authUser.user.id)
      .maybeSingle();
    canEditStrategy = me?.role === "owner" || me?.role === "admin";
  }

  // El saldo de cada sobre sale de la RPC server-side (asignado + rollover − gastado).
  const rows: AllocationRow[] = await Promise.all(
    allocations.map(async (a) => {
      const remaining = await envelopeBalance(
        supabase,
        period.id,
        a.category,
        a.subcategory,
      );
      const allocated = Number(a.allocated);
      const rollover = Number(a.rollover_from_prev);
      const budgeted = allocated + rollover;
      return {
        id: a.id,
        category: a.category,
        allocated,
        rollover,
        budgeted,
        // gastado = presupuestado − saldo restante.
        spent: budgeted - remaining,
        remaining,
        currency: a.currency || currency,
      } satisfies AllocationRow;
    }),
  );

  const expenseCategories = categoryData.gastos ?? [];

  return (
    <>
      <PageHeader
        title={t("budgets.title")}
        description={t("budgets.headerDescription")}
        action={<MonthSwitcher ym={ym} />}
      />
      <div className="space-y-6">
        <BudgetBoard
          periodId={period.id}
          currency={currency}
          readyToAssign={Number(period.ready_to_assign)}
          totalIncome={Number(period.total_income)}
          totalAllocated={Number(period.total_allocated)}
          periodLabel={periodLabel}
          rows={rows}
          categories={expenseCategories}
        />
        <StrategyCard
          strategy={strategy}
          income={Number(period.total_income)}
          currency={currency}
          canEdit={canEditStrategy}
        />
      </div>
    </>
  );
}
