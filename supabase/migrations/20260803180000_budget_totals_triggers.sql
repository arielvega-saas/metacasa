-- Triggers que mantienen las columnas de compatibilidad al día + backfill.
--
-- ORDEN DE DISPARO — es load-bearing: Postgres ejecuta los triggers AFTER en orden ALFABÉTICO de
-- nombre. El de rollover se llama `tg_budget_periods_rollover` y el de totales
-- `tg_budget_periods_zz_totals`: 'r' < 'z', así que los totales se calculan DESPUÉS de que el
-- arrastre ya escribió sus sobres. Al revés, un período nuevo saldría con `total_budgeted` sin el
-- arrastre. El prefijo `zz_` está a propósito para que renombrarlo sea evidentemente peligroso.
--
-- Verificado en prod el 2026-08-03 (datos sintéticos revertidos):
--   ready_to_assign: 0 -> 1.000.000 (tras un INGRESO) -> 600.000 (tras un sobre de 400.000)
--   mes siguiente: total_budgeted 400.000 (incluye el arrastre) y total_allocated 0
--     (el arrastre NO cuenta como asignado -> no se cobra dos veces). Esto último es lo que
--     prueba que el orden de triggers es correcto.
-- Post-backfill: 0 períodos con drift entre la caché y la definición canónica.

create or replace function app_hidden.tg_sync_period_totals()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  perform app_hidden.sync_period_totals(coalesce(new.period_id, old.period_id));
  return null;
end $$;

drop trigger if exists tg_budget_allocations_totals on public.budget_allocations;
create trigger tg_budget_allocations_totals
  after insert or update or delete on public.budget_allocations
  for each row execute function app_hidden.tg_sync_period_totals();

create or replace function app_hidden.tg_period_totals_on_insert()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  perform app_hidden.sync_period_totals(new.id);
  return null;
end $$;

-- El `zz_` del nombre garantiza que corra DESPUÉS de tg_budget_periods_rollover. No renombrar.
drop trigger if exists tg_budget_periods_zz_totals on public.budget_periods;
create trigger tg_budget_periods_zz_totals
  after insert on public.budget_periods
  for each row execute function app_hidden.tg_period_totals_on_insert();

create or replace function app_hidden.tg_sync_periods_for_tx()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare r record; v_hh uuid;
begin
  v_hh := coalesce(new.household_id, old.household_id);
  for r in
    select distinct bp.id
    from public.budget_periods bp
    where bp.household_id = v_hh
      and (
        (new.date is not null and new.date::date between bp.period_start and bp.period_end)
        or
        (old.date is not null and old.date::date between bp.period_start and bp.period_end)
      )
  loop
    perform app_hidden.sync_period_totals(r.id);
  end loop;
  return null;
end $$;

drop trigger if exists tg_transactions_period_totals on public.transactions;
create trigger tg_transactions_period_totals
  after insert or update or delete on public.transactions
  for each row execute function app_hidden.tg_sync_periods_for_tx();

-- ── Backfill: es LA jugada. Corrige a todos los usuarios de iOS 1.0.3 al instante, sin publicar
--    nada en App Store. Datos reales: un período pasó de "$0 con check verde" a $850.000.
select app_hidden.sync_period_totals(id) from public.budget_periods;
