-- Migration: revenuecat_subscriptions_and_entitlements
-- Aplicada: 2026-04-19
--
-- FASE 1: modelo de subscriptions (RevenueCat) + cache de entitlements + helpers.
-- Las inserts/updates deben venir del webhook de RevenueCat via service_role.

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  revenuecat_user_id text,
  product_id text not null,
  entitlement_id text not null,
  store text not null check (store in ('app_store', 'play_store', 'stripe', 'promotional')),
  environment text not null check (environment in ('production', 'sandbox')) default 'production',
  status text not null check (status in ('active', 'trialing', 'grace_period', 'canceled', 'expired', 'paused', 'billing_issue')),
  period_type text check (period_type in ('normal', 'intro', 'trial')),
  purchased_at timestamptz,
  renewed_at timestamptz,
  expires_at timestamptz,
  canceled_at timestamptz,
  unsubscribe_detected_at timestamptz,
  original_transaction_id text,
  latest_receipt_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_subscriptions_user on public.subscriptions (user_id, status);
create index if not exists idx_subscriptions_entitlement on public.subscriptions (entitlement_id, status);
create index if not exists idx_subscriptions_expires on public.subscriptions (expires_at) where status in ('active', 'trialing', 'grace_period');

create trigger subscriptions_updated_at before update on public.subscriptions
  for each row execute function public.tg_update_updated_at();

alter table public.subscriptions enable row level security;
create policy "subscriptions_select_self" on public.subscriptions for select
  using (user_id = (select auth.uid()));

create table if not exists public.user_entitlements (
  user_id uuid not null references auth.users(id) on delete cascade,
  entitlement text not null,
  is_active boolean not null default false,
  expires_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, entitlement)
);
create index if not exists idx_user_entitlements_active on public.user_entitlements (is_active, expires_at);

alter table public.user_entitlements enable row level security;
create policy "user_entitlements_select_self" on public.user_entitlements for select
  using (user_id = (select auth.uid()));

create or replace function public.has_active_entitlement(ent text) returns boolean
language sql stable security invoker set search_path = public as $$
  select coalesce(
    (select is_active and (expires_at is null or expires_at > now())
     from public.user_entitlements
     where user_id = (select auth.uid()) and entitlement = ent
     limit 1),
    false
  )
$$;
grant execute on function public.has_active_entitlement(text) to authenticated;

create or replace function public.tg_sync_user_entitlements() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  target_user uuid;
  target_ent text;
begin
  target_user := coalesce(new.user_id, old.user_id);
  target_ent := coalesce(new.entitlement_id, old.entitlement_id);

  insert into public.user_entitlements (user_id, entitlement, is_active, expires_at, updated_at)
  values (
    target_user,
    target_ent,
    exists (
      select 1 from public.subscriptions
      where user_id = target_user
        and entitlement_id = target_ent
        and status in ('active', 'trialing', 'grace_period')
        and (expires_at is null or expires_at > now())
    ),
    (select max(expires_at) from public.subscriptions where user_id = target_user and entitlement_id = target_ent),
    now()
  )
  on conflict (user_id, entitlement) do update
  set is_active = excluded.is_active,
      expires_at = excluded.expires_at,
      updated_at = now();

  return coalesce(new, old);
end;
$$;

drop trigger if exists subscriptions_sync_entitlements on public.subscriptions;
create trigger subscriptions_sync_entitlements
  after insert or update or delete on public.subscriptions
  for each row execute function public.tg_sync_user_entitlements();

comment on table public.subscriptions is 'Suscripciones de RevenueCat. Escritas via webhook desde RevenueCat con service_role.';
comment on table public.user_entitlements is 'Cache de entitlements activos para consultas rapidas. Sincronizado automaticamente desde subscriptions.';
