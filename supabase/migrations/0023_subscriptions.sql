-- HydroTrack — 0023: subscriptions and the platform admin console
-- (agreed rules).
--
--   * One plan: a single monthly price, set by the platform admin.
--   * Payment is manual: the organization pays by transfer, the platform
--     admin records it ("Record payment"), which extends paid-until.
--   * New organizations get a free trial (14 days by default). When the
--     trial or paid time ends there is a grace period (7 days by default);
--     after that the organization is read-only: everyone can still sign in,
--     view and export, but nothing new can be recorded, edited or deleted
--     until it pays. The platform admin can also suspend an organization
--     (read-only straight away) or give free days.
--   * Records made offline while the organization could still record are
--     accepted whenever they sync. Records made offline after that are
--     kept on the device (refused) and go through once it pays.
--   * Platform admins (only the HydroTrack operator for now) see every
--     organization through the admin_* functions below; they get no
--     access to any organization's own data through RLS.
--
-- The read-only rule is one trigger on every business table
-- (guard_subscription), so every write path — app queries, RPCs, offline
-- sync — gets it. Background jobs (no signed-in user) are never blocked.
-- Not guarded: sign-in and offline sign-in data, PIN resets, devices and
-- their sync log, alerts, debt reminders, the audit log, and membership
-- itself (owners can still deactivate or remove staff while read-only).

-- =========================================================================
-- Tables
-- =========================================================================

create table platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table platform_admins enable row level security;

-- One row: the plan.
create table platform_settings (
  id boolean primary key default true check (id),
  monthly_price numeric(12, 2) check (monthly_price >= 0),
  trial_days integer not null default 14 check (trial_days between 0 and 90),
  grace_days integer not null default 7 check (grace_days between 0 and 30),
  -- How to pay (bank details etc.), shown to owners.
  payment_instructions text,
  updated_at timestamptz not null default now()
);
insert into platform_settings default values;
alter table platform_settings enable row level security;

create table tenant_subscriptions (
  tenant_id uuid primary key references tenants (id) on delete cascade,
  trial_ends_at timestamptz not null,
  paid_until timestamptz,
  suspended_at timestamptz,
  suspended_reason text,
  updated_at timestamptz not null default now()
);
alter table tenant_subscriptions enable row level security;

create table subscription_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  kind text not null check (kind in ('payment', 'free_days', 'suspended', 'resumed')),
  amount numeric(12, 2) check (amount >= 0),
  months integer check (months > 0),
  days integer check (days > 0),
  note text,
  -- Where the organization's paid (or trial) time ends after this event.
  ends_at timestamptz,
  recorded_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);
create index subscription_events_tenant_idx on subscription_events (tenant_id, created_at desc);
alter table subscription_events enable row level security;

-- =========================================================================
-- Helpers
-- =========================================================================

create function is_platform_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.platform_admins where user_id = (select auth.uid()));
$$;

create function require_platform_admin()
returns void
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Only HydroTrack admins can do this' using errcode = '42501';
  end if;
end;
$$;

-- Owners see their organization's payments and free days.
create policy subscription_events_select on subscription_events
  for select to authenticated
  using (
    is_platform_admin()
    or (kind in ('payment', 'free_days') and has_tenant_role(tenant_id, array['owner']::staff_role[]))
  );

-- When the organization's paid or trial time ends (before grace).
create function subscription_ends_at(s tenant_subscriptions)
returns timestamptz
language sql immutable
as $$
  select greatest(s.trial_ends_at, coalesce(s.paid_until, s.trial_ends_at));
$$;

-- When it becomes read-only (end + grace).
create function subscription_access_ends_at(s tenant_subscriptions)
returns timestamptz
language sql stable security definer set search_path = public
as $$
  select subscription_ends_at(s) + make_interval(days => (select grace_days from platform_settings));
$$;

-- Whether the organization may record right now (or, for a record made
-- offline, whether it could at the time it was made).
create function subscription_allows_recording(p_tenant_id uuid)
returns boolean
language plpgsql stable security definer set search_path = public
as $$
declare
  s tenant_subscriptions;
  v_end timestamptz;
begin
  select * into s from tenant_subscriptions where tenant_id = p_tenant_id;
  if not found then
    return true;  -- set up by the tenants trigger below; never missing in practice
  end if;
  v_end := subscription_access_ends_at(s);
  if s.suspended_at is null and now() < v_end then
    return true;
  end if;
  if is_offline_sync() then
    return effective_now() < v_end
      and (s.suspended_at is null or effective_now() < s.suspended_at);
  end if;
  return false;
end;
$$;

-- Status for the app and the admin console.
create function subscription_summary(p_tenant_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  s tenant_subscriptions;
  p platform_settings;
  v_ends timestamptz;
  v_access_ends timestamptz;
  v_status text;
begin
  select * into s from tenant_subscriptions where tenant_id = p_tenant_id;
  if not found then
    return null;
  end if;
  select * into p from platform_settings;
  v_ends := subscription_ends_at(s);
  v_access_ends := subscription_access_ends_at(s);
  v_status := case
    when s.suspended_at is not null then 'suspended'
    when now() < s.trial_ends_at and (s.paid_until is null or s.paid_until <= s.trial_ends_at) then 'trial'
    when now() < v_ends then 'active'
    when now() < v_access_ends then 'grace'
    else 'expired'
  end;
  return jsonb_build_object(
    'status', v_status,
    'trial_ends_at', s.trial_ends_at,
    'paid_until', s.paid_until,
    'ends_at', v_ends,
    'access_ends_at', v_access_ends,
    'suspended_at', s.suspended_at,
    'suspended_reason', s.suspended_reason,
    'can_record', v_status not in ('suspended', 'expired'),
    'monthly_price', p.monthly_price,
    'payment_instructions', p.payment_instructions
  );
end;
$$;

-- =========================================================================
-- Read-only once access ends
-- =========================================================================

create function guard_subscription()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_row jsonb := to_jsonb(coalesce(new, old));
  v_tenant uuid;
begin
  -- Background jobs and the service role act for no one; never blocked.
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  v_tenant := case when tg_table_name = 'tenants' then (v_row ->> 'id')::uuid
                   else (v_row ->> 'tenant_id')::uuid end;
  if not subscription_allows_recording(v_tenant) then
    raise exception
      'This organization''s subscription has ended, so nothing new can be recorded or changed. You can still view and export records. The owner can renew it under Organization → Subscription.'
      using errcode = 'P0001', hint = 'subscription_ended';
  end if;
  return coalesce(new, old);
end;
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'tenants', 'tenant_invitations',
    'products', 'customers', 'drivers', 'vehicles',
    'stock_items', 'stock_batches', 'stock_movements', 'production_recipes',
    'production_runs', 'sales', 'sale_lines', 'ledger_entries', 'cash_entries',
    'expenses', 'load_outs', 'cash_counts',
    'suppliers', 'purchases', 'purchase_lines', 'supplier_ledger'
  ]
  loop
    execute format(
      'create trigger guard_subscription before insert or update or delete on %I
         for each row execute function guard_subscription()', v_table);
  end loop;
end;
$$;

-- Every organization starts on a trial.
create function start_trial()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into tenant_subscriptions (tenant_id, trial_ends_at)
  values (new.id, now() + make_interval(days => (select trial_days from platform_settings)))
  on conflict (tenant_id) do nothing;
  return new;
end;
$$;

create trigger start_trial after insert on tenants
  for each row execute function start_trial();

-- Organizations that exist already start their trial now.
insert into tenant_subscriptions (tenant_id, trial_ends_at)
select id, now() + interval '14 days' from tenants
on conflict (tenant_id) do nothing;

-- =========================================================================
-- For members
-- =========================================================================

-- Any active member: drives the "subscription ended" banner; owners also
-- see the price and how to pay.
create function my_subscription(p_tenant_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
begin
  if p_tenant_id is null or not is_tenant_member(p_tenant_id) then
    raise exception 'Not authorized to view this subscription' using errcode = '42501';
  end if;
  return subscription_summary(p_tenant_id);
end;
$$;

-- device-sync: the same, for a set-up device.
create function device_subscription(p_device_key text)
returns jsonb
language sql stable security definer set search_path = public
as $$
  select subscription_summary((device_for_key(p_device_key)).tenant_id);
$$;

-- =========================================================================
-- Admin console
-- =========================================================================

create function admin_organizations()
returns table (
  id uuid,
  name text,
  created_at timestamptz,
  business_phone text,
  owner_name text,
  owner_phone text,
  owner_email text,
  staff_count integer,
  last_activity_at timestamptz,
  subscription jsonb
)
language plpgsql stable security definer set search_path = public
as $$
#variable_conflict use_column
begin
  perform require_platform_admin();
  return query
  select t.id, t.name, t.created_at, t.phone,
    o.full_name, o.phone, o.email,
    (select count(*)::integer from tenant_members m where m.tenant_id = t.id and m.is_active),
    greatest(
      (select max(s.date_time) from sales s where s.tenant_id = t.id),
      (select max(r.recorded_at) from production_runs r where r.tenant_id = t.id),
      (select max(c.created_at) from cash_entries c where c.tenant_id = t.id)
    ),
    subscription_summary(t.id)
  from tenants t
  left join lateral (
    select p.full_name, p.phone, p.email
    from tenant_members m join profiles p on p.id = m.user_id
    where m.tenant_id = t.id and m.role = 'owner'
    order by m.joined_at
    limit 1
  ) o on true
  order by t.created_at desc;
end;
$$;

create function admin_subscription_events(p_tenant_id uuid)
returns setof subscription_events
language plpgsql stable security definer set search_path = public
as $$
begin
  perform require_platform_admin();
  return query
  select * from subscription_events where tenant_id = p_tenant_id order by created_at desc;
end;
$$;

create function admin_record_payment(p_tenant_id uuid, p_amount numeric, p_months integer, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  s tenant_subscriptions;
  v_until timestamptz;
begin
  perform require_platform_admin();
  if p_amount is null or p_amount < 0 then
    raise exception 'Enter the amount received';
  end if;
  if p_months is null or p_months not between 1 and 24 then
    raise exception 'Months paid for must be between 1 and 24';
  end if;
  select * into s from tenant_subscriptions where tenant_id = p_tenant_id for update;
  if not found then
    raise exception 'Organization not found';
  end if;
  -- Paid time starts after the trial or previous paid time, or today if
  -- those have run out.
  v_until := greatest(now(), s.trial_ends_at, coalesce(s.paid_until, '-infinity'))
    + make_interval(months => p_months);
  update tenant_subscriptions set paid_until = v_until, updated_at = now() where tenant_id = p_tenant_id;
  insert into subscription_events (tenant_id, kind, amount, months, note, ends_at, recorded_by)
  values (p_tenant_id, 'payment', p_amount, p_months, nullif(btrim(p_note), ''), v_until, auth.uid());
  return subscription_summary(p_tenant_id);
end;
$$;

-- Adds days to the trial while still on it, otherwise to the paid time.
create function admin_add_free_days(p_tenant_id uuid, p_days integer, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  s tenant_subscriptions;
  v_until timestamptz;
begin
  perform require_platform_admin();
  if p_days is null or p_days not between 1 and 365 then
    raise exception 'Free days must be between 1 and 365';
  end if;
  select * into s from tenant_subscriptions where tenant_id = p_tenant_id for update;
  if not found then
    raise exception 'Organization not found';
  end if;
  if s.paid_until is null or s.paid_until <= s.trial_ends_at then
    v_until := greatest(now(), s.trial_ends_at) + make_interval(days => p_days);
    update tenant_subscriptions set trial_ends_at = v_until, updated_at = now() where tenant_id = p_tenant_id;
  else
    v_until := greatest(now(), s.paid_until) + make_interval(days => p_days);
    update tenant_subscriptions set paid_until = v_until, updated_at = now() where tenant_id = p_tenant_id;
  end if;
  insert into subscription_events (tenant_id, kind, days, note, ends_at, recorded_by)
  values (p_tenant_id, 'free_days', p_days, nullif(btrim(p_note), ''), v_until, auth.uid());
  return subscription_summary(p_tenant_id);
end;
$$;

create function admin_set_suspended(p_tenant_id uuid, p_suspended boolean, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  s tenant_subscriptions;
begin
  perform require_platform_admin();
  select * into s from tenant_subscriptions where tenant_id = p_tenant_id for update;
  if not found then
    raise exception 'Organization not found';
  end if;
  if p_suspended then
    if s.suspended_at is not null then
      raise exception 'This organization is already suspended';
    end if;
    if nullif(btrim(p_reason), '') is null then
      raise exception 'Give a reason for suspending (the organization sees it)';
    end if;
    update tenant_subscriptions
    set suspended_at = now(), suspended_reason = btrim(p_reason), updated_at = now()
    where tenant_id = p_tenant_id;
  else
    if s.suspended_at is null then
      raise exception 'This organization is not suspended';
    end if;
    update tenant_subscriptions
    set suspended_at = null, suspended_reason = null, updated_at = now()
    where tenant_id = p_tenant_id;
  end if;
  insert into subscription_events (tenant_id, kind, note, recorded_by)
  values (p_tenant_id, case when p_suspended then 'suspended' else 'resumed' end,
          nullif(btrim(p_reason), ''), auth.uid());
  return subscription_summary(p_tenant_id);
end;
$$;

create function admin_platform_settings()
returns platform_settings
language plpgsql stable security definer set search_path = public
as $$
declare
  p platform_settings;
begin
  perform require_platform_admin();
  select * into p from platform_settings;
  return p;
end;
$$;

-- New trial length applies to organizations created from now on; grace
-- applies to everyone straight away.
create function admin_update_platform_settings(
  p_monthly_price numeric,
  p_trial_days integer,
  p_grace_days integer,
  p_payment_instructions text
)
returns platform_settings
language plpgsql security definer set search_path = public
as $$
declare
  p platform_settings;
begin
  perform require_platform_admin();
  if p_monthly_price is null or p_monthly_price < 0 then
    raise exception 'Enter the monthly price';
  end if;
  if p_trial_days is null or p_trial_days not between 0 and 90 then
    raise exception 'Trial days must be between 0 and 90';
  end if;
  if p_grace_days is null or p_grace_days not between 0 and 30 then
    raise exception 'Grace days must be between 0 and 30';
  end if;
  update platform_settings
  set monthly_price = p_monthly_price,
      trial_days = p_trial_days,
      grace_days = p_grace_days,
      payment_instructions = nullif(btrim(p_payment_instructions), ''),
      updated_at = now()
  returning * into p;
  return p;
end;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

revoke all on function require_platform_admin() from public, anon, authenticated;
revoke all on function subscription_ends_at(tenant_subscriptions) from public, anon, authenticated;
revoke all on function subscription_access_ends_at(tenant_subscriptions) from public, anon, authenticated;
revoke all on function subscription_allows_recording(uuid) from public, anon, authenticated;
revoke all on function subscription_summary(uuid) from public, anon, authenticated;
revoke all on function guard_subscription() from public, anon, authenticated;
revoke all on function start_trial() from public, anon, authenticated;
revoke all on function device_subscription(text) from public, anon, authenticated;
grant execute on function device_subscription(text) to service_role;

revoke all on function is_platform_admin() from public, anon;
grant execute on function is_platform_admin() to authenticated;
revoke all on function my_subscription(uuid) from public, anon;
grant execute on function my_subscription(uuid) to authenticated;

revoke all on function admin_organizations() from public, anon;
revoke all on function admin_subscription_events(uuid) from public, anon;
revoke all on function admin_record_payment(uuid, numeric, integer, text) from public, anon;
revoke all on function admin_add_free_days(uuid, integer, text) from public, anon;
revoke all on function admin_set_suspended(uuid, boolean, text) from public, anon;
revoke all on function admin_platform_settings() from public, anon;
revoke all on function admin_update_platform_settings(numeric, integer, integer, text) from public, anon;
grant execute on function admin_organizations() to authenticated;
grant execute on function admin_subscription_events(uuid) to authenticated;
grant execute on function admin_record_payment(uuid, numeric, integer, text) to authenticated;
grant execute on function admin_add_free_days(uuid, integer, text) to authenticated;
grant execute on function admin_set_suspended(uuid, boolean, text) to authenticated;
grant execute on function admin_platform_settings() to authenticated;
grant execute on function admin_update_platform_settings(numeric, integer, integer, text) to authenticated;

-- The HydroTrack operator.
insert into platform_admins (user_id)
select id from auth.users where lower(email) = 'ummihabib88@gmail.com'
on conflict do nothing;
