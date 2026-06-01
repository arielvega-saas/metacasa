-- ============================================================================
-- Fix: public.envelope_balance(...) — currency-blind "spent vs allocated" bug
-- ============================================================================
--
-- BUG (confirmed by audit 2026-06-01):
--   The previous body computed:
--       remaining = (budget_allocations.allocated + rollover_from_prev)   -- in the
--                                                                          -- ALLOCATION currency
--                   - sum(transactions.amount)                            -- in the household
--                                                                          -- BASE currency
--   with NO FX normalization. `budget_allocations.currency` defaults to 'USD' and
--   is independent of `households.default_currency`, while `transactions` has NO
--   `currency` column at all (verified) — every transaction amount is already stored
--   in the household BASE currency. So whenever an envelope's currency differs from
--   the household base, the function subtracted unlike units (e.g. ARS budget minus
--   ARS-base spend is fine, but a USD envelope inside an ARS household subtracted
--   ARS spend from a USD allocation).
--
-- STATUS: LATENT, not active (as of 2026-06-01).
--   Real data: all 13 allocations have currency == household base currency
--   (12 ARS/ARS, 1 USD/USD). `households.fx_rates` is `{}` for ALL 11 households.
--   So today every code path hits the `from == base` short-circuit and the bug never
--   fires. This fix is therefore PREVENTIVE / defensive: it makes the function correct
--   the moment a household ever creates a non-base envelope.
--
-- FIX DIRECTION (mirrors iOS exactly):
--   The iOS clients (BudgetView / BudgetHubView) compute, locally and per-allocation:
--       budgeted = allocation.allocated + allocation.rolloverFromPrev   -- ALLOCATION ccy, un-converted
--       remaining = envelope_balance(...)                              -- this RPC
--       spent    = budgeted - remaining
--   i.e. the client treats this RPC's return value as being in the ALLOCATION currency.
--   To stay consistent with that arithmetic (and avoid breaking the published app),
--   we keep the budget term in the allocation currency and convert the SPEND term
--   from base -> allocation currency. We do NOT convert the allocation to base, because
--   that would make `budgeted (alloc ccy) - remaining (base)` mix units on the client.
--
--   FX convention is a 1:1 mirror of iOS `Core/FXService.swift` `FXConverter.convert`
--   and `metacasa-web/lib/fx.ts` `convertToBase`:
--       households.fx_rates JSONB shape:
--           { "USD": { "rate": 1000, "updated_at": "...", "source": "manual" }, ... }
--       rate = "how many units of the household BASE currency equal 1 unit of THIS currency".
--       baseAmount  = foreignAmount * rate           (base <- foreign)
--   We need the inverse (base -> allocation currency), so:
--       spentInAllocCcy = spentBase / rate(allocCcy)
--   When allocation currency == base currency, no conversion is applied (short-circuit).
--   When the rate is missing (currencies differ but no fx_rates entry), the function
--   returns NULL — the exact analogue of iOS `FXConverter.convert` returning `nil` and
--   `metacasa-web` returning `null`. Both iOS call sites already wrap the RPC in
--   `(try? await ...) ?? budgeted`, so a NULL safely degrades to "remaining = budgeted,
--   spent = 0" instead of silently reporting a wrong (mixed-unit) number.
--
-- SIGNATURE & RETURN SHAPE: UNCHANGED.
--   public.envelope_balance(p_period_id uuid, p_category text, p_subcategory text DEFAULT '')
--   RETURNS numeric, LANGUAGE sql, STABLE, SET search_path = public.
--   (Preserved so neither metacasa-ios nor metacasa-web breaks.)
--
-- HOW TO APPLY (user applies manually — do NOT auto-apply):
--   Option A: `supabase db push`
--   Option B: paste this file into the Supabase SQL Editor and run it.
-- ============================================================================

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
      and coalesce(t.subcategory, '') = p_subcategory
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
