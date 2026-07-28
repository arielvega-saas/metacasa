-- Fase 3.16 + 3.19 + RPC para 3.3 (cache iOS).
--
-- 1) period_year/month: hasta hoy los calculaba solo el cliente (nullable,
--    riesgo de drift). NO se pueden volver GENERATED porque la app iOS
--    publicada los INSERTA explícitamente (fallaría el insert). Trigger que
--    los deriva cuando vienen NULL + backfill. Fechas ya vienen estabilizadas
--    a mediodía UTC → extracción en UTC es correcta.
-- 2) Realtime: publication para sync multi-dispositivo (los clientes se
--    suscriben en fase posterior; habilitarlo es prep sin efecto para quien
--    no se suscribe; RLS aplica a los suscriptores).
-- 3) RPC account_balances: balances por cuenta server-side (hoy iOS baja
--    hasta 10.000 transacciones para calcularlos en el teléfono). SECURITY
--    INVOKER: RLS decide qué ve el caller.

create or replace function app_hidden.tg_fill_period()
returns trigger
language plpgsql
as $$
begin
  if new.period_year is null or new.period_month is null then
    new.period_year  := extract(year  from (new.date at time zone 'UTC'))::int;
    new.period_month := extract(month from (new.date at time zone 'UTC'))::int;
  end if;
  return new;
end $$;

drop trigger if exists fill_period on public.transactions;
create trigger fill_period
  before insert or update of date on public.transactions
  for each row execute function app_hidden.tg_fill_period();

update public.transactions
set period_year  = extract(year  from (date at time zone 'UTC'))::int,
    period_month = extract(month from (date at time zone 'UTC'))::int
where period_year is null or period_month is null;

-- Realtime
alter publication supabase_realtime add table
  public.transactions, public.accounts, public.budget_periods,
  public.budget_allocations, public.goals, public.bills, public.debts;

-- RPC balances por cuenta (para HomeView/AccountsView sin bajar 10k rows).
create or replace function public.account_balances(p_household uuid)
returns table(account_id uuid, balance numeric)
language sql
stable
set search_path to 'public'
as $$
  select a.id,
         a.starting_balance + coalesce(sum(
           case when t.type = 'GASTO' then -t.amount else t.amount end
         ), 0)
  from public.accounts a
  left join public.transactions t
    on t.account_id = a.id and t.household_id = a.household_id
  where a.household_id = p_household
    and a.is_active
  group by a.id, a.starting_balance
$$;
