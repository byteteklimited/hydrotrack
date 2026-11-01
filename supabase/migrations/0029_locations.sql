-- HydroTrack — 0029: factories and depots (Phase D part 5, agreed rules).
--
--   * An organization has locations: factories (produce and sell) and
--     depots (hold and sell). Every organization starts with one, "Main
--     factory"; everything recorded so far is placed there.
--   * Kept per location: stock, sales, production, expenses, cash (and
--     cash counts), customers (and their debts), load-outs and purchases.
--     Shared: products and prices, drivers, vehicles, suppliers, quality,
--     machines, workers and payroll.
--   * Staff are assigned to locations and only see and record their own;
--     owners and admins see every location.
--   * Stock moves between locations by transfer: sent (taken from the
--     sender's batches, oldest first), then received (added at the other
--     location with the same batch numbers, expiry and cost, so tracing a
--     batch follows it).
--   * Each offline device belongs to one location.
--
-- How a record gets its location: the app sends the current location in
-- an `x-location-id` header with every request; offline records use their
-- device's location (hydrotrack.location_id, set by
-- apply_device_operation). New rows are stamped with it (stamp_location),
-- and a record is changed only from its own location. The same header
-- narrows what RLS shows — it can only narrow, never widen, what someone
-- may see. Stock: each location has its own row per item (stock_items has
-- location_id); rows for the same item share item_key, and a location's
-- row is created the first time it's needed (item_at_location), so every
-- existing stock function keeps working on item ids.

-- =========================================================================
-- Locations and who works where
-- =========================================================================

create table locations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  kind text not null default 'factory' check (kind in ('factory', 'depot')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (tenant_id, id)
);
create unique index locations_tenant_name_idx on locations (tenant_id, lower(btrim(name)));

create table member_locations (
  tenant_id uuid not null references tenants (id) on delete cascade,
  user_id uuid not null,
  location_id uuid not null,
  primary key (tenant_id, user_id, location_id),
  foreign key (tenant_id, user_id) references tenant_members (tenant_id, user_id) on delete cascade,
  foreign key (tenant_id, location_id) references locations (tenant_id, id) on delete cascade
);

alter table locations enable row level security;
create policy locations_select on locations
  for select to authenticated using (is_tenant_member(tenant_id));
create policy locations_insert on locations
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy locations_update on locations
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));

alter table member_locations enable row level security;
create policy member_locations_select on member_locations
  for select to authenticated
  using (user_id = (select auth.uid()) and is_tenant_member(tenant_id)
         or has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy member_locations_insert on member_locations
  for insert to authenticated with check (has_tenant_role(tenant_id, array['admin']::staff_role[]));
create policy member_locations_delete on member_locations
  for delete to authenticated using (has_tenant_role(tenant_id, array['admin']::staff_role[]));

create function main_location(p_tenant_id uuid)
returns uuid
language sql stable
security definer set search_path = public
as $$
  select id from locations where tenant_id = p_tenant_id order by is_active desc, created_at, id limit 1;
$$;

insert into locations (tenant_id, name, created_at)
select id, 'Main factory', created_at from tenants;

insert into member_locations (tenant_id, user_id, location_id)
select m.tenant_id, m.user_id, main_location(m.tenant_id) from tenant_members m;

create function create_main_location()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into locations (tenant_id, name) values (new.id, 'Main factory');
  return new;
end;
$$;

-- Named to run before the other "after insert on tenants" triggers.
create trigger a_create_main_location after insert on tenants
  for each row execute function create_main_location();

-- New members start at the main location; owners and admins change it.
create function assign_new_member_location()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into member_locations (tenant_id, user_id, location_id)
  select new.tenant_id, new.user_id, main_location(new.tenant_id)
  where main_location(new.tenant_id) is not null
  on conflict do nothing;
  return new;
end;
$$;

create trigger assign_new_member_location after insert on tenant_members
  for each row execute function assign_new_member_location();

-- =========================================================================
-- Which location a request is for
-- =========================================================================

-- The location asked for: the device's (offline sync), else the app's
-- x-location-id header; null when none (or not a valid id).
create function requested_location()
returns uuid
language plpgsql stable
set search_path = ''
as $$
declare
  v_text text := coalesce(
    nullif(current_setting('hydrotrack.location_id', true), ''),
    nullif(current_setting('request.headers', true), '')::json ->> 'x-location-id');
begin
  return nullif(v_text, '')::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

-- May the caller work at this location? Owners/admins anywhere; others
-- where assigned. Background jobs (no signed-in user) anywhere.
create function can_use_location(p_tenant_id uuid, p_location_id uuid)
returns boolean
language sql stable
security definer set search_path = public
as $$
  select (select auth.uid()) is null
    or has_tenant_role(p_tenant_id, array['admin']::staff_role[])
    or exists (select 1 from member_locations
               where tenant_id = p_tenant_id and user_id = (select auth.uid()) and location_id = p_location_id);
$$;

-- RLS: rows of a location the caller may use, narrowed to the requested
-- location when there is one.
create function location_visible(p_tenant_id uuid, p_location_id uuid)
returns boolean
language sql stable
security definer set search_path = public
as $$
  select (requested_location() is null or p_location_id = requested_location())
    and can_use_location(p_tenant_id, p_location_id);
$$;

-- The location a new record belongs to.
create function resolve_location(p_tenant_id uuid)
returns uuid
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_location uuid := requested_location();
begin
  if v_location is not null then
    if not exists (select 1 from locations where tenant_id = p_tenant_id and id = v_location) then
      raise exception 'That location isn''t part of this organization. Pick a location and try again.';
    end if;
    return v_location;
  end if;
  return coalesce(
    (select ml.location_id from member_locations ml join locations l on l.id = ml.location_id
     where ml.tenant_id = p_tenant_id and ml.user_id = auth.uid() and not has_tenant_role(p_tenant_id, array['admin']::staff_role[])
     order by l.created_at limit 1),
    main_location(p_tenant_id));
end;
$$;

create function location_name(p_location_id uuid)
returns text
language sql stable
security definer set search_path = public
as $$
  select name from locations where id = p_location_id;
$$;

-- " (Depot)" after an item's name when the organization has more than one
-- location (alerts).
create function location_suffix(p_location_id uuid)
returns text
language sql stable
security definer set search_path = public
as $$
  select case when (select count(*) from locations l2 where l2.tenant_id = l.tenant_id and l2.is_active) > 1
              then ' (' || l.name || ')' else '' end
  from locations l where l.id = p_location_id;
$$;

-- =========================================================================
-- Location on records
-- =========================================================================

create function stamp_location()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.location_id is null then
    new.location_id := resolve_location(new.tenant_id);
  end if;
  if not exists (select 1 from locations where tenant_id = new.tenant_id and id = new.location_id) then
    raise exception 'That location isn''t part of this organization';
  end if;
  if not can_use_location(new.tenant_id, new.location_id) then
    raise exception 'You aren''t assigned to %. Ask the owner to add you there.', location_name(new.location_id)
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- Records are changed from their own location (voids, edits, trip
-- settling). Stock items: only quantity changes are held to this.
create function require_own_location()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_here uuid;
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_table_name = 'stock_items' and (tg_op = 'DELETE' or new.quantity_on_hand is not distinct from old.quantity_on_hand) then
    return coalesce(new, old);
  end if;
  v_here := resolve_location(old.tenant_id);
  if v_here is distinct from old.location_id then
    raise exception 'This belongs to %. Switch to % to change it.', location_name(old.location_id), location_name(old.location_id);
  end if;
  return coalesce(new, old);
end;
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'stock_items', 'sales', 'production_runs', 'expenses', 'cash_entries',
    'customers', 'load_outs', 'purchases', 'cash_counts', 'devices'
  ]
  loop
    execute format('alter table %I add column location_id uuid', v_table);
    execute format('update %I t set location_id = main_location(t.tenant_id)', v_table);
    execute format('alter table %I alter column location_id set not null', v_table);
    execute format('alter table %I add foreign key (tenant_id, location_id) references locations (tenant_id, id)', v_table);
    execute format('create index %I on %I (tenant_id, location_id)', v_table || '_location_idx', v_table);
    execute format('create trigger stamp_location before insert on %I for each row execute function stamp_location()', v_table);
  end loop;
  foreach v_table in array array[
    'stock_items', 'sales', 'production_runs', 'customers', 'load_outs', 'cash_counts'
  ]
  loop
    execute format('create trigger require_own_location before update or delete on %I
                      for each row execute function require_own_location()', v_table);
  end loop;
end;
$$;

-- RLS: staff see their own locations; everyone sees only the location the
-- app asked for. Child rows follow their parent's location.
do $$
declare
  v_policy record;
  v_condition text;
begin
  for v_policy in
    select tablename, policyname, qual from pg_policies
    where schemaname = 'public' and cmd = 'SELECT'
      and tablename in ('stock_items', 'sales', 'production_runs', 'expenses', 'cash_entries', 'customers',
                        'load_outs', 'purchases', 'cash_counts', 'sale_lines', 'ledger_entries',
                        'purchase_lines', 'stock_batches', 'stock_movements')
  loop
    v_condition := case v_policy.tablename
      when 'sale_lines' then 'exists (select 1 from sales p where p.tenant_id = sale_lines.tenant_id and p.id = sale_lines.sale_id and location_visible(p.tenant_id, p.location_id))'
      when 'ledger_entries' then 'exists (select 1 from customers p where p.tenant_id = ledger_entries.tenant_id and p.id = ledger_entries.customer_id and location_visible(p.tenant_id, p.location_id))'
      when 'purchase_lines' then 'exists (select 1 from purchases p where p.tenant_id = purchase_lines.tenant_id and p.id = purchase_lines.purchase_id and location_visible(p.tenant_id, p.location_id))'
      when 'stock_batches' then 'exists (select 1 from stock_items p where p.tenant_id = stock_batches.tenant_id and p.id = stock_batches.item_id and location_visible(p.tenant_id, p.location_id))'
      when 'stock_movements' then 'exists (select 1 from stock_items p where p.tenant_id = stock_movements.tenant_id and p.id = stock_movements.item_id and location_visible(p.tenant_id, p.location_id))'
      else 'location_visible(tenant_id, location_id)'
    end;
    execute format('alter policy %I on %I using ((%s) and %s)',
      v_policy.policyname, v_policy.tablename, v_policy.qual, v_condition);
  end loop;
end;
$$;

-- =========================================================================
-- Stock per location
-- =========================================================================

alter table stock_items add column item_key uuid;
update stock_items set item_key = id;
alter table stock_items alter column item_key set not null;

create function default_item_key()
returns trigger
language plpgsql
as $$
begin
  new.item_key := coalesce(new.item_key, new.id);
  return new;
end;
$$;
create trigger default_item_key before insert on stock_items
  for each row execute function default_item_key();

drop index stock_items_tenant_product_unique;
create unique index stock_items_location_product_unique
  on stock_items (tenant_id, location_id, product_id) where product_id is not null;
create unique index stock_items_location_key_unique on stock_items (tenant_id, location_id, item_key);

-- The same item at a location, if that location has it yet.
create function item_here(p_tenant_id uuid, p_item_id uuid, p_location_id uuid)
returns stock_items
language sql stable
security definer set search_path = public
as $$
  select here.* from stock_items src
  join stock_items here on here.tenant_id = src.tenant_id and here.item_key = src.item_key
  where src.tenant_id = p_tenant_id and src.id = p_item_id and here.location_id = p_location_id;
$$;

-- The same item at a location, created there (empty) if it isn't yet.
create function item_at_location(p_tenant_id uuid, p_item_id uuid, p_location_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_here stock_items := item_here(p_tenant_id, p_item_id, p_location_id);
  v_id uuid;
begin
  if v_here.id is not null then
    return v_here.id;
  end if;
  insert into stock_items (tenant_id, location_id, name, category, unit, reorder_level, product_id, item_key, average_cost)
  select tenant_id, p_location_id, name, category, unit, reorder_level, product_id, item_key, average_cost
  from stock_items where tenant_id = p_tenant_id and id = p_item_id
  returning id into v_id;
  return v_id;
end;
$$;

-- The product's finished-goods item at the request's location.
create or replace function finished_item_for(p_tenant_id uuid, p_product_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_any uuid;
begin
  select id into v_any from stock_items
  where tenant_id = p_tenant_id and product_id = p_product_id
  order by location_id = main_location(p_tenant_id) desc
  limit 1;
  if v_any is null then
    return null;
  end if;
  return item_at_location(p_tenant_id, v_any, resolve_location(p_tenant_id));
end;
$$;

create or replace function sale_shortage(p_tenant_id uuid, p_lines jsonb)
returns text
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_grouped record;
  v_item stock_items;
  v_any uuid;
  v_shortage text := '';
begin
  for v_grouped in
    select product_from_record(p_tenant_id, line) as product_id,
           sum((line ->> 'quantity')::integer) as total_qty
    from jsonb_array_elements(p_lines) as line
    group by 1
  loop
    select id into v_any from stock_items where tenant_id = p_tenant_id and product_id = v_grouped.product_id limit 1;
    continue when v_any is null;
    v_item := item_here(p_tenant_id, v_any, resolve_location(p_tenant_id));
    if coalesce(v_item.quantity_on_hand, 0) < v_grouped.total_qty then
      v_shortage := v_shortage || format('%s (need %s, have %s); ',
        coalesce(v_item.name, (select name from stock_items where id = v_any)), v_grouped.total_qty,
        coalesce(v_item.quantity_on_hand, 0));
    end if;
  end loop;
  return v_shortage;
end;
$$;

create or replace function production_shortage(p_tenant_id uuid, p_product_id uuid, p_bags integer)
returns text
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_recipe record;
  v_here stock_items;
  v_need integer;
  v_shortage text := '';
begin
  for v_recipe in
    select pr.quantity_used, pr.per_bags, pr.raw_material_item_id, si.name
    from production_recipes pr
    join stock_items si on si.tenant_id = pr.tenant_id and si.id = pr.raw_material_item_id
    where pr.tenant_id = p_tenant_id and pr.product_id = p_product_id
  loop
    v_need := round(v_recipe.quantity_used * p_bags / v_recipe.per_bags);
    v_here := item_here(p_tenant_id, v_recipe.raw_material_item_id, resolve_location(p_tenant_id));
    if v_need > 0 and coalesce(v_here.quantity_on_hand, 0) < v_need then
      v_shortage := v_shortage || format('%s (need %s, have %s); ', v_recipe.name, v_need, coalesce(v_here.quantity_on_hand, 0));
    end if;
  end loop;
  return v_shortage;
end;
$$;

create or replace function deduct_production_materials(
  p_tenant_id uuid,
  p_run_id uuid,
  p_product_id uuid,
  p_bags integer,
  p_note text
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_recipe record;
  v_deduct integer;
begin
  for v_recipe in
    select * from production_recipes where tenant_id = p_tenant_id and product_id = p_product_id
  loop
    v_deduct := round(v_recipe.quantity_used * p_bags / v_recipe.per_bags);
    if v_deduct > 0 then
      perform consume_stock_fifo(p_tenant_id,
        item_at_location(p_tenant_id, v_recipe.raw_material_item_id, resolve_location(p_tenant_id)),
        v_deduct, 'production_use', p_note, auth.uid(), p_run_id);
    end if;
  end loop;
end;
$$;

create or replace function cost_sale_line()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_any uuid;
begin
  if new.unit_cost is null then
    select id into v_any from stock_items where tenant_id = new.tenant_id and product_id = new.product_id limit 1;
    new.unit_cost := coalesce(
      (item_here(new.tenant_id, v_any, (select location_id from sales where tenant_id = new.tenant_id and id = new.sale_id))).average_cost,
      0);
  end if;
  return new;
end;
$$;

-- =========================================================================
-- Totals per location
-- =========================================================================

create or replace function totals_for_tenant(p_tenant_id uuid)
returns jsonb
language sql stable
security definer set search_path = public
as $$
  select jsonb_build_object(
    'total_bags_produced',
    coalesce((select sum(quantity_produced) from production_runs
              where tenant_id = p_tenant_id and location_id = resolve_location(p_tenant_id)), 0),
    'total_revenue',
    coalesce((select sum(total) from sales
              where tenant_id = p_tenant_id and voided_at is null and location_id = resolve_location(p_tenant_id)), 0)
  );
$$;

-- =========================================================================
-- Transfers
-- =========================================================================

alter type movement_type add value if not exists 'transfer_out';
alter type movement_type add value if not exists 'transfer_in';

alter table stock_movements add column transfer_id uuid;

create table stock_transfers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  from_location_id uuid not null,
  to_location_id uuid not null,
  status text not null default 'sent' check (status in ('sent', 'received')),
  note text,
  sent_by uuid references profiles (id) on delete set null,
  sent_at timestamptz not null default now(),
  received_by uuid references profiles (id) on delete set null,
  received_at timestamptz,
  unique (tenant_id, id),
  check (from_location_id <> to_location_id),
  foreign key (tenant_id, from_location_id) references locations (tenant_id, id),
  foreign key (tenant_id, to_location_id) references locations (tenant_id, id)
);
create index stock_transfers_tenant_idx on stock_transfers (tenant_id, sent_at desc);

-- One row per batch taken, so the receiving end gets the same batches.
create table stock_transfer_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  transfer_id uuid not null,
  item_id uuid not null,
  quantity integer not null check (quantity > 0),
  unit_cost numeric(14, 4) not null default 0,
  production_run_id uuid,
  expiry_date date,
  unique (tenant_id, id),
  foreign key (tenant_id, transfer_id) references stock_transfers (tenant_id, id) on delete cascade,
  foreign key (tenant_id, item_id) references stock_items (tenant_id, id)
);

alter table stock_transfers enable row level security;
create policy stock_transfers_select on stock_transfers
  for select to authenticated
  using (is_tenant_member(tenant_id)
         and (can_use_location(tenant_id, from_location_id) or can_use_location(tenant_id, to_location_id)));
alter table stock_transfer_lines enable row level security;
create policy stock_transfer_lines_select on stock_transfer_lines
  for select to authenticated
  using (exists (select 1 from stock_transfers t where t.tenant_id = stock_transfer_lines.tenant_id
                   and t.id = stock_transfer_lines.transfer_id
                   and (can_use_location(t.tenant_id, t.from_location_id) or can_use_location(t.tenant_id, t.to_location_id))));

-- Sends stock from the request's location: [{item_id, quantity}].
create function send_transfer(p_tenant_id uuid, p_to_location_id uuid, p_lines jsonb, p_note text default null)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_from uuid := resolve_location(p_tenant_id);
  v_transfer uuid;
  v_line jsonb;
  v_item stock_items;
  v_quantity integer;
  v_left integer;
  v_batch record;
  v_take integer;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'send stock');
  if not can_use_location(p_tenant_id, v_from) then
    raise exception 'You aren''t assigned to %', location_name(v_from) using errcode = '42501';
  end if;
  if not exists (select 1 from locations where tenant_id = p_tenant_id and id = p_to_location_id and is_active) then
    raise exception 'Pick where to send it';
  end if;
  if p_to_location_id = v_from then
    raise exception 'Stock can''t be sent to the location it''s already at';
  end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'Add at least one item to send';
  end if;

  insert into stock_transfers (tenant_id, from_location_id, to_location_id, note, sent_by)
  values (p_tenant_id, v_from, p_to_location_id, nullif(btrim(p_note), ''), auth.uid())
  returning id into v_transfer;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select * into v_item from stock_items
    where tenant_id = p_tenant_id and id = (v_line ->> 'item_id')::uuid and location_id = v_from
    for update;
    if not found then
      raise exception 'Item not found at %', location_name(v_from);
    end if;
    v_quantity := (v_line ->> 'quantity')::integer;
    if v_quantity is null or v_quantity <= 0 then
      raise exception 'Enter how many % to send', v_item.unit;
    end if;
    if v_item.quantity_on_hand < v_quantity then
      raise exception 'Not enough % to send (have %)', v_item.name, v_item.quantity_on_hand;
    end if;
    v_left := v_quantity;
    for v_batch in
      select * from stock_batches
      where tenant_id = p_tenant_id and item_id = v_item.id and quantity_remaining > 0
      order by received_at
      for update
    loop
      exit when v_left <= 0;
      v_take := least(v_left, v_batch.quantity_remaining);
      update stock_batches set quantity_remaining = quantity_remaining - v_take where id = v_batch.id;
      insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, batch_id, transfer_id)
      values (p_tenant_id, v_item.id, 'transfer_out', -v_take, 'Sent to ' || location_name(p_to_location_id),
              auth.uid(), v_batch.id, v_transfer);
      insert into stock_transfer_lines (tenant_id, transfer_id, item_id, quantity, unit_cost, production_run_id, expiry_date)
      values (p_tenant_id, v_transfer, v_item.id, v_take, v_item.average_cost, v_batch.production_run_id, v_batch.expiry_date);
      v_left := v_left - v_take;
    end loop;
    if v_left > 0 then
      insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, transfer_id)
      values (p_tenant_id, v_item.id, 'transfer_out', -v_left, 'Sent to ' || location_name(p_to_location_id),
              auth.uid(), v_transfer);
      insert into stock_transfer_lines (tenant_id, transfer_id, item_id, quantity, unit_cost)
      values (p_tenant_id, v_transfer, v_item.id, v_left, v_item.average_cost);
    end if;
    update stock_items set quantity_on_hand = quantity_on_hand - v_quantity where id = v_item.id;
  end loop;
  return v_transfer;
end;
$$;

-- Receives a transfer at its destination (the request's location).
create function receive_transfer(p_tenant_id uuid, p_transfer_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_transfer stock_transfers;
  v_line stock_transfer_lines;
  v_item uuid;
  v_batch uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'receive stock');
  select * into v_transfer from stock_transfers where tenant_id = p_tenant_id and id = p_transfer_id for update;
  if not found then
    raise exception 'Transfer not found';
  end if;
  if v_transfer.status = 'received' then
    raise exception 'This transfer was already received';
  end if;
  if resolve_location(p_tenant_id) <> v_transfer.to_location_id then
    raise exception 'This stock is going to %. Switch to % to receive it.',
      location_name(v_transfer.to_location_id), location_name(v_transfer.to_location_id);
  end if;
  if not can_use_location(p_tenant_id, v_transfer.to_location_id) then
    raise exception 'You aren''t assigned to %', location_name(v_transfer.to_location_id) using errcode = '42501';
  end if;

  for v_line in select * from stock_transfer_lines where tenant_id = p_tenant_id and transfer_id = p_transfer_id
  loop
    v_item := item_at_location(p_tenant_id, v_line.item_id, v_transfer.to_location_id);
    insert into stock_batches (tenant_id, item_id, quantity_received, quantity_remaining, expiry_date,
                               production_run_id, note, created_by)
    values (p_tenant_id, v_item, v_line.quantity, v_line.quantity, v_line.expiry_date, v_line.production_run_id,
            'From ' || location_name(v_transfer.from_location_id), auth.uid())
    returning id into v_batch;
    insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, batch_id, unit_cost, transfer_id)
    values (p_tenant_id, v_item, 'transfer_in', v_line.quantity, 'From ' || location_name(v_transfer.from_location_id),
            auth.uid(), v_batch, v_line.unit_cost, p_transfer_id);
    update stock_items set quantity_on_hand = quantity_on_hand + v_line.quantity where id = v_item;
  end loop;
  update stock_transfers set status = 'received', received_by = auth.uid(), received_at = now()
  where id = p_transfer_id;
end;
$$;

-- transfer_in carries the sender's cost, so the receiving average moves.
create or replace function cost_stock_movement()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_item stock_items;
  v_priced boolean := new.unit_cost is not null;
  v_on_hand integer;
begin
  select * into v_item from stock_items where tenant_id = new.tenant_id and id = new.item_id;

  if new.quantity > 0 and new.type = 'stock_in' and new.production_run_id is not null then
    new.unit_cost := coalesce((
      select sum(-m.quantity * m.unit_cost) from stock_movements m
      where m.tenant_id = new.tenant_id and m.production_run_id = new.production_run_id
        and m.type = 'production_use'
    ), 0) / new.quantity;
    v_priced := true;
  end if;

  if new.unit_cost is null then
    new.unit_cost := v_item.average_cost;
  end if;

  if v_priced and new.quantity > 0 then
    v_on_hand := greatest(v_item.quantity_on_hand, 0);
    update stock_items
    set average_cost = (v_on_hand * average_cost + new.quantity * new.unit_cost) / (v_on_hand + new.quantity)
    where tenant_id = new.tenant_id and id = new.item_id;
  end if;

  return new;
end;
$$;

-- =========================================================================
-- Devices belong to a location
-- =========================================================================

create or replace function device_finance_position(p_device_key text)
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
    from cash_entries where tenant_id = v_device.tenant_id and location_id = v_device.location_id
  );
end;
$$;

create or replace function device_totals(p_device_key text)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_device devices := device_for_key(p_device_key);
begin
  perform set_config('hydrotrack.location_id', v_device.location_id::text, true);
  return totals_for_tenant(v_device.tenant_id);
end;
$$;

-- Who can sign in on a device: members who may work at its location.
create or replace function device_members(p_device_key text)
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
      and (m.role in ('owner', 'admin')
           or exists (select 1 from member_locations ml where ml.tenant_id = m.tenant_id
                        and ml.user_id = m.user_id and ml.location_id = v_device.location_id))
  ), '[]'::jsonb);
end;
$$;

create function device_location(p_device_key text)
returns jsonb
language sql stable
security definer set search_path = public
as $$
  select jsonb_build_object('id', l.id, 'name', l.name, 'kind', l.kind)
  from locations l where l.id = (device_for_key(p_device_key)).location_id;
$$;

-- =========================================================================
-- Alerts name the location; guard; offline
-- =========================================================================

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
    'Low stock: ' || si.name || location_suffix(si.location_id),
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

  -- Stock running out within a week at the last 30 days' rate (items not
  -- already at their reorder level, which get the low-stock alert). At
  -- most once a week per item.
  insert into alerts (tenant_id, kind, title, body, item_id, for_date)
  select si.tenant_id, 'stock_runout',
    'Running out: ' || si.name || location_suffix(si.location_id),
    format('%s will run out in about %s at the current rate (about %s %s a day).',
      si.name,
      case when f.days_left < 1 then 'a day' else floor(f.days_left)::integer || ' days' end,
      trim_scale(round(f.per_day, 1)), si.unit),
    si.id, date_trunc('week', v_today)::date
  from stock_items si
  cross join lateral stock_runout(si, p_now) f
  where f.days_left is not null and f.days_left < 7 and si.quantity_on_hand > si.reorder_level
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

create trigger guard_subscription before insert or update or delete on locations
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on stock_transfers
  for each row execute function guard_subscription();
create trigger guard_subscription before insert or update or delete on stock_transfer_lines
  for each row execute function guard_subscription();

-- Offline: records replay at their device's location.
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
    perform set_config('hydrotrack.location_id', v_device.location_id::text, true);

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
    perform set_config('hydrotrack.location_id', '', true);
    perform set_config('request.jwt.claim.sub', v_caller_sub, true);
    perform set_config('request.jwt.claims', v_caller_claims, true);

    return jsonb_build_object('op_id', v_op_id, 'status', 'applied', 'result', v_result);
  exception when others then
    get stacked diagnostics v_error = message_text;
    perform set_config('hydrotrack.location_id', '', true);
    insert into device_operations (op_id, tenant_id, device_id, actor_id, type, payload, recorded_at, status, error)
    values (v_op_id, v_tenant, v_device.id, v_actor, v_type, v_payload, v_recorded_at, 'rejected', v_error)
    on conflict (op_id) do update
      set status = 'rejected', error = excluded.error, payload = excluded.payload, received_at = now();
    return jsonb_build_object('op_id', v_op_id, 'status', 'rejected', 'error', v_error);
  end;
end;
$$;

revoke all on function main_location(uuid) from public, anon, authenticated;
revoke all on function create_main_location() from public, anon, authenticated;
revoke all on function assign_new_member_location() from public, anon, authenticated;
revoke all on function requested_location() from public, anon;
grant execute on function requested_location() to authenticated;
revoke all on function can_use_location(uuid, uuid) from public, anon;
grant execute on function can_use_location(uuid, uuid) to authenticated;
revoke all on function location_visible(uuid, uuid) from public, anon;
grant execute on function location_visible(uuid, uuid) to authenticated;
revoke all on function resolve_location(uuid) from public, anon, authenticated;
revoke all on function location_name(uuid) from public, anon, authenticated;
revoke all on function location_suffix(uuid) from public, anon, authenticated;
revoke all on function stamp_location() from public, anon, authenticated;
revoke all on function require_own_location() from public, anon, authenticated;
revoke all on function default_item_key() from public, anon, authenticated;
revoke all on function item_here(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function item_at_location(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function device_location(text) from public, anon, authenticated;
grant execute on function device_location(text) to service_role;
revoke all on function send_transfer(uuid, uuid, jsonb, text) from public, anon;
revoke all on function receive_transfer(uuid, uuid) from public, anon;
grant execute on function send_transfer(uuid, uuid, jsonb, text) to authenticated;
grant execute on function receive_transfer(uuid, uuid) to authenticated;
