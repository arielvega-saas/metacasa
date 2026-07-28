-- Dedupe de webhooks de RevenueCat (plan Fase 2.11 / audit S6).
--
-- RevenueCat reintenta webhooks ante timeouts o 5xx. `subscriptions` es
-- append-only y cada reintento creaba filas duplicadas (el trigger de
-- entitlements es idempotente, así que el efecto era ruido en la tabla y
-- auditoría sucia, no un bug de acceso).
--
-- Fix: columna real `event_id` (antes solo vivía en metadata JSONB) +
-- UNIQUE (event_id, entitlement_id) — un evento genera una fila POR
-- entitlement, por eso el unique es compuesto. NULL permitido (filas
-- históricas sin event_id; NULL nunca colisiona en unique compuesto).
-- El webhook pasa a upsert con ignoreDuplicates sobre ese par.

alter table public.subscriptions add column if not exists event_id text;

-- Backfill desde metadata (todas las filas nuevas ya lo traen).
update public.subscriptions
set event_id = metadata->>'event_id'
where event_id is null and metadata->>'event_id' is not null;

-- Dedupe defensivo de filas históricas antes del unique (conserva la más
-- antigua por par).
delete from public.subscriptions s
using public.subscriptions d
where s.event_id is not null
  and s.event_id = d.event_id
  and s.entitlement_id = d.entitlement_id
  and (s.created_at > d.created_at
       or (s.created_at = d.created_at and s.id > d.id));

create unique index if not exists uq_subscriptions_event_entitlement
  on public.subscriptions (event_id, entitlement_id);
