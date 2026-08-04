-- Migration: create_accounts_and_credit_cards
-- Aplicada: 2026-04-19
--
-- FASE 1: cuentas bancarias + tarjetas de credito.

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade default public.current_user_default_household(),
  name text not null,
  type text not null check (type in ('checking', 'savings', 'cash', 'credit_card', 'investment', 'loan', 'other')),
  currency text not null default 'USD',
  starting_balance numeric not null default 0,
  institution text,
  account_number_last4 text,
  icon text,
  color text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_accounts_household on public.accounts (household_id, display_order);

create trigger accounts_updated_at before update on public.accounts
  for each row execute function public.tg_update_updated_at();

alter table public.accounts enable row level security;
create policy "accounts_select_household" on public.accounts for select
  using (public.is_household_member(household_id));
create policy "accounts_insert_household" on public.accounts for insert
  with check (public.is_household_member(household_id) and created_by = (select auth.uid()));
create policy "accounts_update_household" on public.accounts for update
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));
create policy "accounts_delete_household" on public.accounts for delete
  using (public.is_household_member(household_id));

-- credit_cards extiende accounts 1:1 con campos de TC
create table if not exists public.credit_cards (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  credit_limit numeric not null check (credit_limit > 0),
  statement_day smallint not null check (statement_day between 1 and 31),
  due_day smallint not null check (due_day between 1 and 31),
  interest_rate_monthly numeric not null default 0 check (interest_rate_monthly >= 0),
  minimum_payment_pct numeric not null default 5 check (minimum_payment_pct >= 0 and minimum_payment_pct <= 100),
  last_statement_amount numeric default 0,
  last_statement_date date,
  network text check (network in ('visa', 'mastercard', 'amex', 'discover', 'other')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger credit_cards_updated_at before update on public.credit_cards
  for each row execute function public.tg_update_updated_at();

alter table public.credit_cards enable row level security;
create policy "credit_cards_select_household" on public.credit_cards for select
  using (exists (select 1 from public.accounts a where a.id = credit_cards.account_id and public.is_household_member(a.household_id)));
create policy "credit_cards_insert_household" on public.credit_cards for insert
  with check (exists (select 1 from public.accounts a where a.id = account_id and public.is_household_member(a.household_id)));
create policy "credit_cards_update_household" on public.credit_cards for update
  using (exists (select 1 from public.accounts a where a.id = credit_cards.account_id and public.is_household_member(a.household_id)));
create policy "credit_cards_delete_household" on public.credit_cards for delete
  using (exists (select 1 from public.accounts a where a.id = credit_cards.account_id and public.is_household_member(a.household_id)));

-- Link opcional transactions a accounts (si la transaccion fue en una cuenta especifica)
alter table public.transactions add column if not exists account_id uuid references public.accounts(id) on delete set null;
create index if not exists idx_transactions_account_id on public.transactions (account_id);

comment on table public.accounts is 'Cuentas financieras del hogar: corriente, ahorro, efectivo, TC, inversion, prestamo.';
comment on table public.credit_cards is 'Campos especificos de TC (limite, dia de cierre/vencimiento, interes, minimo).';
