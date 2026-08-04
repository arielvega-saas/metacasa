-- Migration: envelope_budgets_v2
-- Aplicada: 2026-04-19
--
-- FASE 1: modelo envelope budgeting YNAB-style.
-- budget_periods + budget_allocations + envelope_balance(period_id, category, subcategory) helper.
-- La tabla legacy `budgets` queda marcada como DEPRECATED hasta migrar la UI.

create table if not exists public.budget_periods (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade default public.current_user_default_household(),
  period_type text not null check (period_type in ('week', 'biweek', 'month', 'quarter', 'year', 'custom')) default 'month',
  period_start date not null,
  period_end date not null,
  total_income numeric not null default 0,
  total_allocated numeric not null default 0,
  ready_to_assign numeric not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, period_start, period_end),
  check (period_end >= period_start)
);
create index if not exists idx_budget_periods_household on public.budget_periods (household_id, period_start desc);

create trigger budget_periods_updated_at before update on public.budget_periods
  for each row execute function public.tg_update_updated_at();

alter table public.budget_periods enable row level security;
create policy "budget_periods_select_household" on public.budget_periods for select
  using (public.is_household_member(household_id));
create policy "budget_periods_insert_household" on public.budget_periods for insert
  with check (public.is_household_member(household_id));
create policy "budget_periods_update_household" on public.budget_periods for update
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "budget_periods_delete_household" on public.budget_periods for delete
  using (public.is_household_member(household_id));

create table if not exists public.budget_allocations (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.budget_periods(id) on delete cascade,
  category text not null,
  subcategory text not null default '',
  allocated numeric not null default 0 check (allocated >= 0),
  rollover_from_prev numeric not null default 0,
  rollover_mode text not null check (rollover_mode in ('none', 'surplus', 'full')) default 'surplus',
  currency text not null default 'USD',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (period_id, category, subcategory)
);
create index if not exists idx_budget_allocations_period on public.budget_allocations (period_id);

create trigger budget_allocations_updated_at before update on public.budget_allocations
  for each row execute function public.tg_update_updated_at();

alter table public.budget_allocations enable row level security;
create policy "budget_allocations_select_household" on public.budget_allocations for select
  using (exists (select 1 from public.budget_periods bp where bp.id = budget_allocations.period_id and public.is_household_member(bp.household_id)));
create policy "budget_allocations_insert_household" on public.budget_allocations for insert
  with check (exists (select 1 from public.budget_periods bp where bp.id = period_id and public.is_household_member(bp.household_id)));
create policy "budget_allocations_update_household" on public.budget_allocations for update
  using (exists (select 1 from public.budget_periods bp where bp.id = budget_allocations.period_id and public.is_household_member(bp.household_id)));
create policy "budget_allocations_delete_household" on public.budget_allocations for delete
  using (exists (select 1 from public.budget_periods bp where bp.id = budget_allocations.period_id and public.is_household_member(bp.household_id)));

create or replace function public.envelope_balance(
  p_period_id uuid,
  p_category text,
  p_subcategory text default ''
) returns numeric
language sql stable security invoker set search_path = public as $$
  with alloc as (
    select ba.allocated + ba.rollover_from_prev as budgeted
    from public.budget_allocations ba
    where ba.period_id = p_period_id
      and ba.category = p_category
      and ba.subcategory = p_subcategory
    limit 1
  ), period as (
    select period_start, period_end, household_id from public.budget_periods where id = p_period_id
  ), spent as (
    select coalesce(sum(t.amount), 0) as total
    from public.transactions t, period p
    where t.household_id = p.household_id
      and t.type = 'GASTO'
      and t.category = p_category
      and coalesce(t.subcategory, '') = p_subcategory
      and t.date::date >= p.period_start
      and t.date::date <= p.period_end
  )
  select coalesce((select budgeted from alloc), 0) - (select total from spent);
$$;
grant execute on function public.envelope_balance(uuid, text, text) to authenticated;

comment on table public.budgets is 'DEPRECATED desde 2026-04-19 Fase 1: reemplazado por budget_periods + budget_allocations. Mantener hasta migrar UI.';
