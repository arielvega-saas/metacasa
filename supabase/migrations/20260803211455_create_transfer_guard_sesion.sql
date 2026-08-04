-- Guard de sesión en `create_transfer`. Existe como migración propia porque así se aplicó en
-- producción: el primer intento de la función falló con NOT NULL sobre `user_id` cuando
-- `auth.uid()` era null (llamada sin sesión), y el arreglo entró como un paso separado.
--
-- El archivo del RPC (`20260803211359_create_transfer_rpc.sql`) ya incluye el guard, así que
-- desde un reset limpio esta migración es un no-op idempotente. Se versiona igual para que el
-- repo diga exactamente la misma secuencia que el ledger de prod: una migración aplicada que
-- no está en el repo es la forma en que se pierde la trazabilidad — pasó antes y está anotado
-- en la memoria `leccion-drift-migraciones-supabase`.
--
-- Fallar con un mensaje claro importa: sin el guard, el error que veía el usuario era una
-- violación de NOT NULL sobre una columna interna, que no dice nada de que falta la sesión.

do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_transfer'
  ) then
    raise exception 'create_transfer no existe: aplicar antes 20260803211359_create_transfer_rpc.sql';
  end if;
end $$;
