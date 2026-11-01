-- HydroTrack — 0019: all-time totals computed on the server.
--
-- Lists now load a day / month / recent window instead of whole tables
-- (PostgREST returns at most 1,000 rows per request, so whole-table reads
-- silently stopped at 1,000). All-time figures for Home are summed here.

create function totals_for_tenant(p_tenant_id uuid)
returns jsonb
language sql stable
security definer set search_path = public
as $$
  select jsonb_build_object(
    'total_bags_produced',
    coalesce((select sum(quantity_produced) from production_runs where tenant_id = p_tenant_id), 0),
    'total_revenue',
    coalesce((select sum(total) from sales where tenant_id = p_tenant_id and voided_at is null), 0)
  );
$$;

-- Members: bags ever produced and revenue from sales not voided.
create function organization_totals(p_tenant_id uuid)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
begin
  if not is_tenant_member(p_tenant_id) then
    raise exception 'Not a member of this organization' using errcode = '42501';
  end if;
  return totals_for_tenant(p_tenant_id);
end;
$$;

-- device-sync: the same, for a set-up device.
create function device_totals(p_device_key text)
returns jsonb
language sql stable
security definer set search_path = public
as $$
  select totals_for_tenant((device_for_key(p_device_key)).tenant_id);
$$;

revoke all on function totals_for_tenant(uuid) from public, anon, authenticated;
revoke all on function organization_totals(uuid) from public, anon;
grant execute on function organization_totals(uuid) to authenticated;
revoke all on function device_totals(text) from public, anon, authenticated;
grant execute on function device_totals(text) to service_role;
