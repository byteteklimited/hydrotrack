-- HydroTrack — 0030: require_own_location read stock_items' quantity on
-- every table (PL/pgSQL doesn't short-circuit field lookups); check the
-- table first.
create or replace function require_own_location()
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
  if tg_table_name = 'stock_items' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    if (to_jsonb(new) ->> 'quantity_on_hand') is not distinct from (to_jsonb(old) ->> 'quantity_on_hand') then
      return new;
    end if;
  end if;
  v_here := resolve_location(old.tenant_id);
  if v_here is distinct from old.location_id then
    raise exception 'This belongs to %. Switch to % to change it.', location_name(old.location_id), location_name(old.location_id);
  end if;
  return coalesce(new, old);
end;
$$;
