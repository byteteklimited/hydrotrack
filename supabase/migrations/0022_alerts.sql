-- HydroTrack — 0022: alerts for owners (agreed: daily closing summary at
-- 8 pm and low stock; in the app, plus SMS once Termii is set up).
--
-- generate_alerts() runs every 15 minutes (pg_cron, below) and needs no
-- secrets:
--   * low stock: an item at or below its reorder level, at most once a
--     day per item;
--   * daily summary: from 20:00 Lagos time, once a day per organization —
--     bags produced and sold, cash and transfers collected, money outside,
--     cash count shortages.
-- Owners see them in the app (bell on Home). The `send-alerts` Edge
-- Function texts new ones to the business phone in the organization's
-- profile through Termii (same cron secret as debt reminders); without
-- Termii it does nothing, and alerts older than 2 hours are never texted
-- (so switching SMS on later doesn't send a backlog).

create table alerts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  kind text not null check (kind in ('daily_summary', 'low_stock')),
  title text not null,
  body text not null,
  item_id uuid,
  for_date date not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  sms_status text not null default 'pending'
    check (sms_status in ('pending', 'sending', 'sent', 'failed', 'skipped')),
  sms_error text,
  unique (tenant_id, id),
  foreign key (tenant_id, item_id) references stock_items (tenant_id, id) on delete cascade
);
create unique index alerts_once_a_day on alerts (tenant_id, kind, for_date, coalesce(item_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index alerts_tenant_recent_idx on alerts (tenant_id, created_at desc);

alter table alerts enable row level security;
create policy alerts_select on alerts
  for select to authenticated
  using (has_tenant_role(tenant_id, array['owner']::staff_role[]));

-- Owners mark their organization's alerts read.
create function mark_alerts_read(p_tenant_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['owner']::staff_role[], 'read alerts');
  update alerts set read_at = now() where tenant_id = p_tenant_id and read_at is null;
end;
$$;

-- The day's summary text for one organization (plain characters: it may
-- go out by SMS).
create function daily_summary_text(p_tenant_id uuid, p_day date)
returns text
language sql stable
security definer set search_path = public
as $$
  with day as (
    select (p_day::timestamp at time zone 'Africa/Lagos') as starts,
           ((p_day + 1)::timestamp at time zone 'Africa/Lagos') as ends
  )
  select format(
    'Today: %s bags produced, %s bags sold. Collected NGN%s cash and NGN%s by transfer. Money outside: NGN%s.%s',
    coalesce((select sum(quantity_produced) from production_runs where tenant_id = p_tenant_id and date = p_day), 0),
    coalesce((select sum(l.quantity) from sale_lines l join sales s on s.tenant_id = l.tenant_id and s.id = l.sale_id, day
              where s.tenant_id = p_tenant_id and s.voided_at is null
                and s.date_time >= day.starts and s.date_time < day.ends), 0),
    to_char(coalesce((select sum(amount) from cash_entries, day where tenant_id = p_tenant_id
              and direction = 'money_in' and method = 'cash'
              and created_at >= day.starts and created_at < day.ends), 0), 'FM999,999,999,990'),
    to_char(coalesce((select sum(amount) from cash_entries, day where tenant_id = p_tenant_id
              and direction = 'money_in' and method <> 'cash'
              and created_at >= day.starts and created_at < day.ends), 0), 'FM999,999,999,990'),
    to_char(coalesce((select sum(balance) from customers where tenant_id = p_tenant_id and balance > 0), 0), 'FM999,999,999,990'),
    coalesce((select format(' Cash counts short: %s (NGN%s).', count(*), to_char(-sum(difference), 'FM999,999,999,990'))
              from cash_counts, day where tenant_id = p_tenant_id and difference < 0
                and counted_at >= day.starts and counted_at < day.ends
              having count(*) > 0), '')
  );
$$;

-- Creates any alerts due at p_now (idempotent: once a day per alert).
create function generate_alerts(p_now timestamptz default now())
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_today date := (p_now at time zone 'Africa/Lagos')::date;
  v_count integer := 0;
  v_added integer;
begin
  insert into alerts (tenant_id, kind, title, body, item_id, for_date)
  select si.tenant_id, 'low_stock',
    'Low stock: ' || si.name,
    format('%s is down to %s %s (reorder at %s).', si.name, si.quantity_on_hand, si.unit, si.reorder_level),
    si.id, v_today
  from stock_items si
  where si.reorder_level > 0 and si.quantity_on_hand <= si.reorder_level
  on conflict do nothing;
  get diagnostics v_added = row_count;
  v_count := v_count + v_added;

  if extract(hour from p_now at time zone 'Africa/Lagos') >= 20 then
    insert into alerts (tenant_id, kind, title, body, for_date)
    select t.id, 'daily_summary', 'Daily summary · ' || to_char(v_today, 'DD Mon'),
      daily_summary_text(t.id, v_today), v_today
    from tenants t
    on conflict do nothing;
    get diagnostics v_added = row_count;
    v_count := v_count + v_added;
  end if;

  return v_count;
end;
$$;

-- send-alerts Edge Function: new alerts to text, with the business phone
-- (234XXXXXXXXXX). Older ones, or ones with no valid phone, are skipped.
create function claim_alert_sms(p_limit integer default 100)
returns table (id uuid, phone text, message text)
language plpgsql
security definer set search_path = public
as $$
#variable_conflict use_column
begin
  update alerts a set sms_status = 'skipped'
  where a.sms_status = 'pending'
    and (a.created_at < now() - interval '2 hours'
         or coalesce(normalize_ng_phone((select t.phone from tenants t where t.id = a.tenant_id)), '') !~ '^234\d{10}$');

  return query
  with picked as (
    select a.id from alerts a
    where a.sms_status = 'pending'
    order by a.created_at
    limit p_limit
    for update skip locked
  )
  update alerts a set sms_status = 'sending'
  from picked, tenants t
  where a.id = picked.id and t.id = a.tenant_id
  returning a.id, normalize_ng_phone(t.phone), t.name || ': ' || a.title || '. ' || a.body;
end;
$$;

create function finish_alert_sms(p_id uuid, p_sent boolean, p_error text default null)
returns void
language sql
security definer set search_path = public
as $$
  update alerts set sms_status = case when p_sent then 'sent' else 'failed' end,
    sms_error = left(p_error, 500)
  where id = p_id and sms_status = 'sending';
$$;

revoke all on function daily_summary_text(uuid, date) from public, anon, authenticated;
revoke all on function generate_alerts(timestamptz) from public, anon, authenticated;
revoke all on function claim_alert_sms(integer) from public, anon, authenticated;
revoke all on function finish_alert_sms(uuid, boolean, text) from public, anon, authenticated;
grant execute on function claim_alert_sms(integer) to service_role;
grant execute on function finish_alert_sms(uuid, boolean, text) to service_role;
revoke all on function mark_alerts_read(uuid) from public, anon;
grant execute on function mark_alerts_read(uuid) to authenticated;

-- In-app alerts: no secrets needed.
select cron.schedule('generate-alerts', '*/15 * * * *', $job$ select public.generate_alerts(); $job$);

-- SMS copies: same Vault secrets as debt reminders (README).
select cron.schedule(
  'send-alerts',
  '2-59/15 * * * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/send-alerts',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret',
      (select decrypted_secret from vault.decrypted_secrets where name = 'debt_reminders_cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $job$
);
