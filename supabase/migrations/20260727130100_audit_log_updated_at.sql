-- Fase 3.17: trazabilidad para tablas de dinero.
--
-- * `transactions.updated_at` (hasta hoy no se podía saber si un movimiento
--   fue editado) + trigger touch en transactions y bills.
-- * `app_hidden.audit_log` append-only: quién hizo qué y cuándo en las tablas
--   de dinero. Vive en app_hidden (NO expuesta por PostgREST); el trigger es
--   SECURITY DEFINER así el insert no depende de policies del caller.

alter table public.transactions add column if not exists updated_at timestamptz default now();

create or replace function app_hidden.tg_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists touch_updated_at on public.transactions;
create trigger touch_updated_at
  before update on public.transactions
  for each row execute function app_hidden.tg_touch_updated_at();

drop trigger if exists touch_updated_at on public.bills;
create trigger touch_updated_at
  before update on public.bills
  for each row execute function app_hidden.tg_touch_updated_at();

create table if not exists app_hidden.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor uuid,
  table_name text not null,
  row_id uuid,
  action text not null,
  old_row jsonb,
  new_row jsonb
);

create index if not exists idx_audit_log_table_row on app_hidden.audit_log(table_name, row_id);
create index if not exists idx_audit_log_at on app_hidden.audit_log(at);

create or replace function app_hidden.tg_audit()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  insert into app_hidden.audit_log (table_name, row_id, action, actor, old_row, new_row)
  values (
    tg_table_name,
    case when tg_op = 'DELETE' then old.id else new.id end,
    tg_op,
    auth.uid(),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['transactions','accounts','bills','debts','goals','budget_allocations']
  loop
    execute format('drop trigger if exists audit_changes on public.%I', t);
    execute format(
      'create trigger audit_changes after insert or update or delete on public.%I
       for each row execute function app_hidden.tg_audit()', t);
  end loop;
end $$;
