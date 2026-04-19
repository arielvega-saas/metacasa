-- Migration: create_goals_and_contributions
-- Aplicada: 2026-04-19
--
-- FASE 1: metas de ahorro del hogar + log de contribuciones + trigger de sync.

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade default public.current_user_default_household(),
  name text not null,
  description text,
  target_amount numeric not null check (target_amount > 0),
  current_amount numeric not null default 0 check (current_amount >= 0),
  currency text not null default 'USD',
  target_date date,
  status text not null check (status in ('active', 'completed', 'paused', 'canceled')) default 'active',
  icon text,
  color text,
  priority integer not null default 0,
  category text,
  account_id uuid references public.accounts(id) on delete set null,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists idx_goals_household on public.goals (household_id, status, priority desc);

create trigger goals_updated_at before update on public.goals
  for each row execute function public.tg_update_updated_at();

alter table public.goals enable row level security;
create policy "goals_select_household" on public.goals for select
  using (public.is_household_member(household_id));
create policy "goals_insert_household" on public.goals for insert
  with check (public.is_household_member(household_id) and created_by = (select auth.uid()));
create policy "goals_update_household" on public.goals for update
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "goals_delete_household" on public.goals for delete
  using (public.is_household_member(household_id));

create table if not exists public.goal_contributions (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.goals(id) on delete cascade,
  amount numeric not null check (amount > 0),
  contributed_by uuid not null references auth.users(id),
  contributed_at timestamptz not null default now(),
  notes text,
  transaction_id uuid references public.transactions(id) on delete set null
);
create index if not exists idx_goal_contributions_goal on public.goal_contributions (goal_id, contributed_at desc);

alter table public.goal_contributions enable row level security;
create policy "goal_contributions_select_household" on public.goal_contributions for select
  using (exists (select 1 from public.goals g where g.id = goal_contributions.goal_id and public.is_household_member(g.household_id)));
create policy "goal_contributions_insert_household" on public.goal_contributions for insert
  with check (exists (select 1 from public.goals g where g.id = goal_id and public.is_household_member(g.household_id)) and contributed_by = (select auth.uid()));
create policy "goal_contributions_delete_household" on public.goal_contributions for delete
  using (exists (select 1 from public.goals g where g.id = goal_contributions.goal_id and public.is_household_member(g.household_id)));

create or replace function public.tg_goal_contribution_apply() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  g record;
begin
  if (TG_OP = 'INSERT') then
    update public.goals
    set current_amount = current_amount + new.amount,
        status = case when current_amount + new.amount >= target_amount and status = 'active' then 'completed' else status end,
        completed_at = case when current_amount + new.amount >= target_amount and status = 'active' then now() else completed_at end
    where id = new.goal_id
    returning * into g;
  elsif (TG_OP = 'DELETE') then
    update public.goals
    set current_amount = greatest(0, current_amount - old.amount),
        status = case when status = 'completed' and current_amount - old.amount < target_amount then 'active' else status end,
        completed_at = case when status = 'completed' and current_amount - old.amount < target_amount then null else completed_at end
    where id = old.goal_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists goal_contributions_apply on public.goal_contributions;
create trigger goal_contributions_apply
  after insert or delete on public.goal_contributions
  for each row execute function public.tg_goal_contribution_apply();
