-- Fase 4.5: cotizaciones automáticas.
--
-- Hasta hoy el FX era 100% manual: `fx_rates` tenía 0 filas y ningún hogar
-- tenía `fx_rates` cargado, así que la app multi-moneda dependía de que el
-- usuario tipeara la cotización a mano (y la actualizara).
--
-- ARQUITECTURA (sin edge function ni secretos que administrar):
--   pg_net es asíncrono, así que el ciclo va en dos pasos encadenados por cron:
--     1) `fx_fetch()`  dispara los GET y guarda los request_id.
--     2) `fx_process()` (5 min después) lee `net._http_response`, parsea el
--        JSON en Postgres y persiste.
--   Hacerlo en SQL evita tener que autenticar un llamado cron → edge function.
--
-- FUENTES:
--   * open.er-api.com/v6/latest/USD → todas las monedas (rates por 1 USD).
--   * dolarapi.com/v1/dolares/blue  → ARS. El "oficial" de las APIs globales
--     no refleja lo que la gente realmente paga en Argentina; el blue sí.
--     Este override ES el diferencial LatAm del producto.
--
-- CONVENCIONES (respetadas, no inventadas):
--   * `public.fx_rates.rate` = unidades de `quote_currency` por 1 `base_currency`
--     (consistente con `latest_fx_rate`). Guardamos todo con base 'USD'.
--   * `households.fx_rates` JSONB = { "USD": { rate, updated_at, source } }
--     donde rate = unidades de la moneda BASE DEL HOGAR por 1 unidad de esa
--     moneda (lo que esperan iOS `FXConverter` y web `lib/fx.ts`).
--     Se deriva como  rate = r[base_hogar] / r[moneda]  con los r por-USD.
--
-- REGLA DE ORO: nunca pisamos una cotización que el usuario cargó a mano
-- (`source = 'manual'`). El job sólo escribe entradas nuevas o las que él mismo
-- creó (`source` = 'auto' / 'blue').

create table if not exists app_hidden.fx_sync_requests (
  request_id bigint primary key,
  kind text not null check (kind in ('global', 'blue')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists idx_fx_sync_requests_pending
  on app_hidden.fx_sync_requests (created_at) where processed_at is null;

-- Monedas que nos interesa mantener al día (mercados del producto).
create or replace function app_hidden.fx_supported_currencies()
returns text[]
language sql
immutable
as $$ select array['USD','ARS','EUR','BRL','CLP','COP','MXN','UYU','PEN','GBP','HKD'] $$;

-- ── Paso 1: disparar los requests ────────────────────────────────────────────
create or replace function app_hidden.fx_fetch()
returns void
language plpgsql
security definer
set search_path to 'public', 'net', 'app_hidden'
as $$
declare
  req_global bigint;
  req_blue bigint;
begin
  select net.http_get('https://open.er-api.com/v6/latest/USD', timeout_milliseconds := 15000)
    into req_global;
  insert into app_hidden.fx_sync_requests(request_id, kind) values (req_global, 'global');

  select net.http_get('https://dolarapi.com/v1/dolares/blue', timeout_milliseconds := 15000)
    into req_blue;
  insert into app_hidden.fx_sync_requests(request_id, kind) values (req_blue, 'blue');
end $$;

-- ── Paso 2: parsear respuestas y persistir ───────────────────────────────────
create or replace function app_hidden.fx_process()
returns int
language plpgsql
security definer
set search_path to 'public', 'net', 'app_hidden'
as $$
declare
  r record;
  body jsonb;
  cur text;
  val numeric;
  written int := 0;
  today date := current_date;
begin
  for r in
    select q.request_id, q.kind, resp.status_code, resp.content
    from app_hidden.fx_sync_requests q
    join net._http_response resp on resp.id = q.request_id
    where q.processed_at is null
    order by q.created_at
  loop
    if r.status_code between 200 and 299 and r.content is not null then
      begin
        body := r.content::jsonb;
      exception when others then
        body := null;
      end;

      if body is not null and r.kind = 'global' then
        -- { "rates": { "ARS": 1470.5, "EUR": 0.878, ... } }  (por 1 USD)
        foreach cur in array app_hidden.fx_supported_currencies() loop
          val := nullif(body -> 'rates' ->> cur, '')::numeric;
          if val is not null and val > 0 then
            insert into public.fx_rates(base_currency, quote_currency, rate, rate_date, source)
            values ('USD', cur, val, today, 'auto')
            on conflict (base_currency, quote_currency, rate_date)
              do update set rate = excluded.rate, source = excluded.source;
            written := written + 1;
          end if;
        end loop;

      elsif body is not null and r.kind = 'blue' then
        -- { "compra": 1540, "venta": 1560 }. Usamos VENTA: es lo que te cuesta
        -- comprar un dólar, el número con el que la gente piensa sus precios.
        val := nullif(body ->> 'venta', '')::numeric;
        if val is not null and val > 0 then
          insert into public.fx_rates(base_currency, quote_currency, rate, rate_date, source)
          values ('USD', 'ARS', val, today, 'blue')
          on conflict (base_currency, quote_currency, rate_date)
            do update set rate = excluded.rate, source = excluded.source;
          written := written + 1;
        end if;
      end if;
    end if;

    update app_hidden.fx_sync_requests set processed_at = now() where request_id = r.request_id;
  end loop;

  if written > 0 then
    perform app_hidden.fx_refresh_households();
  end if;
  return written;
end $$;

-- ── Paso 3: propagar a households.fx_rates (respetando manuales) ─────────────
create or replace function app_hidden.fx_refresh_households()
returns int
language plpgsql
security definer
set search_path to 'public', 'app_hidden'
as $$
declare
  h record;
  cur text;
  base_rate numeric;   -- unidades de la base del hogar por 1 USD
  cur_rate numeric;    -- unidades de `cur` por 1 USD
  derived numeric;     -- unidades de la base del hogar por 1 `cur`
  new_rates jsonb;
  touched int := 0;
begin
  for h in select id, upper(coalesce(default_currency,'USD')) as base, fx_rates from public.households loop
    select rate into base_rate from public.fx_rates
      where base_currency = 'USD' and quote_currency = h.base
      order by rate_date desc limit 1;
    -- Si la base del hogar es USD, r[USD] = 1 por definición.
    if h.base = 'USD' then base_rate := 1; end if;
    continue when base_rate is null or base_rate <= 0;

    new_rates := coalesce(h.fx_rates, '{}'::jsonb);

    foreach cur in array app_hidden.fx_supported_currencies() loop
      continue when cur = h.base;   -- no se convierte a sí misma

      -- Respetar lo que el usuario cargó a mano.
      continue when (new_rates -> cur ->> 'source') = 'manual';

      if cur = 'USD' then
        cur_rate := 1;
      else
        select rate into cur_rate from public.fx_rates
          where base_currency = 'USD' and quote_currency = cur
          order by rate_date desc limit 1;
      end if;
      continue when cur_rate is null or cur_rate <= 0;

      derived := round(base_rate / cur_rate, 6);
      new_rates := jsonb_set(
        new_rates,
        array[cur],
        jsonb_build_object(
          'rate', derived,
          'updated_at', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'source', 'auto'
        ),
        true
      );
    end loop;

    if new_rates is distinct from coalesce(h.fx_rates, '{}'::jsonb) then
      update public.households set fx_rates = new_rates where id = h.id;
      touched := touched + 1;
    end if;
  end loop;
  return touched;
end $$;

revoke execute on function app_hidden.fx_fetch() from public, anon, authenticated;
revoke execute on function app_hidden.fx_process() from public, anon, authenticated;
revoke execute on function app_hidden.fx_refresh_households() from public, anon, authenticated;

-- Cotizaciones frescas antes de que arranque el día en LatAm
-- (09:40 UTC ≈ 06:40 ART). El blue se publica por la mañana.
select cron.schedule('fx-fetch-daily',   '40 9 * * *',  $$select app_hidden.fx_fetch()$$);
select cron.schedule('fx-process-daily', '45 9 * * *',  $$select app_hidden.fx_process()$$);
