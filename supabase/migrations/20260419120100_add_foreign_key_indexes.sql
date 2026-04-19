-- Migration: add_foreign_key_indexes
-- Aplicada: 2026-04-19
--
-- Agrega indices cubrientes en FKs sin indice (advisor unindexed_foreign_keys).
-- Tambien un composite util para transactions por user_id + date desc (pantalla principal).

create index if not exists idx_bills_user_id on public.bills (user_id);
create index if not exists idx_connected_wallets_user_id on public.connected_wallets (user_id);
create index if not exists idx_recurring_transactions_user_id on public.recurring_transactions (user_id);
create index if not exists idx_wallet_movements_user_id on public.wallet_movements (user_id);
create index if not exists idx_wallet_movements_wallet_id on public.wallet_movements (wallet_id);
create index if not exists idx_wallet_movements_synced_tx_id on public.wallet_movements (synced_tx_id);
create index if not exists idx_transactions_user_id_date on public.transactions (user_id, date desc);
create index if not exists idx_budgets_user_id on public.budgets (user_id);
