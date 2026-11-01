-- HydroTrack — debt reminder tests (pgTAP, xUnit style).
--
-- Checks who claim_due_debt_reminders picks on a given day (overdue,
-- weekly spacing, at most 4, restart after a payment, failed retries),
-- the SMS text, the bank-detail rules, and that only the service role can
-- send while members can only read their own organization's log.
--
-- One transaction, rolled back at the end: nothing persists and no SMS is
-- sent (this only exercises the database side).
--
-- Run:  ./supabase/tests/run_linked.sh

begin;

create extension if not exists pgtap with schema extensions;

create schema tests;
grant usage on schema tests to authenticated, anon;

create table tests.fx (key text primary key, id uuid not null);
grant select, insert on tests.fx to authenticated, anon;

create function tests.id(p_key text) returns uuid
language sql stable as $$ select id from tests.fx where key = p_key $$;

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
  perform set_config('request.jwt.claims',
    json_build_object('sub', tests.id(p_key), 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create function tests.as_owner_db() returns void language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- The fixed "today" every test uses.
create function tests.today() returns date language sql immutable as $$
  select date '2026-06-30';
$$;

-- A customer of tenant A owing p_balance, last paid p_paid_days_ago days
-- before today (null = never paid; then their first credit sale was
-- p_first_debt_days_ago days ago).
create function tests.customer(
  p_key text,
  p_balance numeric,
  p_paid_days_ago integer,
  p_first_debt_days_ago integer default null,
  p_phone text default '08031234567'
) returns uuid language plpgsql as $$
declare
  v_id uuid;
begin
  insert into public.customers (tenant_id, name, phone, area, balance, last_payment_date)
  values (tests.id('a_tenant'), initcap(p_key) || ' Stores', p_phone, 'Kano', p_balance,
          tests.today() - p_paid_days_ago)
  returning id into v_id;
  if p_first_debt_days_ago is not null then
    insert into public.ledger_entries (tenant_id, customer_id, type, amount, date)
    values (tests.id('a_tenant'), v_id, 'sale', p_balance, tests.today() - p_first_debt_days_ago);
  end if;
  insert into tests.fx (key, id) values (p_key, v_id);
  return v_id;
end;
$$;

-- Claims as the scheduler would on p_day, returning only tenant A's
-- customers (the live project may hold other organizations' customers).
create function tests.claimed_on(p_day date) returns setof uuid language plpgsql as $$
declare
  v_ids uuid[];
begin
  -- Two statements: a query can't see rows inserted by a function it calls.
  select array_agg(c.id) into v_ids from public.claim_due_debt_reminders(p_day, 100000) c;
  return query
    select r.customer_id from public.debt_reminders r
    where r.id = any(v_ids) and r.tenant_id = tests.id('a_tenant');
end;
$$;

-- A past reminder for p_customer, p_days_ago before today.
create function tests.past_reminder(p_customer text, p_days_ago integer, p_status text default 'sent')
returns void language sql as $$
  insert into public.debt_reminders (tenant_id, customer_id, phone, message, balance, status, sent_on)
  values (tests.id('a_tenant'), tests.id(p_customer), '2348031234567', 'x', 1,
          p_status::public.debt_reminder_status, tests.today() - p_days_ago);
$$;

create function tests.seed_organizations() returns void language plpgsql as $$
begin
  perform tests.create_user('alice', 'Alice Owner', 'alice@reminders-test.invalid');
  perform tests.create_user('bob', 'Bob Owner', 'bob@reminders-test.invalid');
  perform tests.as_user('alice');
  insert into tests.fx (key, id) values ('a_tenant', (public.create_tenant('Sunny Water')).id);
  perform tests.as_user('bob');
  insert into tests.fx (key, id) values ('b_tenant', (public.create_tenant('Other Water')).id);
  perform tests.as_owner_db();
  update public.tenants
  set bank_name = 'GTBank', bank_account_number = '0123456789', bank_account_name = 'Sunny Water Ltd'
  where id = tests.id('a_tenant');
end;
$$;

-- =========================================================================
-- Tests
-- =========================================================================

create function tests.test_01_message_text() returns setof text language plpgsql as $$
begin
  return next is(
    public.debt_reminder_message('Sunny Water', 'Musa Ibrahim', 12500, 'GTBank', '0123456789', 'Sunny Water Ltd'),
    'Hello Musa, this is Sunny Water. Your outstanding balance is NGN12,500. '
      || 'Please pay to GTBank 0123456789 (Sunny Water Ltd). Thank you.',
    'Message names the customer, the business, the balance and where to pay');
  return next is(
    public.debt_reminder_message('Sunny Water', 'Musa', 1500.5, null, null, null),
    'Hello Musa, this is Sunny Water. Your outstanding balance is NGN1,500.50. '
      || 'Please make a payment soon. Thank you.',
    'Without bank details it still asks for payment; kobo shown only when present');
  return next ok(
    public.debt_reminder_message('Sunny Water', 'Musa', 1234567, 'GTBank', '0123456789', 'Sunny Water Ltd')
      !~ '[^\x20-\x7E]',
    'Message uses plain characters only (no ₦), so it bills as a normal SMS');
end;
$$;

create function tests.test_02_who_is_due() returns setof text language plpgsql as $$
begin
  perform tests.seed_organizations();
  perform tests.customer('overdue', 5000, 20);
  perform tests.customer('just_overdue', 5000, 14);
  perform tests.customer('recent', 5000, 5);
  perform tests.customer('settled', 0, 30);
  perform tests.customer('in_credit', -200, 30);
  perform tests.customer('never_paid_old', 8000, null, 30);
  perform tests.customer('never_paid_new', 8000, null, 3);
  perform tests.customer('bad_phone', 5000, 20, null, '12345');

  return next set_eq(
    'select tests.claimed_on(tests.today())',
    format('values (%L::uuid), (%L::uuid), (%L::uuid)',
      tests.id('overdue'), tests.id('just_overdue'), tests.id('never_paid_old')),
    'Due: owing and 14+ days since last payment (or first credit sale if never paid)');

  return next is(
    (select phone from public.debt_reminders where customer_id = tests.id('overdue')),
    '2348031234567', 'Phone is stored in international format for Termii');
  return next is(
    (select status::text from public.debt_reminders where customer_id = tests.id('overdue')),
    'sending', 'Claimed reminders start as "sending"');
  return next is(
    (select message from public.debt_reminders where customer_id = tests.id('overdue')),
    'Hello Overdue, this is Sunny Water. Your outstanding balance is NGN5,000. '
      || 'Please pay to GTBank 0123456789 (Sunny Water Ltd). Thank you.',
    'Message uses the organization''s own name and bank details');

  return next is_empty('select tests.claimed_on(tests.today())',
    'Running again the same day claims nobody twice');
end;
$$;

create function tests.test_03_weekly_spacing_and_maximum() returns setof text language plpgsql as $$
begin
  perform tests.seed_organizations();
  perform tests.customer('weekly', 5000, 40);
  perform tests.past_reminder('weekly', 3);
  return next is_empty('select tests.claimed_on(tests.today())',
    'Not reminded again within 7 days of the last reminder');

  perform tests.customer('week_ago', 5000, 40);
  perform tests.past_reminder('week_ago', 7);
  return next set_eq('select tests.claimed_on(tests.today())',
    format('values (%L::uuid)', tests.id('week_ago')),
    'Reminded again once 7 days have passed');

  perform tests.customer('maxed', 5000, 60);
  perform tests.past_reminder('maxed', 35);
  perform tests.past_reminder('maxed', 28);
  perform tests.past_reminder('maxed', 21);
  perform tests.past_reminder('maxed', 14);
  return next is_empty('select tests.claimed_on(tests.today())',
    'No more than 4 reminders since the last payment');
end;
$$;

create function tests.test_04_payment_restarts_the_schedule() returns setof text language plpgsql as $$
begin
  perform tests.seed_organizations();
  perform tests.customer('payer', 5000, 60);
  perform tests.past_reminder('payer', 50);
  perform tests.past_reminder('payer', 43);
  perform tests.past_reminder('payer', 36);
  perform tests.past_reminder('payer', 29);

  -- They paid part of it 20 days ago and still owe.
  update public.customers set last_payment_date = tests.today() - 20 where id = tests.id('payer');
  return next set_eq('select tests.claimed_on(tests.today())',
    format('values (%L::uuid)', tests.id('payer')),
    'A payment restarts the count: overdue again 14 days later gets reminders again');
end;
$$;

create function tests.test_05_failed_sends_retry_next_day() returns setof text language plpgsql as $$
begin
  perform tests.seed_organizations();
  perform tests.customer('retry', 5000, 30);
  perform tests.past_reminder('retry', 1, 'failed');
  return next set_eq('select tests.claimed_on(tests.today())',
    format('values (%L::uuid)', tests.id('retry')),
    'A failed send is retried the next day, not a week later');

  perform tests.customer('dead_number', 5000, 30);
  perform tests.past_reminder('dead_number', 3, 'failed');
  perform tests.past_reminder('dead_number', 2, 'failed');
  perform tests.past_reminder('dead_number', 1, 'failed');
  return next is_empty(
    format('select tests.claimed_on(tests.today()) except select %L::uuid', tests.id('retry')),
    'After 3 failures the number is given up on');
end;
$$;

create function tests.test_06_finishing_a_reminder() returns setof text language plpgsql as $$
declare
  v_reminder uuid;
begin
  perform tests.seed_organizations();
  perform tests.customer('finish', 5000, 30);
  perform tests.claimed_on(tests.today());
  v_reminder := (select id from public.debt_reminders where customer_id = tests.id('finish'));

  perform public.finish_debt_reminder(v_reminder, true, 'termii-123', null);
  return next is(
    (select status::text || ' ' || provider_message_id from public.debt_reminders where id = v_reminder),
    'sent termii-123', 'A delivered reminder is marked sent with Termii''s message id');

  perform public.finish_debt_reminder(v_reminder, false, null, 'late duplicate');
  return next is(
    (select status::text from public.debt_reminders where id = v_reminder),
    'sent', 'A finished reminder can''t be changed afterwards');
end;
$$;

create function tests.test_07_bank_details_rules() returns setof text language plpgsql as $$
begin
  perform tests.seed_organizations();
  perform tests.as_user('bob');
  return next lives_ok(
    format($q$update public.tenants set bank_name = 'Access Bank', bank_account_number = '1234567890',
              bank_account_name = 'Other Water' where id = %L$q$, tests.id('b_tenant')),
    'An owner can set their organization''s bank details');
  return next throws_ok(
    format($q$update public.tenants set bank_account_number = '12345' where id = %L$q$, tests.id('b_tenant')),
    '23514', null, 'Account number must be 10 digits (NUBAN)');
  return next throws_ok(
    format($q$update public.tenants set bank_name = null where id = %L$q$, tests.id('b_tenant')),
    '23514', null, 'Bank details are all three or none');

  update public.tenants set bank_name = 'Hacked' where id = tests.id('a_tenant');
  perform tests.as_owner_db();
  return next is((select bank_name from public.tenants where id = tests.id('a_tenant')), 'GTBank',
    'Nobody can change another organization''s bank details');
end;
$$;

create function tests.test_08_only_the_scheduler_sends() returns setof text language plpgsql as $$
begin
  perform tests.seed_organizations();
  perform tests.customer('secure', 5000, 30);
  perform tests.past_reminder('secure', 20);

  perform tests.as_user('alice');
  return next throws_ok('select public.claim_due_debt_reminders()', '42501', null,
    'Signed-in users can''t trigger sending');
  return next throws_ok(
    format('select public.finish_debt_reminder(%L, true)', gen_random_uuid()), '42501', null,
    'Signed-in users can''t mark reminders as sent');
  return next throws_ok(
    format($q$insert into public.debt_reminders (tenant_id, customer_id, phone, message, balance)
              values (%L, %L, '2348000000000', 'x', 1)$q$, tests.id('a_tenant'), tests.id('secure')),
    '42501', null, 'Signed-in users can''t write to the reminder log');
  return next is((select count(*)::int from public.debt_reminders where tenant_id = tests.id('a_tenant')), 1,
    'Members can read their own organization''s reminders');

  perform tests.as_user('bob');
  return next is((select count(*)::int from public.debt_reminders where tenant_id = tests.id('a_tenant')), 0,
    'Other organizations can''t see them');
end;
$$;

grant execute on all functions in schema tests to authenticated, anon;

select * from runtests('tests'::name);

rollback;
