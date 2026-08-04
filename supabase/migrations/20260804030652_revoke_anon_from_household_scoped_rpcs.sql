-- INTENTO FALLIDO, versionado a propósito porque así se aplicó en prod y porque el error es
-- instructivo: este revoke fue un NO-OP. La corrección real está en
-- `20260804030722_revoke_public_execute_from_household_rpcs.sql`.
--
-- Postgres otorga EXECUTE a PUBLIC por defecto en toda función nueva, y `anon` hereda de PUBLIC.
-- Revocarle a `anon` no quita nada, porque el permiso no venía de un grant a `anon`. Después de
-- correr esto, `has_function_privilege('anon', ..., 'EXECUTE')` seguía dando true.

revoke execute on function public.month_summary(uuid, integer, integer) from anon;
revoke execute on function public.spending_insights(uuid, integer) from anon;

grant execute on function public.month_summary(uuid, integer, integer) to authenticated;
grant execute on function public.spending_insights(uuid, integer) to authenticated;
