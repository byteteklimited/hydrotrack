-- HydroTrack — 0036: plans (agreed rules).
--
--   * Three plans, every feature on each:
--       Starter  ₦15,000 a month, up to 3 staff, one location
--       Standard ₦25,000 a month, up to 10 staff, one location (most popular)
--       Premium  ₦50,000 a month, unlimited staff, several factories/depots
--   * Staff = active members who are not owners, plus open invitations
--     (so unused codes can't get round the limit). Owners never count.
--   * New organizations are on Standard during the trial.
--   * Over a limit (e.g. after moving to a smaller plan) nothing is
--     switched off: only inviting or reactivating staff and adding or
--     reactivating a location are refused until it is back under.
--   * Owners/Admins choose a plan in the app (requested_plan_key);
--     HydroTrack sets it when it records their payment.
--   * HydroTrack's bank account (shown to owners) replaces the single
--     monthly price in platform_settings.

-- =========================================================================
-- Plans
-- =========================================================================

create table plans (
  key text primary key check (key ~ '^[a-z]+$'),
  name text not null,
  description text not null,
  monthly_price numeric(12, 2) not null check (monthly_price >= 0),
  max_staff integer check (max_staff > 0),          -- null: unlimited
  max_locations integer check (max_locations > 0),  -- null: unlimited
  is_popular boolean not null default false,
  position integer not null unique
);
alter table plans enable row level security;

-- Prices are public to anyone signed in; only HydroTrack changes them
-- (admin_update_plan).
create policy plans_select on plans for select to authenticated using (true);

insert into plans (key, name, description, monthly_price, max_staff, max_locations, is_popular, position)
values
  ('starter', 'Starter', 'For small factories', 15000, 3, 1, false, 1),
  ('standard', 'Standard', 'For growing factories', 25000, 10, 1, true, 2),
  ('premium', 'Premium', 'For owners with 2 or more factories', 50000, null, null, false, 3);

alter table tenant_subscriptions
  add column plan_key text not null default 'standard' references plans (key),
  -- The plan the owner chose; becomes plan_key when the payment is recorded.
  add column requested_plan_key text references plans (key);

alter table subscription_events
  add column plan_key text references plans (key),
  drop constraint subscription_events_kind_check,
  add constraint subscription_events_kind_check
    check (kind in ('payment', 'free_days', 'suspended', 'resumed', 'plan_changed'));

drop policy subscription_events_select on subscription_events;
create policy subscription_events_select on subscription_events
  for select to authenticated
  using (
    is_platform_admin()
    or (kind in ('payment', 'free_days', 'plan_changed')
        and has_tenant_role(tenant_id, array['owner']::staff_role[]))
  );

-- =========================================================================
-- HydroTrack's bank account
-- =========================================================================

alter table platform_settings
  drop column monthly_price,
  add column bank_name text,
  add column account_number text check (account_number ~ '^[0-9]{10}$'),
  add column account_name text,
  add constraint platform_settings_bank_all_or_none check (
    (bank_name is null) = (account_number is null)
    and (account_number is null) = (account_name is null)
  );

update platform_settings
set bank_name = 'Moniepoint MFB', account_number = '8137131177', account_name = 'Byte Tek Limited',
    updated_at = now();

-- =========================================================================
-- Usage and limits
-- =========================================================================

-- The organization's plan (Standard if it somehow has no subscription).
create function tenant_plan(p_tenant_id uuid)
returns plans
language plpgsql stable security definer set search_path = public
as $$
declare
  v_plan plans;
begin
  select p.* into v_plan
  from tenant_subscriptions s join plans p on p.key = s.plan_key
  where s.tenant_id = p_tenant_id;
  if not found then
    select * into v_plan from plans where key = 'standard';
  end if;
  return v_plan;
end;
$$;

-- Active members who aren't owners, plus open invitations.
create function staff_in_use(p_tenant_id uuid)
returns integer
language sql stable security definer set search_path = public
as $$
  select (
    (select count(*) from tenant_members
     where tenant_id = p_tenant_id and is_active and role <> 'owner')
    + (select count(*) from tenant_invitations
       where tenant_id = p_tenant_id and accepted_at is null
         and revoked_at is null and expires_at > now())
  )::integer;
$$;

create function locations_in_use(p_tenant_id uuid)
returns integer
language sql stable security definer set search_path = public
as $$
  select count(*)::integer from locations where tenant_id = p_tenant_id and is_active;
$$;

-- Before a new invitation, or a member becoming active staff again (or an
-- owner becoming staff). Accepting an invitation needs no check: the
-- invitation was counted when it was made.
create function enforce_staff_limit()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_plan plans;
  v_used integer;
begin
  if tg_table_name = 'tenant_members' and not (
    new.is_active and new.role <> 'owner'
    and not (old.is_active and old.role <> 'owner')
  ) then
    return new;
  end if;
  v_plan := tenant_plan(new.tenant_id);
  if v_plan.max_staff is null then
    return new;
  end if;
  v_used := staff_in_use(new.tenant_id);
  if v_used >= v_plan.max_staff then
    raise exception
      'The % plan allows up to % staff (owners not counted), and this organization already has % including open invites. Choose a bigger plan under Organization → Subscription, or deactivate someone or revoke an invite first.',
      v_plan.name, v_plan.max_staff, v_used
      using errcode = 'P0001', hint = 'plan_limit';
  end if;
  return new;
end;
$$;

create trigger enforce_staff_limit before insert on tenant_invitations
  for each row execute function enforce_staff_limit();
create trigger enforce_staff_limit before update on tenant_members
  for each row execute function enforce_staff_limit();

-- Before a new location, or one switched back on.
create function enforce_location_limit()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_plan plans;
begin
  if not new.is_active or (tg_op = 'UPDATE' and old.is_active) then
    return new;
  end if;
  v_plan := tenant_plan(new.tenant_id);
  if v_plan.max_locations is not null
     and locations_in_use(new.tenant_id) >= v_plan.max_locations then
    raise exception
      'The % plan includes % location. Choose Premium under Organization → Subscription to run more factories or depots.',
      v_plan.name, v_plan.max_locations
      using errcode = 'P0001', hint = 'plan_limit';
  end if;
  return new;
end;
$$;

create trigger enforce_location_limit before insert or update on locations
  for each row execute function enforce_location_limit();

-- =========================================================================
-- Status
-- =========================================================================

create or replace function subscription_summary(p_tenant_id uuid)
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
    'plan', to_jsonb(tenant_plan(p_tenant_id)),
    'requested_plan_key', s.requested_plan_key,
    'staff_in_use', staff_in_use(p_tenant_id),
    'locations_in_use', locations_in_use(p_tenant_id),
    'bank_name', p.bank_name,
    'account_number', p.account_number,
    'account_name', p.account_name,
    'payment_instructions', p.payment_instructions
  );
end;
$$;

-- =========================================================================
-- Owners and admins choose a plan
-- =========================================================================

create function request_plan(p_tenant_id uuid, p_plan_key text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'choose a plan');
  if not exists (select 1 from plans where key = p_plan_key) then
    raise exception 'Choose one of the plans shown';
  end if;
  update tenant_subscriptions
  set requested_plan_key = p_plan_key, updated_at = now()
  where tenant_id = p_tenant_id;
  return subscription_summary(p_tenant_id);
end;
$$;

-- =========================================================================
-- Admin console
-- =========================================================================

drop function admin_record_payment(uuid, numeric, integer, text);

-- Sets the plan paid for (and clears the owner's request).
create function admin_record_payment(
  p_tenant_id uuid,
  p_plan_key text,
  p_amount numeric,
  p_months integer,
  p_note text default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  s tenant_subscriptions;
  v_until timestamptz;
begin
  perform require_platform_admin();
  if not exists (select 1 from plans where key = p_plan_key) then
    raise exception 'Choose the plan paid for';
  end if;
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
  update tenant_subscriptions
  set paid_until = v_until, plan_key = p_plan_key, requested_plan_key = null, updated_at = now()
  where tenant_id = p_tenant_id;
  insert into subscription_events (tenant_id, kind, plan_key, amount, months, note, ends_at, recorded_by)
  values (p_tenant_id, 'payment', p_plan_key, p_amount, p_months, nullif(btrim(p_note), ''), v_until, auth.uid());
  return subscription_summary(p_tenant_id);
end;
$$;

-- A plan change without a payment (a correction, or moving down).
create function admin_set_plan(p_tenant_id uuid, p_plan_key text, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  s tenant_subscriptions;
begin
  perform require_platform_admin();
  if not exists (select 1 from plans where key = p_plan_key) then
    raise exception 'Choose a plan';
  end if;
  select * into s from tenant_subscriptions where tenant_id = p_tenant_id for update;
  if not found then
    raise exception 'Organization not found';
  end if;
  if s.plan_key = p_plan_key then
    raise exception 'This organization is already on that plan';
  end if;
  update tenant_subscriptions
  set plan_key = p_plan_key,
      requested_plan_key = case when requested_plan_key = p_plan_key then null else requested_plan_key end,
      updated_at = now()
  where tenant_id = p_tenant_id;
  insert into subscription_events (tenant_id, kind, plan_key, note, recorded_by)
  values (p_tenant_id, 'plan_changed', p_plan_key, nullif(btrim(p_note), ''), auth.uid());
  return subscription_summary(p_tenant_id);
end;
$$;

create function admin_update_plan(
  p_plan_key text,
  p_monthly_price numeric,
  p_max_staff integer,
  p_max_locations integer
)
returns plans
language plpgsql security definer set search_path = public
as $$
declare
  v_plan plans;
begin
  perform require_platform_admin();
  if p_monthly_price is null or p_monthly_price < 0 then
    raise exception 'Enter the monthly price';
  end if;
  if p_max_staff is not null and p_max_staff < 1 then
    raise exception 'Staff limit must be at least 1, or empty for unlimited';
  end if;
  if p_max_locations is not null and p_max_locations < 1 then
    raise exception 'Location limit must be at least 1, or empty for unlimited';
  end if;
  update plans
  set monthly_price = p_monthly_price, max_staff = p_max_staff, max_locations = p_max_locations
  where key = p_plan_key
  returning * into v_plan;
  if not found then
    raise exception 'Plan not found';
  end if;
  return v_plan;
end;
$$;

drop function admin_update_platform_settings(numeric, integer, integer, text);

-- New trial length applies to organizations created from now on; grace
-- applies to everyone straight away.
create function admin_update_platform_settings(
  p_trial_days integer,
  p_grace_days integer,
  p_bank_name text,
  p_account_number text,
  p_account_name text,
  p_payment_instructions text
)
returns platform_settings
language plpgsql security definer set search_path = public
as $$
declare
  p platform_settings;
  v_bank text := nullif(btrim(p_bank_name), '');
  v_number text := nullif(btrim(p_account_number), '');
  v_name text := nullif(btrim(p_account_name), '');
begin
  perform require_platform_admin();
  if p_trial_days is null or p_trial_days not between 0 and 90 then
    raise exception 'Trial days must be between 0 and 90';
  end if;
  if p_grace_days is null or p_grace_days not between 0 and 30 then
    raise exception 'Grace days must be between 0 and 30';
  end if;
  if (v_bank is null) <> (v_number is null) or (v_number is null) <> (v_name is null) then
    raise exception 'Fill in the bank, account number and account name, or leave all three empty';
  end if;
  if v_number is not null and v_number !~ '^[0-9]{10}$' then
    raise exception 'The account number must be 10 digits';
  end if;
  update platform_settings
  set trial_days = p_trial_days,
      grace_days = p_grace_days,
      bank_name = v_bank,
      account_number = v_number,
      account_name = v_name,
      payment_instructions = nullif(btrim(p_payment_instructions), ''),
      updated_at = now()
  returning * into p;
  return p;
end;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

revoke all on function tenant_plan(uuid) from public, anon, authenticated;
revoke all on function staff_in_use(uuid) from public, anon, authenticated;
revoke all on function locations_in_use(uuid) from public, anon, authenticated;
revoke all on function enforce_staff_limit() from public, anon, authenticated;
revoke all on function enforce_location_limit() from public, anon, authenticated;

revoke all on function request_plan(uuid, text) from public, anon;
revoke all on function admin_record_payment(uuid, text, numeric, integer, text) from public, anon;
revoke all on function admin_set_plan(uuid, text, text) from public, anon;
revoke all on function admin_update_plan(text, numeric, integer, integer) from public, anon;
revoke all on function admin_update_platform_settings(integer, integer, text, text, text, text) from public, anon;
grant execute on function request_plan(uuid, text) to authenticated;
grant execute on function admin_record_payment(uuid, text, numeric, integer, text) to authenticated;
grant execute on function admin_set_plan(uuid, text, text) to authenticated;
grant execute on function admin_update_plan(text, numeric, integer, integer) to authenticated;
grant execute on function admin_update_platform_settings(integer, integer, text, text, text, text) to authenticated;
