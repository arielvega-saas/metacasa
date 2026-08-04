-- Recuperada del ledger de producción el 2026-08-03.
--
-- Estaba aplicada en prod pero SIN archivo en el repo, y es la más grande de las que faltaban:
-- crea `bills`, `installment_plans`, `installment_payments` y `debts` con sus RLS, más la
-- config de waterfall y la propiedad de cuentas. Cuatro tablas del producto vivían sólo en
-- producción. Ver `leccion-drift-migraciones-supabase`.
--
-- El SQL va verbatim como corrió en producción; no se reformatea ni se "mejora".

-- ============================================================
-- Bloque #2 + #3: Waterfall + Bills + Installments + Debts
-- ============================================================

-- 1. BILLS (Vencimientos)
create table if not exists public.bills (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    title text not null,
    description text,
    amount numeric(14,2) not null,
    currency text not null default 'USD',
    due_date date not null,
    status text not null default 'pending',
    paid_at timestamptz,
    category text,
    account_id uuid references public.accounts(id) on delete set null,
    note text,
    recurring boolean default false,
    created_by uuid not null references auth.users(id),
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    constraint bills_status_chk check (status in ('pending','paid','skipped'))
);

create index if not exists bills_household_id_idx on public.bills (household_id);
create index if not exists bills_due_date_idx on public.bills (due_date);
create index if not exists bills_status_idx on public.bills (household_id, status);

alter table public.bills enable row level security;
create policy "bills_select" on public.bills for select using (public.is_household_member(household_id));
create policy "bills_insert" on public.bills for insert with check (public.is_household_member(household_id));
create policy "bills_update" on public.bills for update using (public.is_household_member(household_id));
create policy "bills_delete" on public.bills for delete using (public.is_household_member(household_id));

-- 2. INSTALLMENT PLANS (Cuotas)
create table if not exists public.installment_plans (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    name text not null,
    total_amount numeric(14,2) not null,
    total_installments int not null check (total_installments > 0),
    currency text not null default 'USD',
    start_year int not null,
    start_month int not null check (start_month between 1 and 12),
    category text,
    account_id uuid references public.accounts(id) on delete set null,
    note text,
    status text default 'active' check (status in ('active','completed','cancelled')),
    created_by uuid not null references auth.users(id),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists installment_plans_household_id_idx on public.installment_plans (household_id);
create index if not exists installment_plans_status_idx on public.installment_plans (household_id, status);

alter table public.installment_plans enable row level security;
create policy "installment_plans_select" on public.installment_plans for select using (public.is_household_member(household_id));
create policy "installment_plans_insert" on public.installment_plans for insert with check (public.is_household_member(household_id));
create policy "installment_plans_update" on public.installment_plans for update using (public.is_household_member(household_id));
create policy "installment_plans_delete" on public.installment_plans for delete using (public.is_household_member(household_id));

-- 3. INSTALLMENT PAYMENTS (ledger por mes)
create table if not exists public.installment_payments (
    id uuid primary key default gen_random_uuid(),
    plan_id uuid not null references public.installment_plans(id) on delete cascade,
    period_year int not null,
    period_month int not null check (period_month between 1 and 12),
    installment_number int not null,
    amount numeric(14,2) not null,
    paid boolean default false,
    paid_at timestamptz,
    transaction_id uuid references public.transactions(id) on delete set null,
    unique (plan_id, period_year, period_month)
);

create index if not exists installment_payments_plan_id_idx on public.installment_payments (plan_id);
create index if not exists installment_payments_period_idx on public.installment_payments (period_year, period_month);

alter table public.installment_payments enable row level security;
create policy "installment_payments_select" on public.installment_payments for select using (
    exists (select 1 from public.installment_plans p where p.id = plan_id and public.is_household_member(p.household_id))
);
create policy "installment_payments_insert" on public.installment_payments for insert with check (
    exists (select 1 from public.installment_plans p where p.id = plan_id and public.is_household_member(p.household_id))
);
create policy "installment_payments_update" on public.installment_payments for update using (
    exists (select 1 from public.installment_plans p where p.id = plan_id and public.is_household_member(p.household_id))
);
create policy "installment_payments_delete" on public.installment_payments for delete using (
    exists (select 1 from public.installment_plans p where p.id = plan_id and public.is_household_member(p.household_id))
);

-- 4. DEBTS
create table if not exists public.debts (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    creditor text not null,
    original_amount numeric(14,2) not null,
    current_balance numeric(14,2) not null,
    annual_rate numeric(5,2) not null default 0,
    monthly_payment numeric(14,2),
    currency text not null default 'USD',
    start_date date not null,
    maturity_date date,
    category text,
    note text,
    status text default 'active' check (status in ('active','settled')),
    created_by uuid not null references auth.users(id),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists debts_household_id_idx on public.debts (household_id);
create index if not exists debts_status_idx on public.debts (household_id, status);

alter table public.debts enable row level security;
create policy "debts_select" on public.debts for select using (public.is_household_member(household_id));
create policy "debts_insert" on public.debts for insert with check (public.is_household_member(household_id));
create policy "debts_update" on public.debts for update using (public.is_household_member(household_id));
create policy "debts_delete" on public.debts for delete using (public.is_household_member(household_id));

-- 5. HOUSEHOLD STRATEGY (waterfall config)
alter table public.households add column if not exists strategy jsonb not null default '{
    "savings_pct": 10,
    "investment_pct": 0,
    "distribution_mode": "equal",
    "custom_allocations": {},
    "include_bills_in_waterfall": true,
    "include_installments_in_waterfall": true,
    "include_debt_payments_in_waterfall": true
}'::jsonb;

-- 6. ACCOUNT OWNERSHIP
alter table public.accounts add column if not exists ownership text default 'personal';
alter table public.accounts add column if not exists owner_user_id uuid references auth.users(id);
-- Only add check if it's not already present
do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'accounts_ownership_chk'
    ) then
        alter table public.accounts add constraint accounts_ownership_chk check (ownership in ('personal','shared','external'));
    end if;
end $$;
