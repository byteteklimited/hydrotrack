-- HydroTrack — 0025: quality and NAFDAC compliance (Phase D part 1,
-- agreed rules).
--
--   * Water tests (pH, TDS, residual chlorine) each production shift,
--     checked against the organization's limits (defaults from NIS 554:
--     pH 6.5–8.5, TDS ≤ 500 mg/L, chlorine 0.2–0.25 mg/L). A failed test
--     is flagged and the owner alerted; production can still be recorded.
--   * Batch numbers: every production run gets one automatically
--     (YYMMDD-shift initial-run, e.g. 261101-M-1). Sales already take stock
--     oldest batch first, so each sale notes the batches its bags came
--     from (sales.batch_numbers, printed on receipts) and trace_batch lists
--     every sale and customer that got a batch.
--   * Permits (NAFDAC licence, SON, water board, fire…): the owner is
--     alerted 60, 30 and 7 days before expiry and on the day.
--   * Sanitation: each organization's own daily checklist (starting from a
--     suggested list), ticked off each day.
--   * The 8 pm daily summary also mentions failed or missing water tests
--     and a missed sanitation checklist.
-- Water tests and the checklist work offline (apply_device_operation).

-- =========================================================================
-- Limits
-- =========================================================================

alter table tenants
  add column water_ph_min numeric(4, 2) not null default 6.5,
  add column water_ph_max numeric(4, 2) not null default 8.5,
  add column water_tds_max numeric(7, 1) not null default 500,
  add column water_chlorine_min numeric(5, 2) not null default 0.2,
  add column water_chlorine_max numeric(5, 2) not null default 0.25,
  add constraint tenants_water_ph_check
    check (water_ph_min >= 0 and water_ph_max <= 14 and water_ph_min < water_ph_max),
  add constraint tenants_water_tds_check check (water_tds_max > 0),
  add constraint tenants_water_chlorine_check
    check (water_chlorine_min >= 0 and water_chlorine_min < water_chlorine_max);

-- =========================================================================
-- Water tests
-- =========================================================================

create table water_tests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  date date not null,
  shift production_shift not null,
  tested_at timestamptz not null default effective_now(),
  ph numeric(4, 2) not null check (ph between 0 and 14),
  tds numeric(7, 1) not null check (tds >= 0),
  chlorine numeric(5, 2) not null check (chlorine >= 0),
  passed boolean not null,
  problems text[] not null default '{}',
  note text,
  recorded_by uuid not null,
  unique (tenant_id, id),
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id),
  constraint water_tests_recorded_by_profile_fkey foreign key (recorded_by) references profiles (id)
);
create index water_tests_tenant_date_idx on water_tests (tenant_id, date desc, shift);

alter table water_tests enable row level security;
create policy water_tests_select on water_tests
  for select to authenticated using (is_tenant_member(tenant_id));

-- =========================================================================
-- Batch numbers
-- =========================================================================

alter table production_runs add column batch_number text;

with numbered as (
  select id,
    to_char(date, 'YYMMDD') || '-' || upper(left(shift::text, 1)) || '-'
      || row_number() over (partition by tenant_id, date, shift order by recorded_at, id) as batch_number
  from production_runs
)
update production_runs r set batch_number = n.batch_number from numbered n where n.id = r.id;

create function assign_batch_number()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_prefix text := to_char(new.date, 'YYMMDD') || '-' || upper(left(new.shift::text, 1));
  v_next integer;
begin
  if new.batch_number is not null then
    return new;
  end if;
  -- One numbering at a time per organization, day and shift.
  perform pg_advisory_xact_lock(hashtext(new.tenant_id::text || v_prefix));
  select coalesce(max(split_part(batch_number, '-', 3)::integer), 0) + 1 into v_next
  from production_runs
  where tenant_id = new.tenant_id and batch_number like v_prefix || '-%';
  new.batch_number := v_prefix || '-' || v_next;
  return new;
end;
$$;

create trigger assign_batch_number before insert on production_runs
  for each row execute function assign_batch_number();

alter table production_runs alter column batch_number set not null;
create unique index production_runs_batch_number_idx on production_runs (tenant_id, batch_number);

-- Which batches each sale's bags came from.
alter table sales add column batch_numbers text[] not null default '{}';

update sales s set batch_numbers = found.numbers
from (
  select m.tenant_id, m.sale_id, array_agg(distinct r.batch_number order by r.batch_number) as numbers
  from stock_movements m
  join stock_batches b on b.tenant_id = m.tenant_id and b.id = m.batch_id
  join production_runs r on r.tenant_id = b.tenant_id and r.id = b.production_run_id
  where m.sale_id is not null
  group by m.tenant_id, m.sale_id
) found
where s.tenant_id = found.tenant_id and s.id = found.sale_id;

create function note_sale_batch()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_number text;
begin
  if new.sale_id is null or new.batch_id is null then
    return new;
  end if;
  select r.batch_number into v_number
  from stock_batches b
  join production_runs r on r.tenant_id = b.tenant_id and r.id = b.production_run_id
  where b.tenant_id = new.tenant_id and b.id = new.batch_id;
  if v_number is not null then
    update sales set batch_numbers = array_append(batch_numbers, v_number)
    where tenant_id = new.tenant_id and id = new.sale_id and not (v_number = any (batch_numbers));
  end if;
  return new;
end;
$$;

create trigger note_sale_batch after insert on stock_movements
  for each row execute function note_sale_batch();

-- Every sale (and the customer and driver) that got bags from a batch.
create function trace_batch(p_tenant_id uuid, p_batch_number text)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_run production_runs;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'trace batches');
  select * into v_run from production_runs
  where tenant_id = p_tenant_id and upper(batch_number) = upper(btrim(p_batch_number));
  if not found then
    raise exception 'No production run has batch number %. Check the number on the bag or receipt.', btrim(p_batch_number);
  end if;
  return jsonb_build_object(
    'run', jsonb_build_object(
      'id', v_run.id,
      'batch_number', v_run.batch_number,
      'date', v_run.date,
      'shift', v_run.shift,
      'machine', v_run.machine,
      'product', (select name from products where tenant_id = p_tenant_id and id = v_run.product_id),
      'quantity_produced', v_run.quantity_produced
    ),
    'bags_in_stock', coalesce((select sum(quantity_remaining) from stock_batches
                               where tenant_id = p_tenant_id and production_run_id = v_run.id), 0),
    'water_tests', coalesce((
      select jsonb_agg(jsonb_build_object('passed', w.passed, 'problems', w.problems, 'tested_at', w.tested_at)
                       order by w.tested_at)
      from water_tests w
      where w.tenant_id = p_tenant_id and w.date = v_run.date and w.shift = v_run.shift), '[]'::jsonb),
    'sales', coalesce((
      select jsonb_agg(row_to_json(x)::jsonb order by x.date_time desc)
      from (
        select s.id, s.date_time, s.customer_type, s.customer_name,
          (select c.phone from customers c where c.tenant_id = s.tenant_id and c.name = s.customer_name limit 1) as customer_phone,
          (select d.name from load_outs lo join drivers d on d.tenant_id = lo.tenant_id and d.id = lo.driver_id
           where lo.tenant_id = s.tenant_id and lo.sale_id = s.id limit 1) as driver_name,
          s.voided_at is not null as voided,
          -sum(m.quantity)::integer as bags
        from stock_movements m
        join stock_batches b on b.tenant_id = m.tenant_id and b.id = m.batch_id
        join sales s on s.tenant_id = m.tenant_id and s.id = m.sale_id
        where m.tenant_id = p_tenant_id and b.production_run_id = v_run.id
        group by s.id
      ) x), '[]'::jsonb)
  );
end;
$$;

-- =========================================================================
-- Permits
-- =========================================================================

create table permits (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  number text,
  expires_on date not null,
  note text,
  created_by uuid references profiles (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  unique (tenant_id, id)
);
create index permits_tenant_idx on permits (tenant_id, expires_on);

alter table permits enable row level security;
create policy permits_select on permits
  for select to authenticated using (is_tenant_member(tenant_id));
create policy permits_insert on permits
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy permits_update on permits
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy permits_delete on permits
  for delete to authenticated using (has_tenant_role(tenant_id, array['admin']::staff_role[]));

-- =========================================================================
-- Sanitation checklist
-- =========================================================================

create table sanitation_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  position integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, id)
);
create index sanitation_items_tenant_idx on sanitation_items (tenant_id, position);

create table sanitation_checks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  date date not null,
  item_id uuid not null,
  done boolean not null,
  note text,
  checked_by uuid not null,
  checked_at timestamptz not null default effective_now(),
  unique (tenant_id, id),
  unique (tenant_id, date, item_id),
  foreign key (tenant_id, item_id) references sanitation_items (tenant_id, id),
  foreign key (tenant_id, checked_by) references tenant_members (tenant_id, user_id),
  constraint sanitation_checks_checked_by_profile_fkey foreign key (checked_by) references profiles (id)
);
create index sanitation_checks_tenant_date_idx on sanitation_checks (tenant_id, date desc);

alter table sanitation_items enable row level security;
create policy sanitation_items_select on sanitation_items
  for select to authenticated using (is_tenant_member(tenant_id));
create policy sanitation_items_insert on sanitation_items
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy sanitation_items_update on sanitation_items
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));

alter table sanitation_checks enable row level security;
create policy sanitation_checks_select on sanitation_checks
  for select to authenticated using (is_tenant_member(tenant_id));

-- The suggested starting list.
create function seed_sanitation_items(p_tenant_id uuid)
returns void
language sql
security definer set search_path = public
as $$
  insert into sanitation_items (tenant_id, name, position)
  select p_tenant_id, item.name, item.position
  from unnest(array[
    'Production floor swept and mopped',
    'Machines, nozzles and fillers sanitized',
    'Water tanks covered and clean',
    'Staff wearing hairnets, gloves and aprons',
    'Hand-washing point has soap and water',
    'Toilets cleaned',
    'Waste bins emptied',
    'No pests or droppings seen'
  ]) with ordinality as item(name, position);
$$;

create function seed_sanitation_for_new_tenant()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform seed_sanitation_items(new.id);
  return new;
end;
$$;

create trigger seed_sanitation_items after insert on tenants
  for each row execute function seed_sanitation_for_new_tenant();

select seed_sanitation_items(id) from tenants;

-- Ticks off (or updates) the day's checklist: [{item_id, done, note}].
create function record_sanitation_check(p_tenant_id uuid, p_date date, p_items jsonb)
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
  v_item jsonb;
  v_count integer := 0;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'fill in the sanitation checklist');
  if p_date is null or p_date > (effective_now() at time zone 'Africa/Lagos')::date then
    raise exception 'The checklist can''t be filled in for a future day';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Tick at least one item';
  end if;
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    if not exists (select 1 from sanitation_items
                   where tenant_id = p_tenant_id and id = (v_item ->> 'item_id')::uuid) then
      raise exception 'Checklist item not found';
    end if;
    insert into sanitation_checks (tenant_id, date, item_id, done, note, checked_by)
    values (p_tenant_id, p_date, (v_item ->> 'item_id')::uuid, coalesce((v_item ->> 'done')::boolean, false),
            nullif(btrim(v_item ->> 'note'), ''), auth.uid())
    on conflict (tenant_id, date, item_id) do update
      set done = excluded.done, note = excluded.note, checked_by = excluded.checked_by,
          checked_at = effective_now();
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- =========================================================================
-- Recording a water test
-- =========================================================================

alter table alerts
  drop constraint alerts_kind_check,
  add constraint alerts_kind_check
    check (kind in ('daily_summary', 'low_stock', 'water_test', 'permit_expiry')),
  add column ref_id uuid;
drop index alerts_once_a_day;
create unique index alerts_once_a_day on alerts
  (tenant_id, kind, for_date, coalesce(item_id, ref_id, '00000000-0000-0000-0000-000000000000'::uuid));

create function record_water_test(
  p_tenant_id uuid,
  p_date date,
  p_shift production_shift,
  p_ph numeric,
  p_tds numeric,
  p_chlorine numeric,
  p_note text default null
)
returns water_tests
language plpgsql
security definer set search_path = public
as $$
declare
  t tenants;
  v_problems text[] := '{}';
  v_test water_tests;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'record water tests');
  if p_date is null or p_shift is null or p_ph is null or p_tds is null or p_chlorine is null then
    raise exception 'Enter the date, shift, pH, TDS and chlorine';
  end if;
  select * into t from tenants where id = p_tenant_id;
  if p_ph < t.water_ph_min or p_ph > t.water_ph_max then
    v_problems := v_problems || format('pH %s (allowed %s–%s)', trim_scale(p_ph), trim_scale(t.water_ph_min), trim_scale(t.water_ph_max));
  end if;
  if p_tds > t.water_tds_max then
    v_problems := v_problems || format('TDS %s mg/L (max %s)', trim_scale(p_tds), trim_scale(t.water_tds_max));
  end if;
  if p_chlorine < t.water_chlorine_min or p_chlorine > t.water_chlorine_max then
    v_problems := v_problems || format('chlorine %s mg/L (allowed %s–%s)', trim_scale(p_chlorine),
      trim_scale(t.water_chlorine_min), trim_scale(t.water_chlorine_max));
  end if;

  insert into water_tests (tenant_id, date, shift, ph, tds, chlorine, passed, problems, note, recorded_by)
  values (p_tenant_id, p_date, p_shift, p_ph, p_tds, p_chlorine, cardinality(v_problems) = 0, v_problems,
          nullif(btrim(p_note), ''), auth.uid())
  returning * into v_test;

  if not v_test.passed then
    insert into alerts (tenant_id, kind, title, body, ref_id, for_date)
    values (p_tenant_id, 'water_test', 'Water test failed',
      format('%s shift, %s: %s.', initcap(p_shift::text), to_char(p_date, 'DD Mon'), array_to_string(v_problems, '; ')),
      v_test.id, p_date)
    on conflict do nothing;
  end if;
  return v_test;
end;
$$;

-- =========================================================================
-- Alerts: permits, and the summary's quality lines
-- =========================================================================

create or replace function daily_summary_text(p_tenant_id uuid, p_day date)
returns text
language sql stable
security definer set search_path = public
as $$
  with day as (
    select (p_day::timestamp at time zone 'Africa/Lagos') as starts,
           ((p_day + 1)::timestamp at time zone 'Africa/Lagos') as ends
  )
  select format(
    'Today: %s bags produced, %s bags sold. Collected NGN%s cash and NGN%s by transfer. Money outside: NGN%s.%s%s%s%s',
    coalesce((select sum(quantity_produced) from production_runs where tenant_id = p_tenant_id and date = p_day), 0),
    coalesce((select sum(l.quantity) from sale_lines l join sales s on s.tenant_id = l.tenant_id and s.id = l.sale_id, day
              where s.tenant_id = p_tenant_id and s.voided_at is null
                and s.date_time >= day.starts and s.date_time < day.ends), 0),
    to_char(coalesce((select sum(amount) from cash_entries, day where tenant_id = p_tenant_id
              and direction = 'money_in' and method = 'cash'
              and created_at >= day.starts and created_at < day.ends), 0), 'FM999,999,999,990'),
    to_char(coalesce((select sum(amount) from cash_entries, day where tenant_id = p_tenant_id
              and direction = 'money_in' and method <> 'cash'
              and created_at >= day.starts and created_at < day.ends), 0), 'FM999,999,999,990'),
    to_char(coalesce((select sum(balance) from customers where tenant_id = p_tenant_id and balance > 0), 0), 'FM999,999,999,990'),
    coalesce((select format(' Cash counts short: %s (NGN%s).', count(*), to_char(-sum(difference), 'FM999,999,999,990'))
              from cash_counts, day where tenant_id = p_tenant_id and difference < 0
                and counted_at >= day.starts and counted_at < day.ends
              having count(*) > 0), ''),
    coalesce((select format(' Water tests failed: %s.', count(*))
              from water_tests where tenant_id = p_tenant_id and date = p_day and not passed
              having count(*) > 0), ''),
    coalesce((select ' No water test for: ' || string_agg(distinct r.shift::text, ', ') || ' shift.'
              from production_runs r
              where r.tenant_id = p_tenant_id and r.date = p_day
                and not exists (select 1 from water_tests w where w.tenant_id = r.tenant_id
                                  and w.date = r.date and w.shift = r.shift)
              having count(*) > 0), ''),
    case when exists (select 1 from sanitation_items where tenant_id = p_tenant_id and is_active)
          and not exists (select 1 from sanitation_checks where tenant_id = p_tenant_id and date = p_day)
         then ' Sanitation checklist not done.' else '' end
  );
$$;

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

create trigger guard_subscription before insert or update or delete on water_tests
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on permits
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on sanitation_items
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on sanitation_checks
  for each row execute function guard_subscription();

-- Offline: water tests and the checklist (two new record types).
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

revoke all on function assign_batch_number() from public, anon, authenticated;
revoke all on function note_sale_batch() from public, anon, authenticated;
revoke all on function seed_sanitation_items(uuid) from public, anon, authenticated;
revoke all on function seed_sanitation_for_new_tenant() from public, anon, authenticated;
revoke all on function trace_batch(uuid, text) from public, anon;
revoke all on function record_water_test(uuid, date, production_shift, numeric, numeric, numeric, text) from public, anon;
revoke all on function record_sanitation_check(uuid, date, jsonb) from public, anon;
grant execute on function trace_batch(uuid, text) to authenticated;
grant execute on function record_water_test(uuid, date, production_shift, numeric, numeric, numeric, text) to authenticated;
grant execute on function record_sanitation_check(uuid, date, jsonb) to authenticated;
