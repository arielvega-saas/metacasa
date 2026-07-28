-- Suite pgTAP: aislamiento multi-hogar y triggers de dinero.
--
-- POR QUÉ EXISTE: la RLS de este proyecto es lo único que separa la plata de
-- una familia de la de otra. Un `drop policy` de más, un helper renombrado o
-- una policy PERMISSIVE mal puesta (ya pasó con `bills`) abre una fuga que no
-- da error: simplemente devuelve filas de más. Estos tests fallan cuando eso
-- ocurre.
--
-- CÓMO CORRER
--   psql "$DATABASE_URL" -f supabase/tests/rls_isolation.sql
--   (o pegarlo en el SQL Editor de Supabase)
-- Todo vive dentro de una transacción que termina en ROLLBACK: no deja datos.
-- Verificado contra producción el 2026-07-28 → 14/14 ok, 0 filas residuales.
--
-- GOTCHAS que costaron encontrar (no los borres):
--   * `plan(N)` tiene que ir ANTES del primer test, si no pgTAP aborta con
--     "You tried to run a test without a plan!".
--   * Las temp tables del fixture se leen desde dentro de
--     `set local role authenticated`, así que ese rol necesita GRANT explícito
--     (incluida la secuencia del serial).

begin;
select plan(14);

-- Tabla donde juntamos la salida TAP para poder contar fallas de una.
create temp table tap(n serial, line text);
grant insert, select on tap to authenticated;
grant usage, select on sequence tap_n_seq to authenticated;

-- ── Fixture: dos usuarios en dos hogares distintos ───────────────────────────
create temp table ids(k text primary key, v uuid);
grant select on ids to authenticated;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values (gen_random_uuid(), '00000000-0000-0000-0000-000000000000','authenticated',
        'authenticated','pgtap_ana@test.local','',now(),now(),now()),
       (gen_random_uuid(), '00000000-0000-0000-0000-000000000000','authenticated',
        'authenticated','pgtap_beto@test.local','',now(),now(),now());
insert into ids select 'ana',  id from auth.users where email='pgtap_ana@test.local';
insert into ids select 'beto', id from auth.users where email='pgtap_beto@test.local';

insert into public.households (id,name,default_currency,created_by)
values (gen_random_uuid(),'Hogar Ana','ARS',(select v from ids where k='ana')),
       (gen_random_uuid(),'Hogar Beto','ARS',(select v from ids where k='beto'));
insert into ids select 'hh_ana',  id from public.households where name='Hogar Ana';
insert into ids select 'hh_beto', id from public.households where name='Hogar Beto';

insert into public.household_members (household_id,user_id,role)
values ((select v from ids where k='hh_ana'), (select v from ids where k='ana'), 'owner'),
       ((select v from ids where k='hh_beto'),(select v from ids where k='beto'),'owner');

insert into public.transactions (household_id,user_id,type,amount,category,date,note)
values ((select v from ids where k='hh_ana'), (select v from ids where k='ana'),
        'GASTO',1000,'Alimentación','2026-03-15T12:00:00Z','Secreto de Ana'),
       ((select v from ids where k='hh_beto'),(select v from ids where k='beto'),
        'GASTO',2000,'Transporte','2026-03-15T12:00:00Z','Secreto de Beto');

-- ── Ana ──────────────────────────────────────────────────────────────────────
select set_config('request.jwt.claims',
  json_build_object('sub',(select v from ids where k='ana'),'role','authenticated')::text, true);
set local role authenticated;

insert into tap(line) select is((select count(*)::int from public.transactions),1,
  'Ana ve exactamente 1 transaccion (la suya)');
insert into tap(line) select is((select count(*)::int from public.transactions
  where note='Secreto de Beto'),0, 'Ana NO ve las transacciones de Beto');
insert into tap(line) select is((select count(*)::int from public.households),1,
  'Ana ve solo su hogar');
insert into tap(line) select is((select count(*)::int from public.household_members),1,
  'Ana ve solo su membresia');
insert into tap(line) select throws_ok(
  format($q$insert into public.transactions (household_id,user_id,type,amount,category,date)
           values (%L,%L,'GASTO',1,'X',now())$q$,
         (select v from ids where k='hh_beto'),(select v from ids where k='ana')),
  '42501', null, 'Ana NO puede insertar en el hogar de Beto');
insert into tap(line) select throws_ok(
  format($q$select * from public.month_summary(%L,2026,3)$q$,(select v from ids where k='hh_beto')),
  '42501', null, 'month_summary rechaza un hogar ajeno');
insert into tap(line) select is((select count(*)::int from public.suggest_category(
  (select v from ids where k='hh_beto'),'Secreto de Beto')),0,
  'suggest_category no filtra reglas de otro hogar');
reset role;

-- ── Beto ─────────────────────────────────────────────────────────────────────
select set_config('request.jwt.claims',
  json_build_object('sub',(select v from ids where k='beto'),'role','authenticated')::text, true);
set local role authenticated;

insert into tap(line) select is((select count(*)::int from public.transactions),1,
  'Beto ve exactamente 1 transaccion (la suya)');
insert into tap(line) select is((select note from public.transactions limit 1),'Secreto de Beto',
  'Beto ve SU transaccion, no la de Ana');
reset role;

-- ── Triggers de dinero ───────────────────────────────────────────────────────
insert into public.transactions (household_id,user_id,type,amount,category,date,note)
values ((select v from ids where k='hh_ana'),(select v from ids where k='ana'),
        'INGRESO',500,'Sueldo','2026-05-20T12:00:00Z','Test periodo');

insert into tap(line) select is((select period_year  from public.transactions where note='Test periodo'),2026,
  'trigger fill_period deriva period_year');
insert into tap(line) select is((select period_month from public.transactions where note='Test periodo'),5,
  'trigger fill_period deriva period_month');
insert into tap(line) select isnt((select count(*) from app_hidden.audit_log
  where table_name='transactions'
    and row_id=(select id from public.transactions where note='Test periodo')),0::bigint,
  'audit_log registro el INSERT');
insert into tap(line) select is((select category from public.category_rules
  where household_id=(select v from ids where k='hh_ana')
    and pattern=app_hidden.normalize_note('Test periodo')),'Sueldo',
  'trigger learn_category aprendio la regla');

update public.transactions set category='Otros' where note='Test periodo';
insert into tap(line) select is((select category from public.category_rules
  where household_id=(select v from ids where k='hh_ana')
    and pattern=app_hidden.normalize_note('Test periodo')),'Otros',
  'la correccion del usuario pisa la regla aprendida');

-- Resumen legible + salida TAP completa.
select count(*) filter (where line like 'ok %')     as pasaron,
       count(*) filter (where line not like 'ok %') as fallaron,
       coalesce(string_agg(line,' || ') filter (where line not like 'ok %'),'ninguna') as fallas
from tap;

select line from tap order by n;
select * from finish();
rollback;
