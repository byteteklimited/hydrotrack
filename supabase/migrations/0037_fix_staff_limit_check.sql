-- HydroTrack — 0037: enforce_staff_limit (0036) read new.is_active on
-- invitations too, which have no such column, so every new invitation
-- failed. Members are now checked in their own branch.

create or replace function enforce_staff_limit()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_plan plans;
  v_used integer;
begin
  if tg_table_name = 'tenant_members' then
    -- Only a member becoming active staff takes a new place.
    if not (new.is_active and new.role <> 'owner')
       or (old.is_active and old.role <> 'owner') then
      return new;
    end if;
  end if;
  v_plan := tenant_plan(new.tenant_id);
  if v_plan.max_staff is null then
    return new;
  end if;
  v_used := staff_in_use(new.tenant_id);
  if v_used >= v_plan.max_staff then
    raise exception
      'The % plan allows up to % staff (owners not counted), and this organization already has % including open invites. Choose a bigger plan under Organization → Subscription, or deactivate someone or revoke an invite first.',
      v_plan.name, v_plan.max_staff, v_used
      using errcode = 'P0001', hint = 'plan_limit';
  end if;
  return new;
end;
$$;

revoke all on function enforce_staff_limit() from public, anon, authenticated;
