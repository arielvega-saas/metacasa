-- Recuperada del ledger de producción el 2026-08-03.
--
-- Estaba aplicada en prod pero SIN archivo en el repo: alguien la aplicó por API/dashboard y
-- nunca la versionó. Un `db reset` desde el repo habría producido un schema distinto al de prod,
-- y cualquier razonamiento sobre "qué hay en la base" mirando el repo habría sido falso.
-- Ver la memoria `leccion-drift-migraciones-supabase`.

-- Add covering indexes for foreign keys flagged by performance advisor.
-- Each index named idx_<table>_<col> for clarity. CONCURRENTLY would be ideal
-- but apply_migration runs in transaction context; tables are small at dev
-- so plain CREATE INDEX is fine.
CREATE INDEX IF NOT EXISTS idx_accounts_owner_user_id ON public.accounts(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_debts_created_by ON public.debts(created_by);
CREATE INDEX IF NOT EXISTS idx_installment_payments_transaction_id ON public.installment_payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_installment_plans_account_id ON public.installment_plans(account_id);
CREATE INDEX IF NOT EXISTS idx_installment_plans_created_by ON public.installment_plans(created_by);
CREATE INDEX IF NOT EXISTS idx_transaction_templates_created_by ON public.transaction_templates(created_by);
