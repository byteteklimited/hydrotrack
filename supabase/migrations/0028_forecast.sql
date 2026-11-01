-- HydroTrack — 0028: forecasting — when stock runs out (Phase D part 4,
-- agreed rules).
--
-- For every raw material and product: use over the last 30 days (sales,
-- load-outs and production use; stock-count corrections are left out)
-- gives a daily rate, and on-hand ÷ rate gives the days left. Items with
-- under 30 days of history are averaged over the days since their first
-- movement. The owner is alerted when an item will run out within 7 days
-- (at most once a week per item), unless it's already at its reorder
-- level — that has its own low-stock alert.

create function stock_runout(si stock_items, p_now timestamptz default now())
returns table (used numeric, per_day numeric, days_left numeric)
language sql stable
security definer set search_path = public
as $$
  with usage as (
    select coalesce(-sum(m.quantity) filter (
             where m.type in ('stock_out', 'production_use') and m.quantity < 0
               and m.at >= p_now - interval '30 days' and m.at <= p_now), 0)::numeric as used,
      least(30, greatest(1, extract(epoch from p_now - min(m.at)) / 86400))::numeric as days
    from stock_movements m
    where m.tenant_id = si.tenant_id and m.item_id = si.id and m.at <= p_now
  )
  select u.used,
    case when u.used > 0 then u.used / u.days end,
    case when u.used > 0 then greatest(si.quantity_on_hand, 0) / (u.used / u.days) end
  from usage u;
$$;

-- For the app: every item's rate and days left.
create function stock_forecast(p_tenant_id uuid)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
begin
  if not is_tenant_member(p_tenant_id) then
    raise exception 'Not authorized to view stock forecasts' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'item_id', si.id,
      'used_30_days', f.used,
      'per_day', round(f.per_day, 2),
      'days_left', round(f.days_left, 1)))
    from stock_items si
    cross join lateral stock_runout(si) f
    where si.tenant_id = p_tenant_id
  ), '[]'::jsonb);
end;
$$;

alter table alerts
  drop constraint alerts_kind_check,
  add constraint alerts_kind_check
    check (kind in ('daily_summary', 'low_stock', 'water_test', 'permit_expiry', 'maintenance_due', 'stock_runout'));

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
    'Low stock: ' || si.name,
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
    'Running out: ' || si.name,
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

revoke all on function stock_runout(stock_items, timestamptz) from public, anon, authenticated;
revoke all on function stock_forecast(uuid) from public, anon;
grant execute on function stock_forecast(uuid) to authenticated;
