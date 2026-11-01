-- HydroTrack — products and prices tests (pgTAP, xUnit style).
--
-- Per-organization products, their stock items, retiring/deleting, and
-- the price rule (cashiers sell at the list price; managers may change
-- it; offline sales keep the device's price). One transaction, rolled
-- back: nothing persists.
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


-- A product's finished-goods stock item, whatever role is active.
create function tests.stock_of(p_product uuid) returns uuid
language sql stable security definer as $$
  select id from public.stock_items where product_id = p_product
$$;

-- Organization A (owner alice, manager mike, cashier carol) with 100 bags
-- of its 50cl Sachet in stock and a set-up device; organization B (bob).
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_b uuid;
  v_device jsonb;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@products-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@products-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@products-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@products-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  perform tests.as_user('bob');
  v_b := (public.create_tenant('Other Water')).id;
  perform tests.as_owner_db();
  insert into tests.fx (key, id) values ('a', v_a), ('b', v_b),
    ('sachet', tests.product(v_a, 'sachet50cl')), ('b_sachet', tests.product(v_b, 'sachet50cl'));
  insert into public.tenant_members (tenant_id, user_id, role) values
    (v_a, tests.id('mike'), 'manager'), (v_a, tests.id('carol'), 'cashier');
  perform tests.as_user('alice');
  perform public.add_stock(v_a, tests.stock_of(tests.id('sachet')), 100, 'Opening');
  perform public.update_product(v_a, tests.id('sachet'), '50cl Sachet', 'bags', 400, 380);
  v_device := public.register_device(v_a, 'Front desk');
  perform tests.as_owner_db();
  insert into tests.fx (key, id, note) values ('device', (v_device ->> 'id')::uuid, v_device ->> 'key');
end;
$$;

create function tests.sell(p_product uuid, p_price numeric, p_type text default 'walk_in') returns uuid
language sql as $$
  select public.record_sale(tests.id('a'), p_type::public.sales_customer_type,
    case when p_type = 'distributor' then 'Musa' end, p_price, p_price, 'cash', 0,
    jsonb_build_array(jsonb_build_object('product_id', p_product, 'quantity', 1, 'unit_price', p_price)));
$$;

create function tests.test_01_new_organizations_get_the_usual_products() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  return next is((select count(*)::int from public.products where tenant_id = tests.id('a')), 4,
    'A new organization starts with 4 products');
  return next is((select count(*)::int from public.stock_items where tenant_id = tests.id('a') and product_id is not null), 4,
    'each with its own stock item');
  return next is((select walk_in_price from public.products where id = tests.id('sachet')), 400::numeric,
    'with a walk-in price');
end;
$$;

create function tests.test_02_managing_products() returns setof text language plpgsql as $$
declare
  v_new public.products;
begin
  perform tests.seed();
  perform tests.as_user('alice');
  v_new := public.create_product(tests.id('a'), '35cl Sachet', 'bags', 250, 230);
  return next is(
    (select name || '/' || unit from public.stock_items where tenant_id = tests.id('a') and product_id = v_new.id),
    '35cl Sachet/bags', 'A new product gets its own stock item');
  return next throws_ok(format('select public.create_product(%L, %L, %L, 1, 1)', tests.id('a'), ' 35CL sachet ', 'bags'),
    'P0001', null, 'Two products can''t share a name');

  perform public.update_product(tests.id('a'), v_new.id, '35cl Pure Water', 'bags', 260, 240);
  return next is(
    (select name from public.stock_items where tenant_id = tests.id('a') and product_id = v_new.id),
    '35cl Pure Water', 'Renaming a product renames its stock');

  perform tests.as_user('mike');
  return next throws_ok(format('select public.create_product(%L, %L, %L, 1, 1)', tests.id('a'), 'X', 'bags'),
    '42501', null, 'A manager can''t manage products');
  perform tests.as_user('bob');
  return next throws_ok(format('select public.update_product(%L, %L, %L, %L, 1, 1)', tests.id('a'), tests.id('sachet'), 'X', 'bags'),
    '42501', null, 'Another organization can''t change them');
  return next is((select count(*)::int from public.products where tenant_id = tests.id('a')), 0,
    'or even see them');
end;
$$;

create function tests.test_03_retiring_and_deleting() returns setof text language plpgsql as $$
declare
  v_unused public.products;
begin
  perform tests.seed();
  perform tests.as_user('alice');
  perform public.set_product_retired(tests.id('a'), tests.id('sachet'), true);
  return next throws_ok(format('select tests.sell(%L, 400)', tests.id('sachet')), 'P0001', null,
    'A retired product can''t be sold');
  perform public.set_product_retired(tests.id('a'), tests.id('sachet'), false);
  return next lives_ok(format('select tests.sell(%L, 400)', tests.id('sachet')),
    'Once brought back it can be sold again');

  return next throws_ok(format('select public.delete_product(%L, %L)', tests.id('a'), tests.id('sachet')),
    'P0001', null, 'A product that was used can''t be deleted');
  v_unused := public.create_product(tests.id('a'), 'Never made', 'bags', 1, 1);
  perform public.delete_product(tests.id('a'), v_unused.id);
  return next is((select count(*)::int from public.stock_items where tenant_id = tests.id('a') and product_id = v_unused.id), 0,
    'An unused product is deleted with its stock item');
  return next throws_ok(format('select public.delete_stock_item(%L, %L)', tests.id('a'),
      tests.stock_of(tests.id('sachet'))),
    'P0001', null, 'A product''s stock item can''t be deleted on its own');
end;
$$;

create function tests.test_04_prices() returns setof text language plpgsql as $$
declare
  v_sale uuid;
begin
  perform tests.seed();
  perform tests.as_user('carol');
  v_sale := tests.sell(tests.id('sachet'), 400);
  return next is((select list_price from public.sale_lines where sale_id = v_sale), 400::numeric,
    'A cashier sells at the walk-in price');
  v_sale := tests.sell(tests.id('sachet'), 380, 'distributor');
  return next is((select list_price from public.sale_lines where sale_id = v_sale), 380::numeric,
    'and at the distributor price to a distributor');
  return next throws_ok(format('select tests.sell(%L, 350)', tests.id('sachet')), '42501', null,
    'A cashier can''t change the price');

  perform tests.as_user('mike');
  v_sale := tests.sell(tests.id('sachet'), 350);
  return next is((select unit_price || '/' || list_price from public.sale_lines where sale_id = v_sale), '350.00/400.00',
    'A manager can, and the line shows the list price it differed from');

  perform tests.as_owner_db();
  return next is(public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'sale', 'actor_id', tests.id('carol'),
    'recorded_at', now(), 'payload', jsonb_build_object(
      'customer_type', 'walk_in', 'customer_name', null, 'total', 390, 'amount_paid', 390,
      'payment_method', 'cash', 'balance', 0, 'paid_channel', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'product_id', tests.id('sachet'), 'quantity', 1, 'unit_price', 390, 'list_price', 390))))) ->> 'status',
    'applied', 'An offline sale keeps the price the device showed (e.g. before a price change)');

  perform tests.as_user('alice');
  return next throws_ok(format('select tests.sell(%L, 400)', tests.id('b_sachet')), 'P0001', null,
    'Another organization''s product can''t be sold');
end;
$$;

create function tests.test_05_all_time_totals() returns setof text language plpgsql as $$
declare
  v_voided uuid;
begin
  perform tests.seed();
  perform tests.as_user('alice');
  perform tests.sell(tests.id('sachet'), 400);
  v_voided := tests.sell(tests.id('sachet'), 400);
  perform public.void_sale(tests.id('a'), v_voided, 'Entered twice');
  perform public.record_production_run(tests.id('a'), current_date, 'morning', 'M1', 'Musa',
    tests.id('sachet'), 250, 5);
  return next is(public.organization_totals(tests.id('a')),
    '{"total_bags_produced": 250, "total_revenue": 400}'::jsonb,
    'Home''s all-time totals: bags produced, and revenue without voided sales');

  perform tests.as_user('bob');
  return next throws_ok(format('select public.organization_totals(%L)', tests.id('a')), '42501', null,
    'Another organization can''t read them');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
