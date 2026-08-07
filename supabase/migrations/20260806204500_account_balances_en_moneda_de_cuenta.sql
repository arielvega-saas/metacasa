-- El saldo de una cuenta tiene que estar en LA MONEDA DE ESA CUENTA.
--
-- `accounts.starting_balance` se guarda en la moneda de la cuenta, pero
-- `transactions.amount` está en la moneda BASE del hogar. La versión anterior
-- de esta función los sumaba directo, o sea sumaba dólares con pesos.
--
-- Caja de ahorro en USD dentro de un hogar en ARS, saldo inicial US$1.000 y un
-- ingreso de US$500 cargado a tasa 1000:
--
--     amount (base ARS) = 500.000
--     balance = 1.000 + 500.000 = 501.000   → la app mostraba US$ 501.000
--
-- cuando el saldo real es US$1.500. Y el dashboard lo empeoraba: volvía a
-- convertir ese número *desde* USD.
--
-- Regla, idéntica a la de los clientes (`lib/db/account-balance.ts` en la web y
-- `AccountBalanceService.currentBalance` en iOS) — las tres tienen que dar el
-- mismo número:
--
--   1. Si la moneda del movimiento coincide con la de la cuenta → `amount_original`.
--   2. Si la cuenta está en la moneda base → `amount` tal cual.
--   3. Si difieren → convertir `amount` desde base dividiendo por la tasa de la
--      moneda de la cuenta (`fx_rates` guarda moneda → tasa HACIA base: en un
--      hogar ARS, USD.rate = 1540 significa 1 USD = 1540 ARS).
--   4. Sin tasa → se usa `amount` crudo. Descartar el movimiento dejaría el
--      saldo mal sin que nada lo indique.

create or replace function public.account_balances(p_household uuid)
returns table(account_id uuid, balance numeric)
language sql
stable
set search_path to 'public'
as $function$
  with hogar as (
    select default_currency, fx_rates
    from public.households
    where id = p_household
  )
  select a.id,
         a.starting_balance + coalesce(sum(
           (case when t.type = 'GASTO' then -1 else 1 end) *
           case
             -- 1. misma moneda que la cuenta: el monto tal como se tipeó
             when upper(coalesce(t.currency_original, h.default_currency)) = upper(a.currency)
                  and t.amount_original is not null
               then t.amount_original
             -- 2. cuenta en moneda base: `amount` ya está en esa moneda
             when upper(a.currency) = upper(h.default_currency)
               then t.amount
             -- 3. convertir de base a la moneda de la cuenta
             when nullif(h.fx_rates -> upper(a.currency) ->> 'rate', '')::numeric is not null
                  and nullif(h.fx_rates -> upper(a.currency) ->> 'rate', '')::numeric <> 0
               then t.amount / (h.fx_rates -> upper(a.currency) ->> 'rate')::numeric
             -- 4. sin tasa: mejor un saldo aproximado que uno al que le faltan movimientos
             else t.amount
           end
         ), 0)
  from public.accounts a
  cross join hogar h
  left join public.transactions t
    on t.account_id = a.id and t.household_id = a.household_id
  where a.household_id = p_household
    and a.is_active
  group by a.id, a.starting_balance
$function$;
