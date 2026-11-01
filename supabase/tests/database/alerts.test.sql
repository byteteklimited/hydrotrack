-- HydroTrack — owner alerts tests (pgTAP, xUnit style).
--
-- Low stock once a day, the 8 pm daily summary, owners-only access, and
-- SMS copies (business phone, no backlog). One transaction, rolled back.
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


-- Organization A (owner alice, manager mike, cashier carol) with nylon
-- (reorder at 5) and 20 sachet bags; organization B (owner bob).
create function tests.seed() returns void language plpgsql as $$
declare
  v_a uuid;
  v_b uuid;
  v_nylon uuid;
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@alert-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@alert-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@alert-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@alert-test.invalid');
  perform tests.as_user('alice');
  v_a := (public.create_tenant('Sunny Water')).id;
  perform tests.as_user('bob');
  v_b := (public.create_tenant('Other Water')).id;
  perform tests.as_owner_db();
  insert into public.tenant_members (tenant_id, user_id, role) values
    (v_a, tests.id('mike'), 'manager'), (v_a, tests.id('carol'), 'cashier');
  insert into public.stock_items (tenant_id, name, category, unit, reorder_level, quantity_on_hand)
  values (v_a, 'Nylon roll', 'raw_material', 'rolls', 5, 3) returning id into v_nylon;
  insert into tests.fx (key, id) values ('a', v_a), ('b', v_b), ('nylon', v_nylon),
    ('sachet', tests.product(v_a, 'sachet50cl'));
  perform tests.as_user('alice');
  perform public.add_stock(v_a, (select id from public.stock_items where product_id = tests.id('sachet')), 20, 'Opening');
  perform tests.as_owner_db();
end;
$$;

create function tests.lagos(p_time text) returns timestamptz language sql immutable as $$
  select (current_date::text || ' ' || p_time)::timestamp at time zone 'Africa/Lagos';
$$;

create function tests.test_01_low_stock_once_a_day() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform public.generate_alerts(tests.lagos('09:00'));
  perform public.generate_alerts(tests.lagos('09:15'));
  return next is((select count(*)::int from public.alerts where tenant_id = tests.id('a') and kind = 'low_stock'), 1,
    'An item at or below its reorder level gets one alert a day');
  return next is((select body from public.alerts where item_id = tests.id('nylon')),
    'Nylon roll is down to 3 rolls (reorder at 5).', 'saying how low it is');
  return next is((select count(*)::int from public.alerts where tenant_id = tests.id('a') and kind = 'daily_summary'), 0,
    'No summary before 8 pm');
end;
$$;

create function tests.test_02_daily_summary() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.as_user('carol');
  perform public.record_sale(tests.id('a'), 'walk_in', null, 4000, 4000, 'cash', 0,
    jsonb_build_array(jsonb_build_object('product_id', tests.id('sachet'), 'quantity', 10, 'unit_price', 400)));
  perform public.record_cash_count(tests.id('a'), 3500, 'Short');
  perform tests.as_owner_db();
  perform public.generate_alerts(tests.lagos('20:05'));
  perform public.generate_alerts(tests.lagos('20:20'));
  return next is((select count(*)::int from public.alerts where tenant_id = tests.id('a') and kind = 'daily_summary'), 1,
    'One summary per organization from 8 pm');
  return next is((select body from public.alerts where tenant_id = tests.id('a') and kind = 'daily_summary'),
    'Today: 0 bags produced, 10 bags sold. Collected NGN4,000 cash and NGN0 by transfer. '
      || 'Money outside: NGN0. Cash counts short: 1 (NGN500). Sanitation checklist not done.',
    'with the day''s production, sales, takings, money outside and shortages');
end;
$$;

create function tests.test_03_owners_only() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform public.generate_alerts(tests.lagos('20:30'));
  perform tests.as_user('mike');
  return next is((select count(*)::int from public.alerts), 0, 'Managers don''t see owner alerts');
  perform tests.as_user('bob');
  return next is((select count(*)::int from public.alerts where tenant_id = tests.id('a')), 0,
    'Other organizations don''t either');
  perform tests.as_user('alice');
  return next ok((select count(*) from public.alerts) >= 2, 'The owner does');
  perform public.mark_alerts_read(tests.id('a'));
  return next is((select count(*)::int from public.alerts where read_at is null), 0, 'and can mark them read');
  perform tests.as_user('carol');
  return next throws_ok(format('select public.mark_alerts_read(%L)', tests.id('a')), '42501', null,
    'Staff can''t');
  return next throws_ok('select public.generate_alerts()', '42501', null, 'Nobody can create alerts through the API');
end;
$$;

create function tests.test_04_sms_copies() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform public.generate_alerts(tests.lagos('20:30'));
  return next is((select count(*)::int from public.claim_alert_sms() c
                  join public.alerts a on a.id = c.id where a.tenant_id = tests.id('a')), 0,
    'No business phone: alerts aren''t texted');
  return next is((select sms_status from public.alerts where tenant_id = tests.id('a') limit 1), 'skipped',
    '... and are marked skipped');

  update public.tenants set phone = '08031234567' where id = tests.id('a');
  update public.alerts set sms_status = 'pending' where tenant_id = tests.id('a');
  return next is((select string_agg(distinct c.phone, ',') from public.claim_alert_sms() c
                  join public.alerts a on a.id = c.id where a.tenant_id = tests.id('a')), '2348031234567',
    'With a phone they''re texted to it');

  update public.alerts set sms_status = 'pending', created_at = now() - interval '3 hours'
  where tenant_id = tests.id('a');
  return next is((select count(*)::int from public.claim_alert_sms() c
                  join public.alerts a on a.id = c.id where a.tenant_id = tests.id('a')), 0,
    'Alerts older than 2 hours are never texted (no backlog when SMS is switched on)');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
