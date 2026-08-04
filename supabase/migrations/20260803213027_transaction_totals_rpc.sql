-- Totales de un rango, calculados en el servidor.
--
-- HOY iOS baja hasta 1000 filas ordenadas por fecha DESC y las suma en el cliente. Pasado ese
-- tope se descartan las transacciones MÁS VIEJAS del rango y los totales salen bajos, sin ningún
-- aviso: el usuario ve menos gastos de los que tuvo. Un hogar activo con movimientos diarios llega
-- a 1000 en pocos meses de historial.
--
-- Además, sumar en el cliente obliga a repetir ahí las reglas de negocio (excluir transferencias,
-- el rango inclusivo del último día). Cada repetición es una oportunidad de divergir — ya pasó con
-- `netWorth` duplicado y con las dos definiciones de "asignado".
--
-- Mismas reglas que `budget_period_summary` y `envelope_balance`: día calendario UTC inclusivo en
-- ambos extremos, y sin transferencias entre cuentas propias.
--
-- Verificado en prod el 2026-08-03 contra el cálculo directo sobre mayo 2026: ingresos 1.490.001 y
-- gastos 1.020.500 en ambos. Y pasándole el `to` a MEDIANOCHE del día 31 devolvió el total
-- completo, o sea que el bug del último día también queda cubierto server-side.

create or replace function public.transaction_totals(
  p_household uuid,
  p_from      timestamptz,
  p_to        timestamptz
)
returns table (ingresos numeric, gastos numeric)
language sql stable security invoker set search_path to 'public'
as $$
  select
    coalesce(sum(t.amount) filter (where t.type = 'INGRESO'), 0)::numeric,
    coalesce(sum(t.amount) filter (where t.type = 'GASTO'),   0)::numeric
  from public.transactions t
  where t.household_id = p_household
    and t.transfer_group_id is null
    and t.date::date >= p_from::date
    and t.date::date <= p_to::date;
$$;

comment on function public.transaction_totals(uuid, timestamptz, timestamptz) is
  'Ingresos y gastos de un rango, agregados en el servidor. Reemplaza al calculo en cliente que '
  'bajaba hasta 1000 filas y truncaba en silencio las mas viejas. Excluye transferencias y usa dia '
  'calendario UTC inclusivo en ambos extremos, igual que budget_period_summary y envelope_balance.';
