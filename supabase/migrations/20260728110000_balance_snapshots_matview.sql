-- Fase 4.4: agregados precalculados para que el dashboard no dependa de
-- recomputar todo desde `transactions` en cada request.
--
-- HOY: cada apertura del Home hace `totals()` del mes + del mes anterior +
-- sparklines + net worth. Con 96 transacciones no se nota; con 10k usuarios
-- activos es el primer cuello de botella (lo marcó la auditoría de backend).
--
-- QUÉ SE AGREGA
--   1. `mv_household_month_summary` — ingresos/gastos/neto por (hogar, año, mes).
--      MATERIALIZED VIEW con índice único → permite REFRESH CONCURRENTLY, así
--      el refresh no bloquea lecturas.
--   2. `account_balance_snapshots` — foto diaria del saldo por cuenta, para
--      graficar evolución de patrimonio sin recorrer el histórico entero.
--   3. `month_summary(p_household, p_year, p_month)` — lectura barata para los
--      clientes, con RLS aplicada (SECURITY INVOKER + chequeo de pertenencia).
--
-- POR QUÉ MATVIEW Y NO TABLA CON TRIGGERS: los montos se editan y borran; una
-- tabla incremental por trigger acumula deriva ante cualquier bug. El matview
-- se recalcula entero cada noche y siempre coincide con la verdad.
--
-- IMPORTANTE: las matviews NO respetan RLS. Por eso vive en `app_hidden`
-- (fuera de la API REST) y el acceso va por la función `month_summary`, que
-- valida pertenencia al hogar.

create materialized view if not exists app_hidden.mv_household_month_summary as
select
  t.household_id,
  extract(year  from (t.date at time zone 'UTC'))::int  as period_year,
  extract(month from (t.date at time zone 'UTC'))::int  as period_month,
  sum(t.amount) filter (where t.type = 'INGRESO') as ingresos,
  sum(t.amount) filter (where t.type = 'GASTO')   as gastos,
  coalesce(sum(t.amount) filter (where t.type = 'INGRESO'), 0)
    - coalesce(sum(t.amount) filter (where t.type = 'GASTO'), 0) as neto,
  count(*) as movimientos,
  max(t.created_at) as ultimo_movimiento
from public.transactions t
group by 1, 2, 3;

-- Índice ÚNICO: requisito de REFRESH ... CONCURRENTLY.
create unique index if not exists uq_mv_household_month
  on app_hidden.mv_household_month_summary (household_id, period_year, period_month);

-- Snapshot diario de saldo por cuenta (para históricos de patrimonio).
create table if not exists app_hidden.account_balance_snapshots (
  account_id uuid not null references public.accounts(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  snapshot_date date not null,
  balance numeric(19,4) not null,
  currency text not null,
  primary key (account_id, snapshot_date)
);

create index if not exists idx_abs_household_date
  on app_hidden.account_balance_snapshots (household_id, snapshot_date desc);

create or replace function app_hidden.refresh_financial_aggregates()
returns void
language plpgsql
security definer
set search_path to 'public', 'app_hidden'
as $$
begin
  -- CONCURRENTLY para no bloquear a los clientes que estén leyendo.
  refresh materialized view concurrently app_hidden.mv_household_month_summary;

  -- Foto de hoy por cuenta activa (idempotente: si el job corre dos veces en
  -- el día, la segunda pisa la misma fila).
  insert into app_hidden.account_balance_snapshots (account_id, household_id, snapshot_date, balance, currency)
  select a.id, a.household_id, current_date,
         a.starting_balance + coalesce(sum(
           case when t.type = 'GASTO' then -t.amount else t.amount end), 0),
         a.currency
  from public.accounts a
  left join public.transactions t
    on t.account_id = a.id and t.household_id = a.household_id
  where a.is_active
  group by a.id, a.household_id, a.starting_balance, a.currency
  on conflict (account_id, snapshot_date)
    do update set balance = excluded.balance, currency = excluded.currency;
end $$;

revoke execute on function app_hidden.refresh_financial_aggregates() from public, anon, authenticated;

-- Lectura para clientes: RLS-safe porque valida pertenencia explícitamente
-- (la matview por sí sola no aplica RLS).
create or replace function public.month_summary(p_household uuid, p_year int, p_month int)
returns table(ingresos numeric, gastos numeric, neto numeric, movimientos bigint)
language plpgsql
stable
security definer
set search_path to 'public', 'app_hidden'
as $$
begin
  if not app_hidden.is_household_member(p_household) then
    raise exception 'not a member of household %', p_household using errcode = '42501';
  end if;
  return query
    select coalesce(m.ingresos, 0), coalesce(m.gastos, 0), coalesce(m.neto, 0), coalesce(m.movimientos, 0)
    from app_hidden.mv_household_month_summary m
    where m.household_id = p_household
      and m.period_year = p_year
      and m.period_month = p_month;
end $$;

-- 04:50 UTC: antes de que corran las recurrentes (05:10) y de que abran la app.
select cron.schedule('refresh-financial-aggregates-daily', '50 4 * * *',
  $$select app_hidden.refresh_financial_aggregates()$$);
