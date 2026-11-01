-- HydroTrack — subscriptions and admin console tests (pgTAP, xUnit style).
--
-- Trial on creation, grace, read-only after that (every write path,
-- not reads, not other organizations, not background jobs), offline
-- records made in time, suspension, and the platform-admin-only console.
-- One transaction, rolled back.
--
-- Run:  ./supabase/tests/run_linked.sh

begin;

create extension if not exists pgtap with schema extensions;

create schema tests;
grant usage on schema tests to authenticated, anon;

create table tests.fx (key text primary key, id uuid not null, note text);
grant select, insert on tests.fx to authenticated, anon;

create function tests.id(p_key text) returns uuid
language sql stable as $$ select id from tests.fx where key = p_key $$;

create function tests.note(p_key text) returns text
language sql stable as $$ select note from tests.fx where key = p_key $$;

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

-- Organization A (owner alice, manager mike, set-up device), organization
-- B (owner bob), and the platform admin (pat, in no organization).
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_b uuid;
  v_device jsonb;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@sub-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@sub-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@sub-test.invalid');
  perform tests.create_user('pat', 'Pat Admin', 'pat@sub-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  v_device := public.register_device(v_a, 'Front desk phone');
  perform tests.as_user('bob');
  v_b := (public.create_tenant('Other Water')).id;
  perform tests.as_owner_db();
  insert into public.tenant_members (tenant_id, user_id, role) values (v_a, tests.id('mike'), 'manager');
  insert into public.platform_admins (user_id) values (tests.id('pat'));
  insert into tests.fx (key, id) values ('a', v_a), ('b', v_b);
  insert into tests.fx (key, id, note) values ('device', (v_device ->> 'id')::uuid, v_device ->> 'key');
end;
$$;

-- Moves A's trial end to p_ago before now (grace is 7 days).
create function tests.trial_ended(p_ago interval) returns void language sql as $$
  update public.tenant_subscriptions set trial_ends_at = now() - p_ago where tenant_id = tests.id('a');
$$;

create function tests.expense_sql(p_tenant text) returns text language sql stable as $$
  select format('select public.record_expense(%L, current_date, %L, %L, 500, %L)',
    tests.id(p_tenant), 'fuel_diesel', 'Diesel', 'cash');
$$;

create function tests.offline_expense(p_op uuid, p_at timestamptz) returns jsonb language sql as $$
  select public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', p_op, 'type', 'expense', 'actor_id', tests.id('mike'), 'recorded_at', p_at,
    'payload', jsonb_build_object('date', p_at::date, 'category', 'fuel_diesel',
      'description', 'Diesel', 'amount', 1000, 'method', 'cash')));
$$;

create function tests.test_01_new_organizations_start_on_a_trial() returns setof text language plpgsql as $$
declare
  v_sub jsonb;
begin
  perform tests.seed();
  perform tests.as_user('mike');
  v_sub := public.my_subscription(tests.id('a'));
  return next is(v_sub ->> 'status', 'trial', 'A new organization is on a trial');
  return next ok((v_sub ->> 'trial_ends_at')::timestamptz between now() + interval '13 days 23 hours'
                                                              and now() + interval '14 days 1 hour',
    'of 14 days');
  return next is((v_sub ->> 'access_ends_at')::timestamptz,
    (v_sub ->> 'trial_ends_at')::timestamptz + interval '7 days', 'with 7 days of grace after it');
  return next lives_ok(tests.expense_sql('a'), 'and can record');
  return next throws_ok(format('select public.my_subscription(%L)', tests.id('b')), '42501', null,
    'Members can''t see another organization''s subscription');
  return next is((select count(*)::int from public.tenant_subscriptions), 0,
    'nor read subscriptions directly');
end;
$$;

create function tests.test_02_grace_then_read_only() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.trial_ended('3 days');
  perform tests.as_user('mike');
  return next is(public.my_subscription(tests.id('a')) ->> 'status', 'grace', 'After the trial: grace');
  return next lives_ok(tests.expense_sql('a'), 'still recording');

  perform tests.as_owner_db();
  perform tests.trial_ended('8 days');
  perform tests.as_user('mike');
  return next is(public.my_subscription(tests.id('a')) ->> 'status', 'expired', 'After grace: expired');
  return next is((public.my_subscription(tests.id('a')) ->> 'can_record')::boolean, false, 'can''t record');
  return next throws_ok(tests.expense_sql('a'), 'P0001',
    'This organization''s subscription has ended, so nothing new can be recorded or changed. You can still view and export records. The owner can renew it under Organization → Subscription.',
    'RPCs are refused with a clear message');
  return next throws_ok(format('insert into public.customers (tenant_id, name) values (%L, %L)', tests.id('a'), 'New'),
    'P0001', null, 'so are direct inserts');
  perform tests.as_user('alice');
  return next throws_ok(format('update public.tenants set address = %L where id = %L', 'Kano', tests.id('a')),
    'P0001', null, 'and profile edits');
  return next throws_like(format('select public.delete_product(%L, %L)', tests.id('a'),
      (select id from public.products where tenant_id = tests.id('a') limit 1)),
    '%subscription has ended%', 'and deletes');
  return next is((select count(*)::int from public.expenses where tenant_id = tests.id('a')), 1,
    'Records can still be read');
  return next lives_ok(format('update public.tenant_members set is_active = false where tenant_id = %L and user_id = %L',
    tests.id('a'), tests.id('mike')), 'The owner can still deactivate staff');
  perform tests.as_user('bob');
  return next lives_ok(tests.expense_sql('b'), 'Other organizations aren''t affected');
  perform tests.as_owner_db();
  return next lives_ok(format('update public.stock_items set reorder_level = 1 where tenant_id = %L', tests.id('a')),
    'Background jobs (no signed-in user) aren''t blocked');
end;
$$;

create function tests.test_03_offline_records_made_in_time() returns setof text language plpgsql as $$
declare
  v_late uuid := gen_random_uuid();
begin
  perform tests.seed();
  perform tests.trial_ended('8 days');  -- read-only since 1 day ago
  return next is(tests.offline_expense(gen_random_uuid(), now() - interval '2 days') ->> 'status', 'applied',
    'A record made offline before access ended syncs');
  return next is(tests.offline_expense(v_late, now() - interval '12 hours') ->> 'status', 'rejected',
    'One made after is refused (and kept on the device''s list)');
  perform tests.as_user('pat');
  perform public.admin_record_payment(tests.id('a'), 15000, 1);
  perform tests.as_owner_db();
  return next is(tests.offline_expense(v_late, now() - interval '12 hours') ->> 'status', 'applied',
    'and goes through on retry once the organization has paid');
end;
$$;

create function tests.test_04_suspension() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('pat');
  return next throws_ok(format('select public.admin_set_suspended(%L, true, %L)', tests.id('a'), ' '),
    'P0001', 'Give a reason for suspending (the organization sees it)', 'Suspending needs a reason');
  perform public.admin_set_suspended(tests.id('a'), true, 'Cheque bounced');
  perform tests.as_user('mike');
  return next is(public.my_subscription(tests.id('a')) ->> 'status', 'suspended', 'Suspended during a trial');
  return next is(public.my_subscription(tests.id('a')) ->> 'suspended_reason', 'Cheque bounced', 'with the reason');
  return next throws_ok(tests.expense_sql('a'), 'P0001', null, 'is read-only straight away');
  perform tests.as_owner_db();
  return next is(tests.offline_expense(gen_random_uuid(), now() - interval '1 hour') ->> 'status', 'applied',
    'Offline records made before the suspension still sync');
  perform tests.as_user('pat');
  perform public.admin_set_suspended(tests.id('a'), false);
  perform tests.as_user('mike');
  return next lives_ok(tests.expense_sql('a'), 'Resuming allows recording again');
end;
$$;

create function tests.test_05_payments_and_free_days() returns setof text language plpgsql as $$
declare
  v_sub jsonb;
  v_trial_end timestamptz;
begin
  perform tests.seed();
  select trial_ends_at into v_trial_end from public.tenant_subscriptions where tenant_id = tests.id('a');
  perform tests.as_user('pat');
  v_sub := public.admin_record_payment(tests.id('a'), 15000, 2, 'Transfer');
  return next is((v_sub ->> 'paid_until')::timestamptz, v_trial_end + interval '2 months',
    'Paying during the trial adds the months after the trial');
  return next is(v_sub ->> 'status', 'active', 'and makes it active');
  v_sub := public.admin_add_free_days(tests.id('a'), 10, 'Goodwill');
  return next is((v_sub ->> 'paid_until')::timestamptz, v_trial_end + interval '2 months' + interval '10 days',
    'Free days extend the paid time');
  return next throws_ok(format('select public.admin_record_payment(%L, 15000, 0)', tests.id('a')), 'P0001',
    'Months paid for must be between 1 and 24', 'Months are checked');

  perform tests.as_owner_db();
  update public.tenant_subscriptions set trial_ends_at = now() - interval '30 days', paid_until = null
  where tenant_id = tests.id('b');
  perform tests.as_user('pat');
  v_sub := public.admin_record_payment(tests.id('b'), 15000, 1);
  return next ok((v_sub ->> 'paid_until')::timestamptz between now() + interval '27 days' and now() + interval '32 days',
    'After running out, paid time starts today');
  v_sub := public.admin_add_free_days(tests.id('b'), 5);
  return next is(v_sub ->> 'status', 'active', 'Free days after a payment keep it active');

  perform tests.as_user('alice');
  return next is((select count(*)::int from public.subscription_events), 2,
    'The owner sees their payments and free days');
  perform tests.as_user('mike');
  return next is((select count(*)::int from public.subscription_events), 0, 'Staff don''t');
  perform tests.as_user('pat');
  return next is((select count(*)::int from public.admin_subscription_events(tests.id('a'))), 2,
    'The admin sees each organization''s history');
end;
$$;

create function tests.test_06_settings() returns setof text language plpgsql as $$
declare
  v_org uuid;
begin
  perform tests.seed();
  perform tests.as_user('pat');
  perform public.admin_update_platform_settings(15000, 30, 5, ' Pay to GTBank 0123456789 ');
  return next is((public.admin_platform_settings()).payment_instructions, 'Pay to GTBank 0123456789',
    'The admin sets the price, trial, grace and how to pay');
  return next throws_ok('select public.admin_update_platform_settings(15000, 120, 5, null)', 'P0001',
    'Trial days must be between 0 and 90', 'Values are checked');
  perform tests.as_user('mike');
  return next is((public.my_subscription(tests.id('a')) ->> 'monthly_price')::numeric, 15000::numeric,
    'Members see the price');
  return next is((public.my_subscription(tests.id('a')) ->> 'access_ends_at')::timestamptz,
    (public.my_subscription(tests.id('a')) ->> 'trial_ends_at')::timestamptz + interval '5 days',
    'New grace applies to everyone');
  perform tests.as_user('bob');
  v_org := (public.create_tenant('Third Water')).id;
  return next ok((public.my_subscription(v_org) ->> 'trial_ends_at')::timestamptz > now() + interval '29 days',
    'New trial length applies to new organizations');
end;
$$;

create function tests.test_07_admin_console_is_admin_only() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('alice');
  return next is(public.is_platform_admin(), false, 'Owners aren''t platform admins');
  return next throws_ok('select * from public.admin_organizations()', '42501', null, 'can''t list organizations');
  return next throws_ok(format('select public.admin_record_payment(%L, 1, 12)', tests.id('a')), '42501', null,
    'can''t record their own payment');
  return next throws_ok(format('select public.admin_add_free_days(%L, 30)', tests.id('a')), '42501', null,
    'or give themselves free days');
  return next throws_ok(format('select public.admin_set_suspended(%L, true, %L)', tests.id('b'), 'x'), '42501', null,
    'or suspend anyone');
  return next throws_ok('select public.admin_update_platform_settings(0, 90, 30, null)', '42501', null,
    'or change the price');
  return next throws_ok('select public.admin_platform_settings()', '42501', null, 'or read the settings');
  return next throws_ok('insert into public.platform_admins (user_id) select auth.uid()', '42501', null,
    'or make themselves admins');
  update public.tenant_subscriptions set paid_until = now() + interval '10 years';
  perform tests.as_owner_db();
  return next is((select paid_until from public.tenant_subscriptions where tenant_id = tests.id('a')), null,
    'or edit their subscription directly');
  perform tests.as_user('alice');

  perform tests.as_user('pat');
  return next is(public.is_platform_admin(), true, 'The platform admin is');
  return next is((select count(*)::int from public.admin_organizations() where id in (tests.id('a'), tests.id('b'))), 2,
    'and sees every organization');
  return next is((select owner_email from public.admin_organizations() where id = tests.id('a')),
    'alice@sub-test.invalid', 'with its owner''s contact');
  return next is((select staff_count from public.admin_organizations() where id = tests.id('a')), 2,
    'and staff count');
  return next is((select count(*)::int from public.expenses), 0,
    'but gets no access to organizations'' own records');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
