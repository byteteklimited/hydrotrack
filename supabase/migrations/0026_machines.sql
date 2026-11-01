-- HydroTrack — 0026: machines and generator (Phase D part 2, agreed
-- rules).
--
--   * Each organization lists its machines (sachet machines, bottling
--     line, generator, borehole pump…). Production runs pick from the list;
--     production_runs.machine_id is filled from the machine name, so the
--     RPCs and offline records keep sending the name. Old runs keep their
--     typed names (a machine is created for each name already used).
--   * Maintenance: tasks per machine every N days ("change filter every 30
--     days"); due and overdue tasks show in the app and alert the owner
--     once when they fall due. Marking one done can carry a cost, posted
--     as a maintenance expense.
--   * Breakdowns: when a machine stopped and restarted, the cause, and the
--     repair cost (posted as a maintenance expense). Downtime hours per
--     machine per period in machine_report.
--   * Diesel: litres and cost put into the generator (the cost posts as a
--     diesel expense), optional run-hours; litres per bag in machine_report.
-- Diesel, maintenance done and breakdowns work offline.

-- =========================================================================
-- Machines
-- =========================================================================

create table machines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  kind text not null default 'production' check (kind in ('production', 'generator', 'pump', 'other')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, id)
);
create unique index machines_tenant_name_idx on machines (tenant_id, lower(btrim(name)));

alter table machines enable row level security;
create policy machines_select on machines
  for select to authenticated using (is_tenant_member(tenant_id));
create policy machines_insert on machines
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]));
create policy machines_update on machines
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]));

create function seed_machines(p_tenant_id uuid)
returns void
language sql
security definer set search_path = public
as $$
  insert into machines (tenant_id, name, kind)
  select p_tenant_id, m.name, m.kind
  from (values ('Machine 1', 'production'), ('Machine 2', 'production'), ('Generator', 'generator')) as m(name, kind)
  on conflict do nothing;
  insert into machines (tenant_id, name)
  select distinct on (lower(btrim(machine))) p_tenant_id, btrim(machine)
  from production_runs where tenant_id = p_tenant_id and btrim(machine) <> ''
  on conflict do nothing;
$$;

create function seed_machines_on_tenant()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform seed_machines(new.id);
  return new;
end;
$$;

create trigger seed_machines after insert on tenants
  for each row execute function seed_machines_on_tenant();

select seed_machines(id) from tenants;

-- Runs point at their machine (looked up by name).
alter table production_runs
  add column machine_id uuid,
  add foreign key (tenant_id, machine_id) references machines (tenant_id, id);
create index production_runs_machine_idx on production_runs (tenant_id, machine_id, date);

update production_runs r set machine_id = m.id
from machines m
where m.tenant_id = r.tenant_id and lower(btrim(m.name)) = lower(btrim(r.machine));

create function link_run_machine()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.machine is distinct from old.machine then
    select id into new.machine_id from machines
    where tenant_id = new.tenant_id and lower(btrim(name)) = lower(btrim(new.machine));
  end if;
  return new;
end;
$$;

create trigger link_run_machine before insert or update on production_runs
  for each row execute function link_run_machine();

-- =========================================================================
-- Expenses made by machine records (role checked by the caller)
-- =========================================================================

create function post_machine_expense(
  p_tenant_id uuid,
  p_date date,
  p_category expense_category,
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
  if p_amount is null or p_amount <= 0 then
    return null;
  end if;
  if p_method is null then
    raise exception 'Say how the % was paid (cash or transfer)', p_category;
  end if;
  insert into expenses (tenant_id, date, category, description, amount, method, recorded_by)
  values (p_tenant_id, p_date, p_category, p_description, p_amount, p_method, auth.uid())
  returning id into v_expense_id;
  insert into cash_entries (tenant_id, date_time, direction, source, amount, method, note, recorded_by)
  values (p_tenant_id, p_date::timestamptz, 'money_out', 'expense', p_amount, p_method, p_description, auth.uid());
  return v_expense_id;
end;
$$;

create function require_machine(p_tenant_id uuid, p_machine_id uuid)
returns machines
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_machine machines;
begin
  select * into v_machine from machines where tenant_id = p_tenant_id and id = p_machine_id;
  if not found then
    raise exception 'Machine not found';
  end if;
  return v_machine;
end;
$$;

-- =========================================================================
-- Maintenance
-- =========================================================================

create table maintenance_tasks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  machine_id uuid not null,
  name text not null check (btrim(name) <> ''),
  every_days integer not null check (every_days between 1 and 730),
  last_done_on date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, machine_id) references machines (tenant_id, id) on delete cascade
);
create index maintenance_tasks_tenant_idx on maintenance_tasks (tenant_id, machine_id);

create function maintenance_due_on(t maintenance_tasks)
returns date
language sql immutable
set search_path = ''
as $$
  select coalesce(t.last_done_on, (t.created_at at time zone 'Africa/Lagos')::date) + t.every_days;
$$;

create table maintenance_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  task_id uuid not null,
  machine_id uuid not null,
  done_on date not null,
  cost numeric(12, 2) not null default 0 check (cost >= 0),
  expense_id uuid,
  note text,
  done_by uuid not null,
  created_at timestamptz not null default effective_now(),
  unique (tenant_id, id),
  foreign key (tenant_id, task_id) references maintenance_tasks (tenant_id, id) on delete cascade,
  foreign key (tenant_id, machine_id) references machines (tenant_id, id),
  foreign key (tenant_id, done_by) references tenant_members (tenant_id, user_id),
  constraint maintenance_logs_done_by_profile_fkey foreign key (done_by) references profiles (id)
);
create index maintenance_logs_tenant_idx on maintenance_logs (tenant_id, done_on desc);

alter table maintenance_tasks enable row level security;
create policy maintenance_tasks_select on maintenance_tasks
  for select to authenticated using (is_tenant_member(tenant_id));
create policy maintenance_tasks_insert on maintenance_tasks
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]));
create policy maintenance_tasks_update on maintenance_tasks
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]));
alter table maintenance_logs enable row level security;
create policy maintenance_logs_select on maintenance_logs
  for select to authenticated using (is_tenant_member(tenant_id));

create function record_maintenance(
  p_tenant_id uuid,
  p_task_id uuid,
  p_done_on date,
  p_cost numeric default 0,
  p_method payment_channel default null,
  p_note text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_task maintenance_tasks;
  v_machine machines;
  v_expense uuid;
  v_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'record maintenance');
  select * into v_task from maintenance_tasks where tenant_id = p_tenant_id and id = p_task_id for update;
  if not found then
    raise exception 'Maintenance task not found';
  end if;
  if p_done_on is null or p_done_on > (effective_now() at time zone 'Africa/Lagos')::date then
    raise exception 'Maintenance can''t be marked done for a future day';
  end if;
  v_machine := require_machine(p_tenant_id, v_task.machine_id);
  v_expense := post_machine_expense(p_tenant_id, p_done_on, 'maintenance',
    format('%s: %s', v_machine.name, v_task.name), coalesce(p_cost, 0), p_method);
  insert into maintenance_logs (tenant_id, task_id, machine_id, done_on, cost, expense_id, note, done_by)
  values (p_tenant_id, p_task_id, v_task.machine_id, p_done_on, coalesce(p_cost, 0), v_expense,
          nullif(btrim(p_note), ''), auth.uid())
  returning id into v_id;
  update maintenance_tasks set last_done_on = greatest(coalesce(last_done_on, p_done_on), p_done_on)
  where tenant_id = p_tenant_id and id = p_task_id;
  return v_id;
end;
$$;

-- =========================================================================
-- Breakdowns
-- =========================================================================

create table breakdowns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  machine_id uuid not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  cause text not null check (btrim(cause) <> ''),
  repair_cost numeric(12, 2) not null default 0 check (repair_cost >= 0),
  expense_id uuid,
  note text,
  reported_by uuid not null,
  ended_by uuid,
  unique (tenant_id, id),
  check (ended_at is null or ended_at > started_at),
  foreign key (tenant_id, machine_id) references machines (tenant_id, id),
  foreign key (tenant_id, reported_by) references tenant_members (tenant_id, user_id),
  constraint breakdowns_reported_by_profile_fkey foreign key (reported_by) references profiles (id),
  constraint breakdowns_ended_by_profile_fkey foreign key (ended_by) references profiles (id)
);
create index breakdowns_tenant_idx on breakdowns (tenant_id, started_at desc);
create unique index breakdowns_one_open_per_machine on breakdowns (tenant_id, machine_id) where ended_at is null;

alter table breakdowns enable row level security;
create policy breakdowns_select on breakdowns
  for select to authenticated using (is_tenant_member(tenant_id));

-- p_id lets a device give the breakdown its id, so ending it offline can
-- name it before either has synced.
create function report_breakdown(
  p_tenant_id uuid,
  p_machine_id uuid,
  p_started_at timestamptz,
  p_cause text,
  p_id uuid default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'report breakdowns');
  perform require_machine(p_tenant_id, p_machine_id);
  if p_started_at is null or p_started_at > effective_now() + interval '5 minutes' then
    raise exception 'When did the machine stop? It can''t be in the future';
  end if;
  if nullif(btrim(p_cause), '') is null then
    raise exception 'Say what went wrong';
  end if;
  if exists (select 1 from breakdowns where tenant_id = p_tenant_id and machine_id = p_machine_id and ended_at is null) then
    raise exception 'This machine already has an open breakdown. Mark that one fixed first.';
  end if;
  insert into breakdowns (id, tenant_id, machine_id, started_at, cause, reported_by)
  values (coalesce(p_id, gen_random_uuid()), p_tenant_id, p_machine_id, p_started_at, btrim(p_cause), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

create function end_breakdown(
  p_tenant_id uuid,
  p_breakdown_id uuid,
  p_ended_at timestamptz,
  p_repair_cost numeric default 0,
  p_method payment_channel default null,
  p_note text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_breakdown breakdowns;
  v_machine machines;
  v_expense uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'record repairs');
  select * into v_breakdown from breakdowns where tenant_id = p_tenant_id and id = p_breakdown_id for update;
  if not found then
    raise exception 'Breakdown not found';
  end if;
  if v_breakdown.ended_at is not null then
    raise exception 'This breakdown was already marked fixed';
  end if;
  if p_ended_at is null or p_ended_at <= v_breakdown.started_at then
    raise exception 'The machine must restart after it stopped';
  end if;
  if p_ended_at > effective_now() + interval '5 minutes' then
    raise exception 'The restart time can''t be in the future';
  end if;
  v_machine := require_machine(p_tenant_id, v_breakdown.machine_id);
  v_expense := post_machine_expense(p_tenant_id, (p_ended_at at time zone 'Africa/Lagos')::date, 'maintenance',
    format('Repair: %s (%s)', v_machine.name, v_breakdown.cause), coalesce(p_repair_cost, 0), p_method);
  update breakdowns
  set ended_at = p_ended_at, repair_cost = coalesce(p_repair_cost, 0), expense_id = v_expense,
      note = nullif(btrim(p_note), ''), ended_by = auth.uid()
  where tenant_id = p_tenant_id and id = p_breakdown_id;
end;
$$;

-- =========================================================================
-- Diesel
-- =========================================================================

create table diesel_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  machine_id uuid not null,
  date date not null,
  litres numeric(9, 2) not null check (litres > 0),
  cost numeric(12, 2) not null check (cost >= 0),
  run_hours numeric(7, 1) check (run_hours >= 0),
  expense_id uuid,
  note text,
  recorded_by uuid not null,
  created_at timestamptz not null default effective_now(),
  unique (tenant_id, id),
  foreign key (tenant_id, machine_id) references machines (tenant_id, id),
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id),
  constraint diesel_logs_recorded_by_profile_fkey foreign key (recorded_by) references profiles (id)
);
create index diesel_logs_tenant_idx on diesel_logs (tenant_id, date desc);

alter table diesel_logs enable row level security;
create policy diesel_logs_select on diesel_logs
  for select to authenticated using (is_tenant_member(tenant_id));

create function record_diesel(
  p_tenant_id uuid,
  p_machine_id uuid,
  p_date date,
  p_litres numeric,
  p_cost numeric,
  p_method payment_channel,
  p_run_hours numeric default null,
  p_note text default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_machine machines;
  v_expense uuid;
  v_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'record diesel');
  v_machine := require_machine(p_tenant_id, p_machine_id);
  if p_litres is null or p_litres <= 0 then
    raise exception 'Enter the litres put in';
  end if;
  if p_cost is null or p_cost < 0 then
    raise exception 'Enter what the diesel cost';
  end if;
  if p_date is null or p_date > (effective_now() at time zone 'Africa/Lagos')::date then
    raise exception 'Diesel can''t be recorded for a future day';
  end if;
  v_expense := post_machine_expense(p_tenant_id, p_date, 'fuel_diesel',
    format('Diesel for %s: %s litres', v_machine.name, trim_scale(p_litres)), p_cost, p_method);
  insert into diesel_logs (tenant_id, machine_id, date, litres, cost, run_hours, expense_id, note, recorded_by)
  values (p_tenant_id, p_machine_id, p_date, p_litres, p_cost, p_run_hours, v_expense,
          nullif(btrim(p_note), ''), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- =========================================================================
-- Report: per machine, and diesel per bag
-- =========================================================================

create function machine_report(p_tenant_id uuid, p_from date, p_to date)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_from timestamptz := p_from::timestamp at time zone 'Africa/Lagos';
  v_to timestamptz := p_to::timestamp at time zone 'Africa/Lagos';
  v_machines jsonb;
  v_bags bigint;
  v_litres numeric;
  v_diesel_cost numeric;
begin
  if not is_tenant_member(p_tenant_id) then
    raise exception 'Not authorized to view machine reports' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.name), '[]'::jsonb) into v_machines
  from (
    select m.id as machine_id, m.name, m.kind,
      coalesce((select sum(r.quantity_produced) from production_runs r
                where r.tenant_id = m.tenant_id and r.machine_id = m.id
                  and r.date >= p_from and r.date < p_to), 0) as bags,
      coalesce((select round(sum(extract(epoch from
                  least(coalesce(b.ended_at, now()), v_to) - greatest(b.started_at, v_from))) / 3600, 1)
                from breakdowns b
                where b.tenant_id = m.tenant_id and b.machine_id = m.id
                  and b.started_at < v_to and coalesce(b.ended_at, now()) > v_from), 0) as downtime_hours,
      (select count(*) from breakdowns b
       where b.tenant_id = m.tenant_id and b.machine_id = m.id
         and b.started_at >= v_from and b.started_at < v_to) as breakdowns,
      coalesce((select sum(b.repair_cost) from breakdowns b
                where b.tenant_id = m.tenant_id and b.machine_id = m.id
                  and b.ended_at >= v_from and b.ended_at < v_to), 0) as repair_cost,
      coalesce((select sum(l.cost) from maintenance_logs l
                where l.tenant_id = m.tenant_id and l.machine_id = m.id
                  and l.done_on >= p_from and l.done_on < p_to), 0) as maintenance_cost,
      coalesce((select sum(d.litres) from diesel_logs d
                where d.tenant_id = m.tenant_id and d.machine_id = m.id
                  and d.date >= p_from and d.date < p_to), 0) as litres,
      coalesce((select sum(d.cost) from diesel_logs d
                where d.tenant_id = m.tenant_id and d.machine_id = m.id
                  and d.date >= p_from and d.date < p_to), 0) as diesel_cost,
      coalesce((select sum(d.run_hours) from diesel_logs d
                where d.tenant_id = m.tenant_id and d.machine_id = m.id
                  and d.date >= p_from and d.date < p_to), 0) as run_hours
    from machines m
    where m.tenant_id = p_tenant_id
  ) x;

  select coalesce(sum(quantity_produced), 0) into v_bags
  from production_runs where tenant_id = p_tenant_id and date >= p_from and date < p_to;
  select coalesce(sum(litres), 0), coalesce(sum(cost), 0) into v_litres, v_diesel_cost
  from diesel_logs where tenant_id = p_tenant_id and date >= p_from and date < p_to;

  return jsonb_build_object(
    'machines', v_machines,
    'bags', v_bags,
    'litres', v_litres,
    'diesel_cost', v_diesel_cost,
    'litres_per_100_bags', case when v_bags > 0 then round(v_litres * 100 / v_bags, 2) end,
    'diesel_cost_per_bag', case when v_bags > 0 then round(v_diesel_cost / v_bags, 2) end
  );
end;
$$;

-- =========================================================================
-- Alerts: maintenance falling due
-- =========================================================================

alter table alerts
  drop constraint alerts_kind_check,
  add constraint alerts_kind_check
    check (kind in ('daily_summary', 'low_stock', 'water_test', 'permit_expiry', 'maintenance_due'));

create or replace function generate_alerts(p_now timestamptz default now())
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_today date := (p_now at time zone 'Africa/Lagos')::date;
  v_count integer := 0;
  v_added integer;
begin
  insert into alerts (tenant_id, kind, title, body, item_id, for_date)
  select si.tenant_id, 'low_stock',
    'Low stock: ' || si.name,
    format('%s is down to %s %s (reorder at %s).', si.name, si.quantity_on_hand, si.unit, si.reorder_level),
    si.id, v_today
  from stock_items si
  where si.reorder_level > 0 and si.quantity_on_hand <= si.reorder_level
  on conflict do nothing;
  get diagnostics v_added = row_count;
  v_count := v_count + v_added;

  -- Permits: once in each window (60, 30, 7 days, the day), so one added
  -- late still gets its nearest reminder. for_date = the window's start.
  insert into alerts (tenant_id, kind, title, body, ref_id, for_date)
  select p.tenant_id, 'permit_expiry',
    case when p.expires_on = v_today then p.name || ' expires today'
         else p.name || ' expires in ' || (p.expires_on - v_today) || ' days' end,
    format('%s%s expires on %s. Start the renewal now so production isn''t interrupted.',
      p.name, coalesce(' (' || nullif(btrim(p.number), '') || ')', ''), to_char(p.expires_on, 'DD Mon YYYY')),
    p.id,
    p.expires_on - case when p.expires_on - v_today <= 0 then 0
                        when p.expires_on - v_today <= 7 then 7
                        when p.expires_on - v_today <= 30 then 30
                        else 60 end
  from permits p
  where p.expires_on - v_today between 0 and 60
  on conflict do nothing;
  get diagnostics v_added = row_count;
  v_count := v_count + v_added;

  -- Maintenance: once when a task falls due (for_date = its due date).
  insert into alerts (tenant_id, kind, title, body, ref_id, for_date)
  select t.tenant_id, 'maintenance_due',
    'Maintenance due: ' || m.name,
    format('%s on %s is due%s (every %s days).', t.name, m.name,
      case when maintenance_due_on(t) < v_today then ' since ' || to_char(maintenance_due_on(t), 'DD Mon') else ' today' end,
      t.every_days),
    t.id, maintenance_due_on(t)
  from maintenance_tasks t
  join machines m on m.tenant_id = t.tenant_id and m.id = t.machine_id
  where t.is_active and m.is_active and maintenance_due_on(t) <= v_today
  on conflict do nothing;
  get diagnostics v_added = row_count;
  v_count := v_count + v_added;

  if extract(hour from p_now at time zone 'Africa/Lagos') >= 20 then
    insert into alerts (tenant_id, kind, title, body, for_date)
    select t.id, 'daily_summary', 'Daily summary · ' || to_char(v_today, 'DD Mon'),
      daily_summary_text(t.id, v_today), v_today
    from tenants t
    on conflict do nothing;
    get diagnostics v_added = row_count;
    v_count := v_count + v_added;
  end if;

  return v_count;
end;
$$;

-- =========================================================================
-- Subscription guard, offline, grants
-- =========================================================================

create trigger guard_subscription before insert or update or delete on machines
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on maintenance_tasks
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on maintenance_logs
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on breakdowns
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on diesel_logs
  for each row execute function guard_subscription();

-- Offline: diesel, maintenance done, breakdowns (four new record types).
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

revoke all on function seed_machines(uuid) from public, anon, authenticated;
revoke all on function seed_machines_on_tenant() from public, anon, authenticated;
revoke all on function link_run_machine() from public, anon, authenticated;
revoke all on function post_machine_expense(uuid, date, expense_category, text, numeric, payment_channel) from public, anon, authenticated;
revoke all on function require_machine(uuid, uuid) from public, anon, authenticated;
revoke all on function maintenance_due_on(maintenance_tasks) from public, anon, authenticated;
revoke all on function record_maintenance(uuid, uuid, date, numeric, payment_channel, text) from public, anon;
revoke all on function report_breakdown(uuid, uuid, timestamptz, text, uuid) from public, anon;
revoke all on function end_breakdown(uuid, uuid, timestamptz, numeric, payment_channel, text) from public, anon;
revoke all on function record_diesel(uuid, uuid, date, numeric, numeric, payment_channel, numeric, text) from public, anon;
revoke all on function machine_report(uuid, date, date) from public, anon;
grant execute on function record_maintenance(uuid, uuid, date, numeric, payment_channel, text) to authenticated;
grant execute on function report_breakdown(uuid, uuid, timestamptz, text, uuid) to authenticated;
grant execute on function end_breakdown(uuid, uuid, timestamptz, numeric, payment_channel, text) to authenticated;
grant execute on function record_diesel(uuid, uuid, date, numeric, numeric, payment_channel, numeric, text) to authenticated;
grant execute on function machine_report(uuid, date, date) to authenticated;
