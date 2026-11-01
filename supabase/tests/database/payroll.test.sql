-- HydroTrack — staff and payroll tests (pgTAP, xUnit style).
--
-- Workers and private pay rates, attendance and bag counts, advances,
-- the monthly payroll (salary less absences, daily wage, per bag,
-- advances, adjustments), paying it (wages expenses), offline records,
-- and who may see and do what. One transaction, rolled back.
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
  perform tests.create_user('alice', 'Alice Owner', 'alice@p-test.invalid');
  perform tests.create_user('mike', 'Mike Manager', 'mike@p-test.invalid');
  perform tests.create_user('sam', 'Sam Store', 'sam@p-test.invalid');
  perform tests.create_user('carol', 'Carol Cashier', 'carol@p-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@p-test.invalid');
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


-- Workers in A (as alice): Musa monthly 54,000; Ada daily 3,000; Bello per
-- bag 5.
create function tests.workers() returns void language plpgsql as $$
declare
  v_id uuid;
begin
  perform tests.as_user('alice');
  insert into public.workers (tenant_id, name, pay_type) values (tests.id('a'), 'Musa', 'monthly') returning id into v_id;
  insert into public.worker_rates (tenant_id, worker_id, rate) values (tests.id('a'), v_id, 54000);
  insert into tests.fx (key, id) values ('musa_w', v_id);
  insert into public.workers (tenant_id, name, pay_type) values (tests.id('a'), 'Ada', 'daily') returning id into v_id;
  insert into public.worker_rates (tenant_id, worker_id, rate) values (tests.id('a'), v_id, 3000);
  insert into tests.fx (key, id) values ('ada', v_id);
  insert into public.workers (tenant_id, name, pay_type) values (tests.id('a'), 'Bello', 'per_bag') returning id into v_id;
  insert into public.worker_rates (tenant_id, worker_id, rate) values (tests.id('a'), v_id, 5);
  insert into tests.fx (key, id) values ('bello', v_id);
end;
$$;

-- October 2026 as the store keeper: Musa absent 2 days and a half day;
-- Ada present 20 days and a half day; Bello 1,000 + 1,200 bags.
create function tests.october() returns void language plpgsql as $$
declare
  v_day date;
begin
  perform tests.as_user('sam');
  perform public.record_attendance(tests.id('a'), '2026-10-05', jsonb_build_array(
    jsonb_build_object('worker_id', tests.id('musa_w'), 'status', 'absent'),
    jsonb_build_object('worker_id', tests.id('ada'), 'status', 'half_day')));
  perform public.record_attendance(tests.id('a'), '2026-10-06', jsonb_build_array(
    jsonb_build_object('worker_id', tests.id('musa_w'), 'status', 'absent')));
  perform public.record_attendance(tests.id('a'), '2026-10-07', jsonb_build_array(
    jsonb_build_object('worker_id', tests.id('musa_w'), 'status', 'half_day')));
  for v_day in select d::date from generate_series('2026-10-08'::date, '2026-10-27'::date, interval '1 day') d
  loop
    perform public.record_attendance(tests.id('a'), v_day, jsonb_build_array(
      jsonb_build_object('worker_id', tests.id('ada'), 'status', 'present')));
  end loop;
  perform public.record_bag_counts(tests.id('a'), '2026-10-08', jsonb_build_array(
    jsonb_build_object('worker_id', tests.id('bello'), 'bags', 1000)));
  perform public.record_bag_counts(tests.id('a'), '2026-10-09', jsonb_build_array(
    jsonb_build_object('worker_id', tests.id('bello'), 'bags', 1200)));
end;
$$;

create function tests.line(p_worker text) returns public.payroll_lines language sql stable security definer as $$
  select * from public.payroll_lines where worker_id = tests.id(p_worker)
$$;

create function tests.test_01_workers_and_private_rates() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.workers();
  perform tests.as_user('mike');
  return next is((select count(*)::int from public.workers where tenant_id = tests.id('a')), 3,
    'Supervisors see the workers');
  return next is((select count(*)::int from public.worker_rates), 0, 'but not their pay rates');
  return next throws_ok(format('insert into public.workers (tenant_id, name, pay_type) values (%L, %L, %L)',
    tests.id('a'), 'Joy', 'daily'), '42501', null, 'and can''t add workers');
  perform tests.as_user('bob');
  return next is((select count(*)::int from public.workers), 0, 'Other organizations see none');
  perform tests.as_user('alice');
  return next lives_ok(format('insert into public.workers (tenant_id, name, pay_type, user_id) values (%L, %L, %L, %L)',
    tests.id('a'), 'Mike Manager', 'monthly', tests.id('mike')), 'App staff can be put on the payroll');
  return next throws_ok(format('insert into public.workers (tenant_id, name, pay_type, user_id) values (%L, %L, %L, %L)',
    tests.id('a'), 'Mike again', 'monthly', tests.id('mike')), '23505', null, 'once');
end;
$$;

create function tests.test_02_attendance_and_bags() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.workers();
  perform tests.october();
  return next is((select count(*)::int from public.attendance where worker_id = tests.id('ada')), 21,
    'Store keepers mark attendance');
  perform public.record_attendance(tests.id('a'), '2026-10-05', jsonb_build_array(
    jsonb_build_object('worker_id', tests.id('ada'), 'status', 'half_day')));
  return next is((select count(*)::int from public.attendance where worker_id = tests.id('ada')), 21,
    'Marking a day again replaces it');
  return next throws_like(format('select public.record_bag_counts(%L, %L, %L)', tests.id('a'), '2026-10-08',
    jsonb_build_array(jsonb_build_object('worker_id', tests.id('ada'), 'bags', 10))),
    'Bag counts are only for workers paid per bag', 'Bags only for per-bag workers');
  return next throws_like(format('select public.record_attendance(%L, current_date + 1, %L)', tests.id('a'),
    jsonb_build_array(jsonb_build_object('worker_id', tests.id('ada'), 'status', 'present'))),
    'This can''t be recorded for a future day', 'Future days are refused');
  perform tests.as_user('carol');
  return next throws_ok(format('select public.record_attendance(%L, current_date, %L)', tests.id('a'),
    jsonb_build_array(jsonb_build_object('worker_id', tests.id('ada'), 'status', 'present'))),
    '42501', null, 'Cashiers can''t mark attendance');
end;
$$;

create function tests.test_03_payroll() returns setof text language plpgsql as $$
declare
  v_payroll uuid;
begin
  perform tests.seed();
  perform tests.workers();
  perform tests.october();
  perform tests.as_user('alice');
  perform public.give_advance(tests.id('a'), tests.id('musa_w'), '2026-10-15', 10000, 'cash', 'School fees');
  return next is((select category::text || ' ' || amount from public.expenses where description = 'Salary advance: Musa'),
    'wages 10000.00', 'An advance is paid out as wages when given');

  v_payroll := public.prepare_payroll(tests.id('a'), '2026-10-01');
  return next is((select working_days from public.payrolls where id = v_payroll), 27,
    'October 2026 has 27 working days (Mon–Sat)');
  return next is((tests.line('musa_w')).absence_deduction, 5000::numeric,
    'Monthly: 54,000 ÷ 27 × 2.5 days absent = 5,000 off');
  return next is((tests.line('musa_w')).net, 39000::numeric, 'less the 10,000 advance');
  return next is((tests.line('ada')).net, 61500::numeric, 'Daily: 3,000 × 20.5 days');
  return next is((tests.line('bello')).net, 11000::numeric, 'Per bag: 5 × 2,200 bags');

  return next throws_like(format('select public.adjust_payroll_line(%L, %L, 2000)', tests.id('a'), (tests.line('ada')).id),
    'Say what the adjustment is for%', 'An adjustment needs a reason');
  perform public.adjust_payroll_line(tests.id('a'), (tests.line('ada')).id, 2000, 'Bonus');
  perform public.prepare_payroll(tests.id('a'), '2026-10-01');
  return next is((tests.line('ada')).net, 63500::numeric, 'Adjustments are kept when it''s worked out again');

  perform public.give_advance(tests.id('a'), tests.id('bello'), '2026-10-20', 20000, 'cash');
  perform public.prepare_payroll(tests.id('a'), '2026-10-01');
  return next throws_like(format('select public.pay_payroll(%L, %L, %L)', tests.id('a'), v_payroll, 'transfer'),
    'Someone''s advances are more than their pay%', 'It can''t be paid while a line is below zero');
  perform public.adjust_payroll_line(tests.id('a'), (tests.line('bello')).id, 9000, 'Advance written off');

  return next is(public.pay_payroll(tests.id('a'), v_payroll, 'transfer'), 2, 'Paying posts each net amount above zero');
  return next is((select sum(amount) from public.expenses where description like 'Wages: % (Oct 2026)'), 102500::numeric,
    'as wages expenses');
  return next is((select count(*)::int from public.salary_advances where payroll_id = v_payroll), 2,
    'and the advances count as deducted');
  return next throws_like(format('select public.prepare_payroll(%L, %L)', tests.id('a'), '2026-10-01'),
    'This month''s payroll has already been paid', 'A paid month is closed');
end;
$$;

create function tests.test_04_privacy() returns setof text language plpgsql as $$
begin
  perform tests.seed();
  perform tests.workers();
  perform tests.as_user('alice');
  perform public.give_advance(tests.id('a'), tests.id('ada'), current_date, 5000, 'cash');
  perform public.prepare_payroll(tests.id('a'), date_trunc('month', current_date)::date);
  perform tests.as_user('mike');
  return next is((select count(*)::int from public.payrolls), 0, 'Managers can''t see payroll');
  return next is((select count(*)::int from public.payroll_lines), 0, 'or its lines');
  return next is((select count(*)::int from public.salary_advances), 0, 'or advances');
  return next throws_ok(format('select public.prepare_payroll(%L, current_date)', tests.id('a')), '42501', null,
    'or prepare it');
  return next throws_ok(format('select public.give_advance(%L, %L, current_date, 100, %L)', tests.id('a'), tests.id('ada'), 'cash'),
    '42501', null, 'or give advances');
  perform tests.as_user('bob');
  return next throws_ok(format('select public.prepare_payroll(%L, current_date)', tests.id('a')), '42501', null,
    'Other organizations can''t either');
end;
$$;

create function tests.test_05_offline() returns setof text language plpgsql as $$
declare
  v_result jsonb;
begin
  perform tests.seed();
  perform tests.workers();
  perform tests.as_owner_db();
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'attendance', 'actor_id', tests.id('sam'), 'recorded_at', now(),
    'payload', jsonb_build_object('date', current_date, 'entries', jsonb_build_array(
      jsonb_build_object('worker_id', tests.id('ada'), 'status', 'present')))));
  return next is(v_result ->> 'status', 'applied', 'Attendance marked offline syncs');
  v_result := public.apply_device_operation(tests.note('device'), jsonb_build_object(
    'op_id', gen_random_uuid(), 'type', 'bag_counts', 'actor_id', tests.id('sam'), 'recorded_at', now(),
    'payload', jsonb_build_object('date', current_date, 'entries', jsonb_build_array(
      jsonb_build_object('worker_id', tests.id('bello'), 'bags', 900)))));
  return next is(v_result ->> 'status', 'applied', 'and so do bag counts');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
