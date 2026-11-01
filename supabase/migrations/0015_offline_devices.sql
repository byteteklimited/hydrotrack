-- HydroTrack — 0015: offline use on set-up devices.
--
-- How it works:
--   * An owner/admin sets a device up for their organization
--     (register_device). The device gets a secret sync key, shown once;
--     only its SHA-256 hash is stored here.
--   * With that key the device downloads the organization's data and
--     the staff list (Edge Function `device-sync`, action "pull"),
--     including each member's offline sign-in check
--     (offline_credentials): a salted PBKDF2 hash of their PIN/password,
--     never the PIN or password itself. Staff can then sign in on that
--     device without internet.
--   * Everything recorded on the device is queued and sent with the key
--     when there's internet ("push"). apply_device_operation replays each
--     record AS the staff member who made it (their role is checked as
--     usual), exactly once (by its operation id), keeping the time it
--     was recorded on the device.
--   * Agreed rules for records made offline: a sale or production run is
--     saved even if the server no longer has enough stock / raw
--     material (the water already left / was produced) and is flagged
--     for a manager to check; a credit sale that leaves the customer over
--     their limit is flagged too. Flags: sync_flags.
--   * Nothing is lost: a record the server refuses (e.g. the staff
--     member was removed meanwhile) is kept in device_operations with
--     the reason, and stays on the device to retry or remove.

-- =========================================================================
-- Devices
-- =========================================================================

create table devices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  key_hash text not null unique,
  created_by uuid,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid,
  unique (tenant_id, id)
);
create index devices_tenant_idx on devices (tenant_id, created_at desc);

alter table devices enable row level security;
create policy devices_select on devices
  for select to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]));

-- Owner/Admin: sets up a device; returns its id and the key (shown once).
create function register_device(p_tenant_id uuid, p_name text)
returns jsonb
language plpgsql
security definer set search_path = public, extensions
as $$
declare
  v_key text := encode(gen_random_bytes(32), 'hex');
  v_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'set up devices for offline use');
  insert into devices (tenant_id, name, key_hash, created_by)
  values (p_tenant_id, btrim(p_name), encode(digest(v_key, 'sha256'), 'hex'), auth.uid())
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'key', v_key);
end;
$$;

-- Owner/Admin: switches a device off (e.g. lost phone). It can no longer
-- download or send anything; records it hadn't sent stay on it.
create function revoke_device(p_tenant_id uuid, p_device_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'switch off devices');
  update devices set revoked_at = now(), revoked_by = auth.uid()
  where tenant_id = p_tenant_id and id = p_device_id and revoked_at is null;
  if not found then
    raise exception 'Device not found';
  end if;
end;
$$;

-- The device a sync key belongs to (internal; Edge Function only).
create function device_for_key(p_device_key text)
returns devices
language plpgsql stable
security definer set search_path = public, extensions
as $$
declare
  v_device devices;
begin
  select * into v_device from devices
  where key_hash = encode(digest(coalesce(p_device_key, ''), 'sha256'), 'hex');
  if v_device.id is null then
    raise exception 'This device is not set up for offline use' using errcode = '42501';
  end if;
  if v_device.revoked_at is not null then
    raise exception 'This device was switched off by an admin' using errcode = '42501';
  end if;
  return v_device;
end;
$$;

-- =========================================================================
-- Offline sign-in checks
-- =========================================================================

-- One per person (a PIN/password is per account, not per organization).
-- No policies: only the security-definer functions below touch it.
create table offline_credentials (
  user_id uuid primary key references auth.users (id) on delete cascade,
  salt text not null check (salt ~ '^[0-9a-f]{32}$'),
  hash text not null check (hash ~ '^[0-9a-f]{64}$'),
  iterations integer not null check (iterations between 10000 and 1000000),
  updated_at timestamptz not null default now()
);
alter table offline_credentials enable row level security;

-- The app calls this after every successful online sign-in, with a fresh
-- salt and the PBKDF2-HMAC-SHA256 of the secret the person just used.
create function set_my_offline_credential(p_salt text, p_hash text, p_iterations integer)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  insert into offline_credentials (user_id, salt, hash, iterations, updated_at)
  values (auth.uid(), lower(p_salt), lower(p_hash), p_iterations, now())
  on conflict (user_id) do update
    set salt = excluded.salt, hash = excluded.hash,
        iterations = excluded.iterations, updated_at = now();
end;
$$;

-- Staff list for a device: everyone in its organization, with their
-- offline sign-in check when they have one (Edge Function only).
create function device_members(p_device_key text)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_device devices := device_for_key(p_device_key);
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'user_id', m.user_id,
      'role', m.role,
      'is_active', m.is_active,
      'full_name', p.full_name,
      'phone', p.phone,
      'email', p.email,
      'credential', case when c.user_id is null then null else jsonb_build_object(
        'salt', c.salt, 'hash', c.hash, 'iterations', c.iterations) end
    ) order by p.full_name)
    from tenant_members m
    join profiles p on p.id = m.user_id
    left join offline_credentials c on c.user_id = m.user_id
    where m.tenant_id = v_device.tenant_id
  ), '[]'::jsonb);
end;
$$;

-- All-time cash/bank totals (the device only keeps 90 days of entries).
create function device_finance_position(p_device_key text)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_device devices := device_for_key(p_device_key);
begin
  return (
    select jsonb_build_object(
      'cash_in_hand', coalesce(sum(case when method = 'cash' then
        case when direction = 'money_in' then amount else -amount end end), 0),
      'bank_balance', coalesce(sum(case when method <> 'cash' then
        case when direction = 'money_in' then amount else -amount end end), 0))
    from cash_entries where tenant_id = v_device.tenant_id
  );
end;
$$;

-- =========================================================================
-- Flags for managers
-- =========================================================================

create table sync_flags (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  kind text not null check (kind in ('short_stock', 'short_raw_material', 'over_credit_limit')),
  details text not null,
  sale_id uuid,
  production_run_id uuid,
  customer_id uuid,
  recorded_by uuid,
  device_id uuid,
  created_at timestamptz not null default now(),
  checked_at timestamptz,
  checked_by uuid,
  unique (tenant_id, id),
  foreign key (tenant_id, sale_id) references sales (tenant_id, id) on delete cascade,
  foreign key (tenant_id, production_run_id) references production_runs (tenant_id, id) on delete cascade,
  foreign key (tenant_id, customer_id) references customers (tenant_id, id) on delete cascade,
  foreign key (tenant_id, device_id) references devices (tenant_id, id) on delete set null (device_id)
);
create index sync_flags_open_idx on sync_flags (tenant_id, created_at desc) where checked_at is null;

alter table sync_flags enable row level security;
create policy sync_flags_select on sync_flags
  for select to authenticated using (is_tenant_member(tenant_id));

create function mark_sync_flag_checked(p_tenant_id uuid, p_flag_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'mark flagged records as checked');
  update sync_flags set checked_at = now(), checked_by = auth.uid()
  where tenant_id = p_tenant_id and id = p_flag_id and checked_at is null;
end;
$$;

-- =========================================================================
-- Replaying offline records
-- =========================================================================

create table device_operations (
  op_id uuid primary key,
  tenant_id uuid not null references tenants (id) on delete cascade,
  device_id uuid not null,
  actor_id uuid not null,
  type text not null,
  payload jsonb not null,
  recorded_at timestamptz not null,
  status text not null check (status in ('applied', 'rejected')),
  result jsonb,
  error text,
  received_at timestamptz not null default now(),
  foreign key (tenant_id, device_id) references devices (tenant_id, id) on delete cascade
);
create index device_operations_device_idx on device_operations (tenant_id, device_id, received_at desc);

alter table device_operations enable row level security;
create policy device_operations_select on device_operations
  for select to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]));

-- True only inside apply_device_operation (a transaction-local setting
-- clients can't set: PostgREST exposes no way to call set_config).
create function is_offline_sync()
returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce(current_setting('hydrotrack.offline_sync', true), '') = 'on';
$$;

-- record_sale / record_production_run: unchanged, except that the
-- "not enough stock / raw material" block doesn't apply to records made
-- offline (they're flagged instead, by apply_device_operation).
create or replace function record_sale(
  p_tenant_id uuid,
  p_customer_type sales_customer_type,
  p_customer_name text,
  p_total numeric,
  p_amount_paid numeric,
  p_payment_method sales_payment_method,
  p_balance numeric,
  p_lines jsonb,
  p_paid_channel payment_channel default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_sale_id uuid;
  v_line jsonb;
  v_item_id uuid;
  v_product product_type;
  v_quantity integer;
  v_shortage text;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'cashier']::staff_role[], 'record sales');

  if p_payment_method = 'part' and p_amount_paid > 0 and p_paid_channel is null then
    raise exception 'A payment channel is required for the paid portion of a part payment';
  end if;

  v_shortage := sale_shortage(p_tenant_id, p_lines);
  if v_shortage <> '' and not is_offline_sync() then
    raise exception 'Not enough stock to record this sale: %', v_shortage;
  end if;

  insert into sales (tenant_id, customer_type, customer_name, total, amount_paid, payment_method, balance, recorded_by)
  values (p_tenant_id, p_customer_type, p_customer_name, p_total, p_amount_paid, p_payment_method, p_balance, auth.uid())
  returning id into v_sale_id;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    v_product := (v_line ->> 'product')::product_type;
    v_quantity := (v_line ->> 'quantity')::integer;

    insert into sale_lines (tenant_id, sale_id, product, quantity, unit_price)
    values (p_tenant_id, v_sale_id, v_product, v_quantity, (v_line ->> 'unit_price')::numeric);

    v_item_id := finished_item_for(p_tenant_id, v_product);
    if v_item_id is not null then
      perform consume_stock_fifo(p_tenant_id, v_item_id, v_quantity, 'stock_out', 'Sold', auth.uid(), null, v_sale_id);
    end if;
  end loop;

  perform post_sale_side_effects(
    p_tenant_id, v_sale_id, p_customer_type, p_customer_name,
    p_amount_paid, p_payment_method, p_balance, p_paid_channel, ''
  );

  return v_sale_id;
end;
$$;

-- Stock a sale needs that isn't there, e.g. "50cl Sachet (need 50, have
-- 20); ", or '' when there's enough. Summed per product across lines.
create function sale_shortage(p_tenant_id uuid, p_lines jsonb)
returns text
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_grouped record;
  v_item_id uuid;
  v_item_name text;
  v_available integer;
  v_shortage text := '';
begin
  for v_grouped in
    select (line ->> 'product')::product_type as product, sum((line ->> 'quantity')::integer) as total_qty
    from jsonb_array_elements(p_lines) as line
    group by (line ->> 'product')::product_type
  loop
    select id, name, quantity_on_hand into v_item_id, v_item_name, v_available
    from stock_items where tenant_id = p_tenant_id and product_type = v_grouped.product limit 1;
    if v_item_id is not null and v_available < v_grouped.total_qty then
      v_shortage := v_shortage || format('%s (need %s, have %s); ', v_item_name, v_grouped.total_qty, v_available);
    end if;
  end loop;
  return v_shortage;
end;
$$;

create or replace function record_production_run(
  p_tenant_id uuid,
  p_date date,
  p_shift production_shift,
  p_machine text,
  p_operator_name text,
  p_product product_type,
  p_quantity_produced integer,
  p_wastage integer,
  p_expiry_date date default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_run_id uuid;
  v_shortage text;
  v_finished_item_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'record production');

  v_shortage := production_shortage(p_tenant_id, p_product, p_quantity_produced + p_wastage);
  if v_shortage <> '' and not is_offline_sync() then
    raise exception 'Not enough raw material to record this run: %', v_shortage;
  end if;

  insert into production_runs (tenant_id, date, shift, machine, operator_name, product, quantity_produced, wastage, recorded_by)
  values (p_tenant_id, p_date, p_shift, p_machine, p_operator_name, p_product, p_quantity_produced, p_wastage, auth.uid())
  returning id into v_run_id;

  perform deduct_production_materials(p_tenant_id, v_run_id, p_product, p_quantity_produced + p_wastage, 'Used in production run');

  if p_quantity_produced > 0 then
    v_finished_item_id := finished_item_for(p_tenant_id, p_product);
    if v_finished_item_id is not null then
      perform add_stock_batch(p_tenant_id, v_finished_item_id, p_quantity_produced, p_expiry_date, 'stock_in', 'Produced — production run', auth.uid(), v_run_id);
    end if;
  end if;

  return v_run_id;
end;
$$;

-- Applies one queued record from a device, exactly once.
-- p_op: {op_id, type, actor_id, recorded_at, payload}
-- Returns {op_id, status: applied|rejected, result, error}.
create function apply_device_operation(p_device_key text, p_op jsonb)
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
    -- Act as the staff member who recorded it: every role check, and
    -- every "recorded by", is theirs.
    perform set_config('request.jwt.claim.sub', v_actor::text, true);
    perform set_config('request.jwt.claims',
      json_build_object('sub', v_actor, 'role', 'authenticated')::text, true);
    perform set_config('hydrotrack.offline_sync', 'on', true);

    case v_type
    when 'sale' then
      v_shortage := sale_shortage(v_tenant, v_payload -> 'lines');
      v_id := record_sale(
        v_tenant,
        (v_payload ->> 'customer_type')::sales_customer_type,
        v_payload ->> 'customer_name',
        (v_payload ->> 'total')::numeric,
        (v_payload ->> 'amount_paid')::numeric,
        (v_payload ->> 'payment_method')::sales_payment_method,
        (v_payload ->> 'balance')::numeric,
        v_payload -> 'lines',
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
      v_shortage := production_shortage(v_tenant, (v_payload ->> 'product')::product_type,
        (v_payload ->> 'quantity_produced')::integer + (v_payload ->> 'wastage')::integer);
      v_id := record_production_run(
        v_tenant,
        (v_payload ->> 'date')::date,
        (v_payload ->> 'shift')::production_shift,
        v_payload ->> 'machine',
        v_payload ->> 'operator_name',
        (v_payload ->> 'product')::product_type,
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
        (v_payload ->> 'product')::product_type,
        (v_payload ->> 'bags_loaded')::integer,
        v_payload ->> 'note'
      );
      update load_outs set date_time = v_recorded_at where tenant_id = v_tenant and id = v_id;
      v_result := jsonb_build_object('id', v_id);

    when 'driver_return' then
      -- A load-out made on the device and not yet on the server when the
      -- return was recorded is referenced by its operation id.
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

    else
      raise exception 'Unknown record type: %', v_type;
    end case;

    insert into device_operations (op_id, tenant_id, device_id, actor_id, type, payload, recorded_at, status, result)
    values (v_op_id, v_tenant, v_device.id, v_actor, v_type, v_payload, v_recorded_at, 'applied', v_result)
    on conflict (op_id) do update
      set status = 'applied', result = excluded.result, error = null,
          payload = excluded.payload, received_at = now();

    -- Back to the caller's own identity and normal rules for anything
    -- else in this transaction. (On failure the block's rollback undoes
    -- these settings by itself.)
    perform set_config('hydrotrack.offline_sync', '', true);
    perform set_config('request.jwt.claim.sub', v_caller_sub, true);
    perform set_config('request.jwt.claims', v_caller_claims, true);

    return jsonb_build_object('op_id', v_op_id, 'status', 'applied', 'result', v_result);
  exception when others then
    -- Everything the record did is undone; the record itself is kept.
    get stacked diagnostics v_error = message_text;
    insert into device_operations (op_id, tenant_id, device_id, actor_id, type, payload, recorded_at, status, error)
    values (v_op_id, v_tenant, v_device.id, v_actor, v_type, v_payload, v_recorded_at, 'rejected', v_error)
    on conflict (op_id) do update
      set status = 'rejected', error = excluded.error, payload = excluded.payload, received_at = now();
    return jsonb_build_object('op_id', v_op_id, 'status', 'rejected', 'error', v_error);
  end;
end;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

revoke all on function register_device(uuid, text) from public, anon;
revoke all on function revoke_device(uuid, uuid) from public, anon;
revoke all on function set_my_offline_credential(text, text, integer) from public, anon;
revoke all on function mark_sync_flag_checked(uuid, uuid) from public, anon;
grant execute on function register_device(uuid, text) to authenticated;
grant execute on function revoke_device(uuid, uuid) to authenticated;
grant execute on function set_my_offline_credential(text, text, integer) to authenticated;
grant execute on function mark_sync_flag_checked(uuid, uuid) to authenticated;

revoke all on function device_for_key(text) from public, anon, authenticated;
revoke all on function device_members(text) from public, anon, authenticated;
revoke all on function device_finance_position(text) from public, anon, authenticated;
revoke all on function apply_device_operation(text, jsonb) from public, anon, authenticated;
revoke all on function sale_shortage(uuid, jsonb) from public, anon, authenticated;
revoke all on function is_offline_sync() from public, anon, authenticated;
grant execute on function device_for_key(text) to service_role;
grant execute on function device_members(text) to service_role;
grant execute on function device_finance_position(text) to service_role;
grant execute on function apply_device_operation(text, jsonb) to service_role;
