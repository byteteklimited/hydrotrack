-- HydroTrack — 0005: internal stock helpers (FIFO batches).
--
-- Only ever called from inside the RPCs in 0006. EXECUTE is revoked from
-- every client role, so nobody can call these directly over the API (the
-- single-tenant original left them callable — closed here).
--
-- Both keep stock_items.quantity_on_hand, stock_batches and
-- stock_movements in step, always within one tenant.

-- The finished-goods catalog item a product deducts from / adds to, or
-- null if the tenant hasn't linked one (then nothing is deducted).
create function finished_item_for(p_tenant_id uuid, p_product product_type)
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from stock_items
  where tenant_id = p_tenant_id and product_type = p_product
  limit 1;
$$;

-- Takes p_quantity off an item's oldest batches first, one movement row
-- per batch touched, plus a batch-less row for any remainder not covered
-- by tracked batches. Never blocks — callers do their own stock checks.
create function consume_stock_fifo(
  p_tenant_id uuid,
  p_item_id uuid,
  p_quantity integer,
  p_movement_type movement_type,
  p_note text,
  p_by_whom uuid,
  p_production_run_id uuid default null,
  p_sale_id uuid default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_remaining integer := p_quantity;
  v_batch record;
  v_take integer;
begin
  if p_quantity <= 0 then
    return;
  end if;

  for v_batch in
    select * from stock_batches
    where tenant_id = p_tenant_id and item_id = p_item_id and quantity_remaining > 0
    order by received_at asc
    for update
  loop
    exit when v_remaining <= 0;
    v_take := least(v_remaining, v_batch.quantity_remaining);

    update stock_batches set quantity_remaining = quantity_remaining - v_take
    where tenant_id = p_tenant_id and id = v_batch.id;

    insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, production_run_id, batch_id, sale_id)
    values (p_tenant_id, p_item_id, p_movement_type, -v_take, p_note, p_by_whom, p_production_run_id, v_batch.id, p_sale_id);

    v_remaining := v_remaining - v_take;
  end loop;

  if v_remaining > 0 then
    insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, production_run_id, batch_id, sale_id)
    values (p_tenant_id, p_item_id, p_movement_type, -v_remaining, p_note, p_by_whom, p_production_run_id, null, p_sale_id);
  end if;

  update stock_items set quantity_on_hand = quantity_on_hand - p_quantity
  where tenant_id = p_tenant_id and id = p_item_id;
end;
$$;

-- Adds one new batch (optional expiry) and its movement row.
create function add_stock_batch(
  p_tenant_id uuid,
  p_item_id uuid,
  p_quantity integer,
  p_expiry_date date,
  p_movement_type movement_type,
  p_note text,
  p_by_whom uuid,
  p_production_run_id uuid default null,
  p_sale_id uuid default null
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_batch_id uuid;
begin
  if p_quantity <= 0 then
    return null;
  end if;

  insert into stock_batches (tenant_id, item_id, expiry_date, quantity_received, quantity_remaining, production_run_id, note, created_by)
  values (p_tenant_id, p_item_id, p_expiry_date, p_quantity, p_quantity, p_production_run_id, p_note, p_by_whom)
  returning id into v_batch_id;

  insert into stock_movements (tenant_id, item_id, type, quantity, note, by_whom, production_run_id, batch_id, sale_id)
  values (p_tenant_id, p_item_id, p_movement_type, p_quantity, p_note, p_by_whom, p_production_run_id, v_batch_id, p_sale_id);

  update stock_items set quantity_on_hand = quantity_on_hand + p_quantity
  where tenant_id = p_tenant_id and id = p_item_id;

  return v_batch_id;
end;
$$;

revoke execute on function finished_item_for(uuid, product_type) from public, anon, authenticated;
revoke execute on function consume_stock_fifo(uuid, uuid, integer, movement_type, text, uuid, uuid, uuid)
  from public, anon, authenticated;
revoke execute on function add_stock_batch(uuid, uuid, integer, date, movement_type, text, uuid, uuid, uuid)
  from public, anon, authenticated;
