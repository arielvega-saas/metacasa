-- Fase 4.3(b): insights proactivos.
--
-- El salto de "app que reporta el pasado" a "app que te avisa". Compara el
-- gasto del mes EN CURSO contra el promedio de los 3 meses anteriores, por
-- categoría, y devuelve sólo los desvíos que valen la pena contar.
--
-- DECISIONES
--   * El promedio EXCLUYE el mes actual: compararlo contra un promedio que se
--     incluye a sí mismo diluye el desvío justo cuando más importa.
--   * Umbral de ±25%: un insight por cada fluctuación normal es ruido, y a la
--     tercera notificación irrelevante el usuario deja de mirarlas.
--   * Sólo categorías con historial (`prom > 0`): estrenar una categoría no es
--     un "aumento del ∞%".
--   * SECURITY DEFINER + check explícito de pertenencia (mismo patrón que
--     `month_summary`), y sin EXECUTE para `anon`.
--
-- VERIFICADO en prod con un escenario controlado (creado y revertido):
-- historial de 10.000/mes en Delivery y 50.000/mes en Alquiler; mes actual
-- 25.000 y 50.000 → devuelve SÓLO Delivery (+150%), Alquiler no aparece.

create or replace function public.spending_insights(p_household uuid, p_limit int default 5)
returns table(
  category text,
  actual numeric,
  promedio numeric,
  delta_pct numeric,
  direccion text
)
language plpgsql stable security definer
set search_path to 'public', 'app_hidden'
as $$
declare
  y int := extract(year from current_date)::int;
  m int := extract(month from current_date)::int;
begin
  if not app_hidden.is_household_member(p_household) then
    raise exception 'not a member of household %', p_household using errcode = '42501';
  end if;

  return query
  with actual_mes as (
    select t.category, sum(t.amount) as total
    from public.transactions t
    where t.household_id = p_household and t.type = 'GASTO'
      and extract(year from (t.date at time zone 'UTC'))::int = y
      and extract(month from (t.date at time zone 'UTC'))::int = m
    group by 1
  ),
  historico as (
    select t.category, sum(t.amount) / 3.0 as prom
    from public.transactions t
    where t.household_id = p_household and t.type = 'GASTO'
      and t.date >= (date_trunc('month', current_date) - interval '3 months')
      and t.date <  date_trunc('month', current_date)
    group by 1
  )
  select a.category, a.total, round(h.prom, 2),
         round(((a.total - h.prom) / nullif(h.prom, 0)) * 100, 0),
         case when a.total > h.prom then 'subio' else 'bajo' end
  from actual_mes a
  join historico h on h.category = a.category
  where h.prom > 0
    and abs((a.total - h.prom) / h.prom) >= 0.25
  order by abs((a.total - h.prom) / nullif(h.prom,0)) desc
  limit p_limit;
end $$;

revoke execute on function public.spending_insights(uuid,int) from anon;
