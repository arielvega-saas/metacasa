-- ============================================================================
-- Align `bills` schema with the shipped iOS app + enforce strict INSERT policy
-- ============================================================================
--
-- HALLAZGO (auditoría 2026-07-27): la tabla `bills` en prod conserva la forma
-- legacy de la PWA (user_id NOT NULL, recurrence_type, reminder_days) y NUNCA
-- tuvo las columnas que el port iOS "Web → iOS #3" asumió (description, paid_at,
-- account_id, note, recurring, created_by, updated_at). Consecuencia: el módulo
-- Bills de la app iOS PUBLICADA estaba roto contra prod:
--   * decode de Bill falla (createdBy/recurring no-opcionales, columnas ausentes)
--   * insert falla (columnas desconocidas + user_id NOT NULL sin default)
--   * update/markPaid fallan (paid_at/note/etc. desconocidas)
-- La web nueva (database.types.ts) matchea prod y NO se ve afectada por estos
-- agregados (son aditivos, nullable o con default).
--
-- Este fix es DB-side a propósito: destraba la app que ya está en App Store sin
-- esperar un release nuevo.
--
-- Además (plan Fase 1.3 / audit S3): con user_id DEFAULT auth.uid() ya podemos
-- eliminar las policies permissive laxas que diluían el check estricto
-- `user_id = auth.uid()` en INSERT (un miembro podía insertar bills a nombre de
-- otro). Clientes verificados antes de esto:
--   * iOS: omite user_id → default auth.uid() lo llena → pasa el check estricto.
--   * PWA legacy (src/App.jsx saveBill): manda user_id = uid propio → pasa.
--   * metacasa-web (lib/actions/bills.ts): manda user_id = uid propio → pasa.

-- 1) Columnas que el modelo iOS `Bill` espera (aditivas, no rompen a nadie).
alter table public.bills
  add column if not exists description text,
  add column if not exists paid_at timestamptz,
  add column if not exists account_id uuid references public.accounts(id) on delete set null,
  add column if not exists note text,
  add column if not exists recurring boolean not null default false,
  add column if not exists created_by uuid default auth.uid(),
  add column if not exists updated_at timestamptz default now();

-- Índice covering para el FK nuevo (convención del proyecto).
create index if not exists idx_bills_account_id on public.bills(account_id);

-- 2) Backfill: created_by = user_id (todas las filas lo tienen, es NOT NULL);
--    paid_at para las ya pagadas (mejor esfuerzo: created_at como aproximación).
update public.bills set created_by = user_id where created_by is null;
update public.bills set paid_at = created_at where status = 'paid' and paid_at is null;

-- 3) user_id se llena solo con el caller autenticado cuando el cliente lo omite
--    (iOS). Mismo patrón que household_id DEFAULT current_user_default_household().
alter table public.bills alter column user_id set default auth.uid();

-- 4) Ahora sí: eliminar las policies laxas. Quedan las *_household estrictas:
--      INSERT: is_household_member(household_id) AND user_id = (select auth.uid())
--      UPDATE: USING + WITH CHECK is_household_member(household_id)
drop policy if exists "bills_insert" on public.bills;
drop policy if exists "bills_update" on public.bills;
drop policy if exists "tx_templates_update" on public.transaction_templates;
