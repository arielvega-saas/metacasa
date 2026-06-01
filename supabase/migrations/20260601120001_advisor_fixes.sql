-- ============================================================================
-- Advisor fixes — safe, additive cleanups only (Supabase performance linter)
-- ============================================================================
--
-- Source: `get_advisors(performance)` on project rgslvrxdppphzvqgcwbx, 2026-06-01.
-- This migration ONLY drops objects that are provably redundant (identical indexes,
-- and RLS policies that are byte-for-byte equivalent to a sibling policy that we
-- keep). Nothing here changes the effective access-control surface.
--
-- Deliberately NOT touched here (reported instead — see audit notes):
--   * `bills` INSERT policies (bills_insert vs bills_insert_household) — NOT identical:
--       bills_insert        WITH CHECK is_household_member(household_id)
--       bills_insert_household WITH CHECK (is_household_member(household_id)
--                                          AND user_id = (select auth.uid()))
--     Because both are PERMISSIVE, a row passes if EITHER check holds, so the weaker
--     `bills_insert` currently makes the stricter check moot. Dropping `bills_insert`
--     would START enforcing `user_id = auth.uid()`, which could reject inserts the
--     published iOS app makes today. Left in place pending a deliberate review.
--   * `bills` UPDATE policies (bills_update vs bills_update_household) — NOT identical:
--       bills_update           USING is_household_member(household_id)  (no WITH CHECK)
--       bills_update_household USING is_household_member(household_id)
--                              WITH CHECK is_household_member(household_id)
--     Dropping `bills_update` would START enforcing the WITH CHECK on updated rows.
--     Behavior-changing, so left in place.
--   * `transaction_templates` UPDATE policies (tx_templates_update vs
--     transaction_templates_update_household) — same shape difference as bills UPDATE
--     (one has WITH CHECK, the other does not). Left in place.
--   * `unused_index` (INFO) findings — left as-is: most are legitimate FK / lookup
--     indexes that simply have not been hit yet on this low-traffic project. Dropping
--     them would only reintroduce missing-FK-index warnings later.
--   * `auth_db_connections_absolute` (INFO) — Auth pool sizing, a project config
--     setting, not a schema change. Adjust in the Supabase dashboard if desired.
--
-- The 7 `SECURITY DEFINER` security-advisor warnings (is_household_member,
-- current_user_household_ids, current_user_default_household,
-- current_user_household_role, create_household, accept_household_invitation,
-- web_access_state) are INTENTIONAL — they are the RLS helper / RPC layer and MUST
-- be SECURITY DEFINER to break RLS recursion and run privileged logic. Not changed.
-- Leaked-password protection is already enabled (no longer in the advisor list).
--
-- HOW TO APPLY (user applies manually — do NOT auto-apply):
--   Option A: `supabase db push`
--   Option B: paste this file into the Supabase SQL Editor and run it.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Duplicate indexes (lint 0009). Each pair is byte-for-byte identical and
--    neither member backs a constraint, so dropping one of each is safe.
-- ----------------------------------------------------------------------------

-- public.bills: bills_household_id_idx == idx_bills_household_id  (btree (household_id))
-- Keep idx_bills_household_id (matches the project's idx_* naming convention).
drop index if exists public.bills_household_id_idx;

-- public.transaction_templates: idx_transaction_templates_household
--   == transaction_templates_household_idx  (btree (household_id, "position"))
-- Keep idx_transaction_templates_household (idx_* convention).
drop index if exists public.transaction_templates_household_idx;

-- ----------------------------------------------------------------------------
-- 2) Duplicate permissive RLS policies (lint 0006). Only the pairs whose USING
--    and WITH CHECK expressions are IDENTICAL are deduped here; we keep the
--    `*_household` policy (the canonical set created by the household migrations)
--    and drop the redundant twin. These drops do not change who can read/write.
-- ----------------------------------------------------------------------------

-- public.bills — SELECT: bills_select == bills_select_household
--   (both USING is_household_member(household_id)). Keep _household.
drop policy if exists "bills_select" on public.bills;

-- public.bills — DELETE: bills_delete == bills_delete_household
--   (both USING is_household_member(household_id)). Keep _household.
drop policy if exists "bills_delete" on public.bills;
-- NOTE: bills_insert / bills_update intentionally NOT dropped (see header).

-- public.transaction_templates — SELECT: tx_templates_select == transaction_templates_select_household
drop policy if exists "tx_templates_select" on public.transaction_templates;

-- public.transaction_templates — INSERT: tx_templates_insert == transaction_templates_insert_household
--   (both WITH CHECK is_household_member(household_id)).
drop policy if exists "tx_templates_insert" on public.transaction_templates;

-- public.transaction_templates — DELETE: tx_templates_delete == transaction_templates_delete_household
drop policy if exists "tx_templates_delete" on public.transaction_templates;
-- NOTE: tx_templates_update intentionally NOT dropped (differs by WITH CHECK; see header).
