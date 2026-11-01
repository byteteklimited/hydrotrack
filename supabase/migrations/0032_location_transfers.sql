-- HydroTrack — 0032: the transfers screen. Transfers into or out of the
-- request's location (any not yet received, and the last 60 days), with
-- item and location names — the receiving end can't read the sender's
-- stock rows, so names come from here.
create function location_transfers(p_tenant_id uuid)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_here uuid := resolve_location(p_tenant_id);
begin
  if not is_tenant_member(p_tenant_id) or not can_use_location(p_tenant_id, v_here) then
    raise exception 'Not authorized to view transfers' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', t.id,
      'from_location', location_name(t.from_location_id),
      'to_location', location_name(t.to_location_id),
      'incoming', t.to_location_id = v_here,
      'status', t.status,
      'note', t.note,
      'sent_at', t.sent_at,
      'received_at', t.received_at,
      'sent_by', (select full_name from profiles where id = t.sent_by),
      'items', (select jsonb_agg(jsonb_build_object('name', x.name, 'unit', x.unit, 'quantity', x.quantity) order by x.name)
                from (select si.name, si.unit, sum(l.quantity)::integer as quantity
                      from stock_transfer_lines l join stock_items si on si.id = l.item_id
                      where l.tenant_id = t.tenant_id and l.transfer_id = t.id
                      group by si.name, si.unit) x)
    ) order by t.status = 'sent' desc, t.sent_at desc)
    from stock_transfers t
    where t.tenant_id = p_tenant_id
      and v_here in (t.from_location_id, t.to_location_id)
      and (t.status = 'sent' or t.sent_at > now() - interval '60 days')
  ), '[]'::jsonb);
end;
$$;

revoke all on function location_transfers(uuid) from public, anon;
grant execute on function location_transfers(uuid) to authenticated;
