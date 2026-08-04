-- Migration: fix_rls_performance_initplan
-- Aplicada: 2026-04-19
--
-- Reescribe las 14 RLS policies para usar (select auth.uid()) en lugar de auth.uid().
-- Evita re-evaluar auth.uid() por cada fila (advisor auth_rls_initplan).
-- Impacto a escala: alto. Rows actuales: bajo pero crece.

-- bills
drop policy if exists "bills_select" on public.bills;
drop policy if exists "bills_insert" on public.bills;
drop policy if exists "bills_update" on public.bills;
drop policy if exists "bills_delete" on public.bills;
create policy "bills_select" on public.bills for select using ((select auth.uid()) = user_id);
create policy "bills_insert" on public.bills for insert with check ((select auth.uid()) = user_id);
create policy "bills_update" on public.bills for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "bills_delete" on public.bills for delete using ((select auth.uid()) = user_id);

-- budgets
drop policy if exists "Users can manage their budgets" on public.budgets;
create policy "Users can manage their budgets" on public.budgets for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- categories
drop policy if exists "Users can manage their categories" on public.categories;
create policy "Users can manage their categories" on public.categories for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- connected_wallets
drop policy if exists "own wallets" on public.connected_wallets;
create policy "own wallets" on public.connected_wallets for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- recurring_transactions
drop policy if exists "own recurring" on public.recurring_transactions;
create policy "own recurring" on public.recurring_transactions for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- strategy
drop policy if exists "Users can manage their strategy" on public.strategy;
create policy "Users can manage their strategy" on public.strategy for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- transactions
drop policy if exists "Users can select their transactions" on public.transactions;
drop policy if exists "Users can insert their transactions" on public.transactions;
drop policy if exists "Users can update their transactions" on public.transactions;
drop policy if exists "Users can delete their transactions" on public.transactions;
create policy "Users can select their transactions" on public.transactions for select using ((select auth.uid()) = user_id);
create policy "Users can insert their transactions" on public.transactions for insert with check ((select auth.uid()) = user_id);
create policy "Users can update their transactions" on public.transactions for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their transactions" on public.transactions for delete using ((select auth.uid()) = user_id);

-- wallet_movements
drop policy if exists "own movements" on public.wallet_movements;
create policy "own movements" on public.wallet_movements for all using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
