-- Dos agujeros introducidos el 2026-08-03 con las transferencias y el resumen de presupuesto.
-- Los detectó el linter de Supabase; no estaban en la auditoría porque son NUEVOS — los metí yo
-- ese mismo día. Vale anotarlo: arreglar cosas también las rompe, y el linter hay que correrlo
-- DESPUÉS de tocar el schema, no sólo al auditar.
--
-- 1. `v_transfer_health` salteaba RLS.
--
-- Una vista corre con los permisos de su DUEÑA, y ésta es de `postgres`, que ignora RLS. Como
-- además tenía SELECT para `anon`, cualquiera SIN sesión podía leer `household_id` y montos de
-- transferencias desbalanceadas de TODOS los hogares. Leak cross-tenant en una app de finanzas
-- compartidas: el mismo modelo de amenaza que la auto-inscripción en hogares ajenos que se cerró
-- en `20260801090534`.
--
-- `security_invoker = true` hace que corra con los permisos de QUIEN consulta, así que las
-- policies de `transactions` vuelven a aplicar. Y se revoca `anon`: es una vista de diagnóstico
-- interno, no tiene por qué ser pública ni siquiera con RLS puesta.

alter view public.v_transfer_health set (security_invoker = true);

revoke all on public.v_transfer_health from anon;
grant select on public.v_transfer_health to authenticated;

comment on view public.v_transfer_health is
  'Transferencias desbalanceadas (piernas <> 2 o suma <> 0). security_invoker: respeta RLS, '
  'cada usuario ve solo sus hogares. NO exponer a anon.';

-- 2. `app_hidden.fx_to_base` con search_path mutable.
--
-- Sin `search_path` fijo, la resolución de nombres depende del rol que la llame. En una función
-- que decide una tasa de cambio —o sea, cuántos pesos vale un dólar en TODOS los agregados— eso
-- es una vía para que alguien con permiso de crear objetos anteponga un esquema propio y cambie
-- lo que resuelve. Es `immutable`, así que fijarlo no cambia ningún resultado; verificado con los
-- cuatro casos (tasa como objeto, como número, sin tasa, misma moneda).

create or replace function app_hidden.fx_to_base(p_fx jsonb, p_base text, p_ccy text)
returns numeric
language sql
immutable
set search_path to 'pg_catalog', 'public'
as $$
  select case
    when upper(coalesce(p_ccy,'USD')) = upper(coalesce(p_base,'USD')) then 1::numeric
    when jsonb_typeof(p_fx -> upper(p_ccy)) = 'number' then (p_fx ->> upper(p_ccy))::numeric
    when jsonb_typeof(p_fx -> upper(p_ccy)) = 'object' then ((p_fx -> upper(p_ccy)) ->> 'rate')::numeric
    else null::numeric   -- sin tasa: NO se inventa un 1, se excluye y se cuenta
  end
$$;
