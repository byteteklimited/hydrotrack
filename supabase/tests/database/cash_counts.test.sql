-- HydroTrack — end-of-day cash count tests (pgTAP, xUnit style).
--
-- Expected cash per cashier, notes for mismatches, shortages flagged,
-- managers confirm, privacy between cashiers and organizations, and
-- counts made offline. One transaction, rolled back.
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


-- Organization A: owner alice, manager mike, cashiers carol and cate,
-- 100 sachet bags, a set-up device. Organization B: owner bob.
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_device jsonb;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@count-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@count-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@count-test.invalid');
  perform tests.create_user('cate', 'Cate Cashier', 'cate@count-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@count-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  perform tests.as_user('bob');
  perform public.create_tenant('Other Water');
  perform tests.as_owner_db();
  insert into tests.fx (key, id) values ('a', v_a), ('sachet', tests.product(v_a, 'sachet50cl'));
  insert into public.tenant_members (tenant_id, user_id, role) values
    (v_a, tests.id('mike'), 'manager'), (v_a, tests.id('carol'), 'cashier'), (v_a, tests.id('cate'), 'cashier');
  perform tests.as_user('alice');
  perform public.add_stock(v_a, (select id from public.stock_items where product_id = tests.id('sachet')), 100, 'Opening');
  v_device := public.register_device(v_a, 'Till');
  perform tests.as_owner_db();
  insert into tests.fx (key, id, note) values ('device', (v_device ->> 'id')::uuid, v_device ->> 'key');
end;
$$;

-- A cash walk-in sale of p_bags at 400 by whoever is signed in.
create function tests.cash_sale(p_bags integer) returns uuid language sql as $$
  select public.record_sale(tests.id('a'), 'walk_in', null, p_bags * 400, p_bags * 400, 'cash', 0,
    jsonb_build_array(jsonb_build_object('product_id', tests.id('sachet'), 'quantity', p_bags, 'unit_price', 400)));
$$;

create function tests.test_01_expected_cash_is_the_cashiers_own() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('carol');
  perform tests.cash_sale(10);
  perform tests.as_user('cate');
  perform tests.cash_sale(5);
  perform tests.as_user('carol');
  return next is((public.my_expected_cash(tests.id('a')) ->> 'expected')::numeric, 4000::numeric,
    'A cashier is expected to hold only the cash they took (not another cashier''s)');

  perform tests.as_user('mike');
  perform tests.cash_sale(2);
  perform public.record_expense(tests.id('a'), current_date, 'fuel_diesel', 'Diesel', 300, 'cash');
  perform public.record_expense(tests.id('a'), current_date, 'other', 'Bank charges', 50, 'transfer');
  return next is(public.my_expected_cash(tests.id('a')) - 'since',
    '{"cash_in": 800, "cash_out": 300, "expected": 500}'::jsonb,
    'Cash out they paid comes off; transfers don''t count');
end;
$$;

create function tests.test_02_counting() returns setof text language plpgsql as $$
declare
  v_count public.cash_counts;
begin
  perform tests.seed();
  perform tests.as_user('carol');
  perform tests.cash_sale(10);
  return next throws_ok(format('select public.record_cash_count(%L, 3500, null)', tests.id('a')),
    'P0001', null, 'A count that doesn''t match needs a note');
  v_count := public.record_cash_count(tests.id('a'), 3500, 'Gave change from my own money earlier');
  return next is(v_count.difference, -500::numeric, 'The shortage is recorded');
  perform tests.as_owner_db();
  return next is((select kind from public.sync_flags where cash_count_id = v_count.id), 'cash_short',
    'and flagged for the owner');

  perform tests.as_user('carol');
  return next is((public.my_expected_cash(tests.id('a')) ->> 'expected')::numeric, 0::numeric,
    'After counting, the next count starts from zero');
  -- Time passes (a test runs in one transaction, where now() stands still).
  perform tests.as_owner_db();
  update public.cash_counts set counted_at = now() - interval '1 minute' where id = v_count.id;
  update public.cash_entries set created_at = now() - interval '2 minutes' where recorded_by = tests.id('carol');
  perform tests.as_user('carol');
  perform tests.cash_sale(1);
  v_count := public.record_cash_count(tests.id('a'), 400, null);
  return next is(v_count.difference, 0::numeric, 'A later count covers only what came after');
  return next is((select count(*)::int from public.sync_flags where cash_count_id = v_count.id), 0,
    'A matching count isn''t flagged');
end;
$$;

create function tests.test_03_confirming_and_privacy() returns setof text language plpgsql as $$
declare
  v_count public.cash_counts;
begin
  perform tests.seed();
  perform tests.as_user('carol');
  v_count := public.record_cash_count(tests.id('a'), 0, null);
  return next throws_ok(format('select public.confirm_cash_count(%L, %L)', tests.id('a'), v_count.id),
    '42501', null, 'A cashier can''t confirm counts');
  perform tests.as_user('cate');
  perform public.record_cash_count(tests.id('a'), 0, null);
  return next is((select count(*)::int from public.cash_counts), 1, 'Cashiers see only their own counts');
  perform tests.as_user('mike');
  return next is((select count(*)::int from public.cash_counts), 2, 'Managers see everyone''s');
  perform public.confirm_cash_count(tests.id('a'), v_count.id);
  return next isnt((select confirmed_at from public.cash_counts where id = v_count.id), null,
    'and confirm them');
  perform tests.as_user('bob');
  return next is((select count(*)::int from public.cash_counts), 0, 'Other organizations see none');
  return next throws_ok(format('select public.my_expected_cash(%L)', tests.id('a')), '42501', null,
    'or anyone''s expected cash');
end;
$$;

create function tests.test_04_offline() returns setof text language plpgsql as $$
declare
  v_result jsonb;
begin
  perform tests.seed();
  perform tests.as_owner_db();
  perform public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'sale', 'actor_id', tests.id('carol'),
    'recorded_at', now() - interval '2 hours', 'payload', jsonb_build_object(
      'customer_type', 'walk_in', 'customer_name', null, 'total', 2000, 'amount_paid', 2000,
      'payment_method', 'cash', 'balance', 0, 'paid_channel', null,
      'lines', jsonb_build_array(jsonb_build_object('product_id', tests.id('sachet'), 'quantity', 5, 'unit_price', 400)))));
  return next is(
    (select created_at from public.cash_entries where recorded_by = tests.id('carol')),
    now() - interval '2 hours', 'Cash from an offline sale keeps the time it was made');

  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'cash_count', 'actor_id', tests.id('carol'),
    'recorded_at', now() - interval '1 hour', 'payload', jsonb_build_object('counted', 2000, 'note', null)));
  return next is(v_result ->> 'status', 'applied', 'A count made offline syncs');
  return next is((select expected from public.cash_counts where cashier_id = tests.id('carol')), 2000::numeric,
    'against what the cashier had recorded before it');

  perform tests.as_user('mike');
  return next lives_ok(format(
    $q$insert into public.cash_entries (tenant_id, direction, source, amount, method, recorded_by)
       values (%L, 'money_in', 'other', 1, 'cash', %L)$q$, tests.id('a'), tests.id('mike')),
    'Manual cash book entries still work');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
