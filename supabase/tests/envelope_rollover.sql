-- Suite pgTAP: rollover de sobres entre períodos.
--
-- POR QUÉ EXISTE: el rollover estuvo escrito a medias durante meses — la columna
-- `rollover_from_prev` y el toggle de tres modos existían, pero NADIE los calculaba. El usuario
-- configuraba "arrastrar sobrante" y el control no hacía absolutamente nada. Un bug así no da
-- error ni se ve en un build verde: sólo se nota si alguien audita el saldo de su sobre a mano.
-- Estos tests fallan si el trigger deja de correr o si cambia el criterio de alguno de los modos.
--
-- CÓMO CORRER
--   psql "$DATABASE_URL" -f supabase/tests/envelope_rollover.sql
--   (o pegarlo en el SQL Editor de Supabase)
-- Todo vive dentro de una transacción que termina en ROLLBACK: no deja datos.
-- Verificado contra producción el 2026-08-03 → 8/8 ok, 0 filas residuales.
--
-- GOTCHAS (no los borres):
--   * `plan(N)` va ANTES del primer test o pgTAP aborta.
--   * Los sobres del fixture se crean EN LA MONEDA BASE del hogar. Con otra moneda,
--     `envelope_balance` convierte y los números dejan de ser los esperados — me pasó en la
--     primera corrida: un sobre de 1000 con 400 de gasto dio -623024 porque el sobre estaba en
--     ARS y el hogar en USD.
--   * Se usan años 2099 para no colisionar con ningún período real del hogar.

begin;

select plan(8);

-- ── Fixture ────────────────────────────────────────────────────────────────
create temp table _fx on commit drop as
select h.id as household_id,
       h.created_by as user_id,
       coalesce(h.default_currency, 'USD') as ccy
from public.households h
limit 1;

create temp table _periods (label text, id uuid) on commit drop;

-- Período anterior: enero 2099
with ins as (
  insert into public.budget_periods (household_id, period_type, period_start, period_end)
  select household_id, 'month', '2099-01-01', '2099-01-31' from _fx
  returning id
)
insert into _periods select 'prev', id from ins;

-- Tres sobres de 1000, uno por cada modo de rollover.
insert into public.budget_allocations
  (period_id, category, subcategory, allocated, rollover_mode, currency)
select p.id, v.cat, '', 1000, v.mode, f.ccy
from _periods p, _fx f,
     (values ('ZZRoll-Surplus','surplus'), ('ZZRoll-Full','full'), ('ZZRoll-None','none')) as v(cat, mode)
where p.label = 'prev';

-- Gastos: surplus deja 600 de sobrante, full se pasa 500, none deja 600 (pero no debe arrastrar).
insert into public.transactions (household_id, user_id, type, amount, category, date)
select f.household_id, f.user_id, 'GASTO', v.amt, v.cat, '2099-01-15T12:00:00Z'::timestamptz
from _fx f, (values (400,'ZZRoll-Surplus'), (1500,'ZZRoll-Full'), (400,'ZZRoll-None')) as v(amt, cat);

-- ── El saldo del período anterior es el esperado ───────────────────────────
select is(
  public.envelope_balance((select id from _periods where label='prev'), 'ZZRoll-Surplus', ''),
  600::numeric,
  'el sobre surplus cierra enero con 600 de sobrante'
);

select is(
  public.envelope_balance((select id from _periods where label='prev'), 'ZZRoll-Full', ''),
  -500::numeric,
  'el sobre full cierra enero con 500 de déficit'
);

-- ── Crear el período nuevo dispara el trigger ──────────────────────────────
with ins as (
  insert into public.budget_periods (household_id, period_type, period_start, period_end)
  select household_id, 'month', '2099-02-01', '2099-02-28' from _fx
  returning id
)
insert into _periods select 'new', id from ins;

select is(
  (select rollover_from_prev from public.budget_allocations
    where period_id = (select id from _periods where label='new') and category='ZZRoll-Surplus'),
  600::numeric,
  'surplus arrastra el sobrante positivo'
);

select is(
  (select rollover_from_prev from public.budget_allocations
    where period_id = (select id from _periods where label='new') and category='ZZRoll-Full'),
  -500::numeric,
  'full arrastra el déficit — ese es justamente el punto de ese modo'
);

select is(
  (select count(*)::int from public.budget_allocations
    where period_id = (select id from _periods where label='new') and category='ZZRoll-None'),
  0,
  'none no arrastra ni crea el sobre'
);

select is(
  (select allocated from public.budget_allocations
    where period_id = (select id from _periods where label='new') and category='ZZRoll-Surplus'),
  0::numeric,
  'el sobre nuevo nace con allocated=0: se arrastra el saldo, no el presupuesto del mes anterior'
);

select is(
  (select currency from public.budget_allocations
    where period_id = (select id from _periods where label='new') and category='ZZRoll-Surplus'),
  (select ccy from _fx),
  'el sobre arrastrado conserva la moneda del original'
);

-- ── Idempotencia: correrlo de nuevo ASIGNA, no acumula ─────────────────────
select app_hidden.roll_envelopes_forward((select id from _periods where label='new'));

select is(
  (select rollover_from_prev from public.budget_allocations
    where period_id = (select id from _periods where label='new') and category='ZZRoll-Surplus'),
  600::numeric,
  'correr el rollover dos veces no duplica el arrastre'
);

select * from finish();

rollback;
