-- HydroTrack — cross-tenant isolation tests (pgTAP, xUnit style).
--
-- Proves one organization can't read, write, reference or act on
-- another's data — through RLS, composite foreign keys, the RPCs and
-- storage — plus the per-tenant role rules and owner safeguards.
--
-- Everything runs in ONE transaction that is rolled back at the end:
-- the throwaway users, organizations and records below never persist.
-- runtests() additionally rolls back each test function on its own, so
-- tests can't affect each other.
--
-- Run:  supabase test db --linked           (needs Docker for pg_prove)
--  or:  ./supabase/tests/run_linked.sh       (no Docker; Management API)

begin;

create extension if not exists pgtap with schema extensions;

create schema tests;
grant usage on schema tests to authenticated, anon;

-- =========================================================================
-- Helpers
-- =========================================================================

-- Fixture ids by name, readable from any role.
create table tests.fx (key text primary key, id uuid not null, code text);
grant select, insert on tests.fx to authenticated, anon;

create function tests.id(p_key text) returns uuid
language sql stable as $$ select id from tests.fx where key = p_key $$;

-- A tenant's product by its old enum name (the 4 starter products keep
-- it as legacy_key). Security definer so it works whatever role is active.
create function tests.product(p_tenant uuid, p_key text) returns uuid
language sql stable security definer as $$
  select id from public.products where tenant_id = p_tenant and legacy_key = p_key
$$;

create function tests.code(p_key text) returns text
language sql stable as $$ select code from tests.fx where key = p_key $$;

create function tests.create_user(p_key text, p_name text, p_email text, p_phone text default null)
returns uuid language plpgsql as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (instance_id, id, aud, role, email, phone, encrypted_password,
                          email_confirmed_at, raw_user_meta_data, raw_app_meta_data,
                          created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
          p_email, p_phone, '', now(), jsonb_build_object('full_name', p_name), '{}'::jsonb,
          now(), now());
  insert into tests.fx (key, id) values (p_key, v_id);
  return v_id;
end;
$$;

-- Act as a signed-in user, as a signed-out (anon) visitor, or as the
-- database owner (to set up data / inspect it unfiltered).
create function tests.as_user(p_key text) returns void language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', tests.id(p_key), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create function tests.as_anon() returns void language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', '{"role": "anon"}', true);
  perform set_config('role', 'anon', true);
end;
$$;

create function tests.as_owner_db() returns void language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Every tenant-scoped relation the app reads.
create function tests.tenant_relations() returns text[] language sql immutable as $$
  select array[
    'production_runs', 'stock_items', 'production_recipes', 'stock_batches',
    'stock_movements', 'sales', 'sale_lines', 'customers', 'ledger_entries',
    'cash_entries', 'expenses', 'drivers', 'vehicles', 'load_outs',
    'staff_audit_log', 'tenant_members', 'tenant_invitations', 'audit_trail',
    'tenants', 'products'
  ];
$$;

-- Rows of p_relation belonging to p_tenant that the CURRENT role can see.
create function tests.visible(p_relation text, p_tenant uuid) returns bigint
language plpgsql as $$
declare
  v_count bigint;
begin
  execute format(
    'select count(*) from public.%I where %I = $1',
    p_relation, case when p_relation = 'tenants' then 'id' else 'tenant_id' end
  ) into v_count using p_tenant;
  return v_count;
end;
$$;

-- Same, but a "permission denied" also counts as nothing visible (signed-
-- out visitors are refused some relations outright, others return none).
create function tests.visible_or_denied(p_relation text) returns bigint
language plpgsql as $$
declare
  v_count bigint;
begin
  execute format('select count(*) from public.%I', p_relation) into v_count;
  return v_count;
exception when insufficient_privilege then
  return 0;
end;
$$;

-- =========================================================================
-- Fixtures: Tenant A (owner Alice, admin Erin, cashier Carol),
-- Tenant B (owner Bob), Dave (no organization), Frank (invited to B).
-- Each organization gets a full set of real records, made through the
-- same RPCs the app uses.
-- =========================================================================

create function tests.seed_tenant(p_owner text, p_prefix text, p_name text)
returns void language plpgsql as $$
declare
  v_tenant uuid;
  v_sachet uuid;
  v_nylon uuid;
  v_customer uuid;
  v_driver uuid;
  v_vehicle uuid;
  v_sale uuid;
  v_run uuid;
  v_load_out uuid;
  v_recipe uuid;
  v_invite public.tenant_invitations;
begin
  perform tests.as_user(p_owner);
  v_tenant := (public.create_tenant(p_name)).id;
  v_sachet := (select id from public.stock_items where tenant_id = v_tenant and product_id = tests.product(v_tenant, 'sachet50cl'));

  insert into public.stock_items (tenant_id, name, category, unit)
  values (v_tenant, 'Nylon roll', 'raw_material', 'rolls') returning id into v_nylon;
  perform public.add_stock(v_tenant, v_nylon, 50, 'Delivery');
  perform public.add_stock(v_tenant, v_sachet, 500, 'Opening stock');
  insert into public.production_recipes (tenant_id, product_id, raw_material_item_id, quantity_used, per_bags)
  values (v_tenant, tests.product(v_tenant, 'sachet50cl'), v_nylon, 1, 100) returning id into v_recipe;
  v_run := public.record_production_run(v_tenant, current_date, 'morning', 'Machine 1', 'Musa', tests.product(v_tenant, 'sachet50cl'), 200, 5);

  insert into public.customers (tenant_id, name, phone, area, credit_limit)
  values (v_tenant, p_prefix || ' Distributor', '08011112222', 'Kano', 100000) returning id into v_customer;
  v_sale := public.record_sale(v_tenant, 'distributor', p_prefix || ' Distributor', 4000, 1000, 'part', 3000,
    '[{"product": "sachet50cl", "quantity": 10, "unit_price": 400}]'::jsonb, 'cash');
  perform public.record_customer_payment(v_tenant, v_customer, 500, 'transfer', current_date, 'Part payment');
  perform public.record_expense(v_tenant, current_date, 'electricity', 'Electricity token', 5000, 'cash');

  insert into public.drivers (tenant_id, name, phone) values (v_tenant, 'Yakubu', '08099998888') returning id into v_driver;
  insert into public.vehicles (tenant_id, name) values (v_tenant, 'Hilux') returning id into v_vehicle;
  v_load_out := public.record_load_out(v_tenant, v_driver, v_vehicle, tests.product(v_tenant, 'sachet50cl'), 20, null);

  v_invite := public.create_invitation(v_tenant, 'Pending Person', '08077776666', null, 'cashier');

  perform tests.as_owner_db();
  insert into tests.fx (key, id) values
    (p_prefix || '_tenant', v_tenant), (p_prefix || '_sachet', v_sachet),
    (p_prefix || '_nylon', v_nylon), (p_prefix || '_recipe', v_recipe),
    (p_prefix || '_run', v_run), (p_prefix || '_customer', v_customer),
    (p_prefix || '_sale', v_sale), (p_prefix || '_driver', v_driver),
    (p_prefix || '_vehicle', v_vehicle), (p_prefix || '_load_out', v_load_out);
  insert into tests.fx (key, id, code) values (p_prefix || '_invite', v_invite.id, v_invite.code);

  insert into storage.objects (bucket_id, name) values ('tenant-files', v_tenant || '/logo.png');
end;
$$;

select tests.create_user('alice', 'Alice Owner', 'alice@a.test');
select tests.create_user('erin', 'Erin Admin', 'erin@a.test');
select tests.create_user('carol', 'Carol Cashier', null, '2348030000001');
select tests.create_user('bob', 'Bob Owner', 'bob@b.test');
select tests.create_user('dave', 'Dave Nobody', 'dave@d.test');
select tests.create_user('frank', 'Frank Invitee', null, '2348030000009');

select tests.seed_tenant('alice', 'a', 'Tenant A Water');
select tests.seed_tenant('bob', 'b', 'Tenant B Water');

-- Carol (cashier) and Erin (admin) join A through the real invite flow;
-- Frank gets an invite to B he hasn't used yet.
create function tests.seed_members() returns void language plpgsql as $$
declare
  v_code text;
begin
  perform tests.as_user('alice');
  v_code := (public.create_invitation(tests.id('a_tenant'), 'Carol Cashier', '08030000001', null, 'cashier')).code;
  perform tests.as_user('carol');
  perform public.accept_invitation(v_code);

  perform tests.as_user('alice');
  v_code := (public.create_invitation(tests.id('a_tenant'), 'Erin Admin', null, 'erin@a.test', 'admin')).code;
  perform tests.as_user('erin');
  perform public.accept_invitation(lower(v_code));  -- codes are case-insensitive

  perform tests.as_user('bob');
  v_code := (public.create_invitation(tests.id('b_tenant'), 'Frank Invitee', '08030000009', null, 'store_keeper')).code;
  perform tests.as_owner_db();
  insert into tests.fx (key, id, code) values ('frank_invite', tests.id('b_tenant'), v_code);
end;
$$;
select tests.seed_members();
select tests.as_owner_db();

-- =========================================================================
-- Tests
-- =========================================================================

create function tests.test_01_members_see_their_own_data() returns setof text
language plpgsql as $$
declare
  r text;
begin
  perform tests.as_user('alice');
  foreach r in array tests.tenant_relations() loop
    return next ok(tests.visible(r, tests.id('a_tenant')) > 0,
      format('Alice sees Tenant A rows in %s (fixtures are real)', r));
  end loop;
end;
$$;

create function tests.test_02_other_tenants_rows_are_invisible() returns setof text
language plpgsql as $$
declare
  r text;
begin
  perform tests.as_user('bob');
  foreach r in array tests.tenant_relations() loop
    return next is(tests.visible(r, tests.id('a_tenant')), 0::bigint,
      format('Bob sees no Tenant A rows in %s', r));
  end loop;

  perform tests.as_user('carol');
  foreach r in array tests.tenant_relations() loop
    return next is(tests.visible(r, tests.id('b_tenant')), 0::bigint,
      format('Carol (Tenant A cashier) sees no Tenant B rows in %s', r));
  end loop;
end;
$$;

create function tests.test_03_profiles_only_visible_within_shared_tenants() returns setof text
language plpgsql as $$
begin
  perform tests.as_user('bob');
  return next is(
    (select count(*) from public.profiles where id in (tests.id('alice'), tests.id('carol'), tests.id('erin'))),
    0::bigint, 'Bob cannot see Tenant A people''s profiles');
  return next is((select count(*) from public.profiles where id = tests.id('bob')), 1::bigint,
    'Bob sees his own profile');

  perform tests.as_user('carol');
  return next is((select count(*) from public.profiles where id = tests.id('alice')), 1::bigint,
    'Carol sees her own organization''s owner');
  return next is((select count(*) from public.profiles where id = tests.id('bob')), 0::bigint,
    'Carol cannot see Tenant B''s owner');
end;
$$;

create function tests.test_04_users_without_an_organization_see_nothing() returns setof text
language plpgsql as $$
declare
  r text;
begin
  perform tests.as_user('dave');
  foreach r in array tests.tenant_relations() loop
    return next is(
      tests.visible(r, tests.id('a_tenant')) + tests.visible(r, tests.id('b_tenant')),
      0::bigint, format('Dave (no organization) sees nothing in %s', r));
  end loop;
end;
$$;

create function tests.test_05_signed_out_visitors_get_nothing() returns setof text
language plpgsql as $$
declare
  r text;
begin
  perform tests.as_anon();
  foreach r in array tests.tenant_relations() || array['profiles'] loop
    return next is(tests.visible_or_denied(r), 0::bigint,
      format('Signed-out visitors see nothing in %s', r));
  end loop;
  return next throws_ok(
    format('select public.record_expense(%L, current_date, ''other'', ''x'', 1, ''cash'')', tests.id('a_tenant')),
    '42501', null, 'Signed-out visitors cannot call business RPCs');
  return next throws_ok('select public.create_tenant(''Sneaky'')', '42501', null,
    'Signed-out visitors cannot create organizations');
end;
$$;

create function tests.test_06_cannot_insert_into_another_tenant() returns setof text
language plpgsql as $$
declare
  b uuid := tests.id('b_tenant');
begin
  perform tests.as_user('alice');
  return next throws_ok(format(
    'insert into public.customers (tenant_id, name, phone, area) values (%L, ''x'', ''0'', ''x'')', b),
    '42501', null, 'Alice cannot add a customer to Tenant B');
  return next throws_ok(format(
    'insert into public.drivers (tenant_id, name, phone) values (%L, ''x'', ''0'')', b),
    '42501', null, 'Alice cannot add a driver to Tenant B');
  return next throws_ok(format(
    'insert into public.vehicles (tenant_id, name) values (%L, ''x'')', b),
    '42501', null, 'Alice cannot add a vehicle to Tenant B');
  return next throws_ok(format(
    'insert into public.stock_items (tenant_id, name, category, unit) values (%L, ''x'', ''raw_material'', ''x'')', b),
    '42501', null, 'Alice cannot add a stock item to Tenant B');
  return next throws_ok(format(
    'insert into public.cash_entries (tenant_id, direction, source, amount, method, recorded_by) values (%L, ''money_in'', ''other'', 1, ''cash'', %L)',
    b, tests.id('alice')),
    '42501', null, 'Alice cannot post a cash entry to Tenant B');
  return next throws_ok(format(
    'insert into public.production_recipes (tenant_id, product_id, raw_material_item_id, quantity_used, per_bags) values (%L, %L, %L, 1, 1)',
    b, tests.product(b, 'bottle75cl'), tests.id('b_nylon')),
    '42501', null, 'Alice cannot add a recipe to Tenant B');
  return next throws_ok(
    'insert into public.tenants (name, slug) values (''Forged'', ''forged'')',
    '42501', null, 'Organizations cannot be inserted directly (only via create_tenant)');
  return next throws_ok(format(
    'insert into public.tenant_members (tenant_id, user_id, role) values (%L, %L, ''owner'')', b, tests.id('alice')),
    '42501', null, 'Alice cannot make herself a member of Tenant B');
end;
$$;

create function tests.test_07_own_rows_cannot_point_at_another_tenants_rows() returns setof text
language plpgsql as $$
declare
  a uuid := tests.id('a_tenant');
begin
  perform tests.as_user('alice');
  return next throws_ok(format(
    'insert into public.production_recipes (tenant_id, product_id, raw_material_item_id, quantity_used, per_bags) values (%L, %L, %L, 1, 1)',
    a, tests.product(a, 'bottle75cl'), tests.id('b_nylon')),
    '23503', null, 'A Tenant A recipe cannot use a Tenant B material (composite FK)');
  return next throws_ok(format(
    'select public.record_load_out(%L, %L, %L, %L, 5, null)', a, tests.id('b_driver'), tests.id('b_vehicle'), tests.product(a, 'sachet50cl')),
    '23503', null, 'A Tenant A load-out cannot use Tenant B''s driver and vehicle');
  return next throws_ok(format(
    'insert into public.cash_entries (tenant_id, direction, source, amount, method, recorded_by) values (%L, ''money_in'', ''other'', 1, ''cash'', %L)',
    a, tests.id('bob')),
    '42501', null, 'A cash entry cannot be stamped as recorded by someone else');
end;
$$;

create function tests.test_08_updates_and_deletes_cannot_reach_another_tenant() returns setof text
language plpgsql as $$
begin
  perform tests.as_user('alice');
  update public.customers set name = 'Hacked', balance = 0 where id = tests.id('b_customer');
  update public.stock_items set quantity_on_hand = 999999 where id = tests.id('b_sachet');
  update public.tenants set name = 'Hacked' where id = tests.id('b_tenant');
  update public.tenant_members set role = 'cashier' where tenant_id = tests.id('b_tenant');
  delete from public.production_recipes where id = tests.id('b_recipe');
  delete from public.sales where id = tests.id('b_sale');

  perform tests.as_owner_db();
  return next is((select name from public.customers where id = tests.id('b_customer')), 'b Distributor',
    'Tenant B customer unchanged');
  return next is((select balance from public.customers where id = tests.id('b_customer')), 2500::numeric(12, 2),
    'Tenant B customer balance unchanged');
  return next isnt((select quantity_on_hand from public.stock_items where id = tests.id('b_sachet')), 999999,
    'Tenant B stock unchanged');
  return next is((select name from public.tenants where id = tests.id('b_tenant')), 'Tenant B Water',
    'Tenant B name unchanged');
  return next is((select role::text from public.tenant_members where tenant_id = tests.id('b_tenant') and user_id = tests.id('bob')),
    'owner', 'Tenant B owner unchanged');
  return next ok(exists (select 1 from public.production_recipes where id = tests.id('b_recipe')),
    'Tenant B recipe not deleted');
  return next ok(exists (select 1 from public.sales where id = tests.id('b_sale')),
    'Tenant B sale not deleted');
end;
$$;

create function tests.test_09_rpcs_reject_another_tenants_id() returns setof text
language plpgsql as $$
declare
  b uuid := tests.id('b_tenant');
  call text;
begin
  perform tests.as_user('alice');
  foreach call in array array[
    format('select public.add_stock(%L, %L, 1, null)', b, tests.id('b_sachet')),
    format('select public.adjust_stock_count(%L, %L, 0, ''x'')', b, tests.id('b_sachet')),
    format('select public.update_stock_item_details(%L, %L, ''x'', ''x'', 0)', b, tests.id('b_sachet')),
    format('select public.delete_stock_item(%L, %L)', b, tests.id('b_nylon')),
    format('select public.record_production_run(%L, current_date, ''morning'', ''M'', ''O'', %L, 1, 0)', b, tests.product(b, 'sachet50cl')),
    format('select public.update_production_run(%L, %L, current_date, ''morning'', ''M'', ''O'', %L, 1, 0)', b, tests.id('b_run'), tests.product(b, 'sachet50cl')),
    format('select public.delete_production_run(%L, %L)', b, tests.id('b_run')),
    format('select public.record_sale(%L, ''walk_in'', null, 400, 400, ''cash'', 0, ''[{"product": "sachet50cl", "quantity": 1, "unit_price": 400}]'')', b),
    format('select public.void_sale(%L, %L, ''x'')', b, tests.id('b_sale')),
    format('select public.record_customer_payment(%L, %L, 1, ''cash'', current_date, null)', b, tests.id('b_customer')),
    format('select public.update_customer_credit_limit(%L, %L, 0)', b, tests.id('b_customer')),
    format('select public.add_opening_balance(%L, %L, 1, ''x'')', b, tests.id('b_customer')),
    format('select public.write_off_debt(%L, %L, 1, ''x'')', b, tests.id('b_customer')),
    format('select public.record_expense(%L, current_date, ''other'', ''x'', 1, ''cash'')', b),
    format('select public.record_load_out(%L, %L, %L, %L, 1, null)', b, tests.id('b_driver'), tests.id('b_vehicle'), tests.product(b, 'sachet50cl')),
    format('select public.settle_load_out(%L, %L, 0, 20, 0, 0, null)', b, tests.id('b_load_out')),
    format('select public.create_invitation(%L, ''x'', ''08000000000'', null, ''admin'')', b),
    format('select public.revoke_invitation(%L, %L)', b, tests.id('b_invite')),
    format('select public.update_member_role(%L, %L, ''cashier'')', b, tests.id('bob')),
    format('select public.set_member_active(%L, %L, false)', b, tests.id('bob')),
    format('select public.remove_member(%L, %L)', b, tests.id('bob'))
  ] loop
    return next throws_ok(call, '42501', null,
      'Alice is refused: ' || split_part(split_part(call, 'public.', 2), '(', 1) || ' on Tenant B');
  end loop;
end;
$$;

create function tests.test_10_rpcs_cannot_reach_another_tenants_rows_via_own_tenant() returns setof text
language plpgsql as $$
declare
  a uuid := tests.id('a_tenant');
begin
  perform tests.as_user('alice');
  return next throws_ok(format('select public.add_stock(%L, %L, 1, null)', a, tests.id('b_sachet')),
    'P0001', 'Stock item not found', 'add_stock: Tenant B item not found via Tenant A');
  return next throws_ok(format('select public.delete_stock_item(%L, %L)', a, tests.id('b_nylon')),
    'P0001', 'Stock item not found', 'delete_stock_item: Tenant B item not found via Tenant A');
  return next throws_ok(format('select public.delete_production_run(%L, %L)', a, tests.id('b_run')),
    'P0001', 'Production run not found', 'delete_production_run: Tenant B run not found via Tenant A');
  return next throws_ok(format('select public.void_sale(%L, %L, ''x'')', a, tests.id('b_sale')),
    'P0001', 'Sale not found', 'void_sale: Tenant B sale not found via Tenant A');
  return next throws_ok(format('select public.record_customer_payment(%L, %L, 1, ''cash'', current_date, null)', a, tests.id('b_customer')),
    'P0001', 'Customer not found', 'record_customer_payment: Tenant B customer not found via Tenant A');
  return next throws_ok(format('select public.write_off_debt(%L, %L, 1, ''x'')', a, tests.id('b_customer')),
    'P0001', 'Customer not found', 'write_off_debt: Tenant B customer not found via Tenant A');
  return next throws_ok(format('select public.settle_load_out(%L, %L, 0, 20, 0, 0, null)', a, tests.id('b_load_out')),
    'P0001', 'Trip not found, or already settled', 'settle_load_out: Tenant B trip not found via Tenant A');
  return next throws_ok(format('select public.revoke_invitation(%L, %L)', a, tests.id('b_invite')),
    'P0001', null, 'revoke_invitation: Tenant B invite not found via Tenant A');
  return next throws_ok(format('select public.update_member_role(%L, %L, ''cashier'')', a, tests.id('bob')),
    'P0001', 'Member not found', 'update_member_role: Tenant B owner not found via Tenant A');

  perform tests.as_owner_db();
  return next is((select voided_at from public.sales where id = tests.id('b_sale')), null,
    'Tenant B sale still not voided');
  return next is((select status::text from public.load_outs where id = tests.id('b_load_out')), 'on_road',
    'Tenant B trip still on the road');
end;
$$;

create function tests.test_11_roles_apply_per_tenant() returns setof text
language plpgsql as $$
declare
  a uuid := tests.id('a_tenant');
begin
  perform tests.as_user('carol');
  return next throws_ok(format('select public.record_expense(%L, current_date, ''other'', ''x'', 1, ''cash'')', a),
    '42501', null, 'Cashier cannot record expenses');
  return next throws_ok(format('select public.add_stock(%L, %L, 1, null)', a, tests.id('a_sachet')),
    '42501', null, 'Cashier cannot add stock');
  return next throws_ok(format('select public.void_sale(%L, %L, ''x'')', a, tests.id('a_sale')),
    '42501', null, 'Cashier cannot void sales');
  return next throws_ok(format('select public.create_invitation(%L, ''x'', ''08000000000'', null, ''admin'')', a),
    '42501', null, 'Cashier cannot invite people');
  return next throws_ok(format(
    'insert into public.stock_items (tenant_id, name, category, unit) values (%L, ''x'', ''raw_material'', ''x'')', a),
    '42501', null, 'Cashier cannot add catalog items');
  return next lives_ok(format('select public.record_sale(%L, ''walk_in'', null, 400, 400, ''cash'', 0, ''[{"product": "sachet50cl", "quantity": 1, "unit_price": 400}]'')', a),
    'Cashier can record a sale in her own organization');
  return next lives_ok(format(
    'insert into public.customers (tenant_id, name, phone, area) values (%L, ''New shop'', ''0'', ''Zaria'')', a),
    'Cashier can add a customer in her own organization');

  perform tests.as_user('erin');
  return next lives_ok(format('select public.void_sale(%L, %L, ''Entered twice'')', a, tests.id('a_sale')),
    'Admin can void a sale');
end;
$$;

create function tests.test_12_deactivated_members_lose_access_immediately() returns setof text
language plpgsql as $$
declare
  a uuid := tests.id('a_tenant');
begin
  perform tests.as_user('alice');
  perform public.set_member_active(a, tests.id('carol'), false);

  perform tests.as_user('carol');
  return next is(tests.visible('customers', a), 0::bigint, 'Deactivated cashier sees no customers');
  return next is(tests.visible('sales', a), 0::bigint, 'Deactivated cashier sees no sales');
  return next throws_ok(format('select public.record_sale(%L, ''walk_in'', null, 400, 400, ''cash'', 0, ''[{"product": "sachet50cl", "quantity": 1, "unit_price": 400}]'')', a),
    '42501', null, 'Deactivated cashier cannot record a sale');
  return next is((select count(*) from public.tenant_members where tenant_id = a and user_id = tests.id('carol') and not is_active),
    1::bigint, 'She can still see her own (deactivated) membership');
  return next is((select name from public.tenants where id = a), 'Tenant A Water',
    'She can still see the organization''s name (for the picker)');
end;
$$;

create function tests.test_13_invitations() returns setof text
language plpgsql as $$
begin
  perform tests.as_user('dave');
  return next throws_ok(format('select public.accept_invitation(%L)', tests.code('frank_invite')),
    'P0001', 'This invite was sent to a different phone number or email.',
    'An invite cannot be redeemed by someone it was not sent to (here: an email-only account, the 0013 regression)');
  return next throws_ok('select public.accept_invitation(''NOTAREALCODE'')',
    'P0001', null, 'Unknown codes are rejected');

  perform tests.as_user('frank');
  return next is(public.accept_invitation(tests.code('frank_invite')), tests.id('b_tenant'),
    'Frank joins Tenant B with the invite sent to his phone');
  return next is((select role::text from public.tenant_members where tenant_id = tests.id('b_tenant') and user_id = tests.id('frank')),
    'store_keeper', 'He gets the role the invite named');
  return next is(tests.visible('customers', tests.id('a_tenant')), 0::bigint,
    'Joining Tenant B gives no access to Tenant A');
  return next throws_ok(format('select public.accept_invitation(%L)', tests.code('frank_invite')),
    'P0001', null, 'An invite works only once');

  perform tests.as_user('bob');
  perform public.revoke_invitation(tests.id('b_tenant'), tests.id('b_invite'));
  perform tests.as_owner_db();
  update auth.users set phone = '2348077776666' where id = tests.id('dave');
  perform tests.as_user('dave');
  return next throws_ok(format('select public.accept_invitation(%L)', tests.code('b_invite')),
    'P0001', null, 'A revoked invite cannot be used');

  perform tests.as_user('alice');
  return next throws_ok(format('select public.create_invitation(%L, ''x'', ''08000000000'', null, ''owner'')', tests.id('a_tenant')),
    'P0001', null, 'Nobody can be invited straight in as Owner');
end;
$$;

create function tests.test_14_expired_invitations_cannot_be_used() returns setof text
language plpgsql as $$
begin
  perform tests.as_owner_db();
  update public.tenant_invitations set expires_at = now() - interval '1 minute'
  where code = tests.code('frank_invite');
  perform tests.as_user('frank');
  return next throws_ok(format('select public.accept_invitation(%L)', tests.code('frank_invite')),
    'P0001', null, 'An expired invite cannot be used');
end;
$$;

create function tests.test_15_owner_safeguards() returns setof text
language plpgsql as $$
declare
  a uuid := tests.id('a_tenant');
begin
  perform tests.as_user('alice');
  return next throws_ok(format('select public.update_member_role(%L, %L, ''admin'')', a, tests.id('alice')),
    'P0001', null, 'The last owner cannot demote themselves');
  return next throws_ok(format('select public.set_member_active(%L, %L, false)', a, tests.id('alice')),
    'P0001', null, 'Nobody can deactivate their own access');

  perform tests.as_user('erin');
  return next throws_ok(format('select public.update_member_role(%L, %L, ''cashier'')', a, tests.id('alice')),
    'P0001', 'Only an owner can change another owner', 'An admin cannot demote an owner');
  return next throws_ok(format('select public.set_member_active(%L, %L, false)', a, tests.id('alice')),
    'P0001', 'Only an owner can change another owner', 'An admin cannot deactivate an owner');
  return next throws_ok(format('select public.update_member_role(%L, %L, ''owner'')', a, tests.id('erin')),
    'P0001', 'Only an owner can make someone an owner', 'An admin cannot make themselves owner');
  return next lives_ok(format('select public.update_member_role(%L, %L, ''manager'')', a, tests.id('carol')),
    'An admin can change a cashier''s role');

  perform tests.as_user('alice');
  return next lives_ok(format('select public.update_member_role(%L, %L, ''owner'')', a, tests.id('erin')),
    'An owner can make an admin an owner');
  return next lives_ok(format('select public.update_member_role(%L, %L, ''admin'')', a, tests.id('alice')),
    'With a second owner, the first can step down');
end;
$$;

create function tests.test_16_removing_members() returns setof text
language plpgsql as $$
declare
  a uuid := tests.id('a_tenant');
begin
  perform tests.as_user('carol');
  perform public.record_sale(a, 'walk_in', null, 400, 400, 'cash', 0,
    '[{"product": "sachet50cl", "quantity": 1, "unit_price": 400}]');

  perform tests.as_user('alice');
  return next throws_ok(format('select public.remove_member(%L, %L)', a, tests.id('carol')),
    'P0001', 'This person has recorded activity and can''t be removed. Deactivate them instead.',
    'Someone with recorded activity cannot be removed');
  return next lives_ok(format('select public.remove_member(%L, %L)', a, tests.id('erin')),
    'A member with no recorded activity can be removed');
  return next throws_ok(format('select public.remove_member(%L, %L)', a, tests.id('alice')),
    'P0001', null, 'Nobody can remove themselves');

  perform tests.as_user('erin');
  return next is(tests.visible('customers', a), 0::bigint, 'A removed member sees nothing');
  return next is((select count(*) from public.tenant_members where user_id = tests.id('erin')), 0::bigint,
    'A removed member has no membership left');
end;
$$;

create function tests.test_17_storage_is_tenant_scoped() returns setof text
language plpgsql as $$
declare
  a uuid := tests.id('a_tenant');
  b uuid := tests.id('b_tenant');
begin
  perform tests.as_user('bob');
  return next is((select count(*) from storage.objects where bucket_id = 'tenant-files' and name like a || '/%'),
    0::bigint, 'Bob cannot see Tenant A''s files');
  return next is((select count(*) from storage.objects where bucket_id = 'tenant-files' and name like b || '/%'),
    1::bigint, 'Bob sees Tenant B''s files');

  perform tests.as_user('alice');
  return next throws_ok(format(
    'insert into storage.objects (bucket_id, name) values (''tenant-files'', %L)', b || '/planted.png'),
    '42501', null, 'Alice cannot upload into Tenant B''s folder');
  return next throws_ok(
    'insert into storage.objects (bucket_id, name) values (''tenant-files'', ''no-tenant/file.png'')',
    '42501', null, 'Uploads outside a tenant folder are refused');
  return next lives_ok(format(
    'insert into storage.objects (bucket_id, name) values (''tenant-files'', %L)', a || '/stamp.png'),
    'Alice can upload into her own organization''s folder');

  perform tests.as_user('carol');
  return next throws_ok(format(
    'insert into storage.objects (bucket_id, name) values (''tenant-files'', %L)', a || '/cashier.png'),
    '42501', null, 'A cashier cannot upload organization files');
end;
$$;

create function tests.test_18_internal_functions_are_not_callable() returns setof text
language plpgsql as $$
declare
  f text;
begin
  foreach f in array array[
    'public.consume_stock_fifo(uuid, uuid, integer, movement_type, text, uuid, uuid, uuid)',
    'public.add_stock_batch(uuid, uuid, integer, date, movement_type, text, uuid, uuid, uuid)',
    'public.finished_item_for(uuid, uuid)',
    'public.post_sale_side_effects(uuid, uuid, sales_customer_type, text, numeric, sales_payment_method, numeric, payment_channel, text)',
    'public.require_tenant_role(uuid, staff_role[], text)',
    'public.peek_invitation(text)',
    'public.redeem_invitation_for_new_user(text, uuid)',
    'public.claim_invitation(text)',
    'public.handle_new_user()'
  ] loop
    return next ok(
      not has_function_privilege('authenticated', f, 'execute')
        and not has_function_privilege('anon', f, 'execute'),
      'Not callable from the app: ' || f);
  end loop;
end;
$$;

create function tests.test_19_history_check_is_tenant_scoped() returns setof text
language plpgsql as $$
begin
  perform tests.as_user('bob');
  return next is(public.member_has_history(tests.id('a_tenant'), tests.id('alice')), false,
    'Bob cannot probe Tenant A''s roster through member_has_history');
  perform tests.as_user('alice');
  return next is(public.member_has_history(tests.id('a_tenant'), tests.id('alice')), true,
    'Alice gets the real answer for her own organization');
end;
$$;

create function tests.test_20_new_organization_starts_isolated_with_catalog() returns setof text
language plpgsql as $$
declare
  c uuid;
begin
  perform tests.as_user('dave');
  c := (public.create_tenant('Dave''s Water')).id;
  return next is((select role::text from public.tenant_members where tenant_id = c and user_id = tests.id('dave')),
    'owner', 'The creator becomes the owner');
  return next is((select count(*) from public.stock_items where tenant_id = c and product_id is not null),
    4::bigint, 'It starts with one finished-goods item per product');
  return next is(tests.visible('stock_items', tests.id('a_tenant')), 0::bigint,
    'Creating an organization grants nothing in others');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
