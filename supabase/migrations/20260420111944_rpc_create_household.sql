-- Recuperada del ledger de producción el 2026-08-03.
--
-- Estaba aplicada en prod pero SIN archivo en el repo: alguien la aplicó por API/dashboard y
-- nunca la versionó. Un `db reset` desde el repo habría producido un schema distinto al de prod,
-- y cualquier razonamiento sobre "qué hay en la base" mirando el repo habría sido falso.
-- Ver la memoria `leccion-drift-migraciones-supabase`.

-- RPC atómica para crear un hogar + agregar al caller como owner member.
-- Usa auth.uid() internamente para evitar issues de RLS cuando el JWT no
-- se propaga bien del cliente. Si no hay JWT válido, tira 'not_authenticated'.

create or replace function public.create_household(
  p_name text,
  p_currency text default 'USD',
  p_timezone text default 'UTC'
) returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid;
  new_household public.households;
begin
  caller := auth.uid();
  if caller is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.households (name, default_currency, timezone, created_by)
  values (p_name, p_currency, p_timezone, caller)
  returning * into new_household;

  insert into public.household_members (household_id, user_id, role)
  values (new_household.id, caller, 'owner');

  return new_household;
end;
$$;

revoke all on function public.create_household(text, text, text) from public, anon;
grant execute on function public.create_household(text, text, text) to authenticated;

comment on function public.create_household(text, text, text) is
  'Crea un hogar y agrega al caller como owner en una sola transacción. Bypasea RLS para inserts, usa auth.uid() como fuente de verdad.';
