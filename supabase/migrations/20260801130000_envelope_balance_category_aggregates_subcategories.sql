-- Un sobre a nivel CATEGORÍA ahora agrega también el gasto que tiene subcategoría.
--
-- El bug: el match era estricto (`coalesce(t.subcategory,'') = p_subcategory`), pero los sobres
-- se crean a nivel categoría con subcategoría VACÍA, mientras que el alta de transacción tiene un
-- selector de subcategoría bien visible que invita a usarlo. Resultado: presupuestás
-- "Comida $200.000", cargás los gastos como *Comida › Supermercado*, y el sobre muestra
-- "$0 gastado, $200.000 disponibles" todo el mes. El anillo queda verde, la proyección de ritmo
-- no dispara (no hay gasto que proyectar) y te pasás de largo sin una sola alerta.
--
-- El fix agrega una protección que el match estricto no necesitaba: si dentro de la misma
-- categoría existe un sobre PROPIO para una subcategoría, el sobre padre excluye ese gasto. Sin
-- eso, un hogar con "Comida" y "Comida › Delivery" contaría el delivery dos veces.
--
-- Impacto medido antes de aplicar: 0 transacciones con subcategoría en toda la base, así que
-- ningún saldo cambió. Se corrigió ahora justamente porque salía gratis.
--
-- Aplicada en prod el 2026-08-01. Verificación de comportamiento (dentro de un bloque DO que
-- termina en excepción, así revierte solo): con un gasto de 1000 con subcategoría, el saldo del
-- sobre de categoría pasó de -3500 a -4500. Diferencia exacta de -1000. Sin rastros en la base.
--
-- Lo único que cambia respecto de 20260601120000 es el predicado de subcategoría en `spent_base`.
create or replace function public.envelope_balance(
  p_period_id uuid,
  p_category text,
  p_subcategory text default ''::text
)
returns numeric
language sql
stable
set search_path to 'public'
as $function$
  with alloc as (
    select
      ba.allocated + ba.rollover_from_prev as budgeted,
      upper(coalesce(ba.currency, 'USD'))  as alloc_ccy
    from public.budget_allocations ba
    where ba.period_id = p_period_id
      and ba.category = p_category
      and ba.subcategory = p_subcategory
    limit 1
  ),
  period as (
    select period_start, period_end, household_id
    from public.budget_periods
    where id = p_period_id
  ),
  hh as (
    select upper(coalesce(h.default_currency, 'USD')) as base_ccy,
           h.fx_rates
    from public.households h
    join period p on p.household_id = h.id
  ),
  spent_base as (
    -- transactions.amount is always in the household BASE currency (table has no
    -- `currency` column). Sum of GASTO rows in this period for this (category, subcategory).
    select coalesce(sum(t.amount), 0) as total
    from public.transactions t, period p
    where t.household_id = p.household_id
      and t.type = 'GASTO'
      and t.category = p_category
      and (
        case
          when p_subcategory = '' then
            -- Sobre a nivel categoría: agrega TODA la categoría, excepto las
            -- subcategorías que tienen su propio sobre en este mismo período.
            not exists (
              select 1
              from public.budget_allocations sub
              where sub.period_id = p_period_id
                and sub.category  = p_category
                and sub.subcategory = coalesce(t.subcategory, '')
                and sub.subcategory <> ''
            )
          else coalesce(t.subcategory, '') = p_subcategory
        end
      )
      and t.date::date >= p.period_start
      and t.date::date <= p.period_end
  ),
  -- Convert spend from BASE -> ALLOCATION currency so it lines up with `budgeted`
  -- (which stays in the allocation currency, matching the iOS client's local math).
  fx as (
    select
      a.alloc_ccy,
      hh.base_ccy,
      -- numeric `rate` extracted from the fx_rates JSONB; tolerates both the
      -- canonical object form { "USD": { "rate": 1000 } } and the simplified
      -- numeric form { "USD": 1000 } (same tolerance as web `parseFxRates`).
      case
        when a.alloc_ccy = hh.base_ccy then null::numeric  -- no conversion needed
        when jsonb_typeof(hh.fx_rates -> a.alloc_ccy) = 'number'
          then (hh.fx_rates ->> a.alloc_ccy)::numeric
        when jsonb_typeof(hh.fx_rates -> a.alloc_ccy) = 'object'
          then ((hh.fx_rates -> a.alloc_ccy) ->> 'rate')::numeric
        else null::numeric
      end as rate
    from alloc a cross join hh
  ),
  spent_in_alloc as (
    select
      case
        when (select alloc_ccy from fx) = (select base_ccy from fx)
          then (select total from spent_base)            -- same currency: passthrough
        when (select rate from fx) is null
          or (select rate from fx) = 0
          then null::numeric                              -- missing/zero rate -> NULL (mirrors iOS nil)
        else (select total from spent_base) / (select rate from fx)  -- base -> alloc ccy
      end as total
  )
  select
    case
      -- If we have an allocation but cannot normalize the spend (different currency,
      -- no usable fx rate), return NULL so the client falls back gracefully instead
      -- of comparing unlike units. If there is no allocation at all, behave like the
      -- original function (treat budgeted as 0).
      when (select alloc_ccy from fx) is not null
           and (select base_ccy from fx) is not null
           and (select alloc_ccy from fx) <> (select base_ccy from fx)
           and (select total from spent_in_alloc) is null
        then null::numeric
      else coalesce((select budgeted from alloc), 0) - coalesce((select total from spent_in_alloc), 0)
    end;
$function$;

comment on function public.envelope_balance(uuid, text, text) is
  'Envelope remaining = (allocated + rollover) in the allocation currency, minus the '
  'period GASTO spend converted from household base currency into the allocation '
  'currency via households.fx_rates (rate = base-per-foreign; base->alloc divides). '
  'Returns the value in the ALLOCATION currency to match the iOS/web client math. '
  'Returns NULL when currencies differ and no usable fx rate exists (mirrors iOS '
  'FXConverter.convert / web convertToBase returning nil/null). Fixed 2026-06-01.';
