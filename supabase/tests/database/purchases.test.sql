-- HydroTrack — purchases and costing tests (pgTAP, xUnit style).
--
-- Purchases with average cost, what we owe suppliers, production cost per
-- bag, cost kept on sale lines, and who may buy/pay. One transaction,
-- rolled back.
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


-- Organization A: owner alice, store keeper sam, cashier carol; nylon
-- (1 roll per 100 sachet bags). Organization B: owner bob.
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_b uuid;
  v_nylon uuid;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@cost-test.invalid');
  perform tests.create_user('sam', 'Sam Store', 'sam@cost-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@cost-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@cost-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  perform tests.as_user('bob');
  v_b := (public.create_tenant('Other Water')).id;
  perform tests.as_owner_db();
  insert into public.tenant_members (tenant_id, user_id, role) values
    (v_a, tests.id('sam'), 'store_keeper'), (v_a, tests.id('carol'), 'cashier');
  perform tests.as_user('alice');
  insert into public.stock_items (tenant_id, name, category, unit)
  values (v_a, 'Nylon roll', 'raw_material', 'rolls') returning id into v_nylon;
  insert into public.production_recipes (tenant_id, product_id, raw_material_item_id, quantity_used, per_bags)
  values (v_a, tests.product(v_a, 'sachet50cl'), v_nylon, 1, 100);
  perform tests.as_owner_db();
  insert into tests.fx (key, id) values ('a', v_a), ('b', v_b), ('nylon', v_nylon),
    ('sachet', tests.product(v_a, 'sachet50cl')),
    ('supplier', (select (public.create_supplier(v_a, 'Kano Plastics', '08030000001')).id
                  from (select tests.as_user('alice')) x));
  perform tests.as_owner_db();
end;
$$;

create function tests.buy(p_rolls integer, p_price numeric, p_paid numeric) returns uuid language sql as $$
  select public.record_purchase(tests.id('a'), tests.id('supplier'), current_date,
    jsonb_build_array(jsonb_build_object('item_id', tests.id('nylon'), 'quantity', p_rolls, 'unit_cost', p_price)),
    p_paid, case when p_paid > 0 then 'cash'::public.payment_channel end, null);
$$;

create function tests.test_01_purchases_and_average_cost() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('sam');
  perform tests.buy(10, 1000, 0);
  perform tests.buy(10, 1200, 2000);
  perform tests.as_owner_db();
  return next is((select quantity_on_hand || '/' || average_cost::numeric(10,2) from public.stock_items where id = tests.id('nylon')),
    '20/1100.00', 'Purchases add stock and average the cost (10 at 1,000 + 10 at 1,200)');
  return next is((select balance from public.suppliers where id = tests.id('supplier')), 20000::numeric,
    'What we owe the supplier: 22,000 bought - 2,000 paid');
  return next is((select amount from public.cash_entries where source = 'purchase' and tenant_id = tests.id('a')), 2000::numeric,
    'The amount paid is money out in the cash book');

  perform tests.as_user('alice');
  perform public.pay_supplier(tests.id('a'), tests.id('supplier'), 5000, 'transfer', current_date, 'Part');
  perform tests.as_owner_db();
  return next is((select balance from public.suppliers where id = tests.id('supplier')), 15000::numeric,
    'Paying a supplier reduces what we owe');
end;
$$;

create function tests.test_02_cost_per_bag_and_cost_of_sales() returns setof text language plpgsql as $$
declare
  v_run uuid;
  v_sale uuid;
begin
  perform tests.seed();
  perform tests.as_user('sam');
  perform tests.buy(10, 1000, 0);
  perform tests.buy(10, 1200, 0);
  v_run := public.record_production_run(tests.id('a'), current_date, 'morning', 'M1', 'Musa',
    tests.id('sachet'), 480, 20);
  perform tests.as_owner_db();
  return next is((select material_cost from public.production_runs where id = v_run), 5500::numeric,
    'A run''s material cost: 5 rolls at the 1,100 average');
  return next is((select average_cost::numeric(10,4) from public.stock_items where product_id = tests.id('sachet')),
    (5500 / 480.0)::numeric(10,4), 'The bags it made cost material / good bags');

  perform tests.as_user('carol');
  v_sale := public.record_sale(tests.id('a'), 'walk_in', null, 4000, 4000, 'cash', 0,
    jsonb_build_array(jsonb_build_object('product_id', tests.id('sachet'), 'quantity', 10, 'unit_price', 400)));
  perform tests.as_owner_db();
  return next is((select unit_cost::numeric(10,4) from public.sale_lines where sale_id = v_sale),
    (5500 / 480.0)::numeric(10,4), 'A sale line keeps what the bags cost');
end;
$$;

create function tests.test_03_who_can() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('carol');
  return next throws_ok('select tests.buy(1, 1, 0)', '42501', null, 'A cashier can''t record purchases');
  return next is((select count(*)::int from public.suppliers), 0, 'or see suppliers');
  perform tests.as_user('sam');
  return next throws_ok(format('select public.pay_supplier(%L, %L, 1, ''cash'', current_date, null)',
    tests.id('a'), tests.id('supplier')), '42501', null, 'A store keeper can''t pay suppliers');
  perform tests.as_user('bob');
  return next throws_ok('select tests.buy(1, 1, 0)', '42501', null, 'Another organization can''t buy for us');
  return next throws_ok(format($q$select public.record_purchase(%L, %L, current_date,
      jsonb_build_array(jsonb_build_object('item_id', %L, 'quantity', 1, 'unit_cost', 1)), 0, null, null)$q$,
      tests.id('b'), tests.id('supplier'), tests.id('nylon')),
    'P0001', null, '... not even through its own organization');
  perform tests.as_user('alice');
  return next throws_ok(format($q$select public.record_purchase(%L, %L, current_date,
      jsonb_build_array(jsonb_build_object('item_id', %L, 'quantity', 1, 'unit_cost', 1)), 0, null, null)$q$,
      tests.id('a'), tests.id('supplier'), (select id from public.stock_items where product_id = tests.id('sachet'))),
    'P0001', null, 'Products are produced, not bought');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
