-- HydroTrack — 0003: business tables, all tenant-owned.
--
-- Every table:
--   * has `tenant_id uuid not null` -> tenants, cascading on tenant delete
--   * has `unique (tenant_id, id)` (also serves as its tenant index)
--   * references other tenant rows through COMPOSITE foreign keys
--     (tenant_id, x_id) -> x (tenant_id, id), so the database itself
--     rejects a row pointing at another tenant's data, independent of RLS
--   * references the acting person as (tenant_id, user_id) ->
--     tenant_members, so "recorded by" is always a member of the same
--     tenant, and a member with history can't be removed (deactivate
--     instead)
-- `on delete set null (col)` (Postgres 15+) nulls only the named column,
-- never tenant_id.

-- =========================================================================
-- Production + inventory
-- =========================================================================

create table production_runs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  date date not null,
  shift production_shift not null,
  machine text not null,
  operator_name text not null,
  product product_type not null,
  quantity_produced integer not null check (quantity_produced >= 0),
  wastage integer not null check (wastage >= 0),
  recorded_by uuid not null,
  recorded_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id)
);
create index production_runs_tenant_date_idx on production_runs (tenant_id, date desc);

create table stock_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null,
  category stock_category not null,
  unit text not null,
  quantity_on_hand integer not null default 0,
  reorder_level integer not null default 0,
  -- Links a finished-goods item to the product sales/load-outs/production
  -- deduct from or add to. At most one item per product per tenant.
  product_type product_type,
  unique (tenant_id, id)
);
create unique index stock_items_tenant_product_type_unique
  on stock_items (tenant_id, product_type)
  where product_type is not null;

create table production_recipes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  product product_type not null,
  raw_material_item_id uuid not null,
  -- "quantity_used [unit] makes per_bags bags", stored as typed.
  quantity_used numeric not null check (quantity_used > 0),
  per_bags integer not null check (per_bags > 0),
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, product, raw_material_item_id),
  foreign key (tenant_id, raw_material_item_id)
    references stock_items (tenant_id, id) on delete cascade
);

create table stock_batches (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  item_id uuid not null,
  received_at timestamptz not null default now(),
  expiry_date date,
  quantity_received integer not null check (quantity_received > 0),
  quantity_remaining integer not null check (
    quantity_remaining >= 0 and quantity_remaining <= quantity_received
  ),
  production_run_id uuid,
  note text,
  created_by uuid not null,
  unique (tenant_id, id),
  foreign key (tenant_id, item_id) references stock_items (tenant_id, id) on delete cascade,
  foreign key (tenant_id, production_run_id)
    references production_runs (tenant_id, id) on delete set null (production_run_id),
  foreign key (tenant_id, created_by) references tenant_members (tenant_id, user_id)
);
create index stock_batches_item_idx on stock_batches (tenant_id, item_id, received_at);
create index stock_batches_run_idx on stock_batches (tenant_id, production_run_id);

-- =========================================================================
-- Sales + debts
-- =========================================================================

create table sales (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  date_time timestamptz not null default now(),
  customer_type sales_customer_type not null,
  customer_name text, -- null for walk-in
  total numeric(12, 2) not null,
  amount_paid numeric(12, 2) not null,
  payment_method sales_payment_method not null,
  balance numeric(12, 2) not null default 0,
  recorded_by uuid not null,
  voided_at timestamptz,
  voided_by uuid,
  void_reason text,
  unique (tenant_id, id),
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id),
  foreign key (tenant_id, voided_by) references tenant_members (tenant_id, user_id)
);
create index sales_tenant_date_idx on sales (tenant_id, date_time desc);

create table sale_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  sale_id uuid not null,
  product product_type not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12, 2) not null,
  unique (tenant_id, id),
  foreign key (tenant_id, sale_id) references sales (tenant_id, id) on delete cascade
);
create index sale_lines_sale_idx on sale_lines (tenant_id, sale_id);

create table customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null,
  phone text not null,
  area text not null,
  credit_limit numeric(12, 2) not null default 0,
  balance numeric(12, 2) not null default 0,
  last_payment_date date,
  unique (tenant_id, id)
);
create index customers_tenant_name_idx on customers (tenant_id, name);

create table ledger_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  customer_id uuid not null,
  type ledger_entry_type not null,
  amount numeric(12, 2) not null,
  date date not null default current_date,
  note text,
  sale_id uuid,
  recorded_by uuid,
  unique (tenant_id, id),
  foreign key (tenant_id, customer_id) references customers (tenant_id, id) on delete cascade,
  foreign key (tenant_id, sale_id) references sales (tenant_id, id) on delete cascade,
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id)
);
create index ledger_entries_customer_idx on ledger_entries (tenant_id, customer_id, date);
create index ledger_entries_sale_idx on ledger_entries (tenant_id, sale_id);

-- =========================================================================
-- Finance + expenses
-- =========================================================================

create table cash_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  date_time timestamptz not null default now(),
  direction cash_direction not null,
  source cash_source not null,
  amount numeric(12, 2) not null,
  method payment_channel not null,
  note text,
  sale_id uuid,
  recorded_by uuid not null,
  unique (tenant_id, id),
  foreign key (tenant_id, sale_id) references sales (tenant_id, id) on delete cascade,
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id)
);
create index cash_entries_tenant_date_idx on cash_entries (tenant_id, date_time desc);
create index cash_entries_sale_idx on cash_entries (tenant_id, sale_id);

create table expenses (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  date date not null,
  category expense_category not null,
  description text not null,
  amount numeric(12, 2) not null,
  method payment_channel not null,
  recorded_by uuid not null,
  unique (tenant_id, id),
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id)
);
create index expenses_tenant_date_idx on expenses (tenant_id, date desc);

-- =========================================================================
-- Distribution
-- =========================================================================

create table drivers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null,
  phone text not null,
  unique (tenant_id, id)
);

create table vehicles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  name text not null,
  unique (tenant_id, id)
);

create table load_outs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  date_time timestamptz not null default now(),
  driver_id uuid not null,
  vehicle_id uuid not null,
  product product_type not null,
  bags_loaded integer not null check (bags_loaded > 0),
  status load_out_status not null default 'on_road',
  note text,
  bags_sold integer,
  bags_returned integer,
  bags_damaged integer,
  cash_returned numeric(12, 2),
  settled_at timestamptz,
  discrepancy_note text,
  sale_id uuid,
  recorded_by uuid,
  unique (tenant_id, id),
  foreign key (tenant_id, driver_id) references drivers (tenant_id, id),
  foreign key (tenant_id, vehicle_id) references vehicles (tenant_id, id),
  foreign key (tenant_id, sale_id) references sales (tenant_id, id) on delete set null (sale_id),
  foreign key (tenant_id, recorded_by) references tenant_members (tenant_id, user_id)
);
create index load_outs_tenant_date_idx on load_outs (tenant_id, date_time desc);

-- stock_movements comes last: it references items, batches, runs, sales.
create table stock_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  item_id uuid not null,
  type movement_type not null,
  quantity integer not null, -- signed: +in, -out
  note text,
  by_whom uuid not null,
  at timestamptz not null default now(),
  batch_id uuid,
  production_run_id uuid,
  sale_id uuid,
  unique (tenant_id, id),
  foreign key (tenant_id, item_id) references stock_items (tenant_id, id) on delete cascade,
  foreign key (tenant_id, batch_id) references stock_batches (tenant_id, id) on delete set null (batch_id),
  foreign key (tenant_id, production_run_id) references production_runs (tenant_id, id) on delete cascade,
  foreign key (tenant_id, sale_id) references sales (tenant_id, id) on delete cascade,
  foreign key (tenant_id, by_whom) references tenant_members (tenant_id, user_id)
);
create index stock_movements_item_idx on stock_movements (tenant_id, item_id, at desc);
create index stock_movements_run_idx on stock_movements (tenant_id, production_run_id);
create index stock_movements_sale_idx on stock_movements (tenant_id, sale_id);

-- =========================================================================
-- Staff audit log (membership changes within a tenant)
-- =========================================================================

create table staff_audit_log (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  actor_id uuid not null,
  target_id uuid not null,
  action text not null, -- 'added' | 'deactivated' | 'reactivated' | 'role_changed'
  detail text,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, actor_id) references tenant_members (tenant_id, user_id),
  foreign key (tenant_id, target_id) references tenant_members (tenant_id, user_id) on delete cascade
);
create index staff_audit_log_tenant_idx on staff_audit_log (tenant_id, created_at desc);
