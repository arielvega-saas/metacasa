-- Rollover de sobres: hasta hoy era una feature 100% decorativa.
--
-- `budget_allocations.rollover_from_prev` existe desde 20260419120600 y `rollover_mode` es
-- configurable desde iOS con sus tres opciones (none/surplus/full). Pero un grep por escrituras de
-- `rollover_from_prev` en TODO el repo devuelve cero: no hay trigger, ni job de pg_cron, ni server
-- action, ni nada en iOS. El usuario configura el sobre "Comida" con "arrastrar sobrante", termina
-- enero gastando $80.000 de $100.000, y en febrero la app le muestra $100.000 en vez de $120.000.
-- El toggle que tocó no hizo absolutamente nada. Es feature central de Goodbudget y YNAB.
--
-- DECISIONES DE DISEÑO
--
-- 1. Va como TRIGGER sobre el INSERT de `budget_periods`, no como job de pg_cron ni como llamada
--    desde el cliente. Motivo: los períodos se crean por demanda (`ensurePeriodForMonth` en iOS,
--    su equivalente en la web) cuando el usuario navega a un mes — no el día 1. Un cron del día 1
--    no cubriría a quien abre marzo estando en enero. Y ponerlo en el trigger deja UNA sola
--    implementación: este proyecto ya se quemó con `netWorth` duplicado en dos lugares, donde las
--    dos copias tenían el mismo bug de multi-moneda.
--
-- 2. Se CREA el sobre en el período nuevo, con `allocated = 0`. Si sólo se arrastrara sobre sobres
--    preexistentes, el arrastre no tendría dónde caer: el mes nuevo arranca sin allocations. Se
--    conservan categoría, subcategoría, moneda y modo de rollover.
--    NO se arrastra `allocated`: eso sería otra feature ("presupuesto recurrente") y en el modelo
--    YNAB cada mes se asigna de nuevo a propósito.
--
-- 3. `surplus` arrastra sólo lo que sobró (`max(0, saldo)`); `full` arrastra también el déficit,
--    o sea negativo — que es justamente para lo que sirve ese modo, y la tabla lo permite porque
--    el CHECK de no-negativo está sobre `allocated`, no sobre `rollover_from_prev`.
--
-- 4. Si `envelope_balance` devuelve NULL (monedas distintas sin tasa de cambio disponible) se
--    SALTEA ese sobre. Inventar un 0 sería afirmar "no te sobró nada" cuando la verdad es "no se
--    puede saber", y en un sobre de arrastre eso se convierte en plata que desaparece.
--
-- 5. Idempotente: el upsert ASIGNA el valor calculado, no lo suma. Si el trigger corriera dos veces
--    el resultado es el mismo.

create or replace function app_hidden.roll_envelopes_forward(p_new_period_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_household   uuid;
  v_start       date;
  v_type        text;
  v_prev_id     uuid;
  v_alloc       record;
  v_balance     numeric;
  v_rollover    numeric;
  v_count       integer := 0;
begin
  select household_id, period_start, period_type
    into v_household, v_start, v_type
  from public.budget_periods
  where id = p_new_period_id;

  if v_household is null then
    return 0;
  end if;

  -- Período anterior: el mismo hogar y el mismo tipo, con el período que termina más cerca
  -- (y antes) del arranque del nuevo. Se compara contra `period_start` para no depender de que
  -- los períodos sean exactamente contiguos.
  select id into v_prev_id
  from public.budget_periods
  where household_id = v_household
    and period_type = v_type
    and period_end < v_start
    and id <> p_new_period_id
  order by period_end desc
  limit 1;

  if v_prev_id is null then
    return 0;  -- primer período del hogar: no hay nada que arrastrar
  end if;

  for v_alloc in
    select category, subcategory, currency, rollover_mode
    from public.budget_allocations
    where period_id = v_prev_id
      and rollover_mode <> 'none'
  loop
    v_balance := public.envelope_balance(v_prev_id, v_alloc.category, v_alloc.subcategory);

    -- NULL = no se pudo normalizar la moneda. Se saltea en vez de inventar un número.
    if v_balance is null then
      continue;
    end if;

    if v_alloc.rollover_mode = 'surplus' then
      v_rollover := greatest(0, v_balance);
    else  -- 'full': arrastra también el déficit
      v_rollover := v_balance;
    end if;

    -- Un arrastre de exactamente 0 no aporta nada y ensuciaría el mes nuevo con sobres vacíos.
    if v_rollover = 0 then
      continue;
    end if;

    insert into public.budget_allocations
      (period_id, category, subcategory, allocated, rollover_from_prev, rollover_mode, currency)
    values
      (p_new_period_id, v_alloc.category, v_alloc.subcategory, 0, v_rollover,
       v_alloc.rollover_mode, v_alloc.currency)
    on conflict (period_id, category, subcategory) do update
      set rollover_from_prev = excluded.rollover_from_prev,
          updated_at = now();

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$;

comment on function app_hidden.roll_envelopes_forward(uuid) is
  'Arrastra los saldos de sobres del período anterior al período dado, según rollover_mode: '
  '`surplus` sólo el sobrante positivo, `full` también el déficit, `none` nada. Crea el sobre en '
  'el período nuevo con allocated=0 si no existe. Saltea sobres cuyo envelope_balance sea NULL '
  '(monedas sin tasa). Idempotente. Devuelve la cantidad de sobres arrastrados.';


-- Trigger: se dispara al crear un período, sin importar qué cliente lo cree.
create or replace function app_hidden.tg_roll_envelopes_forward()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  perform app_hidden.roll_envelopes_forward(new.id);
  return new;
end;
$function$;

drop trigger if exists tg_budget_periods_rollover on public.budget_periods;

create trigger tg_budget_periods_rollover
  after insert on public.budget_periods
  for each row
  execute function app_hidden.tg_roll_envelopes_forward();

comment on function app_hidden.tg_roll_envelopes_forward() is
  'AFTER INSERT en budget_periods: arrastra los sobres del período anterior. Va en trigger y no en '
  'los clientes porque los períodos se crean por demanda al navegar a un mes (no el día 1), y para '
  'que exista UNA sola implementación de la regla.';
