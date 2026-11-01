-- HydroTrack — 0007: staff audit log trigger, history check, audit_trail.

-- Membership changes -> staff_audit_log, per tenant. Covers joining
-- (insert), role changes and deactivate/reactivate (update). The actor is
-- the signed-in user, or for rows written by the accept-invite Edge
-- Function (service role, no auth.uid()) the admin who issued the invite.
create function log_member_change()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_actor uuid := coalesce(auth.uid(), new.invited_by, new.user_id);
begin
  -- The actor must be a member of this tenant (FK); fall back to the
  -- member themself if not (e.g. an owner creating their own tenant).
  if not exists (select 1 from tenant_members where tenant_id = new.tenant_id and user_id = v_actor) then
    v_actor := new.user_id;
  end if;

  if tg_op = 'INSERT' then
    insert into staff_audit_log (tenant_id, actor_id, target_id, action, detail)
    values (new.tenant_id, v_actor, new.user_id, 'added', new.role::text);
    return new;
  end if;

  if new.is_active is distinct from old.is_active then
    insert into staff_audit_log (tenant_id, actor_id, target_id, action)
    values (new.tenant_id, v_actor, new.user_id, case when new.is_active then 'reactivated' else 'deactivated' end);
  end if;
  if new.role is distinct from old.role then
    insert into staff_audit_log (tenant_id, actor_id, target_id, action, detail)
    values (new.tenant_id, v_actor, new.user_id, 'role_changed', old.role::text || ' -> ' || new.role::text);
  end if;
  return new;
end;
$$;

create trigger on_tenant_member_change
  after insert or update on tenant_members
  for each row execute function log_member_change();

revoke execute on function log_member_change() from public, anon, authenticated;

-- Whether a member has recorded anything in this tenant (then they can
-- only be deactivated, not removed). The composite FKs enforce this too;
-- this gives the UI a clear answer up front.
create function member_has_history(p_tenant_id uuid, p_user_id uuid)
returns boolean
language sql stable
security definer set search_path = public
as $$
  select
    exists (select 1 from cash_entries where tenant_id = p_tenant_id and recorded_by = p_user_id)
    or exists (select 1 from expenses where tenant_id = p_tenant_id and recorded_by = p_user_id)
    or exists (select 1 from ledger_entries where tenant_id = p_tenant_id and recorded_by = p_user_id)
    or exists (select 1 from load_outs where tenant_id = p_tenant_id and recorded_by = p_user_id)
    or exists (select 1 from production_runs where tenant_id = p_tenant_id and recorded_by = p_user_id)
    or exists (select 1 from sales where tenant_id = p_tenant_id and (recorded_by = p_user_id or voided_by = p_user_id))
    or exists (select 1 from stock_batches where tenant_id = p_tenant_id and created_by = p_user_id)
    or exists (select 1 from stock_movements where tenant_id = p_tenant_id and by_whom = p_user_id)
    or exists (
      select 1 from staff_audit_log
      where tenant_id = p_tenant_id and actor_id = p_user_id and target_id <> p_user_id
    );
$$;

revoke execute on function member_has_history(uuid, uuid) from public, anon;
grant execute on function member_has_history(uuid, uuid) to authenticated;

-- One read-only feed of "who did what, when" across every feature.
-- security_invoker: runs with the caller's RLS, so it only ever returns
-- rows from tenants the caller is an active member of. Filter by
-- tenant_id for the current tenant.
create view audit_trail with (security_invoker = true) as
  select pr.id, pr.tenant_id, p.full_name as staff_name, m.role,
    'production'::text as category,
    'Logged production run — ' || pr.machine || ', ' ||
      pr.shift::text || ' shift, ' || pr.quantity_produced || ' bags' ||
      case when pr.wastage > 0 then ' (' || pr.wastage || ' wasted)' else '' end
      as description,
    pr.recorded_at as at
  from production_runs pr
  join tenant_members m on m.tenant_id = pr.tenant_id and m.user_id = pr.recorded_by
  join profiles p on p.id = pr.recorded_by

  union all

  select sm.id, sm.tenant_id, p.full_name, m.role, 'inventory'::text,
    (case when sm.quantity >= 0 then 'Added ' else 'Removed ' end) ||
      abs(sm.quantity) || ' ' || si.unit || ' of ' || si.name,
    sm.at
  from stock_movements sm
  join stock_items si on si.tenant_id = sm.tenant_id and si.id = sm.item_id
  join tenant_members m on m.tenant_id = sm.tenant_id and m.user_id = sm.by_whom
  join profiles p on p.id = sm.by_whom

  union all

  select s.id, s.tenant_id, p.full_name, m.role, 'sales'::text,
    'Recorded sale of ' ||
      (select coalesce(sum(sl.quantity), 0) from sale_lines sl
       where sl.tenant_id = s.tenant_id and sl.sale_id = s.id) ||
      ' bags to ' || coalesce(s.customer_name, 'walk-in customer') ||
      ' — ₦' || to_char(s.total, 'FM999,999,999'),
    s.date_time
  from sales s
  join tenant_members m on m.tenant_id = s.tenant_id and m.user_id = s.recorded_by
  join profiles p on p.id = s.recorded_by

  union all

  select le.id, le.tenant_id, p.full_name, m.role, 'debts'::text,
    'Recorded payment of ₦' || to_char(le.amount, 'FM999,999,999') || ' from ' || c.name,
    le.date::timestamptz
  from ledger_entries le
  join customers c on c.tenant_id = le.tenant_id and c.id = le.customer_id
  join tenant_members m on m.tenant_id = le.tenant_id and m.user_id = le.recorded_by
  join profiles p on p.id = le.recorded_by
  where le.type = 'payment'

  union all

  select lo.id, lo.tenant_id, p.full_name, m.role, 'distribution'::text,
    'Recorded load-out for driver ' || d.name || ' — ' || lo.bags_loaded || ' bags',
    lo.date_time
  from load_outs lo
  join drivers d on d.tenant_id = lo.tenant_id and d.id = lo.driver_id
  join tenant_members m on m.tenant_id = lo.tenant_id and m.user_id = lo.recorded_by
  join profiles p on p.id = lo.recorded_by

  union all

  select e.id, e.tenant_id, p.full_name, m.role, 'expenses'::text,
    'Recorded expense — ' || e.description || ', ₦' || to_char(e.amount, 'FM999,999,999'),
    e.date::timestamptz
  from expenses e
  join tenant_members m on m.tenant_id = e.tenant_id and m.user_id = e.recorded_by
  join profiles p on p.id = e.recorded_by

  union all

  select sal.id, sal.tenant_id, actor.full_name, am.role, 'staff'::text,
    case sal.action
      when 'deactivated' then 'Deactivated staff account — ' || target.full_name
      when 'reactivated' then 'Reactivated staff account — ' || target.full_name
      when 'role_changed' then 'Changed role for ' || target.full_name || ' (' || sal.detail || ')'
      when 'added' then 'Added staff account — ' || target.full_name
      else sal.action
    end,
    sal.created_at
  from staff_audit_log sal
  join tenant_members am on am.tenant_id = sal.tenant_id and am.user_id = sal.actor_id
  join profiles actor on actor.id = sal.actor_id
  join profiles target on target.id = sal.target_id;

revoke all on audit_trail from anon;
grant select on audit_trail to authenticated;
