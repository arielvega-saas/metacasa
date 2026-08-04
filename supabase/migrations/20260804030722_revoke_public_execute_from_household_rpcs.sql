-- Corrige `20260804030652`, que fue un no-op.
--
-- `month_summary` y `spending_insights` son SECURITY DEFINER y `anon` podía ejecutarlas. Las dos
-- validan pertenencia al hogar adentro, así que un llamador sin sesión ya fallaba el chequeo: no
-- hubo fuga. Pero que una función SECURITY DEFINER —que ignora RLS por definición— esté al
-- alcance de cualquiera con la anon key deja toda la seguridad colgando de una línea adentro.
--
-- Es la forma exacta del bug de `wallet-proxy` (auditoría 2026-08-01): `verify_jwt: true` parecía
-- suficiente porque la anon key ES un JWT del proyecto, y el chequeo real estaba después del
-- switch.
--
-- El permiso venía de PUBLIC, no de `anon`. En el ACL se ve como `=X/postgres`: la entrada sin
-- rol a la izquierda ES PUBLIC, y es fácil leerla por encima. Hay que revocarle a PUBLIC.
--
-- El bloque final verifica el EFECTO, no la intención: escribir el revoke no prueba que el
-- permiso se haya ido — que es justamente lo que pasó en el intento anterior.

revoke execute on function public.month_summary(uuid, integer, integer) from public;
revoke execute on function public.spending_insights(uuid, integer) from public;

grant execute on function public.month_summary(uuid, integer, integer) to authenticated, service_role;
grant execute on function public.spending_insights(uuid, integer) to authenticated, service_role;

do $$
begin
  if has_function_privilege('anon', 'public.month_summary(uuid,integer,integer)', 'EXECUTE')
     or has_function_privilege('anon', 'public.spending_insights(uuid,integer)', 'EXECUTE') then
    raise exception 'anon TODAVIA puede ejecutar: el revoke no tuvo efecto';
  end if;
  if not has_function_privilege('authenticated', 'public.month_summary(uuid,integer,integer)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.spending_insights(uuid,integer)', 'EXECUTE') then
    raise exception 'se rompio el acceso de los usuarios logueados';
  end if;
end $$;
