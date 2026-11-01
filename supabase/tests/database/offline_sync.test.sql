-- HydroTrack — offline device tests (pgTAP, xUnit style).
--
-- Device set-up and switch-off, offline sign-in checks, and replaying
-- records made offline: exactly once, as the staff member who made them,
-- at the time they were made, with the agreed record-and-flag rules for
-- short stock / raw material / credit limit, rejected records kept, and
-- no reach into another organization.
--
-- One transaction, rolled back at the end: nothing persists.
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

-- A tenant's product by its old enum name (the 4 starter products keep
-- it as legacy_key). Security definer so it works whatever role is active.
create function tests.product(p_tenant uuid, p_key text) returns uuid
language sql stable security definer as $$
  select id from public.products where tenant_id = p_tenant and legacy_key = p_key
$$;

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

-- Organization A (owner alice; cashier carol; manager mike; store keeper
-- sam) with 100 sachet bags, 10 nylon rolls (1 roll per 100 bags), a
-- distributor with a 10,000 credit limit, a driver and a vehicle, and a
-- set-up device. Organization B (owner bob) with its own customer.
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_b uuid;
  v_device jsonb;
  v_nylon uuid;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@offline-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@offline-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@offline-test.invalid');
  perform tests.create_user('sam', 'Sam Store', 'sam@offline-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@offline-test.invalid');

  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  perform tests.as_user('bob');
  v_b := (public.create_tenant('Other Water')).id;
  perform tests.as_owner_db();
  insert into tests.fx (key, id) values ('a', v_a), ('b', v_b);

  insert into public.tenant_members (tenant_id, user_id, role) values
    (v_a, tests.id('carol'), 'cashier'),
    (v_a, tests.id('mike'), 'manager'),
    (v_a, tests.id('sam'), 'store_keeper');

  perform tests.as_user('alice');
  perform public.add_stock(v_a,
    (select id from public.stock_items where tenant_id = v_a and product_id = tests.product(v_a, 'sachet50cl')), 100, 'Opening');
  insert into public.stock_items (tenant_id, name, category, unit)
  values (v_a, 'Nylon roll', 'raw_material', 'rolls') returning id into v_nylon;
  perform public.add_stock(v_a, v_nylon, 10, 'Delivery');
  insert into public.production_recipes (tenant_id, product_id, raw_material_item_id, quantity_used, per_bags)
  values (v_a, tests.product(v_a, 'sachet50cl'), v_nylon, 1, 100);
  v_device := public.register_device(v_a, 'Front desk phone');
  perform tests.as_owner_db();

  insert into tests.fx (key, id) values
    ('nylon', v_nylon),
    ('sachet', (select id from public.stock_items where tenant_id = v_a and product_id = tests.product(v_a, 'sachet50cl')));
  insert into tests.fx (key, id, note) values ('device', (v_device ->> 'id')::uuid, v_device ->> 'key');

  insert into public.customers (tenant_id, name, phone, area, credit_limit)
  values (v_a, 'Musa Stores', '08031234567', 'Kano', 10000);
  insert into tests.fx (key, id) select 'musa', id from public.customers where tenant_id = v_a;
  insert into public.customers (tenant_id, name, phone, area, credit_limit)
  values (v_b, 'Bob Customer', '08030000000', 'Abuja', 5000);
  insert into tests.fx (key, id) select 'bob_customer', id from public.customers where tenant_id = v_b;
  insert into public.drivers (tenant_id, name, phone) values (v_a, 'Yakubu', '08099998888');
  insert into public.vehicles (tenant_id, name) values (v_a, 'Hilux');
  insert into tests.fx (key, id)
  select 'driver', id from public.drivers where tenant_id = v_a
  union all select 'vehicle', id from public.vehicles where tenant_id = v_a;
end;
$$;

-- Sends one record from organization A's device.
create function tests.apply(p_actor text, p_type text, p_payload jsonb,
  p_op_id uuid default gen_random_uuid(), p_recorded_at timestamptz default '2026-10-30 09:15:00+01')
returns jsonb language sql as $$
  select public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', p_op_id, 'type', p_type, 'actor_id', tests.id(p_actor),
    'recorded_at', p_recorded_at, 'payload', p_payload));
$$;

create function tests.sale(p_bags integer, p_credit numeric default 0) returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'customer_type', case when p_credit > 0 then 'distributor' else 'walk_in' end,
    'customer_name', case when p_credit > 0 then 'Musa Stores' end,
    'total', p_bags * 400,
    'amount_paid', p_bags * 400 - p_credit,
    'payment_method', case when p_credit > 0 then 'credit' else 'cash' end,
    'balance', p_credit,
    'lines', jsonb_build_array(jsonb_build_object('product', 'sachet50cl', 'quantity', p_bags, 'unit_price', 400)),
    'paid_channel', null);
$$;

-- =========================================================================
-- Tests
-- =========================================================================

create function tests.test_01_setting_up_devices() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  return next is((select count(*)::int from public.devices where tenant_id = tests.id('a')), 1,
    'An owner can set up a device');
  return next isnt((select key_hash from public.devices where id = tests.id('device')), tests.note('device'),
    'Only a hash of the device key is stored');

  perform tests.as_user('carol');
  return next throws_ok(format('select public.register_device(%L, %L)', tests.id('a'), 'Mine'), '42501', null,
    'A cashier can''t set up devices');
  return next is((select count(*)::int from public.devices), 0, 'Staff below admin can''t see devices');
  perform tests.as_user('bob');
  return next is((select count(*)::int from public.devices where tenant_id = tests.id('a')), 0,
    'Other organizations can''t see them');
  return next throws_ok(format('select public.revoke_device(%L, %L)', tests.id('a'), tests.id('device')), '42501', null,
    'Other organizations can''t switch them off');

  perform tests.as_owner_db();
  return next throws_ok('select public.device_members(''not-a-key'')', '42501', null,
    'A wrong key gets nothing');
  perform tests.as_user('alice');
  perform public.revoke_device(tests.id('a'), tests.id('device'));
  perform tests.as_owner_db();
  return next throws_ok(format('select public.device_members(%L)', tests.note('device')), '42501', null,
    'A switched-off device gets nothing');
end;
$$;

create function tests.test_02_offline_sign_in_checks() returns setof text language plpgsql as $$
declare
  v_members jsonb;
begin
  perform tests.seed();
  perform tests.as_user('carol');
  perform public.set_my_offline_credential(repeat('ab', 16), repeat('cd', 32), 60000);
  perform tests.as_owner_db();

  v_members := public.device_members(tests.note('device'));
  return next is(jsonb_array_length(v_members), 4, 'The device gets organization A''s 4 members');
  return next is(
    (select m -> 'credential' ->> 'hash' from jsonb_array_elements(v_members) m where m ->> 'user_id' = tests.id('carol')::text),
    repeat('cd', 32), 'with each member''s offline sign-in check');
  return next ok(
    not exists (select 1 from jsonb_array_elements(v_members) m where m ->> 'user_id' = tests.id('bob')::text),
    'and nobody from another organization');
  return next is((select count(*)::int from public.offline_credentials where hash like '%carol%'), 0,
    'Only hashes are stored');

  perform tests.as_user('carol');
  return next is((select count(*)::int from public.offline_credentials), 0,
    'Nobody can read sign-in checks through the API');
  return next throws_ok(format('select public.device_members(%L)', tests.note('device')), '42501', null,
    'Signed-in users can''t download a device''s staff list');
  return next throws_ok(
    format('select public.apply_device_operation(%L, %L)', tests.note('device'), '{}'),
    '42501', null, 'Signed-in users can''t send device records directly');
end;
$$;

create function tests.test_03_sale_applied_once_as_its_recorder() returns setof text language plpgsql as $$
declare
  v_op uuid := gen_random_uuid();
  v_result jsonb;
begin
  perform tests.seed();
  v_result := tests.apply('carol', 'sale', tests.sale(10), v_op);
  return next is(v_result ->> 'status', 'applied', 'A cashier''s offline sale is applied');
  return next is(
    (select recorded_by from public.sales where id = (v_result -> 'result' ->> 'id')::uuid),
    tests.id('carol'), 'recorded under the cashier who made it');
  return next is(
    (select date_time from public.sales where id = (v_result -> 'result' ->> 'id')::uuid),
    '2026-10-30 09:15:00+01'::timestamptz, 'at the time it was made on the device');
  return next is(
    (select quantity_on_hand from public.stock_items where id = tests.id('sachet')), 90,
    'Stock goes down');

  v_result := tests.apply('carol', 'sale', tests.sale(10), v_op);
  return next is(v_result ->> 'status', 'applied', 'Sending the same record again is fine');
  return next is((select count(*)::int from public.sales where tenant_id = tests.id('a')), 1,
    '... and doesn''t create a second sale');
  return next is((select quantity_on_hand from public.stock_items where id = tests.id('sachet')), 90,
    '... or take stock twice');
end;
$$;

create function tests.test_04_short_stock_recorded_and_flagged() returns setof text language plpgsql as $$
declare
  v_result jsonb;
begin
  perform tests.seed();
  v_result := tests.apply('carol', 'sale', tests.sale(150));
  return next is(v_result ->> 'status', 'applied', 'An offline sale larger than the stock left is still saved');
  return next is((select quantity_on_hand from public.stock_items where id = tests.id('sachet')), -50,
    'Stock shows the shortfall');
  return next is(
    (select kind from public.sync_flags where sale_id = (v_result -> 'result' ->> 'id')::uuid),
    'short_stock', 'and the sale is flagged for checking');

  perform tests.as_user('carol');
  return next throws_ok(
    format($q$select public.record_sale(%L, 'walk_in', null, 400, 400, 'cash', 0,
      '[{"product": "sachet50cl", "quantity": 1, "unit_price": 400}]'::jsonb)$q$, tests.id('a')),
    'P0001', null, 'Online sales are still blocked when stock is short');
end;
$$;

create function tests.test_05_credit_limit_flag() returns setof text language plpgsql as $$
declare
  v_result jsonb;
begin
  perform tests.seed();
  v_result := tests.apply('carol', 'sale', tests.sale(20, 8000));
  return next is((select count(*)::int from public.sync_flags where tenant_id = tests.id('a')), 0,
    'A credit sale within the limit isn''t flagged');
  v_result := tests.apply('carol', 'sale', tests.sale(20, 8000));
  return next is((select balance from public.customers where id = tests.id('musa')), 16000::numeric,
    'A second offline credit sale is saved');
  return next is(
    (select kind from public.sync_flags where sale_id = (v_result -> 'result' ->> 'id')::uuid),
    'over_credit_limit', 'and flagged because it took the customer over their limit');
end;
$$;

create function tests.test_06_production_short_raw_material() returns setof text language plpgsql as $$
declare
  v_result jsonb;
begin
  perform tests.seed();
  v_result := tests.apply('sam', 'production_run', jsonb_build_object(
    'date', '2026-10-30', 'shift', 'morning', 'machine', 'Machine 1', 'operator_name', 'Musa',
    'product', 'sachet50cl', 'quantity_produced', 1500, 'wastage', 0, 'expiry_date', null));
  return next is(v_result ->> 'status', 'applied', 'Production needing more raw material than recorded is saved');
  return next is(
    (select kind from public.sync_flags where production_run_id = (v_result -> 'result' ->> 'id')::uuid),
    'short_raw_material', 'and flagged');
  return next is((select quantity_on_hand from public.stock_items where id = tests.id('sachet')), 1600,
    'The bags produced are added to stock');
end;
$$;

create function tests.test_07_refused_records_are_kept() returns setof text language plpgsql as $$
declare
  v_op uuid := gen_random_uuid();
  v_result jsonb;
begin
  perform tests.seed();
  v_result := tests.apply('sam', 'sale', tests.sale(5), v_op);
  return next is(v_result ->> 'status', 'rejected', 'A store keeper''s sale is refused (role check still applies)');
  return next is((select count(*)::int from public.sales where tenant_id = tests.id('a')), 0, 'Nothing is written');
  return next is((select status from public.device_operations where op_id = v_op), 'rejected',
    'The refused record is kept on the server with its reason');

  update public.tenant_members set is_active = false where tenant_id = tests.id('a') and user_id = tests.id('carol');
  v_op := gen_random_uuid();
  v_result := tests.apply('carol', 'sale', tests.sale(5), v_op);
  return next is(v_result ->> 'status', 'rejected', 'A deactivated member''s offline sale is refused');
  update public.tenant_members set is_active = true where tenant_id = tests.id('a') and user_id = tests.id('carol');
  v_result := tests.apply('carol', 'sale', tests.sale(5), v_op);
  return next is(v_result ->> 'status', 'applied', 'and goes through when retried after reactivation');

  v_result := tests.apply('bob', 'sale', tests.sale(5));
  return next is(v_result ->> 'status', 'rejected', 'Someone outside the organization can''t record on its device');
end;
$$;

create function tests.test_08_other_daily_records() returns setof text language plpgsql as $$
declare
  v_customer uuid := gen_random_uuid();
  v_load_op uuid := gen_random_uuid();
  v_result jsonb;
begin
  perform tests.seed();
  v_result := tests.apply('carol', 'customer', jsonb_build_object(
    'id', v_customer, 'name', 'New Shop', 'phone', '08022223333', 'area', 'Zaria', 'credit_limit', 20000));
  return next is(v_result ->> 'status', 'applied', 'A customer added offline is saved');
  return next is((select name from public.customers where id = v_customer and tenant_id = tests.id('a')), 'New Shop',
    'with the id the device gave it');

  update public.customers set balance = 5000 where id = v_customer;
  v_result := tests.apply('carol', 'customer_payment', jsonb_build_object(
    'customer_id', v_customer, 'amount', 2000, 'channel', 'cash', 'date', '2026-10-30', 'note', 'Part payment'));
  return next is((select balance from public.customers where id = v_customer), 3000::numeric,
    'A payment from that customer recorded offline is applied');

  v_result := tests.apply('mike', 'expense', jsonb_build_object(
    'date', '2026-10-30', 'category', 'fuel_diesel', 'description', 'Diesel', 'amount', 15000, 'method', 'cash'));
  return next is(v_result ->> 'status', 'applied', 'An offline expense is applied');

  v_result := tests.apply('sam', 'stock_in', jsonb_build_object('item_id', tests.id('nylon'), 'quantity', 5, 'note', 'Delivery'));
  return next is((select quantity_on_hand from public.stock_items where id = tests.id('nylon')), 15,
    'Offline stock-in is applied');
  v_result := tests.apply('sam', 'stock_count', jsonb_build_object('item_id', tests.id('nylon'), 'new_count', 12, 'note', 'Count'));
  return next is((select quantity_on_hand from public.stock_items where id = tests.id('nylon')), 12,
    'Offline stock count is applied');

  v_result := tests.apply('mike', 'load_out', jsonb_build_object(
    'driver_id', tests.id('driver'), 'vehicle_id', tests.id('vehicle'), 'product', 'sachet50cl',
    'bags_loaded', 40, 'note', null), v_load_op);
  v_result := tests.apply('mike', 'driver_return', jsonb_build_object(
    'load_out_op_id', v_load_op, 'bags_sold', 30, 'bags_returned', 10, 'bags_damaged', 0,
    'cash_returned', 12000, 'unit_price', 400, 'amount_paid', 12000, 'payment_method', 'cash'));
  return next is(v_result ->> 'status', 'applied',
    'A driver return for a load-out also made offline is matched to it');
  return next is(
    (select status::text from public.load_outs where tenant_id = tests.id('a')), 'settled',
    'and settles that trip');
end;
$$;

create function tests.test_09_no_reach_into_another_organization() returns setof text language plpgsql as $$
declare
  v_result jsonb;
begin
  perform tests.seed();
  update public.customers set balance = 3000 where id = tests.id('bob_customer');
  v_result := tests.apply('alice', 'customer_payment', jsonb_build_object(
    'customer_id', tests.id('bob_customer'), 'amount', 1000, 'channel', 'cash', 'date', '2026-10-30', 'note', 'x'));
  return next is(v_result ->> 'status', 'rejected', 'A device can''t record against another organization''s customer');
  return next is((select balance from public.customers where id = tests.id('bob_customer')), 3000::numeric,
    'Their balance is untouched');
end;
$$;

create function tests.test_10_checking_flags() returns setof text language plpgsql as $$
declare
  v_flag uuid;
begin
  perform tests.seed();
  perform tests.apply('carol', 'sale', tests.sale(150));
  v_flag := (select id from public.sync_flags where tenant_id = tests.id('a'));

  perform tests.as_user('carol');
  return next is((select count(*)::int from public.sync_flags), 1, 'Members can see their organization''s flags');
  return next throws_ok(format('select public.mark_sync_flag_checked(%L, %L)', tests.id('a'), v_flag), '42501', null,
    'A cashier can''t mark them checked');
  perform tests.as_user('bob');
  return next is((select count(*)::int from public.sync_flags), 0, 'Other organizations can''t see them');
  perform tests.as_user('mike');
  perform public.mark_sync_flag_checked(tests.id('a'), v_flag);
  return next isnt((select checked_at from public.sync_flags where id = v_flag), null, 'A manager can');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
