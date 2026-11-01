-- HydroTrack — 0006: business RPCs, tenant-aware.
--
-- Same behaviour as the final single-tenant versions, with three changes
-- everywhere:
--   1. p_tenant_id is the first parameter; require_tenant_role() checks
--      the caller is an active member of THAT tenant with a permitted
--      role before anything else happens.
--   2. Every read/update of an existing row is filtered by tenant_id too,
--      so passing another tenant's row id finds nothing ("not found").
--   3. Every inserted row carries p_tenant_id; composite FKs (0003) then
--      guarantee anything it references belongs to the same tenant.
-- These functions are security definer (they bypass RLS), which is why
-- 1 and 2 are done explicitly in every one of them.

-- =========================================================================
-- Inventory
-- =========================================================================

create function add_stock(
  p_tenant_id uuid,
  p_item_id uuid,
  p_quantity integer,
  p_note text,
  p_expiry_date date default null
)
returns stock_items
language plpgsql
security definer set search_path = public
as $$
declare
  v_item stock_items;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'add stock');
  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero';
  end if;

  select * into v_item from stock_items where tenant_id = p_tenant_id and id = p_item_id for update;
  if v_item.id is null then
    raise exception 'Stock item not found';
  end if;

  perform add_stock_batch(p_tenant_id, p_item_id, p_quantity, p_expiry_date, 'stock_in', p_note, auth.uid());

  select * into v_item from stock_items where tenant_id = p_tenant_id and id = p_item_id;
  return v_item;
end;
$$;

-- Shrinkage comes off the oldest batches; a surplus becomes a new undated
-- batch. A count that confirms the total still logs a zero movement
-- (the "last stock count" figure depends on it).
create function adjust_stock_count(
  p_tenant_id uuid,
  p_item_id uuid,
  p_new_count integer,
  p_note text
)
returns stock_items
language plpgsql
security definer set search_path = public
as $$
declare
  v_current integer;
  v_delta integer;
  v_item stock_items;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'adjust stock count');

  select quantity_on_hand into v_current
  from stock_items where tenant_id = p_tenant_id and id = p_item_id for update;
  if v_current is null then
    raise exception 'Stock item not found';
  end if;
  v_delta := p_new_count - v_current;

  if v_delta < 0 then
    perform consume_stock_fifo(p_tenant_id, p_item_id, -v_delta, 'adjustment', p_note, auth.uid());
  elsif v_delta > 0 then
    perform add_stock_batch(p_tenant_id, p_item_id, v_delta, null, 'adjustment', p_note, auth.uid());
  else
    insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom)
    values (p_tenant_id, p_item_id, 'adjustment', 0, p_note, auth.uid());
  end if;

  select * into v_item from stock_items where tenant_id = p_tenant_id and id = p_item_id;
  return v_item;
end;
$$;

create function update_stock_item_details(
  p_tenant_id uuid,
  p_item_id uuid,
  p_name text,
  p_unit text,
  p_reorder_level integer
)
returns stock_items
language plpgsql
security definer set search_path = public
as $$
declare
  v_item stock_items;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'edit inventory items');

  update stock_items
  set name = p_name, unit = p_unit, reorder_level = p_reorder_level
  where tenant_id = p_tenant_id and id = p_item_id
  returning * into v_item;

  if v_item.id is null then
    raise exception 'Stock item not found';
  end if;
  return v_item;
end;
$$;

-- Blocked whenever the item has movement history (deleting would cascade
-- away its audit trail); only a never-touched item can be removed.
create function delete_stock_item(p_tenant_id uuid, p_item_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'delete inventory items');

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
-- Production (recipe-based raw-material deduction, hard stock block)
-- =========================================================================

-- Collects every raw-material shortfall for a run into one message
-- (empty string when there's enough of everything).
create function production_shortage(
  p_tenant_id uuid,
  p_product product_type,
  p_bags integer
)
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
    where pr.tenant_id = p_tenant_id and pr.product = p_product
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
  p_product product_type,
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
    select * from production_recipes where tenant_id = p_tenant_id and product = p_product
  loop
    v_deduct := round(v_recipe.quantity_used * p_bags / v_recipe.per_bags);
    if v_deduct > 0 then
      perform consume_stock_fifo(p_tenant_id, v_recipe.raw_material_item_id, v_deduct, 'production_use', p_note, auth.uid(), p_run_id);
    end if;
  end loop;
end;
$$;

-- Puts back exactly what a run's linked production_use movements took,
-- then deletes those movement rows.
create function reverse_production_materials(p_tenant_id uuid, p_run_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_movement record;
begin
  for v_movement in
    select * from stock_movements
    where tenant_id = p_tenant_id and production_run_id = p_run_id and type = 'production_use'
  loop
    if v_movement.batch_id is not null then
      update stock_batches
      set quantity_remaining = greatest(0, least(quantity_received, quantity_remaining - v_movement.quantity))
      where tenant_id = p_tenant_id and id = v_movement.batch_id;
    end if;
    update stock_items set quantity_on_hand = quantity_on_hand - v_movement.quantity
    where tenant_id = p_tenant_id and id = v_movement.item_id;
  end loop;
  delete from stock_movements
  where tenant_id = p_tenant_id and production_run_id = p_run_id and type = 'production_use';
end;
$$;

create function record_production_run(
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
  if v_shortage <> '' then
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

-- Raw materials: undo then redo (checked after the undo, so a run isn't
-- blocked by its own earlier deduction). The finished-goods batch the run
-- created is adjusted in place, never recreated, so bags already sold
-- from it stay sold.
create function update_production_run(
  p_tenant_id uuid,
  p_run_id uuid,
  p_date date,
  p_shift production_shift,
  p_machine text,
  p_operator_name text,
  p_product product_type,
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

  perform reverse_production_materials(p_tenant_id, p_run_id);

  v_shortage := production_shortage(p_tenant_id, p_product, p_quantity_produced + p_wastage);
  if v_shortage <> '' then
    raise exception 'Not enough raw material for this change: %', v_shortage;
  end if;

  update production_runs
  set date = p_date, shift = p_shift, machine = p_machine, operator_name = p_operator_name,
      product = p_product, quantity_produced = p_quantity_produced, wastage = p_wastage
  where tenant_id = p_tenant_id and id = p_run_id;

  perform deduct_production_materials(p_tenant_id, p_run_id, p_product, p_quantity_produced + p_wastage, 'Used in production run (edited)');

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
    v_finished_item_id := finished_item_for(p_tenant_id, p_product);
    if v_finished_item_id is not null then
      perform add_stock_batch(p_tenant_id, v_finished_item_id, p_quantity_produced, p_expiry_date, 'stock_in', 'Produced — production run (edited)', auth.uid(), p_run_id);
    end if;
  end if;
end;
$$;

-- Undo raw-material consumption; write off what's left of the
-- finished-goods batch (sold bags can't be un-sold).
create function delete_production_run(p_tenant_id uuid, p_run_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_batch stock_batches;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'delete production runs');

  if not exists (select 1 from production_runs where tenant_id = p_tenant_id and id = p_run_id) then
    raise exception 'Production run not found';
  end if;

  perform reverse_production_materials(p_tenant_id, p_run_id);

  select * into v_batch from stock_batches
  where tenant_id = p_tenant_id and production_run_id = p_run_id limit 1;
  if v_batch.id is not null and v_batch.quantity_remaining > 0 then
    update stock_items set quantity_on_hand = quantity_on_hand - v_batch.quantity_remaining
    where tenant_id = p_tenant_id and id = v_batch.item_id;
  end if;

  delete from production_runs where tenant_id = p_tenant_id and id = p_run_id;
end;
$$;

-- =========================================================================
-- Sales
-- =========================================================================

-- Shared by record_sale and settle_load_out: the debt-ledger and cash
-- side effects of a sale that already exists.
create function post_sale_side_effects(
  p_tenant_id uuid,
  p_sale_id uuid,
  p_customer_type sales_customer_type,
  p_customer_name text,
  p_amount_paid numeric,
  p_payment_method sales_payment_method,
  p_balance numeric,
  p_paid_channel payment_channel,
  p_note_suffix text
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer_id uuid;
  v_channel payment_channel;
begin
  if p_customer_type = 'distributor' and p_balance > 0 and p_customer_name is not null then
    select id into v_customer_id from customers
    where tenant_id = p_tenant_id and name = p_customer_name
    limit 1;
    if v_customer_id is not null then
      insert into ledger_entries (tenant_id, customer_id, type, amount, date, note, sale_id, recorded_by)
      values (p_tenant_id, v_customer_id, 'sale', p_balance, current_date,
              'Sale — balance carried to account' || p_note_suffix, p_sale_id, auth.uid());
      update customers set balance = balance + p_balance
      where tenant_id = p_tenant_id and id = v_customer_id;
    end if;
  end if;

  if p_amount_paid > 0 then
    v_channel := case
      when p_payment_method in ('cash', 'transfer') then p_payment_method::text::payment_channel
      else p_paid_channel
    end;
    if v_channel is not null then
      insert into cash_entries (tenant_id, date_time, direction, source, amount, method, note, recorded_by, sale_id)
      values (
        p_tenant_id, now(), 'money_in', 'sales', p_amount_paid, v_channel,
        case when p_customer_type = 'distributor' then 'Sale — ' || p_customer_name else 'Sale — walk-in' end || p_note_suffix,
        auth.uid(), p_sale_id
      );
    end if;
  end if;
end;
$$;

create function record_sale(
  p_tenant_id uuid,
  p_customer_type sales_customer_type,
  p_customer_name text,
  p_total numeric,
  p_amount_paid numeric,
  p_payment_method sales_payment_method,
  p_balance numeric,
  p_lines jsonb, -- [{"product": ..., "quantity": ..., "unit_price": ...}]
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
  v_grouped record;
  v_available integer;
  v_item_name text;
  v_shortage text := '';
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'cashier']::staff_role[], 'record sales');

  if p_payment_method = 'part' and p_amount_paid > 0 and p_paid_channel is null then
    raise exception 'A payment channel is required for the paid portion of a part payment';
  end if;

  -- Hard stock block, summed per product across lines.
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
  if v_shortage <> '' then
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

-- Admin-only. Stock comes back as one undated batch per item, the debt
-- side gets a reversing 'voided' ledger entry, and the sale's cash entry
-- is removed (cash collected is a gross figure). The sale row stays,
-- marked voided.
create function void_sale(p_tenant_id uuid, p_sale_id uuid, p_reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_sale sales;
  v_item record;
  v_ledger ledger_entries;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'void sales');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to void a sale';
  end if;

  select * into v_sale from sales where tenant_id = p_tenant_id and id = p_sale_id for update;
  if v_sale.id is null then
    raise exception 'Sale not found';
  end if;
  if v_sale.voided_at is not null then
    raise exception 'This sale has already been voided';
  end if;

  for v_item in
    select item_id, sum(-quantity)::integer as qty
    from stock_movements
    where tenant_id = p_tenant_id and sale_id = p_sale_id and quantity < 0
    group by item_id
  loop
    perform add_stock_batch(
      p_tenant_id, v_item.item_id, v_item.qty, null::date, 'stock_in'::movement_type,
      'Voided sale — stock returned', auth.uid(), null::uuid, p_sale_id
    );
  end loop;

  select * into v_ledger from ledger_entries
  where tenant_id = p_tenant_id and sale_id = p_sale_id and type = 'sale' limit 1;
  if v_ledger.id is not null then
    insert into ledger_entries (tenant_id, customer_id, type, amount, date, note, sale_id, recorded_by)
    values (p_tenant_id, v_ledger.customer_id, 'voided', v_ledger.amount, current_date,
            'Voided sale — credit removed', p_sale_id, auth.uid());
    update customers set balance = balance - v_ledger.amount
    where tenant_id = p_tenant_id and id = v_ledger.customer_id;
  end if;

  delete from cash_entries
  where tenant_id = p_tenant_id and sale_id = p_sale_id and direction = 'money_in';

  update sales
  set voided_at = now(), voided_by = auth.uid(), void_reason = p_reason
  where tenant_id = p_tenant_id and id = p_sale_id;
end;
$$;

-- =========================================================================
-- Debts
-- =========================================================================

create function record_customer_payment(
  p_tenant_id uuid,
  p_customer_id uuid,
  p_amount numeric,
  p_channel payment_channel,
  p_date date,
  p_note text
)
returns customers
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer customers;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'cashier']::staff_role[], 'record payments');
  if p_amount <= 0 then
    raise exception 'Payment amount must be greater than zero';
  end if;

  update customers
  set balance = balance - p_amount, last_payment_date = p_date
  where tenant_id = p_tenant_id and id = p_customer_id
  returning * into v_customer;
  if v_customer.id is null then
    raise exception 'Customer not found';
  end if;

  insert into ledger_entries (tenant_id, customer_id, type, amount, date, note, recorded_by)
  values (p_tenant_id, p_customer_id, 'payment', p_amount, p_date, p_note, auth.uid());

  insert into cash_entries (tenant_id, date_time, direction, source, amount, method, note, recorded_by)
  values (p_tenant_id, p_date::timestamptz, 'money_in', 'debt_payment', p_amount, p_channel, p_note, auth.uid());

  return v_customer;
end;
$$;

create function update_customer_credit_limit(p_tenant_id uuid, p_customer_id uuid, p_new_limit numeric)
returns customers
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer customers;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'edit credit limits');

  update customers set credit_limit = p_new_limit
  where tenant_id = p_tenant_id and id = p_customer_id
  returning * into v_customer;
  if v_customer.id is null then
    raise exception 'Customer not found';
  end if;
  return v_customer;
end;
$$;

-- p_amount is signed: positive = already owed before HydroTrack,
-- negative = already in credit.
create function add_opening_balance(
  p_tenant_id uuid,
  p_customer_id uuid,
  p_amount numeric,
  p_reason text
)
returns customers
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer customers;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'set an opening balance');
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to set an opening balance';
  end if;
  if p_amount = 0 then
    raise exception 'Opening balance must not be zero';
  end if;

  update customers set balance = balance + p_amount
  where tenant_id = p_tenant_id and id = p_customer_id
  returning * into v_customer;
  if v_customer.id is null then
    raise exception 'Customer not found';
  end if;

  insert into ledger_entries (tenant_id, customer_id, type, amount, date, note, recorded_by)
  values (p_tenant_id, p_customer_id, 'opening_balance', p_amount, current_date, p_reason, auth.uid());

  return v_customer;
end;
$$;

create function write_off_debt(
  p_tenant_id uuid,
  p_customer_id uuid,
  p_amount numeric,
  p_reason text
)
returns customers
language plpgsql
security definer set search_path = public
as $$
declare
  v_customer customers;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'write off a debt');
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to write off a debt';
  end if;
  if p_amount <= 0 then
    raise exception 'Write-off amount must be greater than zero';
  end if;

  update customers set balance = balance - p_amount
  where tenant_id = p_tenant_id and id = p_customer_id
  returning * into v_customer;
  if v_customer.id is null then
    raise exception 'Customer not found';
  end if;

  insert into ledger_entries (tenant_id, customer_id, type, amount, date, note, recorded_by)
  values (p_tenant_id, p_customer_id, 'write_off', p_amount, current_date, p_reason, auth.uid());

  return v_customer;
end;
$$;

-- =========================================================================
-- Expenses
-- =========================================================================

create function record_expense(
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
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'record expenses');

  insert into expenses (tenant_id, date, category, description, amount, method, recorded_by)
  values (p_tenant_id, p_date, p_category, p_description, p_amount, p_method, auth.uid())
  returning id into v_expense_id;

  insert into cash_entries (tenant_id, date_time, direction, source, amount, method, note, recorded_by)
  values (
    p_tenant_id, p_date::timestamptz, 'money_out',
    case when p_category = 'wages' then 'wages'::cash_source else 'expense'::cash_source end,
    p_amount, p_method, p_description, auth.uid()
  );

  return v_expense_id;
end;
$$;

-- =========================================================================
-- Distribution
-- =========================================================================

-- Dispatch deducts the whole load (FIFO) when the trip starts.
create function record_load_out(
  p_tenant_id uuid,
  p_driver_id uuid,
  p_vehicle_id uuid,
  p_product product_type,
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

  -- The composite FKs reject a driver/vehicle from another tenant.
  insert into load_outs (tenant_id, driver_id, vehicle_id, product, bags_loaded, status, note, recorded_by)
  values (p_tenant_id, p_driver_id, p_vehicle_id, p_product, p_bags_loaded, 'on_road', p_note, auth.uid())
  returning id into v_load_out_id;

  v_item_id := finished_item_for(p_tenant_id, p_product);
  if v_item_id is not null then
    perform consume_stock_fifo(
      p_tenant_id, v_item_id, p_bags_loaded, 'stock_out',
      p_bags_loaded || ' bags dispatched on load-out', auth.uid()
    );
  end if;

  return v_load_out_id;
end;
$$;

-- Settling a trip: returned bags go back as a new undated batch. When a
-- unit price is given, the sold bags also become a real sale (ledger +
-- cash side effects) WITHOUT a second stock deduction — dispatch already
-- took the whole load.
create function settle_load_out(
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
    v_item_id := finished_item_for(p_tenant_id, v_load_out.product);
    if v_item_id is not null then
      perform add_stock_batch(
        p_tenant_id, v_item_id, p_bags_returned, null, 'stock_in',
        'Returned from load-out — unsold', auth.uid()
      );
    end if;
  end if;

  if p_bags_sold > 0 and p_unit_price is not null then
    v_total := p_bags_sold * p_unit_price;
    v_paid := coalesce(p_amount_paid, v_total);
    v_balance := v_total - v_paid;

    if p_payment_method = 'part' and v_paid > 0 and p_paid_channel is null then
      raise exception 'A payment channel is required for the paid portion of a part payment';
    end if;

    insert into sales (tenant_id, customer_type, customer_name, total, amount_paid, payment_method, balance, recorded_by)
    values (p_tenant_id, p_customer_type, p_customer_name, v_total, v_paid, p_payment_method, v_balance, auth.uid())
    returning id into v_sale_id;

    insert into sale_lines (tenant_id, sale_id, product, quantity, unit_price)
    values (p_tenant_id, v_sale_id, v_load_out.product, p_bags_sold, p_unit_price);

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

-- =========================================================================
-- Grants: callable RPCs to signed-in users only; internal helpers to no
-- client role at all.
-- =========================================================================

revoke execute on function production_shortage(uuid, product_type, integer) from public, anon, authenticated;
revoke execute on function deduct_production_materials(uuid, uuid, product_type, integer, text) from public, anon, authenticated;
revoke execute on function reverse_production_materials(uuid, uuid) from public, anon, authenticated;
revoke execute on function post_sale_side_effects(uuid, uuid, sales_customer_type, text, numeric, sales_payment_method, numeric, payment_channel, text)
  from public, anon, authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'add_stock(uuid, uuid, integer, text, date)',
    'adjust_stock_count(uuid, uuid, integer, text)',
    'update_stock_item_details(uuid, uuid, text, text, integer)',
    'delete_stock_item(uuid, uuid)',
    'record_production_run(uuid, date, production_shift, text, text, product_type, integer, integer, date)',
    'update_production_run(uuid, uuid, date, production_shift, text, text, product_type, integer, integer, date)',
    'delete_production_run(uuid, uuid)',
    'record_sale(uuid, sales_customer_type, text, numeric, numeric, sales_payment_method, numeric, jsonb, payment_channel)',
    'void_sale(uuid, uuid, text)',
    'record_customer_payment(uuid, uuid, numeric, payment_channel, date, text)',
    'update_customer_credit_limit(uuid, uuid, numeric)',
    'add_opening_balance(uuid, uuid, numeric, text)',
    'write_off_debt(uuid, uuid, numeric, text)',
    'record_expense(uuid, date, expense_category, text, numeric, payment_channel)',
    'record_load_out(uuid, uuid, uuid, product_type, integer, text)',
    'settle_load_out(uuid, uuid, integer, integer, integer, numeric, text, sales_customer_type, text, numeric, numeric, sales_payment_method, payment_channel)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
