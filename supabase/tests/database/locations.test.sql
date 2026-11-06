-- HydroTrack — factories and depots tests (pgTAP, xUnit style).
--
-- Main factory on creation, records stamped with the requested location,
-- staff limited to their locations (recording and seeing), stock per
-- location, transfers that keep batches traceable, changes only from a
-- record's own location, devices per location, totals per location.
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
  perform tests.create_user('alice', 'Alice Owner', 'alice@l-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@l-test.invalid');
  perform tests.create_user('sam', 'Sam Store', 'sam@l-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@l-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@l-test.invalid');
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


-- The app's x-location-id header (null = none).
create function tests.at(p_location text) returns void language plpgsql as $$
begin
  perform set_config('request.headers',
    case when p_location is null then '{}' else json_build_object('x-location-id', tests.id(p_location))::text end, true);
end;
$$;

-- A depot in A where carol (cashier) works; mike works at both.
create function tests.depot() returns void language plpgsql as $$
declare
  v_depot uuid;
begin
  perform tests.as_owner_db();
  -- More than one location needs Premium (migration 0036).
  update public.tenant_subscriptions set plan_key = 'premium' where tenant_id = tests.id('a');
  insert into public.locations (tenant_id, name, kind) values (tests.id('a'), 'Kano depot', 'depot') returning id into v_depot;
  insert into tests.fx (key, id) values ('depot', v_depot), ('main', public.main_location(tests.id('a')));
  delete from public.member_locations where tenant_id = tests.id('a') and user_id = tests.id('carol');
  insert into public.member_locations (tenant_id, user_id, location_id) values
    (tests.id('a'), tests.id('carol'), v_depot), (tests.id('a'), tests.id('mike'), v_depot);
end;
$$;

create function tests.sale(p_bags integer) returns uuid language sql as $$
  select public.record_sale(tests.id('a'), 'walk_in', null, p_bags * 400, p_bags * 400, 'cash', 0,
    jsonb_build_array(jsonb_build_object('product_id', tests.id('sachet'), 'quantity', p_bags, 'unit_price', 400)))
$$;

-- 100 bags made at the main factory (batch 261101-M-1).
create function tests.produce() returns uuid language plpgsql as $$
declare
  v_run uuid;
begin
  perform tests.as_user('sam');
  perform tests.at('main');
  v_run := public.record_production_run(tests.id('a'), '2026-11-01', 'morning', 'Machine 1', 'Ade', tests.id('sachet'), 100, 0);
  insert into tests.fx (key, id) values ('run', v_run);
  return v_run;
end;
$$;

create function tests.items_here(p_location text) returns setof public.stock_items language sql stable security definer as $$
  select * from public.stock_items where tenant_id = tests.id('a') and location_id = tests.id(p_location)
$$;

create function tests.test_01_main_factory_and_stamping() returns setof text language plpgsql as $$
declare
  v_sale uuid;
begin
  perform tests.seed();
  perform tests.as_owner_db();
  return next is((select name from public.locations where tenant_id = tests.id('a')), 'Main factory',
    'A new organization starts with "Main factory"');
  return next is((select count(*)::int from public.member_locations where tenant_id = tests.id('a')), 4,
    'and everyone works there');
  perform tests.depot();
  perform tests.produce();
  perform tests.as_user('alice');
  perform tests.at('main');
  v_sale := tests.sale(10);
  return next is((select location_id from public.sales where id = v_sale), tests.id('main'),
    'A record is stamped with the requested location');
  return next is((select location_id from public.cash_entries where sale_id = v_sale), tests.id('main'), 'and so is its cash');
  perform tests.as_user('carol');
  perform tests.at('main');
  return next throws_ok('select tests.sale(1)', '42501', null, 'Staff can''t record at a location they aren''t assigned to');
  perform tests.at(null);
  return next throws_like('select tests.sale(1)', 'Not enough stock%',
    'Without a header staff record at their own location (the depot, which has no stock)');
end;
$$;

create function tests.test_02_who_sees_what() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.depot();
  perform tests.produce();
  perform tests.as_user('alice');
  perform tests.at('main');
  perform tests.sale(10);
  perform tests.as_user('carol');
  perform tests.at(null);
  return next is((select count(*)::int from public.sales), 0, 'Depot staff don''t see the main factory''s sales');
  return next is((select count(*)::int from public.stock_items where location_id = tests.id('main')), 0,
    'or its stock');
  perform tests.at('main');
  return next is((select count(*)::int from public.sales), 0, 'not even by asking for it');
  perform tests.as_user('alice');
  perform tests.at(null);
  return next is((select count(*)::int from public.sales), 1, 'Owners see every location');
  perform tests.at('depot');
  return next is((select count(*)::int from public.sales), 0, 'narrowed to the one they pick');
  return next is((select count(*)::int from public.sale_lines), 0, 'child rows too');
end;
$$;

create function tests.test_03_transfers_keep_batches() returns setof text language plpgsql as $$
declare
  v_transfer uuid;
  v_sale uuid;
begin
  perform tests.seed();
  perform tests.depot();
  perform tests.produce();
  perform tests.as_user('sam');
  perform tests.at('main');
  return next throws_like(format('select public.send_transfer(%L, %L, %L)', tests.id('a'), tests.id('depot'),
    jsonb_build_array(jsonb_build_object('item_id', (select id from tests.items_here('main') where product_id = tests.id('sachet')), 'quantity', 500))),
    'Not enough 50cl Sachet to send (have 100)', 'Can''t send more than there is');
  v_transfer := public.send_transfer(tests.id('a'), tests.id('depot'),
    jsonb_build_array(jsonb_build_object('item_id', (select id from tests.items_here('main') where product_id = tests.id('sachet')), 'quantity', 30)),
    'Morning truck');
  return next is((select quantity_on_hand from tests.items_here('main') where product_id = tests.id('sachet')), 70,
    'Sending takes the stock out straight away');
  return next throws_like(format('select public.receive_transfer(%L, %L)', tests.id('a'), v_transfer),
    'This stock is going to Kano depot%', 'It can only be received at the depot');

  perform tests.as_user('mike');
  perform tests.at('depot');
  perform public.receive_transfer(tests.id('a'), v_transfer);
  return next is((select quantity_on_hand from tests.items_here('depot') where product_id = tests.id('sachet')), 30,
    'Receiving adds it at the depot');
  return next throws_like(format('select public.receive_transfer(%L, %L)', tests.id('a'), v_transfer),
    'This transfer was already received', 'once');
  return next is(public.location_transfers(tests.id('a')) -> 0 ->> 'from_location', 'Main factory',
    'The depot sees where it came from');
  return next is(public.location_transfers(tests.id('a')) -> 0 -> 'items' -> 0 ->> 'name', '50cl Sachet',
    'and what, though it can''t read the factory''s stock');

  perform tests.as_user('carol');
  perform tests.at('depot');
  v_sale := tests.sale(5);
  return next is((select batch_numbers from public.sales where id = v_sale), array['261101-M-1'],
    'A depot sale still knows the production batch');
  perform tests.as_user('mike');
  return next is((select count(*)::int from jsonb_array_elements(public.trace_batch(tests.id('a'), '261101-M-1') -> 'sales')), 1,
    'and tracing the batch finds it');
  return next is((select quantity_on_hand from tests.items_here('main') where product_id = tests.id('sachet')), 70,
    'The main factory''s stock is untouched by the depot sale');
end;
$$;

create function tests.test_04_changes_from_own_location() returns setof text language plpgsql as $$
declare
  v_sale uuid;
begin
  perform tests.seed();
  perform tests.depot();
  perform tests.produce();
  perform tests.as_user('alice');
  perform tests.at('main');
  v_sale := tests.sale(10);
  perform tests.at('depot');
  return next throws_like(format('select public.void_sale(%L, %L, %L)', tests.id('a'), v_sale, 'Mistake'),
    'This belongs to Main factory. Switch to Main factory to change it.', 'Voiding happens at the sale''s own location');
  perform tests.at('main');
  return next lives_ok(format('select public.void_sale(%L, %L, %L)', tests.id('a'), v_sale, 'Mistake'), 'which works');
end;
$$;

create function tests.test_05_production_uses_local_materials() returns setof text language plpgsql as $$
declare
  v_nylon uuid;
begin
  perform tests.seed();
  perform tests.depot();
  perform tests.as_user('alice');
  perform tests.at('main');
  insert into public.stock_items (tenant_id, name, category, unit) values (tests.id('a'), 'Nylon roll', 'raw_material', 'rolls')
  returning id into v_nylon;
  perform public.add_stock(tests.id('a'), v_nylon, 10, 'Delivery');
  insert into public.production_recipes (tenant_id, product_id, raw_material_item_id, quantity_used, per_bags)
  values (tests.id('a'), tests.id('sachet'), v_nylon, 1, 100);
  update public.locations set kind = 'factory' where id = tests.id('depot');
  perform tests.at('depot');
  return next throws_like(format('select public.record_production_run(%L, current_date, %L, %L, %L, %L, 100, 0)',
    tests.id('a'), 'morning', 'Machine 1', 'Ade', tests.id('sachet')),
    'Not enough raw material%', 'A second factory uses its own raw material, not the main factory''s');
  perform tests.at('main');
  perform public.record_production_run(tests.id('a'), current_date, 'morning', 'Machine 1', 'Ade', tests.id('sachet'), 100, 0);
  return next is((select quantity_on_hand from public.stock_items where id = v_nylon), 9, 'At the main factory it does');
end;
$$;

create function tests.test_06_devices_and_totals() returns setof text language plpgsql as $$
declare
  v_device jsonb;
  v_result jsonb;
begin
  perform tests.seed();
  perform tests.depot();
  perform tests.produce();
  perform tests.as_user('alice');
  perform tests.at('main');
  perform tests.sale(10);
  return next is((public.organization_totals(tests.id('a')) ->> 'total_revenue')::numeric, 4000::numeric,
    'Totals are for the location asked for');
  perform tests.at('depot');
  return next is((public.organization_totals(tests.id('a')) ->> 'total_revenue')::numeric, 0::numeric, 'per location');
  v_device := public.register_device(tests.id('a'), 'Depot phone');
  perform tests.as_owner_db();
  perform set_config('request.headers', '{}', true);
  return next is((select location_id from public.devices where id = (v_device ->> 'id')::uuid), tests.id('depot'),
    'A device is set up for the location it was set up at');
  return next ok(not exists (select 1 from jsonb_array_elements(public.device_members(v_device ->> 'key')) m
                             where m ->> 'user_id' = tests.id('sam')::text),
    'Only staff of that location (and owners/admins) can sign in on it');
  v_result := public.apply_device_operation(v_device ->> 'key', jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'expense', 'actor_id', tests.id('mike'), 'recorded_at', now(),
    'payload', jsonb_build_object('date', current_date, 'category', 'other', 'description', 'Broom', 'amount', 500, 'method', 'cash')));
  return next is((select location_id from public.expenses where description = 'Broom'), tests.id('depot'),
    'Its records go to its location');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
