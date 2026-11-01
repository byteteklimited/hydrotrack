-- HydroTrack — quality and compliance tests (pgTAP, xUnit style).
--
-- Batch numbers and tracing a batch to customers, water tests against
-- the organization's limits (with owner alerts), permit reminders,
-- the sanitation checklist, the summary's quality lines, offline
-- recording, and who may do what. One transaction, rolled back.
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


create function tests.product(p_tenant uuid, p_key text) returns uuid
language sql stable security definer as $$
  select id from public.products where tenant_id = p_tenant and legacy_key = p_key
$$;

-- Organization A (owner alice, manager mike, store keeper sam, cashier
-- carol, a set-up device), organization B (owner bob).
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_b uuid;
  v_device jsonb;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@q-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@q-test.invalid');
  perform tests.create_user('sam', 'Sam Store', 'sam@q-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@q-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@q-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  v_device := public.register_device(v_a, 'Front desk phone');
  perform tests.as_user('bob');
  v_b := (public.create_tenant('Other Water')).id;
  perform tests.as_owner_db();
  insert into public.tenant_members (tenant_id, user_id, role) values
    (v_a, tests.id('mike'), 'manager'), (v_a, tests.id('sam'), 'store_keeper'), (v_a, tests.id('carol'), 'cashier');
  insert into public.customers (tenant_id, name, phone, area, credit_limit)
  values (v_a, 'Musa Stores', '08031234567', 'Kano', 100000);
  insert into tests.fx (key, id) values ('a', v_a), ('b', v_b), ('sachet', tests.product(v_a, 'sachet50cl'));
  insert into tests.fx (key, id, note) values ('device', (v_device ->> 'id')::uuid, v_device ->> 'key');
end;
$$;

create function tests.run(p_date date, p_shift text, p_bags integer) returns uuid language sql as $$
  select public.record_production_run(tests.id('a'), p_date, p_shift::public.production_shift, 'Machine 1', 'Ade',
    tests.id('sachet'), p_bags, 0)
$$;

create function tests.sale_to_musa(p_bags integer) returns uuid language sql as $$
  select public.record_sale(tests.id('a'), 'distributor', 'Musa Stores', p_bags * 300, p_bags * 300, 'cash', 0,
    jsonb_build_array(jsonb_build_object('product_id', tests.id('sachet'), 'quantity', p_bags, 'unit_price', 300)))
$$;

create function tests.test_01_batch_numbers_and_tracing() returns setof text language plpgsql as $$
declare
  v_first uuid;
  v_second uuid;
  v_sale uuid;
  v_trace jsonb;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  v_first := tests.run('2026-11-01', 'morning', 10);
  v_second := tests.run('2026-11-01', 'morning', 10);
  perform tests.run('2026-11-01', 'afternoon', 10);
  return next is((select batch_number from public.production_runs where id = v_first), '261101-M-1',
    'A run gets a batch number: date, shift, run');
  return next is((select batch_number from public.production_runs where id = v_second), '261101-M-2',
    'the next run that shift is 2');
  return next ok(exists (select 1 from public.production_runs where batch_number = '261101-A-1'),
    'and the afternoon starts again at 1');

  perform tests.as_user('alice');
  v_sale := tests.sale_to_musa(15);
  return next is((select batch_numbers from public.sales where id = v_sale), array['261101-M-1', '261101-M-2'],
    'A sale notes the batches its bags came from (oldest first)');

  perform tests.as_user('mike');
  v_trace := public.trace_batch(tests.id('a'), ' 261101-m-2 ');
  return next is(v_trace -> 'run' ->> 'batch_number', '261101-M-2', 'Tracing finds the batch (any case, spaces)');
  return next is((v_trace -> 'sales' -> 0 ->> 'customer_name'), 'Musa Stores', 'and the customer who got it');
  return next is((v_trace -> 'sales' -> 0 ->> 'customer_phone'), '08031234567', 'with their phone');
  return next is((v_trace -> 'sales' -> 0 ->> 'bags')::int, 5, 'and how many of its bags');
  return next is((v_trace ->> 'bags_in_stock')::int, 5, 'and what is still in stock');
  return next throws_like(format('select public.trace_batch(%L, %L)', tests.id('a'), 'NOPE'),
    'No production run has batch number NOPE%', 'An unknown batch says so');
  perform tests.as_user('carol');
  return next throws_ok(format('select public.trace_batch(%L, %L)', tests.id('a'), '261101-M-1'), '42501', null,
    'Cashiers can''t trace batches');
  perform tests.as_user('bob');
  return next throws_ok(format('select public.trace_batch(%L, %L)', tests.id('a'), '261101-M-1'), '42501', null,
    'nor can other organizations');
end;
$$;

create function tests.test_02_water_tests() returns setof text language plpgsql as $$
declare
  v_test public.water_tests;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  v_test := public.record_water_test(tests.id('a'), '2026-11-01', 'morning', 7.2, 120, 0.22);
  return next is(v_test.passed, true, 'Readings within NIS 554 limits pass');
  v_test := public.record_water_test(tests.id('a'), '2026-11-01', 'afternoon', 9.1, 650, 0.22, 'Retest at 3pm');
  return next is(v_test.passed, false, 'Out-of-range readings fail');
  return next is(v_test.problems, array['pH 9.1 (allowed 6.5–8.5)', 'TDS 650 mg/L (max 500)'], 'saying which and why');
  perform tests.as_user('alice');
  return next is((select body from public.alerts where kind = 'water_test'),
    'Afternoon shift, 01 Nov: pH 9.1 (allowed 6.5–8.5); TDS 650 mg/L (max 500).', 'and the owner is alerted');

  update public.tenants set water_tds_max = 700 where id = tests.id('a');
  perform tests.as_user('sam');
  return next is((public.record_water_test(tests.id('a'), '2026-11-01', 'afternoon', 8.0, 650, 0.22)).passed, true,
    'Each organization can adjust its limits');
  perform tests.as_user('carol');
  return next throws_ok(format('select public.record_water_test(%L, %L, %L, 7, 100, 0.2)', tests.id('a'), '2026-11-01', 'morning'),
    '42501', null, 'Cashiers can''t record water tests');
  perform tests.as_user('bob');
  return next is((select count(*)::int from public.water_tests), 0, 'Other organizations can''t see them');
  perform tests.as_user('alice');
  return next throws_ok(format('update public.tenants set water_ph_min = 9 where id = %L', tests.id('a')),
    '23514', null, 'Limits must make sense (min below max)');
end;
$$;

create function tests.test_03_permit_reminders() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('alice');
  insert into public.permits (tenant_id, name, number, expires_on)
  values (tests.id('a'), 'NAFDAC licence', 'A1-2345', current_date + 45);
  perform tests.as_owner_db();
  perform public.generate_alerts(now());
  perform public.generate_alerts(now());
  return next is((select count(*)::int from public.alerts where kind = 'permit_expiry'), 1,
    'A permit added 45 days before expiry gets one reminder now');
  return next is((select title from public.alerts where kind = 'permit_expiry'), 'NAFDAC licence expires in 45 days',
    'saying how long is left');
  perform public.generate_alerts(now() + interval '16 days');
  return next is((select count(*)::int from public.alerts where kind = 'permit_expiry'), 2, 'then again at 30 days');
  perform public.generate_alerts(now() + interval '38 days');
  perform public.generate_alerts(now() + interval '45 days');
  return next is((select count(*)::int from public.alerts where kind = 'permit_expiry'), 4, 'at 7 days and on the day');
  return next ok(exists (select 1 from public.alerts where title = 'NAFDAC licence expires today'), 'saying it expires today');
  perform tests.as_user('mike');
  return next throws_ok(format('insert into public.permits (tenant_id, name, expires_on) values (%L, %L, current_date)',
    tests.id('a'), 'Fire'), '42501', null, 'Only admins and owners manage permits');
end;
$$;

create function tests.test_04_sanitation_checklist() returns setof text language plpgsql as $$
declare
  v_items jsonb;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  return next is((select count(*)::int from public.sanitation_items where tenant_id = tests.id('a')), 8,
    'A new organization starts with the suggested checklist');
  select jsonb_agg(jsonb_build_object('item_id', id, 'done', position <> 3, 'note', case when position = 3 then 'Tank lid broken' end))
  into v_items from public.sanitation_items where tenant_id = tests.id('a');
  return next is(public.record_sanitation_check(tests.id('a'), current_date, v_items), 8, 'The day''s checklist is ticked off');
  return next is((select count(*)::int from public.sanitation_checks where not done), 1, 'with items not done kept');
  return next is(public.record_sanitation_check(tests.id('a'), current_date, v_items), 8, 'Filling it in again updates it');
  return next is((select count(*)::int from public.sanitation_checks), 8, 'without duplicates');
  return next throws_ok(format('select public.record_sanitation_check(%L, current_date + 2, %L)', tests.id('a'), v_items),
    'P0001', 'The checklist can''t be filled in for a future day', 'Future days are refused');
  perform tests.as_user('carol');
  return next throws_ok(format('select public.record_sanitation_check(%L, current_date, %L)', tests.id('a'), v_items),
    '42501', null, 'Cashiers can''t fill it in');
  perform tests.as_user('bob');
  return next throws_like(format('select public.record_sanitation_check(%L, current_date, %L)', tests.id('b'), v_items),
    'Checklist item not found', 'Another organization''s items can''t be used');
end;
$$;

create function tests.test_05_daily_summary_quality_lines() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('sam');
  perform tests.run(current_date, 'morning', 10);
  perform public.record_water_test(tests.id('a'), current_date, 'afternoon', 9.5, 100, 0.2);
  perform tests.as_owner_db();
  return next ok(public.daily_summary_text(tests.id('a'), current_date) like
    '% Water tests failed: 1. No water test for: morning shift. Sanitation checklist not done.',
    'The summary mentions failed and missing water tests and a missed checklist');
end;
$$;

create function tests.test_06_offline() returns setof text language plpgsql as $$
declare
  v_result jsonb;
begin
  perform tests.seed();
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'water_test', 'actor_id', tests.id('sam'),
    'recorded_at', '2026-11-01 07:30:00+01',
    'payload', jsonb_build_object('date', '2026-11-01', 'shift', 'morning', 'ph', 7.1, 'tds', 90, 'chlorine', 0.21)));
  return next is(v_result ->> 'status', 'applied', 'A water test made offline syncs');
  return next is((select tested_at from public.water_tests where tenant_id = tests.id('a')),
    '2026-11-01 07:30:00+01'::timestamptz, 'at the time it was made');
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'sanitation_check', 'actor_id', tests.id('sam'),
    'recorded_at', '2026-11-01 08:00:00+01',
    'payload', jsonb_build_object('date', '2026-11-01', 'items',
      (select jsonb_agg(jsonb_build_object('item_id', id, 'done', true)) from public.sanitation_items where tenant_id = tests.id('a')))));
  return next is(v_result ->> 'status', 'applied', 'and so does the checklist');
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'water_test', 'actor_id', tests.id('carol'),
    'recorded_at', '2026-11-01 07:30:00+01',
    'payload', jsonb_build_object('date', '2026-11-01', 'shift', 'morning', 'ph', 7.1, 'tds', 90, 'chlorine', 0.21)));
  return next is(v_result ->> 'status', 'rejected', 'Role checks still apply offline');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
