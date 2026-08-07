import type { Metadata } from "next";
import Link from "next/link";
import { Plus, ArrowDownLeft, ArrowUpRight, Scale, Wallet } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { resolveActiveHousehold } from "@/lib/household";
import { listTransactions } from "@/lib/db/transactions";
import { getFilteredTotals } from "@/lib/db/transfer-exclusion";
import { listAccounts } from "@/lib/db/accounts";
import { getCategories } from "@/lib/db/categories";
import { listTemplates } from "@/lib/db/templates";
import { PageHeader } from "@/components/layout/page-header";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { Amount } from "@/components/finance/amount";
import { TransactionFilters } from "@/components/transactions/transaction-filters";
import { TransactionList } from "@/components/transactions/transaction-list";
import { TransactionsPagination } from "@/components/transactions/transactions-pagination";
import { TX_TYPE, type TxType } from "@/lib/constants";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return { title: t("transactions.title") };
}

const PAGE_SIZE = 25;

interface SearchParams {
  type?: string;
  category?: string;
  account?: string;
  from?: string;
  to?: string;
  q?: string;
  min?: string;
  max?: string;
  page?: string;
  new?: string;
}

/** Normaliza el tipo de la URL a un TxType válido (o undefined). */
function parseType(v?: string): TxType | undefined {
  if (v === TX_TYPE.INCOME || v === TX_TYPE.EXPENSE) return v;
  return undefined;
}

/** Parsea un monto de la URL a número no-negativo (o undefined si inválido). */
function parseAmount(v?: string): number | undefined {
  if (v == null || v.trim() === "") return undefined;
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : undefined;
}

export default async function TransactionsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const sp = await searchParams;
  const supabase = await createClient();
  const t = await getT();
  const { active } = await resolveActiveHousehold(supabase);

  // Sin hogar activo: invitamos a crear uno (consistente con el dashboard).
  if (!active) {
    return (
      <>
        <PageHeader
          title={t("transactions.title")}
          description={t("transactions.descriptionShort")}
        />
        <EmptyState
          icon={Wallet}
          title={t("transactions.noHouseholdTitle")}
          description={t("transactions.noHouseholdDescription")}
        />
      </>
    );
  }

  const householdId = active.id;
  const currency = active.default_currency;

  // Filtros desde la URL.
  const type = parseType(sp.type);
  const category = sp.category?.trim() || undefined;
  const accountId = sp.account?.trim() || undefined;
  const from = sp.from?.trim() || undefined;
  const to = sp.to?.trim() || undefined;
  const search = sp.q?.trim() || undefined;
  const amountMin = parseAmount(sp.min);
  const amountMax = parseAmount(sp.max);
  const page = Math.max(1, Number(sp.page) || 1);
  const offset = (page - 1) * PAGE_SIZE;

  // Fetch en paralelo: página actual de movimientos + cuentas + categorías +
  // resumen agregado del filtro completo (todas las páginas).
  const [list, accounts, categories, summary, templates] = await Promise.all([
    listTransactions(supabase, {
      householdId,
      type,
      category,
      accountId,
      from,
      to,
      search,
      amountMin,
      amountMax,
      limit: PAGE_SIZE,
      offset,
    }),
    listAccounts(supabase, householdId),
    getCategories(supabase, householdId),
    // Totales del filtro COMPLETO (todas las páginas) y sin transferencias, con
    // los mismos filtros que la lista de arriba. La regla vive en un solo lugar
    // (`lib/db/transfer-exclusion.ts`); acá sólo se la invoca.
    getFilteredTotals(supabase, {
      householdId,
      type,
      category,
      accountId,
      from,
      to,
      search,
      amountMin,
      amountMax,
    }),
    // Atajos rápidos (plantillas) para la barra de quick-add sobre la lista.
    listTemplates(supabase, householdId),
  ]);

  const accountOptions = accounts.map((a) => ({ id: a.id, name: a.name }));
  const cats = {
    gastos: categories.gastos ?? [],
    ingresos: categories.ingresos ?? [],
  };
  const openNew = sp.new === "1";

  return (
    <div className="space-y-5">
      <PageHeader
        title={t("transactions.title")}
        description={t("transactions.description")}
        action={
          <Button asChild>
            <Link href="/transactions?new=1">
              <Plus className="size-4" /> {t("transactions.new")}
            </Link>
          </Button>
        }
      />

      {/* Resumen del filtro actual (sobre todas las páginas del resultado) */}
      <div className="grid grid-cols-3 gap-3">
        <SummaryCard
          label={t("transactions.income")}
          value={summary.income}
          currency={currency}
          kind="ingreso"
          icon={ArrowDownLeft}
        />
        <SummaryCard
          label={t("transactions.expense")}
          value={summary.expense}
          currency={currency}
          kind="gasto"
          icon={ArrowUpRight}
        />
        <SummaryCard
          label={t("transactions.balance")}
          value={summary.income - summary.expense}
          currency={currency}
          kind="balance"
          icon={Scale}
        />
      </div>

      {/* Filtros avanzados */}
      <TransactionFilters categories={cats} accounts={accountOptions} />

      {/* Lista + paginación */}
      <TransactionList
        rows={list.rows}
        currency={currency}
        accounts={accountOptions}
        categories={cats}
        openNew={openNew}
        templates={templates}
      />

      {list.count > 0 && (
        <TransactionsPagination page={page} pageSize={PAGE_SIZE} total={list.count} />
      )}
    </div>
  );
}

/** Tarjeta compacta del resumen ingresos/gastos/balance del filtro. */
function SummaryCard({
  label,
  value,
  currency,
  kind,
  icon: Icon,
}: {
  label: string;
  value: number;
  currency: string;
  kind: "ingreso" | "gasto" | "balance";
  icon: typeof ArrowDownLeft;
}) {
  return (
    <Card className="p-3.5 sm:p-4">
      <div className="text-text-muted mb-1 flex items-center gap-1.5 text-xs font-medium">
        <Icon className="size-3.5" /> {label}
      </div>
      <Amount
        value={value}
        currency={currency}
        kind={kind}
        style="abbreviated"
        className="text-base font-semibold sm:text-lg"
      />
    </Card>
  );
}
