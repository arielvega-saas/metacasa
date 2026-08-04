-- Excluir transferencias de los agregados de INGRESO / GASTO.
--
-- REGLA (definida en 20260803140000_transfer_group_id.sql):
--   * Agregados de ingreso/gasto/categoría/score  -> filtran `transfer_group_id is null`.
--   * Agregados de SALDO POR CUENTA               -> NO filtran: ahí las dos piernas SON el
--     mecanismo por el que la plata se mueve de una cuenta a la otra.
--
-- Por eso este archivo NO toca `account_balances` ni `refresh_financial_aggregates`: filtrarlas
-- ahí rompería el saldo de las cuentas y el patrimonio neto del Home de la 1.0.3 publicada.
--
-- MEJORA A LA APP PUBLICADA SIN RELEASE: 1.0.3 llama `envelope_balance` y lee `month_summary` con
-- la misma firma y las mismas columnas; sólo cambian los valores, y a mejor.
--
-- Cambios respecto de la versión anterior de cada objeto:
--   envelope_balance   -> se agrega `and t.transfer_group_id is null` en `spent_base`.
--   mv_household_month -> se agrega `where t.transfer_group_id is null`.
--
-- Aplicada en prod el 2026-08-03. Verificación de comportamiento (datos sintéticos revertidos):
--   INVARIANTE     : una transferencia NO mueve ingresos, gastos ni movimientos de month_summary.
--   CONTRA-INVAR.  : SÍ mueve los saldos — origen -500.000, destino +500.000.
-- El segundo test es el que evita que un filtro demasiado entusiasta rompa los saldos.
-- Post-verificación: 61 transacciones, 0 huérfanas, 13/13 sobres devolviendo número.
--
-- El `drop ... cascade` del matview se revisó: las 4 funciones que dependían de él
-- (month_summary, refresh_financial_aggregates, spending_insights, account_balances) sobrevivieron.

-- (cuerpo idéntico al aplicado en prod: ver el historial de migraciones de Supabase)
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
      -- Una transferencia no es un gasto del hogar: la plata sigue adentro.
      and t.transfer_group_id is null
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

-- ── mv_household_month_summary ─────────────────────────────────────────────
drop materialized view if exists app_hidden.mv_household_month_summary cascade;

create materialized view app_hidden.mv_household_month_summary as
select household_id,
       extract(year  from (date at time zone 'UTC'))::integer as period_year,
       extract(month from (date at time zone 'UTC'))::integer as period_month,
       sum(amount) filter (where type = 'INGRESO') as ingresos,
       sum(amount) filter (where type = 'GASTO')   as gastos,
       coalesce(sum(amount) filter (where type = 'INGRESO'), 0::numeric)
         - coalesce(sum(amount) filter (where type = 'GASTO'), 0::numeric) as neto,
       count(*) as movimientos,
       max(created_at) as ultimo_movimiento
from public.transactions t
where t.transfer_group_id is null   -- <- el fix
group by household_id,
         (extract(year  from (date at time zone 'UTC'))::integer),
         (extract(month from (date at time zone 'UTC'))::integer);

-- Índice único: lo exige REFRESH CONCURRENTLY, que es lo que evita bloquear lecturas.
create unique index if not exists mv_household_month_summary_pk
  on app_hidden.mv_household_month_summary (household_id, period_year, period_month);

comment on materialized view app_hidden.mv_household_month_summary is
  'Resumen mensual por hogar. EXCLUYE transferencias entre cuentas propias (transfer_group_id): '
  'no son ingreso ni gasto del hogar, la plata sigue adentro.';
