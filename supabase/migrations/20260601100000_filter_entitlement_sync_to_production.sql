-- H4 (seguridad): que SOLO las compras de RevenueCat en environment='production'
-- otorguen entitlements. Antes, el trigger contaba también suscripciones de
-- sandbox/TestFlight, así que una compra de prueba podía prender is_active y
-- desbloquear Premium en la WEB de producción (web_access_state -> has_active_entitlement).
-- La app iOS gatea por StoreKit local (production-aware), así que este filtro no afecta su UI.
--
-- Cómo aplicar (elegí una):
--   A) supabase db push   (desde la raíz del repo, con el CLI logueado al proyecto)
--   B) Pegar este bloque en Supabase Dashboard → SQL Editor → Run
--
-- Impacto: 0 suscriptores hoy → cambio preventivo, sin efecto sobre datos existentes.

CREATE OR REPLACE FUNCTION public.tg_sync_user_entitlements()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  target_user uuid;
  target_ent text;
begin
  target_user := coalesce(new.user_id, old.user_id);
  target_ent := coalesce(new.entitlement_id, old.entitlement_id);

  insert into public.user_entitlements (user_id, entitlement, is_active, expires_at, updated_at)
  values (
    target_user,
    target_ent,
    exists (
      select 1 from public.subscriptions
      where user_id = target_user
        and entitlement_id = target_ent
        and status in ('active', 'trialing', 'grace_period')
        and environment = 'production'
        and (expires_at is null or expires_at > now())
    ),
    (select max(expires_at) from public.subscriptions
      where user_id = target_user and entitlement_id = target_ent
        and environment = 'production'),
    now()
  )
  on conflict (user_id, entitlement) do update
  set is_active = excluded.is_active,
      expires_at = excluded.expires_at,
      updated_at = now();

  return coalesce(new, old);
end;
$function$;
