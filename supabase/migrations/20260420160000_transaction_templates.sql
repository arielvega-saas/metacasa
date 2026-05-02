-- Migration: transaction_templates
-- Aplicada: 2026-04-20
--
-- Port del feature "quick shortcuts" de la PWA (App.jsx:3229-3244).
-- Permite guardar transacciones frecuentes como plantillas para crear con 1 tap
-- desde AddTransactionView en iOS y desde el panel de atajos en web.

create table if not exists public.transaction_templates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade default public.current_user_default_household(),
  created_by uuid not null references auth.users(id) on delete set null,
  name text not null,
  emoji text,
  type text not null check (type in ('GASTO', 'INGRESO')),
  amount numeric not null check (amount > 0),
  currency text not null default 'USD',
  category text not null,
  subcategory text,
  note text,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_transaction_templates_household
  on public.transaction_templates (household_id, position);

create trigger transaction_templates_updated_at
  before update on public.transaction_templates
  for each row execute function public.tg_update_updated_at();

alter table public.transaction_templates enable row level security;

create policy "transaction_templates_select_household"
  on public.transaction_templates for select
  using (public.is_household_member(household_id));

create policy "transaction_templates_insert_household"
  on public.transaction_templates for insert
  with check (public.is_household_member(household_id));

create policy "transaction_templates_update_household"
  on public.transaction_templates for update
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy "transaction_templates_delete_household"
  on public.transaction_templates for delete
  using (public.is_household_member(household_id));

comment on table public.transaction_templates is 'Quick shortcuts — transacciones frecuentes guardadas como plantillas. Cross-device sync via household_id.';
