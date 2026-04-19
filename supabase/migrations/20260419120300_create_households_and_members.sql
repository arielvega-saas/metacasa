-- Migration: create_households_and_members
-- Aplicada: 2026-04-19
--
-- FASE 1: Modelo multi-tenant para hogares compartidos.
-- Crea households + household_members + household_invitations + helpers + RLS.

-- 1. households
create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Mi Hogar',
  created_by uuid not null references auth.users(id) on delete restrict,
  timezone text not null default 'UTC',
  default_currency text not null default 'USD',
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.households is 'Hogar compartido: contenedor de presupuestos, cuentas, transacciones. Uno o mas usuarios son miembros.';
comment on column public.households.default_currency is 'Moneda principal del hogar (ISO 4217). Transacciones pueden ser en otras monedas con FX.';

-- 2. household_members
create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member', 'viewer')),
  display_name text,
  joined_at timestamptz not null default now(),
  invited_by uuid references auth.users(id),
  primary key (household_id, user_id)
);

comment on table public.household_members is 'Membership. Roles: owner > admin > member > viewer.';
create index if not exists idx_household_members_user_id on public.household_members (user_id);

-- 3. household_invitations
create table if not exists public.household_invitations (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  email text not null,
  role text not null default 'member' check (role in ('admin', 'member', 'viewer')),
  invite_token text not null unique default encode(gen_random_bytes(24), 'hex'),
  invited_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'expired', 'revoked')),
  created_at timestamptz not null default now()
);
create index if not exists idx_household_invitations_household_id on public.household_invitations (household_id);
create index if not exists idx_household_invitations_email on public.household_invitations (email);

-- 4. Helpers
create or replace function public.current_user_household_ids() returns setof uuid
language sql stable security invoker set search_path = public as $$
  select household_id from public.household_members where user_id = (select auth.uid())
$$;
grant execute on function public.current_user_household_ids() to authenticated;

create or replace function public.is_household_member(hid uuid) returns boolean
language sql stable security invoker set search_path = public as $$
  select exists (
    select 1 from public.household_members
    where household_id = hid and user_id = (select auth.uid())
  )
$$;
grant execute on function public.is_household_member(uuid) to authenticated;

create or replace function public.current_user_household_role(hid uuid) returns text
language sql stable security invoker set search_path = public as $$
  select role from public.household_members
  where household_id = hid and user_id = (select auth.uid())
$$;
grant execute on function public.current_user_household_role(uuid) to authenticated;

-- 5. Trigger genérico updated_at
create or replace function public.tg_update_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists households_updated_at on public.households;
create trigger households_updated_at before update on public.households
  for each row execute function public.tg_update_updated_at();

-- 6. RLS
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invitations enable row level security;

create policy "households_select_members" on public.households for select
  using (id in (select public.current_user_household_ids()));
create policy "households_insert_authenticated" on public.households for insert
  with check ((select auth.uid()) = created_by);
create policy "households_update_admins" on public.households for update
  using (public.current_user_household_role(id) in ('owner', 'admin'))
  with check (public.current_user_household_role(id) in ('owner', 'admin'));
create policy "households_delete_owner" on public.households for delete
  using (public.current_user_household_role(id) = 'owner');

create policy "household_members_select_same_household" on public.household_members for select
  using (household_id in (select public.current_user_household_ids()));
create policy "household_members_insert_self_or_admin" on public.household_members for insert
  with check (
    user_id = (select auth.uid())
    or public.current_user_household_role(household_id) in ('owner', 'admin')
  );
create policy "household_members_update_admins" on public.household_members for update
  using (public.current_user_household_role(household_id) in ('owner', 'admin'));
create policy "household_members_delete_admin_or_self" on public.household_members for delete
  using (
    user_id = (select auth.uid())
    or public.current_user_household_role(household_id) in ('owner', 'admin')
  );

create policy "household_invitations_select_admins" on public.household_invitations for select
  using (public.current_user_household_role(household_id) in ('owner', 'admin'));
create policy "household_invitations_insert_admins" on public.household_invitations for insert
  with check (
    invited_by = (select auth.uid())
    and public.current_user_household_role(household_id) in ('owner', 'admin')
  );
create policy "household_invitations_update_admins" on public.household_invitations for update
  using (public.current_user_household_role(household_id) in ('owner', 'admin'));
create policy "household_invitations_delete_admins" on public.household_invitations for delete
  using (public.current_user_household_role(household_id) in ('owner', 'admin'));

-- 7. Backfill: household default para usuarios existentes
do $$
declare
  u record;
  hid uuid;
begin
  for u in (
    select id, email from auth.users
    where not exists (select 1 from public.household_members hm where hm.user_id = auth.users.id)
  )
  loop
    insert into public.households (name, created_by, default_currency)
    values ('Mi Hogar', u.id, 'USD')
    returning id into hid;
    insert into public.household_members (household_id, user_id, role, display_name)
    values (hid, u.id, 'owner', coalesce(u.email, 'Owner'));
  end loop;
end $$;
