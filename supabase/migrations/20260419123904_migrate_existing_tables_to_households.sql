-- Migration: migrate_existing_tables_to_households
-- Aplicada: 2026-04-19
--
-- Agrega household_id a todas las tablas existentes, backfillea desde user_id,
-- y reescribe RLS para usar household membership.

-- Helper: household default del caller (para que INSERTs sin household_id funcionen)
create or replace function public.current_user_default_household() returns uuid
language sql stable security invoker set search_path = public as $$
  select household_id from public.household_members
  where user_id = (select auth.uid())
  order by joined_at asc
  limit 1
$$;
grant execute on function public.current_user_default_household() to authenticated;

-- TRANSACTIONS
alter table public.transactions add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.transactions t set household_id = hm.household_id
from public.household_members hm
where t.user_id = hm.user_id and t.household_id is null;
alter table public.transactions alter column household_id set not null;
alter table public.transactions alter column household_id set default public.current_user_default_household();
create index if not exists idx_transactions_household_id_date on public.transactions (household_id, date desc);

drop policy if exists "Users can select their transactions" on public.transactions;
drop policy if exists "Users can insert their transactions" on public.transactions;
drop policy if exists "Users can update their transactions" on public.transactions;
drop policy if exists "Users can delete their transactions" on public.transactions;
create policy "transactions_select_household" on public.transactions for select
  using (public.is_household_member(household_id));
create policy "transactions_insert_household" on public.transactions for insert
  with check (public.is_household_member(household_id) and user_id = (select auth.uid()));
create policy "transactions_update_household" on public.transactions for update
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "transactions_delete_household" on public.transactions for delete
  using (public.is_household_member(household_id));

-- BUDGETS
alter table public.budgets add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.budgets b set household_id = hm.household_id
from public.household_members hm
where b.user_id = hm.user_id and b.household_id is null;
alter table public.budgets alter column household_id set not null;
alter table public.budgets alter column household_id set default public.current_user_default_household();
create index if not exists idx_budgets_household_id on public.budgets (household_id);

drop policy if exists "Users can manage their budgets" on public.budgets;
create policy "budgets_select_household" on public.budgets for select using (public.is_household_member(household_id));
create policy "budgets_insert_household" on public.budgets for insert with check (public.is_household_member(household_id) and user_id = (select auth.uid()));
create policy "budgets_update_household" on public.budgets for update using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "budgets_delete_household" on public.budgets for delete using (public.is_household_member(household_id));

-- CATEGORIES (PK cambia a household_id)
alter table public.categories add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.categories c set household_id = hm.household_id
from public.household_members hm
where c.user_id = hm.user_id and c.household_id is null;
alter table public.categories alter column household_id set not null;
alter table public.categories alter column household_id set default public.current_user_default_household();
alter table public.categories drop constraint if exists categories_pkey;
alter table public.categories add constraint categories_pkey primary key (household_id);

drop policy if exists "Users can manage their categories" on public.categories;
create policy "categories_select_household" on public.categories for select using (public.is_household_member(household_id));
create policy "categories_insert_household" on public.categories for insert with check (public.is_household_member(household_id));
create policy "categories_update_household" on public.categories for update using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "categories_delete_household" on public.categories for delete using (public.is_household_member(household_id));

-- STRATEGY (PK cambia a household_id)
alter table public.strategy add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.strategy s set household_id = hm.household_id
from public.household_members hm
where s.user_id = hm.user_id and s.household_id is null;
alter table public.strategy alter column household_id set not null;
alter table public.strategy alter column household_id set default public.current_user_default_household();
alter table public.strategy drop constraint if exists strategy_pkey;
alter table public.strategy add constraint strategy_pkey primary key (household_id);

drop policy if exists "Users can manage their strategy" on public.strategy;
create policy "strategy_select_household" on public.strategy for select using (public.is_household_member(household_id));
create policy "strategy_insert_household" on public.strategy for insert with check (public.is_household_member(household_id));
create policy "strategy_update_household" on public.strategy for update using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "strategy_delete_household" on public.strategy for delete using (public.is_household_member(household_id));

-- BILLS
alter table public.bills add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.bills b set household_id = hm.household_id
from public.household_members hm
where b.user_id = hm.user_id and b.household_id is null;
alter table public.bills alter column household_id set not null;
alter table public.bills alter column household_id set default public.current_user_default_household();
create index if not exists idx_bills_household_id on public.bills (household_id);

drop policy if exists "bills_select" on public.bills;
drop policy if exists "bills_insert" on public.bills;
drop policy if exists "bills_update" on public.bills;
drop policy if exists "bills_delete" on public.bills;
create policy "bills_select_household" on public.bills for select using (public.is_household_member(household_id));
create policy "bills_insert_household" on public.bills for insert with check (public.is_household_member(household_id) and user_id = (select auth.uid()));
create policy "bills_update_household" on public.bills for update using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "bills_delete_household" on public.bills for delete using (public.is_household_member(household_id));

-- CONNECTED_WALLETS
alter table public.connected_wallets add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.connected_wallets w set household_id = hm.household_id
from public.household_members hm
where w.user_id = hm.user_id and w.household_id is null;
alter table public.connected_wallets alter column household_id set not null;
alter table public.connected_wallets alter column household_id set default public.current_user_default_household();
create index if not exists idx_connected_wallets_household_id on public.connected_wallets (household_id);

drop policy if exists "own wallets" on public.connected_wallets;
create policy "wallets_select_household" on public.connected_wallets for select using (public.is_household_member(household_id));
create policy "wallets_insert_household" on public.connected_wallets for insert with check (public.is_household_member(household_id) and user_id = (select auth.uid()));
create policy "wallets_update_household" on public.connected_wallets for update using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "wallets_delete_household" on public.connected_wallets for delete using (public.is_household_member(household_id));

-- WALLET_MOVEMENTS
alter table public.wallet_movements add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.wallet_movements wm set household_id = cw.household_id
from public.connected_wallets cw
where wm.wallet_id = cw.id and wm.household_id is null;
update public.wallet_movements wm set household_id = hm.household_id
from public.household_members hm
where wm.user_id = hm.user_id and wm.household_id is null;
alter table public.wallet_movements alter column household_id set not null;
alter table public.wallet_movements alter column household_id set default public.current_user_default_household();
create index if not exists idx_wallet_movements_household_id on public.wallet_movements (household_id);

drop policy if exists "own movements" on public.wallet_movements;
create policy "wallet_movements_select_household" on public.wallet_movements for select using (public.is_household_member(household_id));
create policy "wallet_movements_insert_household" on public.wallet_movements for insert with check (public.is_household_member(household_id) and user_id = (select auth.uid()));
create policy "wallet_movements_update_household" on public.wallet_movements for update using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "wallet_movements_delete_household" on public.wallet_movements for delete using (public.is_household_member(household_id));

-- RECURRING_TRANSACTIONS
alter table public.recurring_transactions add column if not exists household_id uuid references public.households(id) on delete cascade;
update public.recurring_transactions r set household_id = hm.household_id
from public.household_members hm
where r.user_id = hm.user_id and r.household_id is null;
alter table public.recurring_transactions alter column household_id set not null;
alter table public.recurring_transactions alter column household_id set default public.current_user_default_household();
create index if not exists idx_recurring_transactions_household_id on public.recurring_transactions (household_id);

drop policy if exists "own recurring" on public.recurring_transactions;
create policy "recurring_select_household" on public.recurring_transactions for select using (public.is_household_member(household_id));
create policy "recurring_insert_household" on public.recurring_transactions for insert with check (public.is_household_member(household_id) and user_id = (select auth.uid()));
create policy "recurring_update_household" on public.recurring_transactions for update using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy "recurring_delete_household" on public.recurring_transactions for delete using (public.is_household_member(household_id));
