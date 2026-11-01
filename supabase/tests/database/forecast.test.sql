-- HydroTrack — stock run-out forecast tests (pgTAP, xUnit style).
--
-- Daily rate from the last 30 days' use (not stock counts), items with
-- less history, the run-out alert (weekly, not for items already low),
-- and who may see forecasts. One transaction, rolled back.
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
  perform tests.create_user('alice', 'Alice Owner', 'alice@f-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@f-test.invalid');
  perform tests.create_user('sam', 'Sam Store', 'sam@f-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@f-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@f-test.invalid');
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


-- A raw material in A with p_on_hand now and reorder level 2; movements
-- are added by tests.move.
create function tests.item(p_key text, p_on_hand integer) returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  insert into public.stock_items (tenant_id, name, category, unit, quantity_on_hand, reorder_level)
  values (tests.id('a'), initcap(p_key), 'raw_material', 'rolls', p_on_hand, 2) returning id into v_id;
  insert into tests.fx (key, id) values (p_key, v_id);
  return v_id;
end;
$$;

create function tests.move(p_item text, p_type text, p_quantity integer, p_days_ago integer) returns void language sql as $$
  insert into public.stock_movements (tenant_id, item_id, type, quantity, by_whom, at)
  values (tests.id('a'), tests.id(p_item), p_type::public.movement_type, p_quantity, tests.id('alice'),
          now() - make_interval(days => p_days_ago));
$$;

create function tests.forecast(p_item text) returns jsonb language sql stable as $$
  select f from jsonb_array_elements(public.stock_forecast(tests.id('a'))) f
  where f ->> 'item_id' = tests.id(p_item)::text
$$;

create function tests.test_01_rate_and_days_left() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_owner_db();
  perform tests.item('nylon', 100);
  perform tests.move('nylon', 'stock_in', 160, 40);
  perform tests.move('nylon', 'production_use', -30, 20);
  perform tests.move('nylon', 'production_use', -30, 5);
  perform tests.move('nylon', 'production_use', -50, 35);
  perform tests.move('nylon', 'adjustment', -5, 3);
  perform tests.as_user('sam');
  return next is((tests.forecast('nylon') ->> 'per_day')::numeric, 2::numeric,
    '60 used in the last 30 days = 2 a day (older use and stock counts left out)');
  return next is((tests.forecast('nylon') ->> 'days_left')::numeric, 50::numeric, '100 on hand lasts 50 days');

  perform tests.as_owner_db();
  perform tests.item('preforms', 40);
  perform tests.move('preforms', 'stock_in', 60, 10);
  perform tests.move('preforms', 'stock_out', -20, 2);
  perform tests.as_user('sam');
  return next is((tests.forecast('preforms') ->> 'per_day')::numeric, 2::numeric,
    'An item with 10 days of history is averaged over those 10 days');

  perform tests.as_owner_db();
  perform tests.item('caps', 50);
  perform tests.as_user('sam');
  return next is(tests.forecast('caps') ->> 'days_left', null, 'No use, no forecast');
  perform tests.as_user('bob');
  return next throws_ok(format('select public.stock_forecast(%L)', tests.id('a')), '42501', null,
    'Other organizations can''t see it');
end;
$$;

create function tests.test_02_runout_alert() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_owner_db();
  perform tests.item('nylon', 10);
  perform tests.move('nylon', 'stock_in', 70, 40);
  perform tests.move('nylon', 'production_use', -60, 10);
  perform tests.item('labels', 1);
  perform tests.move('labels', 'stock_in', 31, 40);
  perform tests.move('labels', 'production_use', -30, 10);
  perform public.generate_alerts(now());
  perform public.generate_alerts(now());
  return next is((select count(*)::int from public.alerts where kind = 'stock_runout'), 1,
    'An item running out within a week alerts the owner once');
  return next is((select body from public.alerts where kind = 'stock_runout'),
    'Nylon will run out in about 5 days at the current rate (about 2 rolls a day).', 'saying when');
  return next is((select count(*)::int from public.alerts where kind = 'stock_runout' and item_id = tests.id('labels')), 0,
    'Items already at their reorder level get the low-stock alert instead');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
