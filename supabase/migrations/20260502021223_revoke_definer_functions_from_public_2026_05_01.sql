-- Recuperada del ledger de producción el 2026-08-03.
--
-- Estaba aplicada en prod pero SIN archivo en el repo: se aplicó por API/dashboard y nunca se
-- versionó. Un `db reset` desde el repo habría dado un schema distinto al de prod — y en ESTE
-- caso el schema resultante habría sido más permisivo, porque lo que hace la migración es
-- justamente revocar permisos. Ver la memoria `leccion-drift-migraciones-supabase`.
--
-- El SQL va verbatim como corrió en producción; no se reformatea ni se "mejora".

-- Apple/Play store readiness: SECURITY DEFINER functions deben tener
-- EXECUTE solo donde realmente se necesite. Los advisors marcaban exposición
-- innecesaria al rol `anon` y a veces a `authenticated`.

-- Trigger functions (nunca deben ser RPCs)
REVOKE EXECUTE ON FUNCTION public.encrypt_wallet_access_token_tg() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.tg_goal_contribution_apply() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.tg_sync_user_entitlements() FROM anon, authenticated, public;

-- Helpers usados solo desde otras funciones SQL / RLS policies
REVOKE EXECUTE ON FUNCTION public.current_user_default_household() FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.current_user_household_ids() FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.current_user_household_role(uuid) FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.is_household_member(uuid) FROM anon, public;

-- Quota check: solo edge functions con service_role deben llamarla
REVOKE EXECUTE ON FUNCTION public.ai_check_and_increment_quota(uuid, integer, integer, integer, integer, integer, integer) FROM anon, authenticated, public;

-- Wallet access token getter: solo service_role
REVOKE EXECUTE ON FUNCTION public.get_wallet_access_token(uuid) FROM anon, authenticated, public;

-- Wallet encryption key: solo service_role / triggers
REVOKE EXECUTE ON FUNCTION public.wallet_encryption_key() FROM anon, authenticated, public;
