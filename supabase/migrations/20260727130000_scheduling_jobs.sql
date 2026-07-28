-- Fase 3.15: jobs de pg_cron.
--
-- 1) Materialización server-side de recurring_transactions. Espeja la
--    semántica EXACTA de metacasa-web/lib/actions/recurring-run.ts:
--    * candado = next_date (idempotente; si la web corre primero, el job no
--      encuentra nada vencido, y viceversa — sin duplicados).
--    * cada movimiento se fecha en SU next_date (no "hoy"), a mediodía UTC
--      (misma estabilización que web toStableDate: T12:00Z nunca corre de día
--      en ningún timezone).
--    * catchup acotado a 24 por recurrente por corrida.
--    * respeta end_date (desactiva al pasarlo).
--    Divergencia conocida y aceptada: para mensuales del día 29-31, Postgres
--    clampa al fin de mes (ene 31 → feb 28) mientras JS desborda (→ mar 3);
--    quien corre primero fija la fecha. El clamp es el comportamiento más
--    esperable para el usuario.
--    Beneficio principal: los usuarios iOS-only (la app nativa nunca
--    materializó) dejan de necesitar abrir la web.
--
-- 2) Limpieza nocturna de hogares huérfanos (0 miembros) — red de seguridad
--    del fix de delete-account; además limpia los huérfanos legacy previos.

create or replace function app_hidden.run_recurring_materialization(max_catchup int default 24)
returns int
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  r record;
  created_total int := 0;
  next_d date;
  steps int;
begin
  for r in
    select * from public.recurring_transactions
    where coalesce(active, true)
      and next_date is not null
      and next_date <= current_date
    for update skip locked
  loop
    next_d := r.next_date;
    steps := 0;
    while next_d <= current_date and steps < max_catchup loop
      exit when r.end_date is not null and next_d > r.end_date;
      insert into public.transactions
        (household_id, user_id, type, amount, category, subcategory, note,
         date, period_year, period_month)
      values
        (r.household_id, r.user_id, r.type, r.amount, r.category, r.subcategory, r.note,
         (next_d::timestamp + time '12:00') at time zone 'UTC',
         extract(year from next_d)::int, extract(month from next_d)::int);
      created_total := created_total + 1;
      steps := steps + 1;
      next_d := case r.frequency
        when 'daily'   then (next_d + interval '1 day')::date
        when 'weekly'  then (next_d + interval '7 days')::date
        when 'monthly' then (next_d + interval '1 month')::date
        when 'yearly'  then (next_d + interval '1 year')::date
        else (next_d + interval '1 month')::date
      end;
    end loop;
    update public.recurring_transactions
      set next_date = next_d,
          active = case
            when r.end_date is not null and next_d > r.end_date then false
            else active
          end
      where id = r.id;
  end loop;
  return created_total;
end $$;

create or replace function app_hidden.cleanup_orphan_households()
returns int
language plpgsql
security definer
set search_path to 'public'
as $$
declare deleted_count int;
begin
  delete from public.households h
  where not exists (
    select 1 from public.household_members m where m.household_id = h.id
  );
  get diagnostics deleted_count = row_count;
  return deleted_count;
end $$;

-- Solo el job de cron (rol postgres) debe poder ejecutarlas.
revoke execute on function app_hidden.run_recurring_materialization(int) from public, anon, authenticated;
revoke execute on function app_hidden.cleanup_orphan_households() from public, anon, authenticated;

-- 05:10/05:30 UTC = 02:10/02:30 ART (horas tranquilas, antes de que abran la app).
select cron.schedule('recurring-materialization-daily', '10 5 * * *',
  $$select app_hidden.run_recurring_materialization()$$);
select cron.schedule('cleanup-orphan-households-daily', '30 5 * * *',
  $$select app_hidden.cleanup_orphan_households()$$);
