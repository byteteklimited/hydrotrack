-- HydroTrack — 0018: the organization's business profile.
--
-- Address, phone, email, CAC/RC number and NAFDAC number (all optional),
-- shown on receipts and report exports. The logo already had a column
-- (logo_path) and private storage (tenant-files/<tenant id>/...); the app
-- now uploads it. Owner/Admin edit the profile (tenants_update policy).
-- The reminder SMS now gives the business phone number for questions.

alter table tenants
  add column address text,
  add column phone text,
  add column email text,
  add column rc_number text,
  add column nafdac_number text,
  add constraint tenants_address_length check (char_length(address) between 1 and 200),
  add constraint tenants_phone_length check (char_length(phone) between 7 and 20),
  add constraint tenants_email_format check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  add constraint tenants_rc_number_length check (char_length(rc_number) between 1 and 30),
  add constraint tenants_nafdac_number_length check (char_length(nafdac_number) between 1 and 30),
  add constraint tenants_logo_path_own_folder check (
    logo_path is null or storage_path_tenant(logo_path) = id
  );

drop function debt_reminder_message(text, text, numeric, text, text, text);

-- Plain GSM characters only ("NGN", not "₦"), as before; the business
-- phone, when set, is added for questions.
create function debt_reminder_message(
  p_organization text,
  p_customer text,
  p_balance numeric,
  p_bank_name text,
  p_account_number text,
  p_account_name text,
  p_phone text default null
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
    || case when p_phone is null then '' else ' Questions? Call ' || p_phone || '.' end
    || ' Thank you.';
$$;

revoke all on function debt_reminder_message(text, text, numeric, text, text, text, text)
  from public, anon, authenticated;

create or replace function claim_due_debt_reminders(
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
        t.bank_name, t.bank_account_number, t.bank_account_name, t.phone),
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

