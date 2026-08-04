-- Migration: create_email_waitlist
-- Tabla de captura de emails de la landing de marketing (/get).
-- Waitlist Android + newsletter. Insert anónimo permitido (form público).
-- Lectura SOLO service_role (no anon, no authenticated) — la lista no se expone por API pública.
-- Aplicada vía MCP apply_migration el 2026-05-30.

create table if not exists public.email_waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  lang text,
  source text default 'landing',
  user_agent text,
  created_at timestamptz not null default now()
);

-- Dedup: un email una sola vez (case-insensitive). Un re-submit del mismo email da 409.
create unique index if not exists email_waitlist_email_unique
  on public.email_waitlist (lower(email));

comment on table public.email_waitlist is
  'Emails capturados desde la landing de marketing (/get). Insert anónimo, lectura solo service_role.';

alter table public.email_waitlist enable row level security;

-- Política: anon/authenticated pueden INSERTAR (con validación de formato).
-- No hay políticas de SELECT/UPDATE/DELETE => RLS las deniega por API pública.
drop policy if exists "anon can insert waitlist email" on public.email_waitlist;
create policy "anon can insert waitlist email"
  on public.email_waitlist
  for insert
  to anon, authenticated
  with check (
    char_length(email) between 5 and 320
    and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    and (lang is null or lang in ('es','en','pt'))
  );
