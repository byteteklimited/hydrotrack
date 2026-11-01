-- HydroTrack — 0020: end-of-day cash counts (agreed rules).
--
-- Each cashier counts the cash they took at the end of their shift. The
-- server works out what they should have: cash in they recorded (cash
-- sales, cash debt payments) minus cash out they recorded (cash
-- expenses), since their previous count today (or since the start of the
-- day). A manager confirms the count. A shortage is saved with the
-- cashier's explanation and flagged for the owner ("Needs checking");
-- nothing is deducted automatically.
--
-- cash_entries gets created_at (when it was recorded), because date_time
-- is a business date for payments/expenses (midnight) and can't place an
-- entry before or after a mid-day count. Records made offline get the
-- time they were made on the device (hydrotrack.recorded_at, set by
-- apply_device_operation).

-- The time a record was made: the device's time for records made offline,
-- otherwise now.
create function effective_now()
returns timestamptz
language sql stable
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('hydrotrack.recorded_at', true), '')::timestamptz,
    now()
  );
$$;

alter table cash_entries add column created_at timestamptz;
update cash_entries set created_at = date_time;
alter table cash_entries
  alter column created_at set not null,
  alter column created_at set default effective_now();
create index cash_entries_recorder_idx on cash_entries (tenant_id, recorded_by, created_at);

create table cash_counts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  cashier_id uuid not null,
  period_start timestamptz not null,
  counted_at timestamptz not null default effective_now(),
  cash_in numeric(12, 2) not null,
  cash_out numeric(12, 2) not null,
  expected numeric(12, 2) not null,
  counted numeric(12, 2) not null check (counted >= 0),
  difference numeric(12, 2) generated always as (counted - expected) stored,
  note text,
  confirmed_by uuid,
  confirmed_at timestamptz,
  unique (tenant_id, id),
  foreign key (tenant_id, cashier_id) references tenant_members (tenant_id, user_id),
  foreign key (tenant_id, confirmed_by) references tenant_members (tenant_id, user_id),
  foreign key (cashier_id) references profiles (id),
  constraint cash_counts_confirmed_by_profile_fkey foreign key (confirmed_by) references profiles (id)
);
create index cash_counts_tenant_idx on cash_counts (tenant_id, counted_at desc);

alter table cash_counts enable row level security;
-- Cashiers see their own counts; managers and up see everyone's.
create policy cash_counts_select on cash_counts
  for select to authenticated
  using (
    (cashier_id = (select auth.uid()) and is_tenant_member(tenant_id))
    or has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[])
  );

alter table sync_flags
  drop constraint sync_flags_kind_check,
  add constraint sync_flags_kind_check
    check (kind in ('short_stock', 'short_raw_material', 'over_credit_limit', 'cash_short')),
  add column cash_count_id uuid,
  add foreign key (tenant_id, cash_count_id) references cash_counts (tenant_id, id) on delete cascade;

-- What a cashier should have now: since their last count today (or the
-- start of today, Lagos time).
create function expected_cash_for(p_tenant_id uuid, p_cashier_id uuid, p_until timestamptz)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_day_start timestamptz := date_trunc('day', p_until at time zone 'Africa/Lagos') at time zone 'Africa/Lagos';
  v_since timestamptz;
  v_in numeric;
  v_out numeric;
begin
  select greatest(coalesce(max(counted_at), v_day_start), v_day_start) into v_since
  from cash_counts
  where tenant_id = p_tenant_id and cashier_id = p_cashier_id and counted_at <= p_until;

  select
    coalesce(sum(amount) filter (where direction = 'money_in'), 0),
    coalesce(sum(amount) filter (where direction = 'money_out'), 0)
  into v_in, v_out
  from cash_entries
  where tenant_id = p_tenant_id and recorded_by = p_cashier_id and method = 'cash'
    and created_at > v_since and created_at <= p_until;

  return jsonb_build_object('since', v_since, 'cash_in', v_in, 'cash_out', v_out, 'expected', v_in - v_out);
end;
$$;

-- For the "Count cash" screen: the signed-in person's expected cash.
create function my_expected_cash(p_tenant_id uuid)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'cashier']::staff_role[], 'count cash');
  return expected_cash_for(p_tenant_id, auth.uid(), now());
end;
$$;

-- Records the signed-in person's count. A note is required when it
-- doesn't match; a shortage is flagged for the owner.
create function record_cash_count(p_tenant_id uuid, p_counted numeric, p_note text)
returns cash_counts
language plpgsql
security definer set search_path = public
as $$
declare
  v_at timestamptz := effective_now();
  v_expected jsonb;
  v_count cash_counts;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'cashier']::staff_role[], 'count cash');
  if p_counted is null or p_counted < 0 then
    raise exception 'Enter the cash you counted';
  end if;

  v_expected := expected_cash_for(p_tenant_id, auth.uid(), v_at);
  if p_counted <> (v_expected ->> 'expected')::numeric and nullif(btrim(p_note), '') is null then
    raise exception 'The count doesn''t match. Add a note explaining the difference.';
  end if;

  insert into cash_counts (tenant_id, cashier_id, period_start, counted_at, cash_in, cash_out, expected, counted, note)
  values (
    p_tenant_id, auth.uid(), (v_expected ->> 'since')::timestamptz, v_at,
    (v_expected ->> 'cash_in')::numeric, (v_expected ->> 'cash_out')::numeric,
    (v_expected ->> 'expected')::numeric, p_counted, nullif(btrim(p_note), '')
  )
  returning * into v_count;

  if v_count.difference < 0 then
    insert into sync_flags (tenant_id, kind, details, cash_count_id, recorded_by)
    values (p_tenant_id, 'cash_short',
      format('%s counted %s, expected %s: short by %s. Note: %s',
        (select full_name from profiles where id = auth.uid()),
        v_count.counted, v_count.expected, -v_count.difference, coalesce(v_count.note, '-')),
      v_count.id, auth.uid());
  end if;

  return v_count;
end;
$$;

-- Managers and up confirm a count (they checked the cash).
create function confirm_cash_count(p_tenant_id uuid, p_count_id uuid)
returns cash_counts
language plpgsql
security definer set search_path = public
as $$
declare
  v_count cash_counts;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'confirm cash counts');
  update cash_counts set confirmed_by = auth.uid(), confirmed_at = now()
  where tenant_id = p_tenant_id and id = p_count_id and confirmed_at is null
  returning * into v_count;
  if v_count.id is null then
    raise exception 'Cash count not found, or already confirmed';
  end if;
  return v_count;
end;
$$;

-- Offline: counts made on a device ('cash_count'), and every record made
-- offline keeps its device time in cash_entries.created_at.
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


-- Column defaults run as the person inserting, so they need to call it
-- (it only reads a setting clients can't change).
revoke all on function effective_now() from public, anon;
grant execute on function effective_now() to authenticated, service_role;
revoke all on function expected_cash_for(uuid, uuid, timestamptz) from public, anon, authenticated;
do $$
declare
  f text;
begin
  foreach f in array array[
    'my_expected_cash(uuid)',
    'record_cash_count(uuid, numeric, text)',
    'confirm_cash_count(uuid, uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
