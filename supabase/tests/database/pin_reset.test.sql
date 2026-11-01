-- HydroTrack — staff PIN reset tests (pgTAP, xUnit style).
--
-- Who can issue reset codes, and that codes are single-use, expiring,
-- replaced by newer ones, limited to active members, and private. One
-- transaction, rolled back.
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


-- Organization A: owner alice (email), admin adam (email), manager erin
-- (email), cashier carol and a second owner otto (phone). Organization B: owner bob.
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_b uuid;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@reset-test.invalid');
  perform tests.create_user('adam', 'Adam Admin', 'adam@reset-test.invalid');
  perform tests.create_user('erin', 'Erin Manager', 'erin@reset-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', null, '2348031110001');
  perform tests.create_user('otto', 'Otto Owner', null, '2348031110002');
  perform tests.create_user('bob', 'Bob Owner', 'bob@reset-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  perform tests.as_user('bob');
  v_b := (public.create_tenant('Other Water')).id;
  perform tests.as_owner_db();
  insert into tests.fx (key, id) values ('a', v_a), ('b', v_b);
  insert into public.tenant_members (tenant_id, user_id, role) values
    (v_a, tests.id('adam'), 'admin'), (v_a, tests.id('carol'), 'cashier'), (v_a, tests.id('otto'), 'owner'),
    (v_a, tests.id('erin'), 'manager');
end;
$$;

create function tests.test_01_who_can_issue_codes() returns setof text language plpgsql as $$
declare
  v_code jsonb;
begin
  perform tests.seed();
  perform tests.as_user('adam');
  v_code := public.create_pin_reset(tests.id('a'), tests.id('carol'));
  return next ok(v_code ->> 'code' ~ '^[A-Z0-9]{10}$', 'An admin gets a one-time code for a staff member');
  return next throws_ok(format('select public.create_pin_reset(%L, %L)', tests.id('a'), tests.id('otto')),
    '42501', null, 'An admin can''t reset an owner''s PIN');
  return next throws_ok(format('select public.create_pin_reset(%L, %L)', tests.id('a'), tests.id('erin')),
    'P0001', null, 'People who sign in with email are told to use Forgot password');

  perform tests.as_user('carol');
  return next throws_ok(format('select public.create_pin_reset(%L, %L)', tests.id('a'), tests.id('carol')),
    '42501', null, 'A cashier can''t issue codes');
  perform tests.as_user('bob');
  return next throws_ok(format('select public.create_pin_reset(%L, %L)', tests.id('a'), tests.id('carol')),
    '42501', null, 'Another organization can''t reset our staff''s PINs');
  return next throws_ok(format('select public.create_pin_reset(%L, %L)', tests.id('b'), tests.id('carol')),
    'P0001', null, '... not even through its own organization');
end;
$$;

create function tests.test_02_codes() returns setof text language plpgsql as $$
declare
  v_first text;
  v_second text;
begin
  perform tests.seed();
  perform tests.as_user('alice');
  v_first := public.create_pin_reset(tests.id('a'), tests.id('carol')) ->> 'code';
  v_second := public.create_pin_reset(tests.id('a'), tests.id('carol')) ->> 'code';
  perform tests.as_owner_db();
  return next throws_ok(format('select public.peek_pin_reset(%L)', v_first), 'P0001', null,
    'A newer code cancels the older one');
  return next is((public.peek_pin_reset(lower(v_second)) ->> 'user_id')::uuid, tests.id('carol'),
    'The newest code works (any letter case)');

  insert into public.offline_credentials (user_id, salt, hash, iterations)
  values (tests.id('carol'), repeat('a', 32), repeat('b', 64), 60000);
  perform public.complete_pin_reset(v_second);
  return next throws_ok(format('select public.peek_pin_reset(%L)', v_second), 'P0001', null,
    'A code works once');
  return next is((select count(*)::int from public.offline_credentials where user_id = tests.id('carol')), 0,
    'The old offline sign-in check is removed');

  perform tests.as_user('alice');
  v_first := public.create_pin_reset(tests.id('a'), tests.id('carol')) ->> 'code';
  perform tests.as_owner_db();
  update public.pin_reset_codes set expires_at = now() - interval '1 minute' where code = v_first;
  return next throws_ok(format('select public.peek_pin_reset(%L)', v_first), 'P0001', null,
    'An expired code doesn''t work');

  perform tests.as_user('alice');
  v_first := public.create_pin_reset(tests.id('a'), tests.id('carol')) ->> 'code';
  perform tests.as_owner_db();
  update public.tenant_members set is_active = false where tenant_id = tests.id('a') and user_id = tests.id('carol');
  return next throws_ok(format('select public.peek_pin_reset(%L)', v_first), 'P0001', null,
    'A deactivated member can''t use a code');

  perform tests.as_user('carol');
  return next throws_ok(format('select public.peek_pin_reset(%L)', v_first), '42501', null,
    'Codes can''t be checked through the API');
  return next is((select count(*)::int from public.pin_reset_codes), 0, 'or read');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
