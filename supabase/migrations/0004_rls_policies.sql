-- HydroTrack — 0004: row level security for every business table.
--
-- Reads: any active member of the row's tenant (every role sees the
-- dashboard, which draws on every feature — same as the original app).
-- Writes: only the handful of tables the app writes to directly get an
-- insert/update/delete policy, with the same role rules as the original
-- app, now per tenant. Everything else is written only by the
-- security-definer RPCs in 0005/0006, which check tenant + role
-- themselves. A table with no write policy cannot be written by
-- `authenticated` at all.
--
-- Owners pass every has_tenant_role() check (see 0002).

do $$
declare
  t text;
begin
  foreach t in array array[
    'production_runs', 'stock_items', 'production_recipes', 'stock_batches',
    'stock_movements', 'sales', 'sale_lines', 'customers', 'ledger_entries',
    'cash_entries', 'expenses', 'drivers', 'vehicles', 'load_outs',
    'staff_audit_log'
  ]
  loop
    execute format('alter table %I enable row level security', t);
    execute format(
      'create policy %I on %I for select to authenticated using (is_tenant_member(tenant_id))',
      t || '_select_member', t
    );
  end loop;
end;
$$;

-- stock_items: Admin/Manager add catalog items directly. Quantity only
-- ever changes through the stock RPCs, so new items must start at zero.
create policy stock_items_insert on stock_items
  for insert to authenticated
  with check (
    has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[])
    and quantity_on_hand = 0
  );

-- production_recipes: Admin/Manager manage the bill of materials.
create policy production_recipes_insert on production_recipes
  for insert to authenticated
  with check (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]));
create policy production_recipes_update on production_recipes
  for update to authenticated
  using (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]))
  with check (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]));
create policy production_recipes_delete on production_recipes
  for delete to authenticated
  using (has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[]));

-- customers: Admin/Manager/Cashier add customers. Balances and credit
-- limits only change through RPCs, so a new customer starts at zero.
create policy customers_insert on customers
  for insert to authenticated
  with check (
    has_tenant_role(tenant_id, array['admin', 'manager', 'cashier']::staff_role[])
    and balance = 0
  );

-- cash_entries: Admin/Manager record manual entries, stamped as themselves.
create policy cash_entries_insert on cash_entries
  for insert to authenticated
  with check (
    has_tenant_role(tenant_id, array['admin', 'manager']::staff_role[])
    and recorded_by = (select auth.uid())
    and sale_id is null
  );

-- drivers / vehicles: Admin/Manager/Store Keeper add them.
create policy drivers_insert on drivers
  for insert to authenticated
  with check (has_tenant_role(tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[]));
create policy vehicles_insert on vehicles
  for insert to authenticated
  with check (has_tenant_role(tenant_id, array['admin', 'manager', 'store_keeper']::staff_role[]));
