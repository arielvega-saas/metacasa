-- Migration: fix_advisor_warnings_final
-- Aplicada: 2026-04-19
--
-- Cierra los ultimos warnings de advisor tras Fase 1:
-- 1) search_path explicito en tg_update_updated_at (function_search_path_mutable)
-- 2) FK indexes que faltaban en tablas nuevas (accounts, goals, goal_contributions, households, household_members, household_invitations)

create or replace function public.tg_update_updated_at() returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create index if not exists idx_accounts_created_by on public.accounts (created_by);
create index if not exists idx_goals_created_by on public.goals (created_by);
create index if not exists idx_goals_account_id on public.goals (account_id);
create index if not exists idx_goal_contributions_contributed_by on public.goal_contributions (contributed_by);
create index if not exists idx_goal_contributions_transaction_id on public.goal_contributions (transaction_id);
create index if not exists idx_households_created_by on public.households (created_by);
create index if not exists idx_household_members_invited_by on public.household_members (invited_by);
create index if not exists idx_household_invitations_invited_by on public.household_invitations (invited_by);
create index if not exists idx_household_invitations_accepted_by on public.household_invitations (accepted_by);
