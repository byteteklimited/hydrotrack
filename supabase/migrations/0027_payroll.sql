-- HydroTrack — 0027: staff and payroll (Phase D part 3, agreed rules).
--
--   * Workers: people on the payroll — packers, loaders, security without
--     app accounts, and app staff (linked to their membership). Each has a
--     pay type: monthly salary, daily wage, or per bag.
--   * Pay rates, advances and payroll are seen only by owners and admins
--     (rates live in worker_rates, which supervisors can't read).
--   * Attendance: managers and store keepers mark each worker present,
--     half day or absent for a day. Bag counts: they enter each per-bag
--     worker's bags for a day. Both work offline.
--   * Advances: recorded when given (wages paid out then), deducted at the
--     next payroll.
--   * Monthly payroll (owners/admins): prepare_payroll works out each line —
--       monthly: salary − salary ÷ working days (Mon–Sat) × absent days
--                (a half day counts half; only days marked absent count)
--       daily:   wage × days present (half day = half)
--       per bag: rate × bags
--     minus advances not yet deducted, plus any adjustment the owner types.
--     pay_payroll posts each person's net pay as a wages expense (cash or
--     transfer) and marks their advances deducted. Payslips are made in the
--     app.

-- =========================================================================
-- Workers and rates
-- =========================================================================

create table workers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  phone text,
  job_title text,
  pay_type text not null check (pay_type in ('monthly', 'daily', 'per_bag')),
  user_id uuid,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, user_id) references tenant_members (tenant_id, user_id) on delete set null (user_id)
);
create unique index workers_one_per_member on workers (tenant_id, user_id) where user_id is not null;
create index workers_tenant_idx on workers (tenant_id, name);

create table worker_rates (
  tenant_id uuid not null references tenants (id) on delete cascade,
  worker_id uuid not null,
  rate numeric(12, 2) not null check (rate >= 0),
  updated_at timestamptz not null default now(),
  primary key (tenant_id, worker_id),
  foreign key (tenant_id, worker_id) references workers (tenant_id, id) on delete cascade
);

alter table workers enable row level security;
create policy workers_select on workers
  for select to authenticated using (is_tenant_member(tenant_id));
create policy workers_insert on workers
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy workers_update on workers
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));

alter table worker_rates enable row level security;
create policy worker_rates_select on worker_rates
  for select to authenticated using (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy worker_rates_insert on worker_rates
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy worker_rates_update on worker_rates
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));

-- =========================================================================
-- Attendance and bag counts
-- =========================================================================

create table attendance (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  worker_id uuid not null,
  date date not null,
  status text not null check (status in ('present', 'half_day', 'absent')),
  marked_by uuid not null,
  marked_at timestamptz not null default effective_now(),
  unique (tenant_id, id),
  unique (tenant_id, worker_id, date),
  foreign key (tenant_id, worker_id) references workers (tenant_id, id) on delete cascade,
  foreign key (tenant_id, marked_by) references tenant_members (tenant_id, user_id),
  constraint attendance_marked_by_profile_fkey foreign key (marked_by) references profiles (id)
);
create index attendance_tenant_date_idx on attendance (tenant_id, date);

create table bag_counts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  worker_id uuid not null,
  date date not null,
  bags integer not null check (bags >= 0),
  entered_by uuid not null,
  entered_at timestamptz not null default effective_now(),
  unique (tenant_id, id),
  unique (tenant_id, worker_id, date),
  foreign key (tenant_id, worker_id) references workers (tenant_id, id) on delete cascade,
  foreign key (tenant_id, entered_by) references tenant_members (tenant_id, user_id),
  constraint bag_counts_entered_by_profile_fkey foreign key (entered_by) references profiles (id)
);
create index bag_counts_tenant_date_idx on bag_counts (tenant_id, date);

alter table attendance enable row level security;
create policy attendance_select on attendance
  for select to authenticated using (is_tenant_member(tenant_id));
alter table bag_counts enable row level security;
create policy bag_counts_select on bag_counts
  for select to authenticated using (is_tenant_member(tenant_id));

create function require_day_for_records(p_date date)
returns void
language plpgsql stable
security definer set search_path = public
as $$
begin
  if p_date is null or p_date > (effective_now() at time zone 'Africa/Lagos')::date then
    raise exception 'This can''t be recorded for a future day';
  end if;
end;
$$;

-- [{worker_id, status}] for one day; marking again replaces.
create function record_attendance(p_tenant_id uuid, p_date date, p_entries jsonb)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_entry jsonb;
  v_count integer := 0;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'mark attendance');
  perform require_day_for_records(p_date);
  for v_entry in select * from jsonb_array_elements(p_entries)
  loop
    if not exists (select 1 from workers where tenant_id = p_tenant_id and id = (v_entry ->> 'worker_id')::uuid) then
      raise exception 'Worker not found';
    end if;
    insert into attendance (tenant_id, worker_id, date, status, marked_by)
    values (p_tenant_id, (v_entry ->> 'worker_id')::uuid, p_date, v_entry ->> 'status', auth.uid())
    on conflict (tenant_id, worker_id, date) do update
      set status = excluded.status, marked_by = excluded.marked_by, marked_at = effective_now();
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- [{worker_id, bags}] for one day; entering again replaces.
create function record_bag_counts(p_tenant_id uuid, p_date date, p_entries jsonb)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_entry jsonb;
  v_count integer := 0;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'enter bag counts');
  perform require_day_for_records(p_date);
  for v_entry in select * from jsonb_array_elements(p_entries)
  loop
    if not exists (select 1 from workers where tenant_id = p_tenant_id and id = (v_entry ->> 'worker_id')::uuid
                     and pay_type = 'per_bag') then
      raise exception 'Bag counts are only for workers paid per bag';
    end if;
    insert into bag_counts (tenant_id, worker_id, date, bags, entered_by)
    values (p_tenant_id, (v_entry ->> 'worker_id')::uuid, p_date, (v_entry ->> 'bags')::integer, auth.uid())
    on conflict (tenant_id, worker_id, date) do update
      set bags = excluded.bags, entered_by = excluded.entered_by, entered_at = effective_now();
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- =========================================================================
-- Wages paid out (advances and payroll)
-- =========================================================================

create function post_wages(
  p_tenant_id uuid,
  p_date date,
  p_description text,
  p_amount numeric,
  p_method payment_channel
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_expense_id uuid;
begin
  if p_method is null then
    raise exception 'Say how it was paid (cash or transfer)';
  end if;
  insert into expenses (tenant_id, date, category, description, amount, method, recorded_by)
  values (p_tenant_id, p_date, 'wages', p_description, p_amount, p_method, auth.uid())
  returning id into v_expense_id;
  insert into cash_entries (tenant_id, date_time, direction, source, amount, method, note, recorded_by)
  values (p_tenant_id, p_date::timestamptz, 'money_out', 'wages', p_amount, p_method, p_description, auth.uid());
  return v_expense_id;
end;
$$;

create table payrolls (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  status text not null default 'draft' check (status in ('draft', 'paid')),
  working_days integer not null,
  prepared_by uuid references profiles (id) on delete set null,
  prepared_at timestamptz not null default now(),
  paid_by uuid references profiles (id) on delete set null,
  paid_at timestamptz,
  method payment_channel,
  unique (tenant_id, id),
  unique (tenant_id, month)
);

create table salary_advances (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  worker_id uuid not null,
  date date not null,
  amount numeric(12, 2) not null check (amount > 0),
  method payment_channel not null,
  note text,
  expense_id uuid,
  payroll_id uuid,
  given_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, worker_id) references workers (tenant_id, id) on delete cascade,
  foreign key (tenant_id, payroll_id) references payrolls (tenant_id, id) on delete set null (payroll_id)
);
create index salary_advances_tenant_idx on salary_advances (tenant_id, worker_id, date);

create table payroll_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  payroll_id uuid not null,
  worker_id uuid not null,
  pay_type text not null,
  rate numeric(12, 2) not null,
  days_present numeric(5, 1) not null default 0,
  days_absent numeric(5, 1) not null default 0,
  bags integer not null default 0,
  gross numeric(12, 2) not null,
  absence_deduction numeric(12, 2) not null default 0,
  advances numeric(12, 2) not null default 0,
  adjustment numeric(12, 2) not null default 0,
  adjustment_note text,
  net numeric(12, 2) not null,
  expense_id uuid,
  unique (tenant_id, id),
  unique (tenant_id, payroll_id, worker_id),
  foreign key (tenant_id, payroll_id) references payrolls (tenant_id, id) on delete cascade,
  foreign key (tenant_id, worker_id) references workers (tenant_id, id) on delete cascade
);

alter table payrolls enable row level security;
create policy payrolls_select on payrolls
  for select to authenticated using (has_tenant_role(tenant_id, array['admin']::staff_role[]));
alter table payroll_lines enable row level security;
create policy payroll_lines_select on payroll_lines
  for select to authenticated using (has_tenant_role(tenant_id, array['admin']::staff_role[]));
alter table salary_advances enable row level security;
create policy salary_advances_select on salary_advances
  for select to authenticated using (has_tenant_role(tenant_id, array['admin']::staff_role[]));

create function give_advance(
  p_tenant_id uuid,
  p_worker_id uuid,
  p_date date,
  p_amount numeric,
  p_method payment_channel,
  p_note text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_worker workers;
  v_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'give salary advances');
  select * into v_worker from workers where tenant_id = p_tenant_id and id = p_worker_id;
  if not found then
    raise exception 'Worker not found';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Enter the amount given';
  end if;
  perform require_day_for_records(p_date);
  insert into salary_advances (tenant_id, worker_id, date, amount, method, note, expense_id, given_by)
  values (p_tenant_id, p_worker_id, p_date, p_amount, p_method, nullif(btrim(p_note), ''),
          post_wages(p_tenant_id, p_date, 'Salary advance: ' || v_worker.name, p_amount, p_method), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- Mondays to Saturdays in the month.
create function working_days_in(p_month date)
returns integer
language sql immutable
set search_path = ''
as $$
  select count(*)::integer
  from generate_series(p_month, (p_month + interval '1 month' - interval '1 day')::date, interval '1 day') d
  where extract(isodow from d) < 7;
$$;

-- Creates the month's draft, or works it out again (keeping adjustments).
create function prepare_payroll(p_tenant_id uuid, p_month date)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_month date := date_trunc('month', p_month)::date;
  v_end date := (date_trunc('month', p_month) + interval '1 month')::date;
  v_payroll payrolls;
  v_working integer := working_days_in(date_trunc('month', p_month)::date);
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'prepare payroll');
  if v_month > (now() at time zone 'Africa/Lagos')::date then
    raise exception 'Payroll can''t be prepared for a future month';
  end if;
  select * into v_payroll from payrolls where tenant_id = p_tenant_id and month = v_month for update;
  if found and v_payroll.status = 'paid' then
    raise exception 'This month''s payroll has already been paid';
  end if;
  if not found then
    insert into payrolls (tenant_id, month, working_days, prepared_by)
    values (p_tenant_id, v_month, v_working, auth.uid())
    returning * into v_payroll;
  else
    update payrolls set working_days = v_working, prepared_by = auth.uid(), prepared_at = now()
    where id = v_payroll.id;
  end if;

  with figures as (
    select w.id as worker_id, w.pay_type, coalesce(r.rate, 0) as rate,
      coalesce((select sum(case a.status when 'present' then 1 when 'half_day' then 0.5 else 0 end)
                from attendance a where a.tenant_id = w.tenant_id and a.worker_id = w.id
                  and a.date >= v_month and a.date < v_end), 0) as present,
      coalesce((select sum(case a.status when 'absent' then 1 when 'half_day' then 0.5 else 0 end)
                from attendance a where a.tenant_id = w.tenant_id and a.worker_id = w.id
                  and a.date >= v_month and a.date < v_end), 0) as absent,
      coalesce((select sum(b.bags) from bag_counts b where b.tenant_id = w.tenant_id and b.worker_id = w.id
                  and b.date >= v_month and b.date < v_end), 0)::integer as bags,
      coalesce((select sum(s.amount) from salary_advances s where s.tenant_id = w.tenant_id and s.worker_id = w.id
                  and s.payroll_id is null and s.date < v_end), 0) as advances
    from workers w
    left join worker_rates r on r.tenant_id = w.tenant_id and r.worker_id = w.id
    where w.tenant_id = p_tenant_id
      and (w.is_active
           or exists (select 1 from attendance a where a.tenant_id = w.tenant_id and a.worker_id = w.id
                        and a.date >= v_month and a.date < v_end)
           or exists (select 1 from bag_counts b where b.tenant_id = w.tenant_id and b.worker_id = w.id
                        and b.date >= v_month and b.date < v_end))
  ),
  lines as (
    select f.*,
      case f.pay_type when 'monthly' then f.rate
                      when 'daily' then round(f.rate * f.present, 2)
                      else round(f.rate * f.bags, 2) end as gross,
      case when f.pay_type = 'monthly' and v_working > 0
           then least(f.rate, round(f.rate / v_working * f.absent, 2)) else 0 end as deduction
    from figures f
  )
  insert into payroll_lines (tenant_id, payroll_id, worker_id, pay_type, rate, days_present, days_absent, bags,
                             gross, absence_deduction, advances, net)
  select p_tenant_id, v_payroll.id, l.worker_id, l.pay_type, l.rate, l.present, l.absent, l.bags,
    l.gross, l.deduction, l.advances, l.gross - l.deduction - l.advances
  from lines l
  on conflict (tenant_id, payroll_id, worker_id) do update
    set pay_type = excluded.pay_type, rate = excluded.rate, days_present = excluded.days_present,
        days_absent = excluded.days_absent, bags = excluded.bags, gross = excluded.gross,
        absence_deduction = excluded.absence_deduction, advances = excluded.advances,
        net = excluded.gross - excluded.absence_deduction - excluded.advances + payroll_lines.adjustment;
  return v_payroll.id;
end;
$$;

-- A bonus (+) or deduction (−) on one line of a draft.
create function adjust_payroll_line(p_tenant_id uuid, p_line_id uuid, p_adjustment numeric, p_note text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_line payroll_lines;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'adjust payroll');
  select l.* into v_line from payroll_lines l join payrolls p on p.tenant_id = l.tenant_id and p.id = l.payroll_id
  where l.tenant_id = p_tenant_id and l.id = p_line_id and p.status = 'draft'
  for update of l;
  if not found then
    raise exception 'Payroll line not found, or that payroll is already paid';
  end if;
  if coalesce(p_adjustment, 0) <> 0 and nullif(btrim(p_note), '') is null then
    raise exception 'Say what the adjustment is for (it shows on the payslip)';
  end if;
  update payroll_lines
  set adjustment = coalesce(p_adjustment, 0), adjustment_note = nullif(btrim(p_note), ''),
      net = gross - absence_deduction - advances + coalesce(p_adjustment, 0)
  where id = v_line.id;
end;
$$;

-- Pays a draft: each net amount becomes a wages expense; advances count
-- as deducted.
create function pay_payroll(p_tenant_id uuid, p_payroll_id uuid, p_method payment_channel)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_payroll payrolls;
  v_line record;
  v_count integer := 0;
  v_date date := (now() at time zone 'Africa/Lagos')::date;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'pay payroll');
  select * into v_payroll from payrolls where tenant_id = p_tenant_id and id = p_payroll_id for update;
  if not found then
    raise exception 'Payroll not found';
  end if;
  if v_payroll.status = 'paid' then
    raise exception 'This payroll has already been paid';
  end if;
  if exists (select 1 from payroll_lines where payroll_id = p_payroll_id and net < 0) then
    raise exception 'Someone''s advances are more than their pay. Adjust their line before paying.';
  end if;
  for v_line in
    select l.*, w.name from payroll_lines l join workers w on w.tenant_id = l.tenant_id and w.id = l.worker_id
    where l.tenant_id = p_tenant_id and l.payroll_id = p_payroll_id and l.net > 0
  loop
    update payroll_lines
    set expense_id = post_wages(p_tenant_id, v_date,
          format('Wages: %s (%s)', v_line.name, to_char(v_payroll.month, 'Mon YYYY')), v_line.net, p_method)
    where id = v_line.id;
    v_count := v_count + 1;
  end loop;
  update salary_advances s set payroll_id = p_payroll_id
  from payroll_lines l
  where l.tenant_id = p_tenant_id and l.payroll_id = p_payroll_id and s.tenant_id = l.tenant_id
    and s.worker_id = l.worker_id and s.payroll_id is null
    and s.date < (v_payroll.month + interval '1 month')::date;
  update payrolls set status = 'paid', paid_at = now(), paid_by = auth.uid(), method = p_method
  where id = p_payroll_id;
  return v_count;
end;
$$;

-- =========================================================================
-- Subscription guard, offline, grants
-- =========================================================================

create trigger guard_subscription before insert or update or delete on workers
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on worker_rates
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on attendance
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on bag_counts
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on salary_advances
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on payrolls
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on payroll_lines
  for each row execute function guard_subscription();

-- Offline: attendance and bag counts (two new record types).
create or replace function apply_device_operation(p_device_key text, p_op jsonb)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
#variable_conflict use_column
declare
  v_device devices := device_for_key(p_device_key);
  v_op_id uuid := (p_op ->> 'op_id')::uuid;
  v_type text := p_op ->> 'type';
  v_actor uuid := (p_op ->> 'actor_id')::uuid;
  v_recorded_at timestamptz := coalesce((p_op ->> 'recorded_at')::timestamptz, now());
  v_payload jsonb := coalesce(p_op -> 'payload', '{}'::jsonb);
  v_tenant uuid := v_device.tenant_id;
  v_existing device_operations;
  v_result jsonb;
  v_shortage text;
  v_id uuid;
  v_product_id uuid;
  v_lines jsonb;
  v_customer customers;
  v_load_out_id uuid;
  v_error text;
  v_caller_sub text := coalesce(current_setting('request.jwt.claim.sub', true), '');
  v_caller_claims text := coalesce(current_setting('request.jwt.claims', true), '');
begin
  if v_op_id is null or v_type is null or v_actor is null then
    raise exception 'Malformed record: op_id, type and actor_id are required';
  end if;

  select * into v_existing from device_operations where op_id = v_op_id;
  if v_existing.op_id is not null and v_existing.tenant_id <> v_tenant then
    raise exception 'Record belongs to another organization' using errcode = '42501';
  end if;
  if v_existing.status = 'applied' then
    return jsonb_build_object('op_id', v_op_id, 'status', 'applied', 'result', v_existing.result);
  end if;

  update devices set last_seen_at = now() where id = v_device.id;

  begin
    perform set_config('request.jwt.claim.sub', v_actor::text, true);
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_actor, 'role', 'authenticated')::text, true);
    perform set_config('hydrotrack.offline_sync', 'on', true);
    perform set_config('hydrotrack.recorded_at', v_recorded_at::text, true);

    case v_type
    when 'sale' then
      select coalesce(jsonb_agg(line || jsonb_build_object('product_id', product_from_record(v_tenant, line))), '[]'::jsonb)
      into v_lines
      from jsonb_array_elements(coalesce(v_payload -> 'lines', '[]'::jsonb)) as line;
      v_shortage := sale_shortage(v_tenant, v_lines);
      v_id := record_sale(
        v_tenant,
        (v_payload ->> 'customer_type')::sales_customer_type,
        v_payload ->> 'customer_name',
        (v_payload ->> 'total')::numeric,
        (v_payload ->> 'amount_paid')::numeric,
        (v_payload ->> 'payment_method')::sales_payment_method,
        (v_payload ->> 'balance')::numeric,
        v_lines,
        (v_payload ->> 'paid_channel')::payment_channel
      );
      update sales set date_time = v_recorded_at where tenant_id = v_tenant and id = v_id;
      update cash_entries set date_time = v_recorded_at where tenant_id = v_tenant and sale_id = v_id;
      update ledger_entries set date = (v_recorded_at at time zone 'Africa/Lagos')::date
        where tenant_id = v_tenant and sale_id = v_id;
      update stock_movements set at = v_recorded_at where tenant_id = v_tenant and sale_id = v_id;
      if v_shortage <> '' then
        insert into sync_flags (tenant_id, kind, details, sale_id, recorded_by, device_id)
        values (v_tenant, 'short_stock',
          'Sale recorded offline when stock was short: ' || rtrim(v_shortage, '; '),
          v_id, v_actor, v_device.id);
      end if;
      select * into v_customer from customers
      where tenant_id = v_tenant and name = v_payload ->> 'customer_name'
        and (v_payload ->> 'balance')::numeric > 0
      limit 1;
      if v_customer.id is not null and v_customer.balance > v_customer.credit_limit then
        insert into sync_flags (tenant_id, kind, details, sale_id, customer_id, recorded_by, device_id)
        values (v_tenant, 'over_credit_limit',
          format('%s now owes %s, over their credit limit of %s (credit sale recorded offline)',
            v_customer.name, v_customer.balance, v_customer.credit_limit),
          v_id, v_customer.id, v_actor, v_device.id);
      end if;
      v_result := jsonb_build_object('id', v_id);

    when 'production_run' then
      v_product_id := product_from_record(v_tenant, v_payload);
      v_shortage := production_shortage(v_tenant, v_product_id,
        (v_payload ->> 'quantity_produced')::integer + (v_payload ->> 'wastage')::integer);
      v_id := record_production_run(
        v_tenant,
        (v_payload ->> 'date')::date,
        (v_payload ->> 'shift')::production_shift,
        v_payload ->> 'machine',
        v_payload ->> 'operator_name',
        v_product_id,
        (v_payload ->> 'quantity_produced')::integer,
        (v_payload ->> 'wastage')::integer,
        (v_payload ->> 'expiry_date')::date
      );
      update production_runs set recorded_at = v_recorded_at where tenant_id = v_tenant and id = v_id;
      update stock_movements set at = v_recorded_at where tenant_id = v_tenant and production_run_id = v_id;
      if v_shortage <> '' then
        insert into sync_flags (tenant_id, kind, details, production_run_id, recorded_by, device_id)
        values (v_tenant, 'short_raw_material',
          'Production recorded offline when raw material was short: ' || rtrim(v_shortage, '; '),
          v_id, v_actor, v_device.id);
      end if;
      v_result := jsonb_build_object('id', v_id);

    when 'customer_payment' then
      perform record_customer_payment(
        v_tenant,
        (v_payload ->> 'customer_id')::uuid,
        (v_payload ->> 'amount')::numeric,
        (v_payload ->> 'channel')::payment_channel,
        (v_payload ->> 'date')::date,
        v_payload ->> 'note'
      );
      v_result := jsonb_build_object('customer_id', v_payload ->> 'customer_id');

    when 'expense' then
      v_id := record_expense(
        v_tenant,
        (v_payload ->> 'date')::date,
        (v_payload ->> 'category')::expense_category,
        v_payload ->> 'description',
        (v_payload ->> 'amount')::numeric,
        (v_payload ->> 'method')::payment_channel
      );
      v_result := jsonb_build_object('id', v_id);

    when 'customer' then
      perform require_tenant_role(v_tenant, array['admin', 'manager', 'cashier']::staff_role[], 'add customers');
      insert into customers (id, tenant_id, name, phone, area, credit_limit, balance)
      values (
        (v_payload ->> 'id')::uuid, v_tenant, btrim(v_payload ->> 'name'),
        btrim(v_payload ->> 'phone'), btrim(v_payload ->> 'area'),
        coalesce((v_payload ->> 'credit_limit')::numeric, 0), 0
      )
      on conflict (id) do nothing;
      v_result := jsonb_build_object('id', v_payload ->> 'id');

    when 'stock_in' then
      perform add_stock(
        v_tenant,
        (v_payload ->> 'item_id')::uuid,
        (v_payload ->> 'quantity')::integer,
        v_payload ->> 'note',
        (v_payload ->> 'expiry_date')::date
      );
      v_result := jsonb_build_object('item_id', v_payload ->> 'item_id');

    when 'stock_count' then
      perform adjust_stock_count(
        v_tenant,
        (v_payload ->> 'item_id')::uuid,
        (v_payload ->> 'new_count')::integer,
        v_payload ->> 'note'
      );
      v_result := jsonb_build_object('item_id', v_payload ->> 'item_id');

    when 'load_out' then
      v_id := record_load_out(
        v_tenant,
        (v_payload ->> 'driver_id')::uuid,
        (v_payload ->> 'vehicle_id')::uuid,
        product_from_record(v_tenant, v_payload),
        (v_payload ->> 'bags_loaded')::integer,
        v_payload ->> 'note'
      );
      update load_outs set date_time = v_recorded_at where tenant_id = v_tenant and id = v_id;
      v_result := jsonb_build_object('id', v_id);

    when 'driver_return' then
      v_load_out_id := coalesce(
        (v_payload ->> 'load_out_id')::uuid,
        (select (o.result ->> 'id')::uuid from device_operations o
          where o.op_id = (v_payload ->> 'load_out_op_id')::uuid
            and o.tenant_id = v_tenant and o.status = 'applied')
      );
      if v_load_out_id is null then
        raise exception 'The load-out for this return hasn''t synced yet';
      end if;
      perform settle_load_out(
        v_tenant,
        v_load_out_id,
        (v_payload ->> 'bags_sold')::integer,
        (v_payload ->> 'bags_returned')::integer,
        (v_payload ->> 'bags_damaged')::integer,
        (v_payload ->> 'cash_returned')::numeric,
        v_payload ->> 'discrepancy_note',
        coalesce((v_payload ->> 'customer_type')::sales_customer_type, 'walk_in'),
        v_payload ->> 'customer_name',
        (v_payload ->> 'unit_price')::numeric,
        (v_payload ->> 'amount_paid')::numeric,
        coalesce((v_payload ->> 'payment_method')::sales_payment_method, 'cash'),
        (v_payload ->> 'paid_channel')::payment_channel
      );
      update load_outs set settled_at = v_recorded_at where tenant_id = v_tenant and id = v_load_out_id;
      v_result := jsonb_build_object('id', v_load_out_id);

    when 'cash_count' then
      v_id := (record_cash_count(
        v_tenant,
        (v_payload ->> 'counted')::numeric,
        v_payload ->> 'note'
      )).id;
      v_result := jsonb_build_object('id', v_id);

    when 'water_test' then
      v_id := (record_water_test(
        v_tenant,
        (v_payload ->> 'date')::date,
        (v_payload ->> 'shift')::production_shift,
        (v_payload ->> 'ph')::numeric,
        (v_payload ->> 'tds')::numeric,
        (v_payload ->> 'chlorine')::numeric,
        v_payload ->> 'note'
      )).id;
      v_result := jsonb_build_object('id', v_id);

    when 'sanitation_check' then
      perform record_sanitation_check(
        v_tenant,
        (v_payload ->> 'date')::date,
        coalesce(v_payload -> 'items', '[]'::jsonb)
      );
      v_result := jsonb_build_object('date', v_payload ->> 'date');

    when 'diesel' then
      v_id := record_diesel(
        v_tenant,
        (v_payload ->> 'machine_id')::uuid,
        (v_payload ->> 'date')::date,
        (v_payload ->> 'litres')::numeric,
        (v_payload ->> 'cost')::numeric,
        (v_payload ->> 'method')::payment_channel,
        (v_payload ->> 'run_hours')::numeric,
        v_payload ->> 'note'
      );
      v_result := jsonb_build_object('id', v_id);

    when 'maintenance_done' then
      v_id := record_maintenance(
        v_tenant,
        (v_payload ->> 'task_id')::uuid,
        (v_payload ->> 'done_on')::date,
        (v_payload ->> 'cost')::numeric,
        (v_payload ->> 'method')::payment_channel,
        v_payload ->> 'note'
      );
      v_result := jsonb_build_object('id', v_id);

    when 'breakdown' then
      v_id := report_breakdown(
        v_tenant,
        (v_payload ->> 'machine_id')::uuid,
        (v_payload ->> 'started_at')::timestamptz,
        v_payload ->> 'cause',
        (v_payload ->> 'id')::uuid
      );
      v_result := jsonb_build_object('id', v_id);

    when 'breakdown_end' then
      perform end_breakdown(
        v_tenant,
        (v_payload ->> 'breakdown_id')::uuid,
        (v_payload ->> 'ended_at')::timestamptz,
        (v_payload ->> 'repair_cost')::numeric,
        (v_payload ->> 'method')::payment_channel,
        v_payload ->> 'note'
      );
      v_result := jsonb_build_object('id', v_payload ->> 'breakdown_id');

    when 'attendance' then
      perform record_attendance(v_tenant, (v_payload ->> 'date')::date, coalesce(v_payload -> 'entries', '[]'::jsonb));
      v_result := jsonb_build_object('date', v_payload ->> 'date');

    when 'bag_counts' then
      perform record_bag_counts(v_tenant, (v_payload ->> 'date')::date, coalesce(v_payload -> 'entries', '[]'::jsonb));
      v_result := jsonb_build_object('date', v_payload ->> 'date');

    else
      raise exception 'Unknown record type: %', v_type;
    end case;

    insert into device_operations (op_id, tenant_id, device_id, actor_id, type, payload, recorded_at, status, result)
    values (v_op_id, v_tenant, v_device.id, v_actor, v_type, v_payload, v_recorded_at, 'applied', v_result)
    on conflict (op_id) do update
      set status = 'applied', result = excluded.result, error = null,
          payload = excluded.payload, received_at = now();

    perform set_config('hydrotrack.offline_sync', '', true);
    perform set_config('hydrotrack.recorded_at', '', true);
    perform set_config('request.jwt.claim.sub', v_caller_sub, true);
    perform set_config('request.jwt.claims', v_caller_claims, true);

    return jsonb_build_object('op_id', v_op_id, 'status', 'applied', 'result', v_result);
  exception when others then
    get stacked diagnostics v_error = message_text;
    insert into device_operations (op_id, tenant_id, device_id, actor_id, type, payload, recorded_at, status, error)
    values (v_op_id, v_tenant, v_device.id, v_actor, v_type, v_payload, v_recorded_at, 'rejected', v_error)
    on conflict (op_id) do update
      set status = 'rejected', error = excluded.error, payload = excluded.payload, received_at = now();
    return jsonb_build_object('op_id', v_op_id, 'status', 'rejected', 'error', v_error);
  end;
end;
$$;

revoke all on function require_day_for_records(date) from public, anon, authenticated;
revoke all on function post_wages(uuid, date, text, numeric, payment_channel) from public, anon, authenticated;
revoke all on function working_days_in(date) from public, anon, authenticated;
revoke all on function record_attendance(uuid, date, jsonb) from public, anon;
revoke all on function record_bag_counts(uuid, date, jsonb) from public, anon;
revoke all on function give_advance(uuid, uuid, date, numeric, payment_channel, text) from public, anon;
revoke all on function prepare_payroll(uuid, date) from public, anon;
revoke all on function adjust_payroll_line(uuid, uuid, numeric, text) from public, anon;
revoke all on function pay_payroll(uuid, uuid, payment_channel) from public, anon;
grant execute on function record_attendance(uuid, date, jsonb) to authenticated;
grant execute on function record_bag_counts(uuid, date, jsonb) to authenticated;
grant execute on function give_advance(uuid, uuid, date, numeric, payment_channel, text) to authenticated;
grant execute on function prepare_payroll(uuid, date) to authenticated;
grant execute on function adjust_payroll_line(uuid, uuid, numeric, text) to authenticated;
grant execute on function pay_payroll(uuid, uuid, payment_channel) to authenticated;
