-- Recuperada del ledger de producción el 2026-08-03.
--
-- Estaba aplicada en prod pero SIN archivo en el repo: alguien la aplicó por API/dashboard y
-- nunca la versionó. Un `db reset` desde el repo habría producido un schema distinto al de prod,
-- y cualquier razonamiento sobre "qué hay en la base" mirando el repo habría sido falso.
-- Ver la memoria `leccion-drift-migraciones-supabase`.

-- Templates (quick shortcuts): el usuario guarda hasta N plantillas de tx
-- para crear movimientos recurrentes con 1 tap. Port del web (App.jsx:3229-3244
-- `templates`).
create table if not exists public.transaction_templates (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    name text not null,
    emoji text,
    type text not null check (type in ('GASTO','INGRESO')),
    amount numeric(14,2) not null,
    currency text not null default 'USD',
    category text not null,
    subcategory text,
    note text,
    position int not null default 0,
    created_by uuid not null references auth.users(id),
    created_at timestamptz default now()
);

create index if not exists transaction_templates_household_idx
    on public.transaction_templates (household_id, position);

alter table public.transaction_templates enable row level security;

create policy "tx_templates_select" on public.transaction_templates
    for select using (public.is_household_member(household_id));
create policy "tx_templates_insert" on public.transaction_templates
    for insert with check (public.is_household_member(household_id));
create policy "tx_templates_update" on public.transaction_templates
    for update using (public.is_household_member(household_id));
create policy "tx_templates_delete" on public.transaction_templates
    for delete using (public.is_household_member(household_id));

-- FX Rates: tasas de conversión manuales del usuario, guardadas como jsonb
-- en households. Formato: { "USD": { "rate": 1000, "updated_at": "...", "source": "manual" } }
-- El rate se interpreta como "cuántas unidades de DEFAULT_CURRENCY del hogar
-- equivalen a 1 unidad de esa moneda". Ej: household en ARS, USD=1000 → 1 USD = 1000 ARS.
alter table public.households
    add column if not exists fx_rates jsonb not null default '{}'::jsonb;
