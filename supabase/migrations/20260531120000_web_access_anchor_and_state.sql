-- Ancla server-side del trial de 7 días para acceso WEB.
-- (El gate de iOS es client-side via StoreKit AppTransaction; la web no puede
--  usar StoreKit, así que necesita su propia fuente de verdad para el trial.)
create table if not exists public.user_access_anchors (
  user_id uuid primary key references auth.users(id) on delete cascade,
  trial_started_at timestamptz not null default now(),
  ios_original_purchase_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.user_access_anchors is
  'Ancla del trial de 7 dias para acceso web. El gate de iOS es client-side (StoreKit). web_access_state() la usa como fuente de verdad del trial; iOS puede empujar ios_original_purchase_date para alinear con el trial real de Apple.';

alter table public.user_access_anchors enable row level security;

-- RLS: cada usuario solo su propia ancla. (select auth.uid()) por performance.
drop policy if exists "anchor_select_own" on public.user_access_anchors;
create policy "anchor_select_own" on public.user_access_anchors
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "anchor_insert_own" on public.user_access_anchors;
create policy "anchor_insert_own" on public.user_access_anchors
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "anchor_update_own" on public.user_access_anchors;
create policy "anchor_update_own" on public.user_access_anchors
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- RPC: estado de acceso web del usuario actual. Lazy-init del trial en el 1er acceso.
create or replace function public.web_access_state()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := (select auth.uid());
  v_trial_start timestamptz;
  v_ios_anchor timestamptz;
  v_anchor timestamptz;
  v_trial_ends timestamptz;
  v_has_sub boolean;
  v_state text;
begin
  if uid is null then
    return jsonb_build_object('state', 'locked', 'reason', 'no_session');
  end if;

  insert into public.user_access_anchors (user_id)
  values (uid)
  on conflict (user_id) do nothing;

  select trial_started_at, ios_original_purchase_date
    into v_trial_start, v_ios_anchor
  from public.user_access_anchors
  where user_id = uid;

  v_has_sub := public.has_active_entitlement('premium');

  v_anchor := least(coalesce(v_ios_anchor, v_trial_start), v_trial_start);
  v_trial_ends := v_anchor + interval '7 days';

  if v_has_sub then
    v_state := 'active';
  elsif now() < v_trial_ends then
    v_state := 'trial';
  else
    v_state := 'locked';
  end if;

  return jsonb_build_object(
    'state', v_state,
    'trial_ends_at', v_trial_ends,
    'has_subscription', v_has_sub,
    'in_trial', (now() < v_trial_ends)
  );
end;
$$;

revoke all on function public.web_access_state() from public, anon;
grant execute on function public.web_access_state() to authenticated;
