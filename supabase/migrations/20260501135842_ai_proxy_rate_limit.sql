-- Recuperada del ledger de producción el 2026-08-03.
--
-- Estaba aplicada en prod pero SIN archivo en el repo. Ver `leccion-drift-migraciones-supabase`.
-- El SQL va verbatim como corrió en producción; no se reformatea ni se "mejora".

-- Rate limiting para el endpoint ai-proxy.
create table if not exists public.ai_usage_daily (
    user_id uuid not null references auth.users(id) on delete cascade,
    day date not null default current_date,
    request_count integer not null default 0,
    input_tokens bigint not null default 0,
    output_tokens bigint not null default 0,
    cache_read_tokens bigint not null default 0,
    cache_write_tokens bigint not null default 0,
    last_request_at timestamptz not null default now(),
    primary key (user_id, day)
);

create index if not exists ai_usage_daily_user_day_idx
    on public.ai_usage_daily (user_id, day desc);

alter table public.ai_usage_daily enable row level security;

drop policy if exists ai_usage_daily_select_own on public.ai_usage_daily;
create policy ai_usage_daily_select_own
    on public.ai_usage_daily
    for select
    using ((select auth.uid()) = user_id);

create or replace function public.ai_check_and_increment_quota(
    p_user_id uuid,
    p_daily_limit int default 50,
    p_monthly_limit int default 1000,
    p_input_tokens int default 0,
    p_output_tokens int default 0,
    p_cache_read_tokens int default 0,
    p_cache_write_tokens int default 0
) returns table(allowed boolean, daily_used int, monthly_used int)
language plpgsql
security definer
set search_path = public
as $$
declare
    v_daily_used int;
    v_monthly_used int;
    v_month_start date := date_trunc('month', current_date)::date;
begin
    select coalesce(sum(request_count), 0)
    into v_monthly_used
    from public.ai_usage_daily
    where user_id = p_user_id
      and day >= v_month_start;

    select coalesce(request_count, 0)
    into v_daily_used
    from public.ai_usage_daily
    where user_id = p_user_id
      and day = current_date;

    if v_daily_used >= p_daily_limit or v_monthly_used >= p_monthly_limit then
        return query select false, v_daily_used, v_monthly_used;
        return;
    end if;

    insert into public.ai_usage_daily (
        user_id, day, request_count,
        input_tokens, output_tokens,
        cache_read_tokens, cache_write_tokens,
        last_request_at
    )
    values (
        p_user_id, current_date, 1,
        p_input_tokens, p_output_tokens,
        p_cache_read_tokens, p_cache_write_tokens,
        now()
    )
    on conflict (user_id, day) do update
    set request_count = ai_usage_daily.request_count + 1,
        input_tokens = ai_usage_daily.input_tokens + p_input_tokens,
        output_tokens = ai_usage_daily.output_tokens + p_output_tokens,
        cache_read_tokens = ai_usage_daily.cache_read_tokens + p_cache_read_tokens,
        cache_write_tokens = ai_usage_daily.cache_write_tokens + p_cache_write_tokens,
        last_request_at = now();

    return query select true, v_daily_used + 1, v_monthly_used + 1;
end;
$$;

grant execute on function public.ai_check_and_increment_quota
    to authenticated, service_role;
