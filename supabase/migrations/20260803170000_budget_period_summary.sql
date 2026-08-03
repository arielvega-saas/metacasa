-- "Listo para asignar": una sola definición para toda la app.
--
-- HOY hay CUATRO lectores con criterios distintos: el card del Home, el insight de
-- sobre-asignación, el hub de Presupuesto y el asistente de IA — que le dice al usuario el número
-- equivocado EN TEXTO. El Home lee la columna `ready_to_assign`, que iOS NUNCA escribe (queda en 0),
-- y el hub lo calcula local. Mismo usuario, dos pantallas, dos verdades.
--
-- DEFINICIONES CANÓNICAS (esto es lo que estaba realmente roto: no era una fuente, eran cuatro
-- definiciones distintas):
--   total_income    = suma de INGRESO del rango, en moneda BASE, sin transferencias.
--   total_allocated = suma de `allocated`, en base. SIN el arrastre.
--   total_budgeted  = suma de (allocated + rollover_from_prev), en base. Es lo que hay en los
--                     sobres, y lo que tiene que cerrar con la suma de las filas.
--   ready_to_assign = total_income − total_allocated.
--
-- El arrastre NO se resta: se fondeó con el ingreso del mes ANTERIOR, descontarlo de este mes es
-- cobrarlo dos veces. Es la divergencia que se activó al arreglar el rollover.
--
-- POR QUÉ RPC Y NO SÓLO COLUMNAS MANTENIDAS POR TRIGGER: `ready_to_assign` depende de
-- `households.fx_rates`, que el job diario de FX reescribe. Un valor cacheado cuyo insumo cambia
-- todos los días está garantizado a driftear. El RPC no puede driftear porque no guarda nada.
--
-- POR QUÉ IGUAL SE MANTIENEN LAS COLUMNAS: es lo que arregla a los usuarios de iOS 1.0.3 SIN
-- publicar una app — leen esas columnas y crashearían si fueran null (son `Decimal` no-opcional en
-- `BudgetPeriod`, y el throw del decode revienta el `load()` del Home entero, no sólo el card).
--
-- Aplicada en prod el 2026-08-03. El backfill corrigió datos reales: un período pasó de mostrar
-- "$0 con check verde" a $850.000, y otro de 0 a $660.001. Post-verificación: 0 períodos con drift.

create or replace function app_hidden.fx_to_base(p_fx jsonb, p_base text, p_ccy text)
returns numeric language sql immutable as $$
  select case
    when upper(coalesce(p_ccy,'USD')) = upper(coalesce(p_base,'USD')) then 1::numeric
    when jsonb_typeof(p_fx -> upper(p_ccy)) = 'number' then (p_fx ->> upper(p_ccy))::numeric
    when jsonb_typeof(p_fx -> upper(p_ccy)) = 'object' then ((p_fx -> upper(p_ccy)) ->> 'rate')::numeric
    else null::numeric   -- sin tasa: NO se inventa un 1, se excluye y se cuenta
  end
$$;

create or replace function public.budget_period_summary(p_period_id uuid)
returns table (
  period_id        uuid,
  base_currency    text,
  total_income     numeric,
  total_allocated  numeric,
  total_budgeted   numeric,
  ready_to_assign  numeric,
  fx_missing_count integer
)
language sql stable security invoker set search_path to 'public'
as $$
  with p as (
    select id, household_id, period_start, period_end
    from public.budget_periods where id = p_period_id
  ),
  h as (
    select upper(coalesce(hh.default_currency,'USD')) as base_ccy, hh.fx_rates
    from public.households hh join p on p.household_id = hh.id
  ),
  income as (
    -- MISMA regla de fecha que envelope_balance: día calendario UTC, inclusivo en ambos extremos.
    -- Unifica el `inclusiveDateEnd` de la web y el último-día-perdido de iOS.
    select coalesce(sum(t.amount), 0) as total
    from public.transactions t, p
    where t.household_id = p.household_id
      and t.type = 'INGRESO'
      and t.transfer_group_id is null   -- una transferencia no es ingreso del hogar
      and t.date::date >= p.period_start
      and t.date::date <= p.period_end
  ),
  alloc as (
    select a.allocated, a.rollover_from_prev,
           app_hidden.fx_to_base((select fx_rates from h), (select base_ccy from h), a.currency) as rate
    from public.budget_allocations a, p
    where a.period_id = p.id
  )
  select
    (select id from p),
    (select base_ccy from h),
    (select total from income),
    coalesce(sum(a.allocated * a.rate)                          filter (where a.rate is not null), 0),
    coalesce(sum((a.allocated + a.rollover_from_prev) * a.rate) filter (where a.rate is not null), 0),
    (select total from income)
      - coalesce(sum(a.allocated * a.rate)                      filter (where a.rate is not null), 0),
    count(*) filter (where a.rate is null)::int
  from alloc a;
$$;

create or replace function app_hidden.sync_period_totals(p_period_id uuid)
returns void language plpgsql security definer set search_path to 'public'
as $$
declare s record;
begin
  select * into s from public.budget_period_summary(p_period_id);
  if not found then return; end if;

  update public.budget_periods
     set total_income    = s.total_income,
         total_allocated = s.total_allocated,
         ready_to_assign = s.ready_to_assign,
         updated_at      = now()
   where id = p_period_id
     -- Guard de no-op: `budget_periods` está en la publication de realtime. Sin esto, cada
     -- recálculo idéntico emitiría un broadcast a todos los clientes conectados.
     and (total_income, total_allocated, ready_to_assign)
         is distinct from (s.total_income, s.total_allocated, s.ready_to_assign);
end $$;
