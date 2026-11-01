-- HydroTrack — 0016: each organization manages its own products and
-- prices.
--
-- Until now every organization shared 4 fixed products (the product_type
-- enum). Now:
--   * products: per organization, with a unit, a walk-in price and a
--     distributor price; can be retired (hidden from new records, history
--     kept) and deleted only if never used. Owner/Admin manage them.
--   * Each product has its own finished-goods stock item (created with
--     it), which production adds to and sales / load-outs take from.
--   * sale_lines, production_runs, production_recipes, load_outs and
--     stock_items point to a product by id instead of the enum.
--   * Prices: a sale line fills in the product's price for the customer
--     type. Only Owner/Admin/Manager may sell at a different price
--     (agreed rule); the line keeps the list price so a changed price is
--     visible. Records made offline keep the price used on the device.
--
-- Existing organizations get their 4 products created from the old enum
-- (with the old default prices) and every existing record linked to them.
-- Records still queued on offline devices that name the old products are
-- translated (products.legacy_key).

-- =========================================================================
-- Products
-- =========================================================================

create table products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  unit text not null check (char_length(btrim(unit)) between 1 and 20),
  walk_in_price numeric(12, 2) not null default 0 check (walk_in_price >= 0),
  distributor_price numeric(12, 2) not null default 0 check (distributor_price >= 0),
  sort_order integer not null default 0,
  archived_at timestamptz,
  -- The old enum value, for the 4 products migrated from it.
  legacy_key text,
  created_at timestamptz not null default now(),
  unique (tenant_id, id)
);
create unique index products_tenant_name_unique on products (tenant_id, lower(btrim(name)));
create index products_tenant_order_idx on products (tenant_id, sort_order, name);

alter table products enable row level security;
create policy products_select on products
  for select to authenticated using (is_tenant_member(tenant_id));

insert into products (tenant_id, name, unit, walk_in_price, distributor_price, sort_order, legacy_key)
select t.id, v.name, coalesce(si.unit, v.unit), v.price, v.price, v.sort_order, v.legacy_key
from tenants t
cross join (values
  ('sachet50cl', '50cl Sachet', 'bags', 400, 1),
  ('bottle75cl', '75cl Bottle', 'packs', 150, 2),
  ('bottle1_5l', '1.5L Bottle', 'packs', 350, 3),
  ('bottle5l', '5L Bottle', 'bottles', 900, 4)
) as v (legacy_key, name, unit, price, sort_order)
left join stock_items si
  on si.tenant_id = t.id and si.product_type::text = v.legacy_key;

-- =========================================================================
-- Point every record at a product
-- =========================================================================

alter table stock_items add column product_id uuid;
update stock_items si set product_id = p.id
from products p
where p.tenant_id = si.tenant_id and p.legacy_key = si.product_type::text;
-- Finished-goods items for products that had none yet.
insert into stock_items (tenant_id, name, category, unit, product_id)
select p.tenant_id, p.name, 'finished_goods', p.unit, p.id
from products p
where not exists (select 1 from stock_items si where si.tenant_id = p.tenant_id and si.product_id = p.id);
alter table stock_items
  add foreign key (tenant_id, product_id) references products (tenant_id, id);
create unique index stock_items_tenant_product_unique
  on stock_items (tenant_id, product_id) where product_id is not null;
alter table stock_items drop column product_type;

alter table production_recipes add column product_id uuid;
update production_recipes r set product_id = p.id
from products p where p.tenant_id = r.tenant_id and p.legacy_key = r.product::text;
alter table production_recipes
  alter column product_id set not null,
  add foreign key (tenant_id, product_id) references products (tenant_id, id) on delete cascade,
  drop column product,
  add unique (tenant_id, product_id, raw_material_item_id);

alter table production_runs add column product_id uuid;
update production_runs r set product_id = p.id
from products p where p.tenant_id = r.tenant_id and p.legacy_key = r.product::text;
alter table production_runs
  alter column product_id set not null,
  add foreign key (tenant_id, product_id) references products (tenant_id, id),
  drop column product;
create index production_runs_product_idx on production_runs (tenant_id, product_id);

alter table sale_lines add column product_id uuid, add column list_price numeric(12, 2);
update sale_lines l set product_id = p.id
from products p where p.tenant_id = l.tenant_id and p.legacy_key = l.product::text;
alter table sale_lines
  alter column product_id set not null,
  add foreign key (tenant_id, product_id) references products (tenant_id, id),
  drop column product;
create index sale_lines_product_idx on sale_lines (tenant_id, product_id);

alter table load_outs add column product_id uuid;
update load_outs l set product_id = p.id
from products p where p.tenant_id = l.tenant_id and p.legacy_key = l.product::text;
alter table load_outs
  alter column product_id set not null,
  add foreign key (tenant_id, product_id) references products (tenant_id, id),
  drop column product;

-- =========================================================================
-- Functions that used the enum
-- =========================================================================

drop function record_production_run(uuid, date, production_shift, text, text, product_type, integer, integer, date);
drop function update_production_run(uuid, uuid, date, production_shift, text, text, product_type, integer, integer, date);
drop function record_load_out(uuid, uuid, uuid, product_type, integer, text);
drop function deduct_production_materials(uuid, uuid, product_type, integer, text);
drop function production_shortage(uuid, product_type, integer);
drop function finished_item_for(uuid, product_type);
drop type product_type;

-- The product's finished-goods stock item.
create function finished_item_for(p_tenant_id uuid, p_product_id uuid)
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from stock_items
  where tenant_id = p_tenant_id and product_id = p_product_id
  limit 1;
$$;

-- A product id from a record: its id, or (records queued on a device
-- before this migration) the old product name.
create function product_from_record(p_tenant_id uuid, p_record jsonb)
returns uuid
language sql stable security definer set search_path = public
as $$
  select coalesce(
    (p_record ->> 'product_id')::uuid,
    (select id from products where tenant_id = p_tenant_id and legacy_key = p_record ->> 'product')
  );
$$;

create function production_shortage(p_tenant_id uuid, p_product_id uuid, p_bags integer)
returns text
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_recipe record;
  v_need integer;
  v_shortage text := '';
begin
  for v_recipe in
    select pr.quantity_used, pr.per_bags, si.name, si.quantity_on_hand
    from production_recipes pr
    join stock_items si on si.tenant_id = pr.tenant_id and si.id = pr.raw_material_item_id
    where pr.tenant_id = p_tenant_id and pr.product_id = p_product_id
  loop
    v_need := round(v_recipe.quantity_used * p_bags / v_recipe.per_bags);
    if v_need > 0 and v_recipe.quantity_on_hand < v_need then
      v_shortage := v_shortage || format('%s (need %s, have %s); ', v_recipe.name, v_need, v_recipe.quantity_on_hand);
    end if;
  end loop;
  return v_shortage;
end;
$$;

create function deduct_production_materials(
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
      perform consume_stock_fifo(p_tenant_id, v_recipe.raw_material_item_id, v_deduct, 'production_use', p_note, auth.uid(), p_run_id);
    end if;
  end loop;
end;
$$;

-- A product the organization can record against. Retired products are
-- refused, except for records made offline before they were retired.
create function require_active_product(p_tenant_id uuid, p_product_id uuid)
returns products
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_product products;
begin
  select * into v_product from products where tenant_id = p_tenant_id and id = p_product_id;
  if v_product.id is null then
    raise exception 'Product not found';
  end if;
  if v_product.archived_at is not null and not is_offline_sync() then
    raise exception '% is retired. Bring it back under Products to use it again.', v_product.name;
  end if;
  return v_product;
end;
$$;

create function record_production_run(
  p_tenant_id uuid,
  p_date date,
  p_shift production_shift,
  p_machine text,
  p_operator_name text,
  p_product_id uuid,
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
  perform require_active_product(p_tenant_id, p_product_id);

  v_shortage := production_shortage(p_tenant_id, p_product_id, p_quantity_produced + p_wastage);
  if v_shortage <> '' and not is_offline_sync() then
    raise exception 'Not enough raw material to record this run: %', v_shortage;
  end if;

  insert into production_runs (tenant_id, date, shift, machine, operator_name, product_id, quantity_produced, wastage, recorded_by)
  values (p_tenant_id, p_date, p_shift, p_machine, p_operator_name, p_product_id, p_quantity_produced, p_wastage, auth.uid())
  returning id into v_run_id;

  perform deduct_production_materials(p_tenant_id, v_run_id, p_product_id, p_quantity_produced + p_wastage, 'Used in production run');

  if p_quantity_produced > 0 then
    v_finished_item_id := finished_item_for(p_tenant_id, p_product_id);
    if v_finished_item_id is not null then
      perform add_stock_batch(p_tenant_id, v_finished_item_id, p_quantity_produced, p_expiry_date, 'stock_in', 'Produced — production run', auth.uid(), v_run_id);
    end if;
  end if;

  return v_run_id;
end;
$$;

create function update_production_run(
  p_tenant_id uuid,
  p_run_id uuid,
  p_date date,
  p_shift production_shift,
  p_machine text,
  p_operator_name text,
  p_product_id uuid,
  p_quantity_produced integer,
  p_wastage integer,
  p_expiry_date date default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_shortage text;
  v_finished_item_id uuid;
  v_existing_batch stock_batches;
  v_sold integer;
  v_new_remaining integer;
  v_delta integer;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'edit production runs');

  if not exists (select 1 from production_runs where tenant_id = p_tenant_id and id = p_run_id) then
    raise exception 'Production run not found';
  end if;
  if not exists (select 1 from products where tenant_id = p_tenant_id and id = p_product_id) then
    raise exception 'Product not found';
  end if;

  perform reverse_production_materials(p_tenant_id, p_run_id);

  v_shortage := production_shortage(p_tenant_id, p_product_id, p_quantity_produced + p_wastage);
  if v_shortage <> '' then
    raise exception 'Not enough raw material for this change: %', v_shortage;
  end if;

  update production_runs
  set date = p_date, shift = p_shift, machine = p_machine, operator_name = p_operator_name,
      product_id = p_product_id, quantity_produced = p_quantity_produced, wastage = p_wastage
  where tenant_id = p_tenant_id and id = p_run_id;

  perform deduct_production_materials(p_tenant_id, p_run_id, p_product_id, p_quantity_produced + p_wastage, 'Used in production run (edited)');

  select * into v_existing_batch from stock_batches
  where tenant_id = p_tenant_id and production_run_id = p_run_id limit 1;

  if v_existing_batch.id is not null then
    v_sold := v_existing_batch.quantity_received - v_existing_batch.quantity_remaining;

    if p_quantity_produced <= 0 and v_sold = 0 then
      update stock_items set quantity_on_hand = quantity_on_hand - v_existing_batch.quantity_remaining
      where tenant_id = p_tenant_id and id = v_existing_batch.item_id;
      delete from stock_batches where tenant_id = p_tenant_id and id = v_existing_batch.id;
    else
      v_new_remaining := greatest(0, p_quantity_produced - v_sold);
      v_delta := v_new_remaining - v_existing_batch.quantity_remaining;

      update stock_batches
      set quantity_received = greatest(p_quantity_produced, v_sold),
          quantity_remaining = v_new_remaining,
          expiry_date = p_expiry_date
      where tenant_id = p_tenant_id and id = v_existing_batch.id;

      if v_delta <> 0 then
        update stock_items set quantity_on_hand = quantity_on_hand + v_delta
        where tenant_id = p_tenant_id and id = v_existing_batch.item_id;
        insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, production_run_id, batch_id)
        values (p_tenant_id, v_existing_batch.item_id, 'adjustment', v_delta, 'Production run quantity edited', auth.uid(), p_run_id, v_existing_batch.id);
      end if;
    end if;
  elsif p_quantity_produced > 0 then
    v_finished_item_id := finished_item_for(p_tenant_id, p_product_id);
    if v_finished_item_id is not null then
      perform add_stock_batch(p_tenant_id, v_finished_item_id, p_quantity_produced, p_expiry_date, 'stock_in', 'Produced — production run (edited)', auth.uid(), p_run_id);
    end if;
  end if;
end;
$$;

create function record_load_out(
  p_tenant_id uuid,
  p_driver_id uuid,
  p_vehicle_id uuid,
  p_product_id uuid,
  p_bags_loaded integer,
  p_note text
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_load_out_id uuid;
  v_item_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'record load-outs');
  perform require_active_product(p_tenant_id, p_product_id);

  insert into load_outs (tenant_id, driver_id, vehicle_id, product_id, bags_loaded, status, note, recorded_by)
  values (p_tenant_id, p_driver_id, p_vehicle_id, p_product_id, p_bags_loaded, 'on_road', p_note, auth.uid())
  returning id into v_load_out_id;

  v_item_id := finished_item_for(p_tenant_id, p_product_id);
  if v_item_id is not null then
    perform consume_stock_fifo(
      p_tenant_id, v_item_id, p_bags_loaded, 'stock_out',
      p_bags_loaded || ' bags dispatched on load-out', auth.uid()
    );
  end if;

  return v_load_out_id;
end;
$$;

-- The price a product sells at to a customer type.
create function list_price(v_product products, p_customer_type sales_customer_type)
returns numeric
language sql immutable
set search_path = public
as $$
  select case when p_customer_type = 'distributor'
    then v_product.distributor_price else v_product.walk_in_price end;
$$;

-- Agreed rule: only Owner/Admin/Manager may sell at a price other than
-- the list price. Records made offline were checked on the device.
create function require_price_allowed(
  p_tenant_id uuid,
  p_product products,
  p_unit_price numeric,
  p_list_price numeric
)
returns void
language plpgsql stable
security definer set search_path = public
as $$
begin
  if p_unit_price <> p_list_price
     and not is_offline_sync()
     and not has_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[]) then
    raise exception 'Only a manager can sell % at a price other than %.', p_product.name, p_list_price
      using errcode = '42501';
  end if;
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
  v_shortage text := '';
begin
  for v_grouped in
    select product_from_record(p_tenant_id, line) as product_id,
           sum((line ->> 'quantity')::integer) as total_qty
    from jsonb_array_elements(p_lines) as line
    group by 1
  loop
    select * into v_item from stock_items
    where tenant_id = p_tenant_id and product_id = v_grouped.product_id limit 1;
    if v_item.id is not null and v_item.quantity_on_hand < v_grouped.total_qty then
      v_shortage := v_shortage || format('%s (need %s, have %s); ', v_item.name, v_grouped.total_qty, v_item.quantity_on_hand);
    end if;
  end loop;
  return v_shortage;
end;
$$;

-- p_lines: [{"product_id": ..., "quantity": ..., "unit_price": ...,
--            "list_price": ... (offline only: the price the device used)}]
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
  v_product products;
  v_unit_price numeric;
  v_list_price numeric;
  v_quantity integer;
  v_shortage text;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'cashier']::staff_role[], 'record sales');

  if p_payment_method = 'part' and p_amount_paid > 0 and p_paid_channel is null then
    raise exception 'A payment channel is required for the paid portion of a part payment';
  end if;
  if jsonb_array_length(coalesce(p_lines, '[]'::jsonb)) = 0 then
    raise exception 'A sale needs at least one product';
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
    v_product := require_active_product(p_tenant_id, product_from_record(p_tenant_id, v_line));
    v_quantity := (v_line ->> 'quantity')::integer;
    v_unit_price := (v_line ->> 'unit_price')::numeric;
    v_list_price := case when is_offline_sync() and v_line ? 'list_price'
      then (v_line ->> 'list_price')::numeric
      else list_price(v_product, p_customer_type) end;
    perform require_price_allowed(p_tenant_id, v_product, v_unit_price, v_list_price);

    insert into sale_lines (tenant_id, sale_id, product_id, quantity, unit_price, list_price)
    values (p_tenant_id, v_sale_id, v_product.id, v_quantity, v_unit_price, v_list_price);

    v_item_id := finished_item_for(p_tenant_id, v_product.id);
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

create or replace function settle_load_out(
  p_tenant_id uuid,
  p_load_out_id uuid,
  p_bags_sold integer,
  p_bags_returned integer,
  p_bags_damaged integer,
  p_cash_returned numeric,
  p_discrepancy_note text,
  p_customer_type sales_customer_type default 'walk_in',
  p_customer_name text default null,
  p_unit_price numeric default null,
  p_amount_paid numeric default null,
  p_payment_method sales_payment_method default 'cash',
  p_paid_channel payment_channel default null
)
returns load_outs
language plpgsql
security definer set search_path = public
as $$
declare
  v_load_out load_outs;
  v_product products;
  v_list_price numeric;
  v_item_id uuid;
  v_sale_id uuid;
  v_total numeric;
  v_paid numeric;
  v_balance numeric;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'settle trips');

  update load_outs
  set status = 'settled',
      bags_sold = p_bags_sold,
      bags_returned = p_bags_returned,
      bags_damaged = p_bags_damaged,
      cash_returned = p_cash_returned,
      settled_at = now(),
      discrepancy_note = p_discrepancy_note
  where tenant_id = p_tenant_id and id = p_load_out_id and status = 'on_road'
  returning * into v_load_out;
  if v_load_out.id is null then
    raise exception 'Trip not found, or already settled';
  end if;

  if p_bags_returned > 0 then
    v_item_id := finished_item_for(p_tenant_id, v_load_out.product_id);
    if v_item_id is not null then
      perform add_stock_batch(
        p_tenant_id, v_item_id, p_bags_returned, null, 'stock_in',
        'Returned from load-out — unsold', auth.uid()
      );
    end if;
  end if;

  if p_bags_sold > 0 and p_unit_price is not null then
    select * into v_product from products where tenant_id = p_tenant_id and id = v_load_out.product_id;
    v_list_price := list_price(v_product, p_customer_type);
    perform require_price_allowed(p_tenant_id, v_product, p_unit_price, v_list_price);

    v_total := p_bags_sold * p_unit_price;
    v_paid := coalesce(p_amount_paid, v_total);
    v_balance := v_total - v_paid;

    if p_payment_method = 'part' and v_paid > 0 and p_paid_channel is null then
      raise exception 'A payment channel is required for the paid portion of a part payment';
    end if;

    insert into sales (tenant_id, customer_type, customer_name, total, amount_paid, payment_method, balance, recorded_by)
    values (p_tenant_id, p_customer_type, p_customer_name, v_total, v_paid, p_payment_method, v_balance, auth.uid())
    returning id into v_sale_id;

    insert into sale_lines (tenant_id, sale_id, product_id, quantity, unit_price, list_price)
    values (p_tenant_id, v_sale_id, v_load_out.product_id, p_bags_sold, p_unit_price, v_list_price);

    update load_outs set sale_id = v_sale_id where tenant_id = p_tenant_id and id = p_load_out_id;

    perform post_sale_side_effects(
      p_tenant_id, v_sale_id, p_customer_type, p_customer_name,
      v_paid, p_payment_method, v_balance, p_paid_channel, ' (distribution trip)'
    );
  end if;

  select * into v_load_out from load_outs where tenant_id = p_tenant_id and id = p_load_out_id;
  return v_load_out;
end;
$$;

-- Finished-goods stock items belong to their product: change or remove
-- them through Products.
create or replace function delete_stock_item(p_tenant_id uuid, p_item_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'delete inventory items');

  if exists (select 1 from stock_items where tenant_id = p_tenant_id and id = p_item_id and product_id is not null) then
    raise exception 'This is a product''s stock. Retire or delete the product under Products instead.';
  end if;
  if exists (select 1 from stock_movements where tenant_id = p_tenant_id and item_id = p_item_id) then
    raise exception 'This item has stock movement history and cannot be deleted.';
  end if;

  delete from stock_items where tenant_id = p_tenant_id and id = p_item_id;
  if not found then
    raise exception 'Stock item not found';
  end if;
end;
$$;

-- =========================================================================
-- Managing products (Owner/Admin)
-- =========================================================================

create function add_product_internal(
  p_tenant_id uuid,
  p_name text,
  p_unit text,
  p_walk_in_price numeric,
  p_distributor_price numeric,
  p_legacy_key text default null
)
returns products
language plpgsql
security definer set search_path = public
as $$
declare
  v_product products;
begin
  if exists (select 1 from products where tenant_id = p_tenant_id and lower(btrim(name)) = lower(btrim(p_name))) then
    raise exception 'There is already a product called %', btrim(p_name);
  end if;
  insert into products (tenant_id, name, unit, walk_in_price, distributor_price, sort_order, legacy_key)
  values (
    p_tenant_id, btrim(p_name), btrim(p_unit), p_walk_in_price, p_distributor_price,
    coalesce((select max(sort_order) from products where tenant_id = p_tenant_id), 0) + 1,
    p_legacy_key
  )
  returning * into v_product;
  insert into stock_items (tenant_id, name, category, unit, product_id)
  values (p_tenant_id, v_product.name, 'finished_goods', v_product.unit, v_product.id);
  return v_product;
end;
$$;

create function create_product(
  p_tenant_id uuid,
  p_name text,
  p_unit text,
  p_walk_in_price numeric,
  p_distributor_price numeric
)
returns products
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'manage products');
  return add_product_internal(p_tenant_id, p_name, p_unit, p_walk_in_price, p_distributor_price);
end;
$$;

create function update_product(
  p_tenant_id uuid,
  p_product_id uuid,
  p_name text,
  p_unit text,
  p_walk_in_price numeric,
  p_distributor_price numeric
)
returns products
language plpgsql
security definer set search_path = public
as $$
declare
  v_product products;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'manage products');
  if exists (
    select 1 from products
    where tenant_id = p_tenant_id and id <> p_product_id and lower(btrim(name)) = lower(btrim(p_name))
  ) then
    raise exception 'There is already a product called %', btrim(p_name);
  end if;

  update products
  set name = btrim(p_name), unit = btrim(p_unit),
      walk_in_price = p_walk_in_price, distributor_price = p_distributor_price
  where tenant_id = p_tenant_id and id = p_product_id
  returning * into v_product;
  if v_product.id is null then
    raise exception 'Product not found';
  end if;

  update stock_items set name = v_product.name, unit = v_product.unit
  where tenant_id = p_tenant_id and product_id = p_product_id;
  return v_product;
end;
$$;

-- Retire (hide from new records) or bring back.
create function set_product_retired(p_tenant_id uuid, p_product_id uuid, p_retired boolean)
returns products
language plpgsql
security definer set search_path = public
as $$
declare
  v_product products;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'manage products');
  update products
  set archived_at = case when p_retired then coalesce(archived_at, now()) else null end
  where tenant_id = p_tenant_id and id = p_product_id
  returning * into v_product;
  if v_product.id is null then
    raise exception 'Product not found';
  end if;
  return v_product;
end;
$$;

-- Only a product that was never sold, produced, loaded or stocked.
create function delete_product(p_tenant_id uuid, p_product_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'manage products');
  if not exists (select 1 from products where tenant_id = p_tenant_id and id = p_product_id) then
    raise exception 'Product not found';
  end if;
  if exists (select 1 from sale_lines where tenant_id = p_tenant_id and product_id = p_product_id)
     or exists (select 1 from production_runs where tenant_id = p_tenant_id and product_id = p_product_id)
     or exists (select 1 from load_outs where tenant_id = p_tenant_id and product_id = p_product_id)
     or exists (
       select 1 from stock_movements m
       join stock_items si on si.tenant_id = m.tenant_id and si.id = m.item_id
       where m.tenant_id = p_tenant_id and si.product_id = p_product_id
     ) then
    raise exception 'This product has been used, so it can''t be deleted. Retire it instead.';
  end if;

  delete from stock_items where tenant_id = p_tenant_id and product_id = p_product_id;
  delete from products where tenant_id = p_tenant_id and id = p_product_id;
end;
$$;

-- New organizations start with the 4 usual products (and their stock).
create or replace function create_tenant(p_name text)
returns tenants
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tenant tenants;
  v_slug text;
begin
  if v_uid is null then
    raise exception 'Sign in to create an organization' using errcode = '42501';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'Organization name is required';
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(btrim(p_name)), '[^a-z0-9]+', '-', 'g'));
  v_slug := left(coalesce(nullif(v_slug, ''), 'org'), 40) || '-' || substr(md5(gen_random_uuid()::text), 1, 6);

  insert into tenants (name, slug, created_by)
  values (btrim(p_name), v_slug, v_uid)
  returning * into v_tenant;

  insert into tenant_members (tenant_id, user_id, role)
  values (v_tenant.id, v_uid, 'owner');

  -- legacy_key: lets records queued on devices with the old app match.
  perform add_product_internal(v_tenant.id, '50cl Sachet', 'bags', 400, 400, 'sachet50cl');
  perform add_product_internal(v_tenant.id, '75cl Bottle', 'packs', 150, 150, 'bottle75cl');
  perform add_product_internal(v_tenant.id, '1.5L Bottle', 'packs', 350, 350, 'bottle1_5l');
  perform add_product_internal(v_tenant.id, '5L Bottle', 'bottles', 900, 900, 'bottle5l');

  return v_tenant;
end;
$$;

-- =========================================================================
-- Offline records: product ids (or the old names, translated)
-- =========================================================================

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

    else
      raise exception 'Unknown record type: %', v_type;
    end case;

    insert into device_operations (op_id, tenant_id, device_id, actor_id, type, payload, recorded_at, status, result)
    values (v_op_id, v_tenant, v_device.id, v_actor, v_type, v_payload, v_recorded_at, 'applied', v_result)
    on conflict (op_id) do update
      set status = 'applied', result = excluded.result, error = null,
          payload = excluded.payload, received_at = now();

    perform set_config('hydrotrack.offline_sync', '', true);
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

-- =========================================================================
-- Grants
-- =========================================================================

do $$
declare
  f text;
begin
  foreach f in array array[
    'finished_item_for(uuid, uuid)',
    'product_from_record(uuid, jsonb)',
    'production_shortage(uuid, uuid, integer)',
    'deduct_production_materials(uuid, uuid, uuid, integer, text)',
    'require_active_product(uuid, uuid)',
    'list_price(products, sales_customer_type)',
    'require_price_allowed(uuid, products, numeric, numeric)',
    'add_product_internal(uuid, text, text, numeric, numeric, text)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;

  foreach f in array array[
    'record_production_run(uuid, date, production_shift, text, text, uuid, integer, integer, date)',
    'update_production_run(uuid, uuid, date, production_shift, text, text, uuid, integer, integer, date)',
    'record_load_out(uuid, uuid, uuid, uuid, integer, text)',
    'create_product(uuid, text, text, numeric, numeric)',
    'update_product(uuid, uuid, text, text, numeric, numeric)',
    'set_product_retired(uuid, uuid, boolean)',
    'delete_product(uuid, uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
