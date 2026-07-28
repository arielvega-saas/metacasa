-- Fase 2.12: motor de scheduling (habilita recordatorios de bills, recurring
-- transactions server-side, limpieza de huérfanos, FX automático — Fase 3).
-- pg_cron: jobs SQL programados. pg_net: HTTP requests desde SQL (para que
-- los jobs llamen edge functions, p.ej. push notifications).

create extension if not exists pg_cron;

-- pg_net va en el schema `extensions` (no en public): el advisor de Supabase
-- marca WARN por extensiones en public. OJO: pg_net NO soporta ALTER
-- EXTENSION SET SCHEMA — hay que crearla directamente en el schema correcto.
create schema if not exists extensions;
create extension if not exists pg_net with schema extensions;
