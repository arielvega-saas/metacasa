-- Migration: multi_currency_extended
-- Aplicada: 2026-04-19
--
-- FASE 1: multi-moneda extendida a budgets, bills + fx_rates cache.

-- FX en budgets legacy (para transicion)
alter table public.budgets add column if not exists currency text not null default 'USD';
alter table public.budgets add column if not exists amount_original numeric;
alter table public.budgets add column if not exists currency_original text;
alter table public.budgets add column if not exists fx_rate_to_base numeric default 1;

-- FX en bills
alter table public.bills add column if not exists currency text not null default 'USD';
alter table public.bills add column if not exists amount_original numeric;
alter table public.bills add column if not exists currency_original text;
alter table public.bills add column if not exists fx_rate_to_base numeric default 1;

-- fx_rates: cache de tasas diarias
create table if not exists public.fx_rates (
  base_currency text not null,
  quote_currency text not null,
  rate_date date not null,
  rate numeric not null check (rate > 0),
  source text not null default 'MANUAL',
  created_at timestamptz not null default now(),
  primary key (base_currency, quote_currency, rate_date)
);
create index if not exists idx_fx_rates_date on public.fx_rates (rate_date desc);

alter table public.fx_rates enable row level security;
create policy "fx_rates_select_authenticated" on public.fx_rates for select
  to authenticated using (true);
-- INSERT/UPDATE/DELETE reservados a service_role.

create or replace function public.latest_fx_rate(p_base text, p_quote text) returns numeric
language sql stable security invoker set search_path = public as $$
  select rate from public.fx_rates
  where base_currency = p_base and quote_currency = p_quote
  order by rate_date desc
  limit 1
$$;
grant execute on function public.latest_fx_rate(text, text) to authenticated;

comment on table public.fx_rates is 'Cache de tasas de cambio diarias. Sincronizado via edge function con API externa.';
