-- HydroTrack — plans tests (pgTAP, xUnit style).
--
-- Three plans; Standard during the trial; staff and location limits
-- (owners not counted, open invites counted, nothing switched off when
-- over); owners choose a plan and HydroTrack confirms it with a payment;
-- plan editing is admin-only. One transaction, rolled back.
--
-- Run:  ./supabase/tests/run_linked.sh

begin;

create extension if not exists pgtap with schema extensions;

create schema tests;
grant usage on schema tests to authenticated, anon;

create table tests.fx (key text primary key, id uuid not null);
grant select, insert on tests.fx to authenticated, anon;

create function tests.id(p_key text) returns uuid
language sql stable as $$ select id from tests.fx where key = p_key $$;

create function tests.create_user(p_key text, p_name text, p_email text)
returns uuid language plpgsql as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_user_meta_data, raw_app_meta_data,
                          created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
          p_email, '', now(), jsonb_build_object('full_name', p_name), '{}'::jsonb,
          now(), now());
  insert into tests.fx (key, id) values (p_key, v_id);
  return v_id;
end;
$$;

create function tests.as_user(p_key text) returns void language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', tests.id(p_key), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create function tests.as_owner_db() returns void language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Organization A (owner alice, manager mike) and the platform admin pat.
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@plan-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@plan-test.invalid');
  perform tests.create_user('pat', 'Pat Admin', 'pat@plan-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  perform tests.as_owner_db();
  insert into public.tenant_members (tenant_id, user_id, role) values (v_a, tests.id('mike'), 'manager');
  insert into public.platform_admins (user_id) values (tests.id('pat'));
  insert into tests.fx (key, id) values ('a', v_a);
end;
$$;

create function tests.set_plan(p_plan text) returns void language plpgsql as $$
begin
  perform tests.as_owner_db();
  update public.tenant_subscriptions set plan_key = p_plan where tenant_id = tests.id('a');
end;
$$;

create function tests.invite_sql(p_n integer) returns text language sql stable as $$
  select format('select public.create_invitation(%L, %L, %L, null, %L)',
    tests.id('a'), 'Person ' || p_n, '0803000000' || p_n, 'cashier');
$$;

create function tests.location_sql(p_name text) returns text language sql stable as $$
  select format('insert into public.locations (tenant_id, name, kind) values (%L, %L, %L)',
    tests.id('a'), p_name, 'depot');
$$;

create function tests.test_01_three_plans_standard_on_trial() returns setof text language plpgsql as $$
declare
  v_sub jsonb;
begin
  perform tests.seed();
  perform tests.as_user('mike');
  return next is(
    (select string_agg(key || ':' || monthly_price::int || ':' || coalesce(max_staff::text, '-') || ':'
                       || coalesce(max_locations::text, '-'), ' ' order by position) from public.plans),
    'starter:15000:3:1 standard:25000:10:1 premium:50000:-:-',
    'Starter, Standard and Premium with their prices and limits');
  return next is((select key from public.plans where is_popular), 'standard', 'Standard is the popular one');
  v_sub := public.my_subscription(tests.id('a'));
  return next is(v_sub -> 'plan' ->> 'key', 'standard', 'A new organization is on Standard during its trial');
  return next is((v_sub ->> 'staff_in_use')::int, 1, 'The owner isn''t counted as staff');
  return next is((v_sub ->> 'locations_in_use')::int, 1, 'Its main factory is its one location');
  return next is(v_sub ->> 'bank_name' || ' ' || (v_sub ->> 'account_number') || ' ' || (v_sub ->> 'account_name'),
    'Moniepoint MFB 8137131177 Byte Tek Limited', 'Members see HydroTrack''s bank account');
  update public.plans set monthly_price = 1;
  perform tests.as_owner_db();
  return next is((select monthly_price::int from public.plans where key = 'starter'), 15000,
    'Members can''t change plan prices');
end;
$$;

create function tests.test_02_staff_limit() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.set_plan('starter');
  perform tests.as_user('alice');
  return next lives_ok(tests.invite_sql(1), 'Starter: a 2nd staff invite is fine');
  return next lives_ok(tests.invite_sql(2), 'and a 3rd');
  return next throws_ok(tests.invite_sql(3), 'P0001',
    'The Starter plan allows up to 3 staff (owners not counted), and this organization already has 3 including open invites. Choose a bigger plan under Organization → Subscription, or deactivate someone or revoke an invite first.',
    'a 4th is refused with a clear message');
  perform public.revoke_invitation(tests.id('a'),
    (select id from public.tenant_invitations where full_name = 'Person 1'));
  return next lives_ok(tests.invite_sql(4), 'Revoking an invite frees its place');
  perform tests.as_owner_db();
  update public.tenant_invitations set expires_at = now() - interval '1 day' where full_name = 'Person 2';
  perform tests.as_user('alice');
  return next lives_ok(tests.invite_sql(5), 'and so does an expired one');
  perform tests.set_plan('premium');
  perform tests.as_user('alice');
  return next lives_ok(tests.invite_sql(6), 'Premium has no staff limit');
end;
$$;

create function tests.test_03_over_the_limit_blocks_new_only() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('alice');
  perform public.set_member_active(tests.id('a'), tests.id('mike'), false);
  perform public.create_invitation(tests.id('a'), 'P1', '08030000011', null, 'cashier');
  perform public.create_invitation(tests.id('a'), 'P2', '08030000012', null, 'cashier');
  perform public.create_invitation(tests.id('a'), 'P3', '08030000013', null, 'cashier');
  perform tests.set_plan('starter');
  perform tests.as_user('alice');
  return next throws_ok(format('select public.set_member_active(%L, %L, true)', tests.id('a'), tests.id('mike')),
    'P0001', null, 'Reactivating staff over the limit is refused');
  return next is((select count(*)::int from public.tenant_invitations where revoked_at is null), 3,
    'but nothing already there is switched off');
  perform public.revoke_invitation(tests.id('a'), (select id from public.tenant_invitations where full_name = 'P1'));
  return next lives_ok(format('select public.set_member_active(%L, %L, true)', tests.id('a'), tests.id('mike')),
    'Back under the limit, they can be reactivated');
  return next lives_ok(format('select public.update_member_role(%L, %L, %L)', tests.id('a'), tests.id('mike'), 'admin'),
    'Changing an active staff member''s role is not a new place');
end;
$$;

create function tests.test_04_location_limit() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('alice');
  return next throws_ok(tests.location_sql('Kano depot'), 'P0001',
    'The Standard plan includes 1 location. Choose Premium under Organization → Subscription to run more factories or depots.',
    'Standard: a second location is refused');
  perform tests.set_plan('premium');
  perform tests.as_user('alice');
  return next lives_ok(tests.location_sql('Kano depot'), 'Premium: a second location is fine');
  return next lives_ok(tests.location_sql('Zaria factory'), 'and a third');
  perform tests.as_owner_db();
  update public.locations set is_active = false where name = 'Zaria factory';
  perform tests.set_plan('standard');
  perform tests.as_user('alice');
  return next is((select count(*)::int from public.locations where is_active), 2,
    'Moving down keeps the existing locations working');
  return next throws_ok(tests.location_sql('Kaduna depot'), 'P0001', null, 'but no new one can be added');
  return next throws_ok(format('update public.locations set is_active = true where tenant_id = %L and name = %L',
    tests.id('a'), 'Zaria factory'), 'P0001', null, 'or switched back on');
end;
$$;

create function tests.test_05_owner_chooses_admin_confirms() returns setof text language plpgsql as $$
declare
  v_sub jsonb;
begin
  perform tests.seed();
  perform tests.as_user('mike');
  return next throws_ok(format('select public.request_plan(%L, %L)', tests.id('a'), 'premium'), '42501', null,
    'A manager can''t choose the plan');
  perform tests.as_user('alice');
  return next throws_ok(format('select public.request_plan(%L, %L)', tests.id('a'), 'gold'), 'P0001',
    'Choose one of the plans shown', 'Only real plans can be chosen');
  v_sub := public.request_plan(tests.id('a'), 'premium');
  return next is(v_sub ->> 'requested_plan_key', 'premium', 'The owner chooses Premium');
  return next is(v_sub -> 'plan' ->> 'key', 'standard', 'which waits for payment');
  perform tests.as_user('pat');
  v_sub := public.admin_record_payment(tests.id('a'), 'premium', 50000, 1, 'Moniepoint transfer');
  return next is(v_sub -> 'plan' ->> 'key', 'premium', 'Recording the payment sets the plan');
  return next is(v_sub ->> 'requested_plan_key', null, 'and clears the request');
  return next throws_ok(format('select public.admin_record_payment(%L, %L, 1, 1)', tests.id('a'), 'gold'), 'P0001',
    'Choose the plan paid for', 'The plan paid for must exist');
  v_sub := public.admin_set_plan(tests.id('a'), 'starter', 'Asked to move down');
  return next is(v_sub -> 'plan' ->> 'key', 'starter', 'HydroTrack can change the plan without a payment');
  return next throws_ok(format('select public.admin_set_plan(%L, %L)', tests.id('a'), 'starter'), 'P0001',
    'This organization is already on that plan', 'but not to the same plan');
  perform tests.as_user('alice');
  return next is((select string_agg(kind || ':' || plan_key, ' ' order by created_at) from public.subscription_events),
    'payment:premium plan_changed:starter', 'The owner sees payments and plan changes with their plan');
end;
$$;

create function tests.test_06_editing_plans_is_admin_only() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('alice');
  return next throws_ok('select public.admin_update_plan(''starter'', 1, null, null)', '42501', null,
    'Owners can''t change plans');
  return next throws_ok(format('select public.admin_set_plan(%L, %L)', tests.id('a'), 'premium'), '42501', null,
    'or upgrade themselves');
  perform tests.as_user('pat');
  return next is((public.admin_update_plan('starter', 18000, 4, 1)).monthly_price::int, 18000,
    'The admin changes a plan''s price and limits');
  return next throws_ok('select public.admin_update_plan(''starter'', 18000, 0, 1)', 'P0001',
    'Staff limit must be at least 1, or empty for unlimited', 'Limits are checked');
  return next throws_ok('select public.admin_update_platform_settings(14, 7, ''Moniepoint MFB'', ''81371'', ''Byte Tek Limited'', null)',
    'P0001', 'The account number must be 10 digits', 'The account number is checked');
  return next throws_ok('select public.admin_update_platform_settings(14, 7, ''Moniepoint MFB'', null, null, null)',
    'P0001', 'Fill in the bank, account number and account name, or leave all three empty',
    'Bank details are all or none');
  return next throws_ok('select public.staff_in_use(gen_random_uuid())', '42501', null,
    'Internal helpers can''t be called directly');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
