-- HydroTrack — machines and generator tests (pgTAP, xUnit style).
--
-- The machine list and runs linked to it, diesel (expense posted),
-- maintenance tasks (due dates, alerts, cost), breakdowns (downtime,
-- repair cost), the machine report (diesel per bag, downtime), offline
-- records, and who may do what. One transaction, rolled back.
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
  perform tests.create_user('alice', 'Alice Owner', 'alice@m-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@m-test.invalid');
  perform tests.create_user('sam', 'Sam Store', 'sam@m-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@m-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@m-test.invalid');
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


create function tests.machine(p_name text) returns uuid language sql stable security definer as $$
  select id from public.machines where tenant_id = tests.id('a') and name = p_name
$$;

create function tests.test_01_machines_and_runs() returns setof text language plpgsql as $$
declare
  v_run uuid;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  return next is((select count(*)::int from public.machines where tenant_id = tests.id('a')), 3,
    'A new organization starts with Machine 1, Machine 2 and a generator');
  v_run := public.record_production_run(tests.id('a'), current_date, 'morning', 'machine 1', 'Ade', tests.id('sachet'), 100, 2);
  return next is((select machine_id from public.production_runs where id = v_run), tests.machine('Machine 1'),
    'A run is linked to its machine by name (any case)');
  v_run := public.record_production_run(tests.id('a'), current_date, 'morning', 'Old press', 'Ade', tests.id('sachet'), 10, 0);
  return next is((select machine_id from public.production_runs where id = v_run), null::uuid,
    'An unknown name is kept as typed');
  return next throws_ok(format('insert into public.machines (tenant_id, name) values (%L, %L)', tests.id('a'), 'Bottling line'),
    '42501', null, 'Store keepers can''t add machines');
  perform tests.as_user('mike');
  return next lives_ok(format('insert into public.machines (tenant_id, name) values (%L, %L)', tests.id('a'), 'Bottling line'),
    'Managers can');
  return next throws_ok(format('insert into public.machines (tenant_id, name) values (%L, %L)', tests.id('a'), ' machine 1 '),
    '23505', null, 'Names are unique in an organization');
end;
$$;

create function tests.test_02_diesel() returns setof text language plpgsql as $$
declare
  v_id uuid;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  v_id := public.record_diesel(tests.id('a'), tests.machine('Generator'), current_date, 50, 45000, 'cash', 6);
  return next ok(v_id is not null, 'Store keepers log diesel');
  return next is((select category::text || ' ' || amount from public.expenses where id =
                   (select expense_id from public.diesel_logs where id = v_id)), 'fuel_diesel 45000.00',
    'and its cost is posted as a diesel expense');
  return next is((select count(*)::int from public.cash_entries where tenant_id = tests.id('a') and direction = 'money_out'), 1,
    'paid out of cash');
  return next throws_ok(format('select public.record_diesel(%L, %L, current_date, 10, 9000, null)', tests.id('a'), tests.machine('Generator')),
    'P0001', 'Say how the fuel_diesel was paid (cash or transfer)', 'How it was paid is needed');
  perform tests.as_user('carol');
  return next throws_ok(format('select public.record_diesel(%L, %L, current_date, 10, 9000, %L)', tests.id('a'), tests.machine('Generator'), 'cash'),
    '42501', null, 'Cashiers can''t log diesel');
  perform tests.as_user('bob');
  return next throws_like(format('select public.record_diesel(%L, %L, current_date, 10, 9000, %L)', tests.id('b'), tests.machine('Generator'), 'cash'),
    'Machine not found', 'Another organization''s machine can''t be used');
  return next is((select count(*)::int from public.diesel_logs), 0, 'nor its logs seen');
end;
$$;

create function tests.test_03_maintenance() returns setof text language plpgsql as $$
declare
  v_task uuid;
begin
  perform tests.seed();
  perform tests.as_user('mike');
  insert into public.maintenance_tasks (tenant_id, machine_id, name, every_days, last_done_on)
  values (tests.id('a'), tests.machine('Machine 1'), 'Change filter', 30, current_date - 31)
  returning id into v_task;
  perform tests.as_owner_db();
  perform public.generate_alerts(now());
  perform public.generate_alerts(now());
  return next is((select count(*)::int from public.alerts where kind = 'maintenance_due'), 1,
    'An overdue task alerts the owner once');
  return next is((select body from public.alerts where kind = 'maintenance_due'),
    format('Change filter on Machine 1 is due since %s (every 30 days).', to_char(current_date - 1, 'DD Mon')),
    'saying since when');
  perform tests.as_user('sam');
  perform public.record_maintenance(tests.id('a'), v_task, current_date, 8000, 'transfer', 'New cartridge');
  return next is((select last_done_on from public.maintenance_tasks where id = v_task), current_date,
    'Marking it done restarts its schedule');
  return next is((select amount from public.expenses where category = 'maintenance' and tenant_id = tests.id('a')), 8000::numeric,
    'and its cost is posted as a maintenance expense');
  return next throws_ok(format('select public.record_maintenance(%L, %L, current_date + 1)', tests.id('a'), v_task),
    'P0001', 'Maintenance can''t be marked done for a future day', 'Future days are refused');
  return next throws_ok(format('insert into public.maintenance_tasks (tenant_id, machine_id, name, every_days) values (%L, %L, %L, 7)',
    tests.id('a'), tests.machine('Machine 1'), 'Grease'), '42501', null, 'Store keepers can''t add tasks');
end;
$$;

create function tests.test_04_breakdowns() returns setof text language plpgsql as $$
declare
  v_id uuid;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  v_id := public.report_breakdown(tests.id('a'), tests.machine('Machine 2'), now() - interval '5 hours', 'Sealer jaw broke');
  return next throws_like(format('select public.report_breakdown(%L, %L, now(), %L)', tests.id('a'), tests.machine('Machine 2'), 'Again'),
    'This machine already has an open breakdown%', 'One open breakdown per machine');
  return next throws_like(format('select public.end_breakdown(%L, %L, now() - interval %L)', tests.id('a'), v_id, '6 hours'),
    'The machine must restart after it stopped', 'It must restart after it stopped');
  perform public.end_breakdown(tests.id('a'), v_id, now() - interval '1 hour', 25000, 'cash', 'Welded');
  return next is((select repair_cost from public.breakdowns where id = v_id), 25000::numeric, 'Marking it fixed keeps the repair cost');
  return next is((select description from public.expenses where tenant_id = tests.id('a')), 'Repair: Machine 2 (Sealer jaw broke)',
    'posted as a maintenance expense');
  return next throws_like(format('select public.end_breakdown(%L, %L, now())', tests.id('a'), v_id),
    'This breakdown was already marked fixed', 'It can''t be fixed twice');
end;
$$;

create function tests.test_05_report() returns setof text language plpgsql as $$
declare
  v_report jsonb;
  v_machine jsonb;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  perform public.record_production_run(tests.id('a'), current_date, 'morning', 'Machine 1', 'Ade', tests.id('sachet'), 400, 0);
  perform public.record_production_run(tests.id('a'), current_date, 'afternoon', 'Machine 2', 'Ade', tests.id('sachet'), 100, 0);
  perform public.record_diesel(tests.id('a'), tests.machine('Generator'), current_date, 20, 20000, 'cash');
  perform public.end_breakdown(tests.id('a'),
    public.report_breakdown(tests.id('a'), tests.machine('Machine 2'), now() - interval '3 hours', 'Belt'),
    now() - interval '30 minutes');
  v_report := public.machine_report(tests.id('a'), current_date, current_date + 1);
  return next is((v_report ->> 'litres_per_100_bags')::numeric, 4::numeric, 'Diesel per bag: 20 litres for 500 bags = 4 per 100');
  return next is((v_report ->> 'diesel_cost_per_bag')::numeric, 40::numeric, 'and ₦40 a bag');
  select m into v_machine from jsonb_array_elements(v_report -> 'machines') m where m ->> 'name' = 'Machine 2';
  return next is((v_machine ->> 'downtime_hours')::numeric, 2.5, 'Downtime hours per machine');
  return next is((v_machine ->> 'bags')::int, 100, 'and bags per machine');
  perform tests.as_user('bob');
  return next throws_ok(format('select public.machine_report(%L, current_date, current_date + 1)', tests.id('a')),
    '42501', null, 'Other organizations can''t see the report');
end;
$$;

create function tests.test_06_offline() returns setof text language plpgsql as $$
declare
  v_breakdown uuid := gen_random_uuid();
  v_result jsonb;
begin
  perform tests.seed();
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'breakdown', 'actor_id', tests.id('sam'), 'recorded_at', now() - interval '2 hours',
    'payload', jsonb_build_object('id', v_breakdown, 'machine_id', tests.machine('Machine 1'),
      'started_at', now() - interval '2 hours', 'cause', 'Power surge')));
  return next is(v_result ->> 'status', 'applied', 'A breakdown reported offline syncs');
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'breakdown_end', 'actor_id', tests.id('sam'), 'recorded_at', now() - interval '1 hour',
    'payload', jsonb_build_object('breakdown_id', v_breakdown, 'ended_at', now() - interval '1 hour',
      'repair_cost', 5000, 'method', 'cash')));
  return next is(v_result ->> 'status', 'applied', 'and so does marking it fixed, by the id the device gave it');
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'diesel', 'actor_id', tests.id('sam'), 'recorded_at', now(),
    'payload', jsonb_build_object('machine_id', tests.machine('Generator'), 'date', current_date,
      'litres', 30, 'cost', 27000, 'method', 'cash')));
  return next is(v_result ->> 'status', 'applied', 'Diesel logged offline syncs');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
