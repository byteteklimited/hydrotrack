-- HydroTrack — 0014: automatic SMS debt reminders.
--
-- Every morning, customers who owe money and are overdue get an SMS
-- through HydroTrack's Termii account (Edge Function
-- `send-debt-reminders`, called by the pg_cron job at the bottom).
--
-- Schedule (business rules agreed for this phase):
--   * first reminder once a customer still owes money 14 days after their
--     last payment (or, if they never paid, 14 days after their first
--     credit sale / opening balance);
--   * then every 7 days while they still owe;
--   * at most 4 reminders, counted from their last payment, so the
--     schedule starts again after they pay something;
--   * never twice on the same day;
--   * a failed send is retried the next day, up to 3 failures.
--
-- The selection rules and the message text live here, not in the Edge
-- Function, so the pgTAP suite can test them. The Edge Function only
-- sends what claim_due_debt_reminders hands it and reports the result.

-- =========================================================================
-- Organization bank details (printed in the reminder)
-- =========================================================================

alter table tenants
  add column bank_name text,
  add column bank_account_number text,
  add column bank_account_name text,
  add constraint tenants_bank_name_length check (char_length(bank_name) between 1 and 60),
  add constraint tenants_bank_account_number_nuban check (bank_account_number ~ '^\d{10}$'),
  add constraint tenants_bank_account_name_length check (char_length(bank_account_name) between 1 and 80),
  -- All three or none: a reminder with half a bank account is worse than none.
  add constraint tenants_bank_details_complete check (
    (bank_name is null and bank_account_number is null and bank_account_name is null)
    or (bank_name is not null and bank_account_number is not null and bank_account_name is not null)
  );

-- =========================================================================
-- Reminder log
-- =========================================================================

create type debt_reminder_status as enum ('sending', 'sent', 'failed');

create table debt_reminders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  customer_id uuid not null,
  channel text not null default 'sms' check (channel in ('sms', 'whatsapp')),
  phone text not null,
  message text not null,
  balance numeric(12, 2) not null,
  status debt_reminder_status not null default 'sending',
  provider_message_id text,
  error text,
  -- The factory's calendar day (Lagos), for "once a day" and spacing.
  sent_on date not null default (now() at time zone 'Africa/Lagos')::date,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (customer_id, sent_on),
  foreign key (tenant_id, customer_id) references customers (tenant_id, id) on delete cascade
);
create index debt_reminders_customer_idx on debt_reminders (tenant_id, customer_id, sent_on desc);

alter table debt_reminders enable row level security;

-- Members can read their own organization's reminders. Nobody writes
-- through the API: there are no insert/update/delete policies, only the
-- service-role functions below write.
create policy debt_reminders_select on debt_reminders
  for select to authenticated using (is_tenant_member(tenant_id));

-- =========================================================================
-- Message text
-- =========================================================================

-- Plain GSM characters only ("NGN", not "₦"): one non-GSM character turns
-- the whole SMS into Unicode, which costs 2-3x as much per message.
create function debt_reminder_message(
  p_organization text,
  p_customer text,
  p_balance numeric,
  p_bank_name text,
  p_account_number text,
  p_account_name text
)
returns text
language sql immutable
set search_path = ''
as $$
  select
    'Hello ' || split_part(btrim(p_customer), ' ', 1) || ', this is '
    || btrim(p_organization) || '. Your outstanding balance is NGN'
    || case when p_balance = trunc(p_balance)
         then to_char(p_balance, 'FM999,999,999,990')
         else to_char(p_balance, 'FM999,999,999,990.00') end
    || '. '
    || case when p_account_number is null
         then 'Please make a payment soon.'
         else 'Please pay to ' || p_bank_name || ' ' || p_account_number
              || ' (' || p_account_name || ').' end
    || ' Thank you.';
$$;

-- =========================================================================
-- Picking who is due (Edge Function only)
-- =========================================================================

-- Claims up to p_limit reminders due on p_today: inserts a 'sending' row
-- for each and returns what to send. Safe to run concurrently or more
-- than once a day: the (customer, day) unique key means a customer can
-- only ever be claimed once per day.
create function claim_due_debt_reminders(
  p_today date default (now() at time zone 'Africa/Lagos')::date,
  p_limit integer default 100
)
returns table (id uuid, phone text, message text)
language plpgsql
security definer set search_path = public
as $$
#variable_conflict use_column
declare
  c_overdue_days constant integer := 14;
  c_interval_days constant integer := 7;
  c_max_reminders constant integer := 4;
  c_max_failures constant integer := 3;
begin
  return query
  with owing as (
    select
      cu.id as customer_id,
      cu.tenant_id,
      cu.name,
      cu.balance,
      normalize_ng_phone(cu.phone) as phone,
      coalesce(
        cu.last_payment_date,
        (select min(le.date) from ledger_entries le
          where le.tenant_id = cu.tenant_id and le.customer_id = cu.id
            and le.type in ('sale', 'opening_balance'))
      ) as since
    from customers cu
    where cu.balance > 0
  ),
  due as (
    select o.*
    from owing o
    where o.since is not null
      -- A Nigerian mobile number: 234 + 10 digits.
      and o.phone ~ '^234\d{10}$'
      and p_today - o.since >= c_overdue_days
      and (
        select count(*) from debt_reminders r
        where r.customer_id = o.customer_id and r.sent_on > o.since
          and r.status <> 'failed'
      ) < c_max_reminders
      and coalesce((
        select p_today - max(r.sent_on) from debt_reminders r
        where r.customer_id = o.customer_id and r.sent_on > o.since
          and r.status <> 'failed'
      ), c_interval_days) >= c_interval_days
      -- Failed sends are retried the next day, but a number that keeps
      -- failing (wrong or switched off) is given up on.
      and (
        select count(*) from debt_reminders r
        where r.customer_id = o.customer_id and r.sent_on > o.since
          and r.status = 'failed'
      ) < c_max_failures
    order by o.tenant_id, o.customer_id
    limit p_limit
  ),
  claimed as (
    insert into debt_reminders as r (tenant_id, customer_id, phone, message, balance, sent_on)
    select
      d.tenant_id,
      d.customer_id,
      d.phone,
      debt_reminder_message(t.name, d.name, d.balance,
        t.bank_name, t.bank_account_number, t.bank_account_name),
      d.balance,
      p_today
    from due d
    join tenants t on t.id = d.tenant_id
    on conflict (customer_id, sent_on) do nothing
    returning r.id, r.phone, r.message
  )
  select claimed.id, claimed.phone, claimed.message from claimed;
end;
$$;

-- Records what happened to one claimed reminder.
create function finish_debt_reminder(
  p_id uuid,
  p_sent boolean,
  p_provider_message_id text default null,
  p_error text default null
)
returns void
language sql
security definer set search_path = public
as $$
  update debt_reminders
  set status = case when p_sent then 'sent' else 'failed' end::debt_reminder_status,
      provider_message_id = p_provider_message_id,
      error = left(p_error, 500)
  where id = p_id and status = 'sending';
$$;

revoke all on function debt_reminder_message(text, text, numeric, text, text, text) from public, anon, authenticated;
revoke all on function claim_due_debt_reminders(date, integer) from public, anon, authenticated;
revoke all on function finish_debt_reminder(uuid, boolean, text, text) from public, anon, authenticated;
grant execute on function claim_due_debt_reminders(date, integer) to service_role;
grant execute on function finish_debt_reminder(uuid, boolean, text, text) to service_role;

-- =========================================================================
-- Daily schedule
-- =========================================================================

-- Every 30 minutes from 08:00 to 10:30 Lagos time (07:00-09:30 UTC).
-- The first run sends everything due; later runs only pick up anything a
-- run couldn't finish (a large backlog, a provider outage).
--
-- The project URL and the shared secret come from Vault, so neither is in
-- git. They are created once per project (see README, "Debt reminders"):
--   vault secret 'project_url'                -> https://<ref>.supabase.co
--   vault secret 'debt_reminders_cron_secret' -> same value as the Edge
--                                                Function's
--                                                DEBT_REMINDERS_CRON_SECRET
-- Without them the job's request simply fails and nothing is sent.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'send-debt-reminders',
  '*/30 7-9 * * *',
  $job$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/send-debt-reminders',
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
