-- Crear y borrar transferencias de forma ATÓMICA.
--
-- Hoy `AIToolHandler.transferBetweenAccounts` hace dos inserts PostgREST separados: dos
-- transacciones HTTP independientes. Si la segunda falla queda un GASTO huérfano que le come plata
-- al usuario sin contrapartida — el propio código lo admite en el texto de su mensaje de error.
--
-- El cuerpo de una función plpgsql corre dentro de una sola transacción, y acá además es un único
-- `INSERT ... VALUES (fila1),(fila2)`: atómico incluso a nivel statement. No hace falta manejo
-- explícito de rollback.
--
-- SECURITY INVOKER a propósito, NO definer: así la RLS sigue activa y un usuario no puede insertar
-- en un hogar del que no es miembro. Un definer acá ampliaría la superficie sin necesidad.
--
-- El guard de sesión lo encontró el propio test: sin él, llamarla sin `auth.uid()` reventaba con
-- "null value in column user_id violates not-null constraint", un error de constraint que no le
-- dice nada a nadie.
--
-- Verificado en prod el 2026-08-03: 2 piernas con desbalance 0; rechaza cuenta de otro hogar,
-- monto negativo, misma cuenta y falta de sesión; y de 3 intentos fallidos NO quedó ni una fila
-- (61 → 63, sólo las 2 de la transferencia válida). `v_transfer_health` vacía.

create or replace function public.create_transfer(
  p_household     uuid,
  p_from_account  uuid,
  p_to_account    uuid,
  p_amount        numeric,
  p_date          timestamptz,
  p_note          text default null
) returns uuid
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  g uuid := gen_random_uuid();
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Se requiere una sesión de usuario' using errcode = '42501';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'El monto debe ser mayor a 0' using errcode = '22023';
  end if;

  if p_from_account is null or p_to_account is null then
    raise exception 'Faltan las cuentas de origen o destino' using errcode = '22023';
  end if;

  if p_from_account = p_to_account then
    raise exception 'Origen y destino deben ser cuentas distintas' using errcode = '22023';
  end if;

  -- Las dos cuentas tienen que ser del MISMO hogar. Sin esto se podría "mover" plata hacia el
  -- hogar de otra persona, generando un ingreso fantasma del otro lado.
  if (select count(*) from public.accounts
       where id in (p_from_account, p_to_account)
         and household_id = p_household) <> 2 then
    raise exception 'Las cuentas no pertenecen a este hogar' using errcode = '42501';
  end if;

  insert into public.transactions
    (household_id, user_id, account_id, type, amount, category, note, date, transfer_group_id)
  values
    (p_household, v_user, p_from_account, 'GASTO',   p_amount, 'Transferencia',
       coalesce(p_note, 'Transferencia entre cuentas'), p_date, g),
    (p_household, v_user, p_to_account,   'INGRESO', p_amount, 'Transferencia',
       coalesce(p_note, 'Transferencia entre cuentas'), p_date, g);

  return g;
end $$;

revoke all on function public.create_transfer(uuid,uuid,uuid,numeric,timestamptz,text) from public;
grant execute on function public.create_transfer(uuid,uuid,uuid,numeric,timestamptz,text) to authenticated;

comment on function public.create_transfer(uuid,uuid,uuid,numeric,timestamptz,text) is
  'Crea las dos piernas de una transferencia en un solo INSERT atomico, vinculadas por '
  'transfer_group_id. SECURITY INVOKER: la RLS decide. Valida sesion, monto > 0, cuentas distintas '
  'y que ambas sean del mismo hogar.';

-- Borrar una transferencia completa. Sin esto, borrar una pierna desde la UI deja la otra colgada.
create or replace function public.delete_transfer(p_group uuid)
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare v_count integer;
begin
  delete from public.transactions where transfer_group_id = p_group;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

revoke all on function public.delete_transfer(uuid) from public;
grant execute on function public.delete_transfer(uuid) to authenticated;

comment on function public.delete_transfer(uuid) is
  'Borra las dos piernas de una transferencia. La RLS filtra: solo borra lo que el usuario puede ver.';
