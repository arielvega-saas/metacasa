-- Fase 2.13 / audit S2: sacar los helpers puros de RLS de la superficie REST.
--
-- PostgREST expone todo `public.*` como /rest/v1/rpc/<fn>. Los helpers de RLS
-- (is_household_member, current_user_household_*) no son API para clientes:
-- son plumbing de policies. Moverlos a `app_hidden` (schema NO expuesto por
-- PostgREST) reduce superficie sin romper nada porque:
--   * Las policies y los column defaults referencian funciones por OID, no
--     por nombre → sobreviven el ALTER ... SET SCHEMA (verificado).
--   * Ninguna otra función las llama por nombre (verificado por introspección
--     de pg_proc el 2026-07-27).
--   * Ningún cliente (iOS/web/PWA) las invoca como RPC (verificado por grep).
--   * Los roles conservan EXECUTE (las ACL viajan con la función), pero
--     necesitan USAGE sobre el schema nuevo para que las policies evalúen.
--
-- NO se mueven: create_household, accept_household_invitation, web_access_state,
-- envelope_balance, has_active_entitlement — esas SÍ son RPC de clientes.

create schema if not exists app_hidden;

grant usage on schema app_hidden to authenticated, anon, service_role;

alter function public.is_household_member(uuid) set schema app_hidden;
alter function public.current_user_household_ids() set schema app_hidden;
alter function public.current_user_household_role(uuid) set schema app_hidden;
alter function public.current_user_default_household() set schema app_hidden;
