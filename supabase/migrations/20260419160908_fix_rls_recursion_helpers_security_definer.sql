-- Migration: fix_rls_recursion_helpers_security_definer
-- Aplicada: 2026-04-19
--
-- Fix: "stack depth limit exceeded" al crear hogar desde el cliente.
--
-- Las helper functions (current_user_household_ids, is_household_member,
-- current_user_household_role, current_user_default_household) estaban
-- como security invoker. Al ser invocadas desde policies RLS, sus queries
-- internos sobre household_members disparaban las mismas policies
-- recursivamente → stack depth limit exceeded.
--
-- Solución: declararlas como security definer. Ejecutan con permisos del
-- owner y bypasean RLS al consultar household_members. Son seguras porque
-- filtran siempre por user_id = (select auth.uid()) → solo devuelven data
-- del caller.

create or replace function public.current_user_household_ids() returns setof uuid
language sql stable security definer set search_path = public as $$
  select household_id from public.household_members where user_id = (select auth.uid())
$$;

create or replace function public.is_household_member(hid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.household_members
    where household_id = hid and user_id = (select auth.uid())
  )
$$;

create or replace function public.current_user_household_role(hid uuid) returns text
language sql stable security definer set search_path = public as $$
  select role from public.household_members
  where household_id = hid and user_id = (select auth.uid())
$$;

create or replace function public.current_user_default_household() returns uuid
language sql stable security definer set search_path = public as $$
  select household_id from public.household_members
  where user_id = (select auth.uid())
  order by joined_at asc
  limit 1
$$;

grant execute on function public.current_user_household_ids() to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.current_user_household_role(uuid) to authenticated;
grant execute on function public.current_user_default_household() to authenticated;
