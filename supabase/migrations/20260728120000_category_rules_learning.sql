-- Fase 4.3(a): categorización automática que APRENDE, server-side.
--
-- Antes: el keyword-map vivía en el cliente (`CATEGORY_KEYWORDS` en la PWA) y
-- no aprendía nada — las mismas palabras genéricas para todos los usuarios, en
-- todos los países, para siempre. Cada cliente (iOS/web/wallets) tenía que
-- duplicar esa lógica.
--
-- Ahora: cada hogar construye SUS propias reglas a partir de lo que realmente
-- categoriza. Es la escuela "IA invisible" de Copilot: no hay chat, hay una
-- app que deja de preguntar lo que ya sabe.
--
-- DISEÑO
--   * `normalize_note()` — minúsculas, sin acentos ni dígitos, espacios
--     colapsados. IMMUTABLE (invoca `unaccent` con diccionario explícito) para
--     poder indexarla.
--   * `category_rules` — (household_id, pattern) único, con RLS por hogar.
--   * Trigger `learn_category` en `transactions` — cada alta/edición con nota
--     refuerza, crea o CORRIGE la regla. Es SECURITY DEFINER para no depender
--     de las policies del caller.
--   * `suggest_category()` — SECURITY INVOKER: la RLS de `category_rules`
--     garantiza que un hogar no vea reglas de otro (verificado en prod).
--
-- DECISIONES QUE IMPORTAN
--   1. Una CORRECCIÓN gana sobre el histórico: si el usuario recategoriza un
--      comercio, la regla cambia YA y `hits` vuelve a 1, en vez de tener que
--      superar en cantidad a las viejas. Recategorizar y que la app siga
--      sugiriendo lo anterior se siente roto.
--   2. `source = 'manual'` nunca se pisa (regla fijada por el usuario).
--   3. Sembrado desde el historial propio de cada hogar: la feature arranca
--      útil el día uno, sin período de entrenamiento.

create extension if not exists unaccent with schema extensions;

create or replace function app_hidden.normalize_note(p text)
returns text language sql immutable
set search_path to 'extensions', 'public'
as $$
  select nullif(
    btrim(regexp_replace(
      regexp_replace(
        lower(extensions.unaccent('extensions.unaccent', coalesce(p, ''))),
        '[^a-z ]+', ' ', 'g'),
      ' {2,}', ' ', 'g')),
    '')
$$;

create table if not exists public.category_rules (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  pattern text not null,
  category text not null,
  subcategory text,
  hits int not null default 1,
  source text not null default 'learned' check (source in ('learned','manual','seed')),
  updated_at timestamptz not null default now(),
  unique (household_id, pattern)
);

create index if not exists idx_category_rules_household on public.category_rules(household_id);

alter table public.category_rules enable row level security;

drop policy if exists category_rules_select on public.category_rules;
create policy category_rules_select on public.category_rules
  for select using (app_hidden.is_household_member(household_id));
drop policy if exists category_rules_insert on public.category_rules;
create policy category_rules_insert on public.category_rules
  for insert with check (app_hidden.is_household_member(household_id));
drop policy if exists category_rules_update on public.category_rules;
create policy category_rules_update on public.category_rules
  for update using (app_hidden.is_household_member(household_id))
  with check (app_hidden.is_household_member(household_id));
drop policy if exists category_rules_delete on public.category_rules;
create policy category_rules_delete on public.category_rules
  for delete using (app_hidden.is_household_member(household_id));

create or replace function app_hidden.tg_learn_category()
returns trigger language plpgsql security definer
set search_path to 'public', 'app_hidden'
as $$
declare norm text;
begin
  norm := app_hidden.normalize_note(new.note);
  if norm is null or length(norm) < 3 or coalesce(new.category,'') = '' then
    return new;
  end if;

  insert into public.category_rules (household_id, pattern, category, subcategory, hits, source)
  values (new.household_id, norm, new.category, nullif(new.subcategory,''), 1, 'learned')
  on conflict (household_id, pattern) do update
    set category = case
          when public.category_rules.category <> excluded.category then excluded.category
          else public.category_rules.category end,
        subcategory = case
          when public.category_rules.category <> excluded.category then excluded.subcategory
          else coalesce(excluded.subcategory, public.category_rules.subcategory) end,
        hits = case
          when public.category_rules.category <> excluded.category then 1
          else public.category_rules.hits + 1 end,
        updated_at = now()
    where public.category_rules.source <> 'manual';
  return new;
end $$;

drop trigger if exists learn_category on public.transactions;
create trigger learn_category
  after insert or update of category, subcategory, note on public.transactions
  for each row execute function app_hidden.tg_learn_category();

create or replace function public.suggest_category(p_household uuid, p_note text)
returns table(category text, subcategory text, confidence numeric, matched_pattern text)
language sql stable
set search_path to 'public', 'app_hidden'
as $$
  with q as (select app_hidden.normalize_note(p_note) as n)
  select r.category, r.subcategory,
         least(0.99, round(
           (case when r.pattern = q.n then 0.70 else 0.45 end)
           + least(0.29, r.hits::numeric / 20), 2))::numeric as confidence,
         r.pattern
  from public.category_rules r, q
  where q.n is not null
    and r.household_id = p_household
    and (r.pattern = q.n or q.n like '%' || r.pattern || '%')
  order by (r.pattern = q.n) desc, length(r.pattern) desc, r.hits desc
  limit 3
$$;

-- Sembrado desde el historial de cada hogar (categoría más usada por comercio).
insert into public.category_rules (household_id, pattern, category, subcategory, hits, source)
select household_id, norm, category, subcategory, usos, 'learned'
from (
  select t.household_id,
         app_hidden.normalize_note(t.note) as norm,
         t.category,
         nullif(t.subcategory,'') as subcategory,
         count(*) as usos,
         row_number() over (
           partition by t.household_id, app_hidden.normalize_note(t.note)
           order by count(*) desc, max(t.created_at) desc) as rk
  from public.transactions t
  where app_hidden.normalize_note(t.note) is not null
    and length(app_hidden.normalize_note(t.note)) >= 3
    and coalesce(t.category,'') <> ''
  group by 1,2,3,4
) ranked
where rk = 1
on conflict (household_id, pattern) do nothing;
