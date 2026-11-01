-- HydroTrack — 0021: suppliers, purchases and costs (agreed rules).
--
-- * Suppliers, and purchases of raw materials paid now or on credit; what
--   the factory owes each supplier is tracked like customer debts in
--   reverse (supplier_ledger), with payments to suppliers.
-- * Average cost: every stock item has average_cost (per unit). A purchase
--   updates it ((on hand x old average + quantity x price) / new total);
--   a production run's output is costed at the raw material it used, and
--   updates the product's average the same way. Other stock in (counts,
--   returns) keeps the average.
-- * Every stock movement records the unit cost at that moment; a
--   production run keeps its material cost (production_runs.material_cost)
--   and each sale line its unit cost (the product's average when sold), so
--   reports can show cost per bag and profit after the cost of bags sold.

alter type cash_source add value if not exists 'purchase';
alter type cash_source add value if not exists 'supplier_payment';

alter table stock_items add column average_cost numeric(14, 4) not null default 0;
alter table stock_movements add column unit_cost numeric(14, 4);
alter table production_runs add column material_cost numeric(14, 2) not null default 0;
alter table sale_lines add column unit_cost numeric(14, 4);

-- =========================================================================
-- Costing
-- =========================================================================

-- Fills in each movement's unit cost and keeps average_cost current. A
-- caller that knows the price (purchases) sets unit_cost; production
-- output is priced from the run's own material use.
create function cost_stock_movement()
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

create trigger stock_movements_cost
  before insert on stock_movements
  for each row execute function cost_stock_movement();

-- A run's material cost follows its raw-material movements (recorded,
-- reversed on edit/delete).
create function track_run_material_cost()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.type = 'production_use' and new.production_run_id is not null then
    update production_runs set material_cost = material_cost + (-new.quantity * new.unit_cost)
    where tenant_id = new.tenant_id and id = new.production_run_id;
  elsif tg_op = 'DELETE' and old.type = 'production_use' and old.production_run_id is not null then
    update production_runs set material_cost = material_cost - (-old.quantity * old.unit_cost)
    where tenant_id = old.tenant_id and id = old.production_run_id;
  end if;
  return null;
end;
$$;

create trigger stock_movements_run_cost
  after insert or delete on stock_movements
  for each row execute function track_run_material_cost();

-- Each sale line keeps what the product cost at the time it was sold.
create function cost_sale_line()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.unit_cost is null then
    new.unit_cost := coalesce((
      select average_cost from stock_items
      where tenant_id = new.tenant_id and product_id = new.product_id
    ), 0);
  end if;
  return new;
end;
$$;

create trigger sale_lines_cost
  before insert on sale_lines
  for each row execute function cost_sale_line();

revoke all on function cost_stock_movement() from public, anon, authenticated;
revoke all on function track_run_material_cost() from public, anon, authenticated;
revoke all on function cost_sale_line() from public, anon, authenticated;

-- =========================================================================
-- Suppliers and purchases
-- =========================================================================

create table suppliers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  phone text,
  -- What the factory owes them.
  balance numeric(12, 2) not null default 0,
  created_at timestamptz not null default now(),
  unique (tenant_id, id)
);
create unique index suppliers_tenant_name_unique on suppliers (tenant_id, lower(btrim(name)));

create table purchases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  supplier_id uuid not null,
  date date not null,
  total numeric(12, 2) not null,
  amount_paid numeric(12, 2) not null,
  paid_channel payment_channel,
  note text,
  recorded_by uuid not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, supplier_id) references suppliers (tenant_id, id),
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id),
  constraint purchases_recorded_by_profile_fkey foreign key (recorded_by) references profiles (id)
);
create index purchases_tenant_date_idx on purchases (tenant_id, date desc);

create table purchase_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  purchase_id uuid not null,
  item_id uuid not null,
  quantity integer not null check (quantity > 0),
  unit_cost numeric(14, 4) not null check (unit_cost >= 0),
  unique (tenant_id, id),
  foreign key (tenant_id, purchase_id) references purchases (tenant_id, id) on delete cascade,
  foreign key (tenant_id, item_id) references stock_items (tenant_id, id)
);

create table supplier_ledger (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  supplier_id uuid not null,
  type text not null check (type in ('purchase', 'payment')),
  amount numeric(12, 2) not null,
  date date not null,
  note text,
  purchase_id uuid,
  recorded_by uuid not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, supplier_id) references suppliers (tenant_id, id) on delete cascade,
  foreign key (tenant_id, purchase_id) references purchases (tenant_id, id) on delete cascade
);
create index supplier_ledger_supplier_idx on supplier_ledger (tenant_id, supplier_id, date);

alter table suppliers enable row level security;
alter table purchases enable row level security;
alter table purchase_lines enable row level security;
alter table supplier_ledger enable row level security;

-- Who buys and pays: Owner/Admin/Manager/Store keeper. Cashiers don't see
-- what the factory pays its suppliers.
do $$
declare
  t text;
begin
  foreach t in array array['suppliers', 'purchases', 'purchase_lines', 'supplier_ledger'] loop
    execute format(
      'create policy %I on %I for select to authenticated using (has_tenant_role(tenant_id, array[''admin'', ''manager'', ''store_keeper'']::staff_role[]))',
      t || '_select', t);
  end loop;
end;
$$;

create function create_supplier(p_tenant_id uuid, p_name text, p_phone text)
returns suppliers
language plpgsql
security definer set search_path = public
as $$
declare
  v_supplier suppliers;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'add suppliers');
  if exists (select 1 from suppliers where tenant_id = p_tenant_id and lower(btrim(name)) = lower(btrim(p_name))) then
    raise exception 'There is already a supplier called %', btrim(p_name);
  end if;
  insert into suppliers (tenant_id, name, phone)
  values (p_tenant_id, btrim(p_name), nullif(btrim(p_phone), ''))
  returning * into v_supplier;
  return v_supplier;
end;
$$;

-- p_lines: [{"item_id": ..., "quantity": ..., "unit_cost": ...}] (raw
-- materials). Paid now (p_amount_paid, by p_paid_channel), the rest owed.
create function record_purchase(
  p_tenant_id uuid,
  p_supplier_id uuid,
  p_date date,
  p_lines jsonb,
  p_amount_paid numeric,
  p_paid_channel payment_channel,
  p_note text
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_supplier suppliers;
  v_purchase_id uuid;
  v_line jsonb;
  v_item stock_items;
  v_quantity integer;
  v_cost numeric;
  v_total numeric := 0;
  v_batch_id uuid;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[], 'record purchases');

  select * into v_supplier from suppliers where tenant_id = p_tenant_id and id = p_supplier_id;
  if v_supplier.id is null then
    raise exception 'Supplier not found';
  end if;
  if jsonb_array_length(coalesce(p_lines, '[]'::jsonb)) = 0 then
    raise exception 'A purchase needs at least one item';
  end if;

  select coalesce(sum((l ->> 'quantity')::integer * (l ->> 'unit_cost')::numeric), 0) into v_total
  from jsonb_array_elements(p_lines) l;
  if p_amount_paid < 0 or p_amount_paid > v_total then
    raise exception 'Amount paid must be between 0 and the total (%)', v_total;
  end if;
  if p_amount_paid > 0 and p_paid_channel is null then
    raise exception 'Say whether it was paid in cash or by transfer';
  end if;

  insert into purchases (tenant_id, supplier_id, date, total, amount_paid, paid_channel, note, recorded_by)
  values (p_tenant_id, p_supplier_id, p_date, v_total, p_amount_paid,
          case when p_amount_paid > 0 then p_paid_channel end, nullif(btrim(p_note), ''), auth.uid())
  returning id into v_purchase_id;

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select * into v_item from stock_items where tenant_id = p_tenant_id and id = (v_line ->> 'item_id')::uuid;
    if v_item.id is null then
      raise exception 'Stock item not found';
    end if;
    if v_item.product_id is not null then
      raise exception '% is made here, not bought. Record production instead.', v_item.name;
    end if;
    v_quantity := (v_line ->> 'quantity')::integer;
    v_cost := (v_line ->> 'unit_cost')::numeric;
    if v_quantity <= 0 or v_cost < 0 then
      raise exception 'Each item needs a quantity above 0 and a price of 0 or more';
    end if;

    insert into purchase_lines (tenant_id, purchase_id, item_id, quantity, unit_cost)
    values (p_tenant_id, v_purchase_id, v_item.id, v_quantity, v_cost);

    insert into stock_batches (tenant_id, item_id, quantity_received, quantity_remaining, note, created_by)
    values (p_tenant_id, v_item.id, v_quantity, v_quantity, 'Bought from ' || v_supplier.name, auth.uid())
    returning id into v_batch_id;
    -- unit_cost given: the costing trigger updates the average.
    insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, batch_id, unit_cost)
    values (p_tenant_id, v_item.id, 'stock_in', v_quantity, 'Bought from ' || v_supplier.name, auth.uid(), v_batch_id, v_cost);
    update stock_items set quantity_on_hand = quantity_on_hand + v_quantity
    where tenant_id = p_tenant_id and id = v_item.id;
  end loop;

  insert into supplier_ledger (tenant_id, supplier_id, type, amount, date, note, purchase_id, recorded_by)
  values (p_tenant_id, p_supplier_id, 'purchase', v_total, p_date, 'Purchase', v_purchase_id, auth.uid());
  if p_amount_paid > 0 then
    insert into supplier_ledger (tenant_id, supplier_id, type, amount, date, note, purchase_id, recorded_by)
    values (p_tenant_id, p_supplier_id, 'payment', p_amount_paid, p_date, 'Paid with purchase', v_purchase_id, auth.uid());
    insert into cash_entries (tenant_id, date_time, direction, source, amount, method, note, recorded_by)
    values (p_tenant_id, p_date::timestamptz, 'money_out', 'purchase', p_amount_paid, p_paid_channel,
            'Purchase from ' || v_supplier.name, auth.uid());
  end if;
  update suppliers set balance = balance + v_total - p_amount_paid
  where tenant_id = p_tenant_id and id = p_supplier_id;

  return v_purchase_id;
end;
$$;

create function pay_supplier(
  p_tenant_id uuid,
  p_supplier_id uuid,
  p_amount numeric,
  p_channel payment_channel,
  p_date date,
  p_note text
)
returns suppliers
language plpgsql
security definer set search_path = public
as $$
declare
  v_supplier suppliers;
begin
  perform require_tenant_role(p_tenant_id, array['admin', 'manager']::staff_role[], 'pay suppliers');
  if p_amount is null or p_amount <= 0 then
    raise exception 'Payment amount must be greater than zero';
  end if;
  update suppliers set balance = balance - p_amount
  where tenant_id = p_tenant_id and id = p_supplier_id
  returning * into v_supplier;
  if v_supplier.id is null then
    raise exception 'Supplier not found';
  end if;
  insert into supplier_ledger (tenant_id, supplier_id, type, amount, date, note, recorded_by)
  values (p_tenant_id, p_supplier_id, 'payment', p_amount, p_date, nullif(btrim(p_note), ''), auth.uid());
  insert into cash_entries (tenant_id, date_time, direction, source, amount, method, note, recorded_by)
  values (p_tenant_id, p_date::timestamptz, 'money_out', 'supplier_payment', p_amount, p_channel,
          'Paid ' || v_supplier.name, auth.uid());
  return v_supplier;
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array[
    'create_supplier(uuid, text, text)',
    'record_purchase(uuid, uuid, date, jsonb, numeric, payment_channel, text)',
    'pay_supplier(uuid, uuid, numeric, payment_channel, date, text)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
