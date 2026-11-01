-- HydroTrack — 0008: onboarding and member management.
--
-- create_tenant          any signed-in user creates an organization and
--                        becomes its owner; starter catalog seeded
-- create_invitation      owner/admin issues a single-use join code
-- revoke_invitation      owner/admin cancels an unused code
-- accept_invitation      a signed-in user (existing account) joins
-- redeem_invitation_for_new_user
--                        service role only — used by the accept-invite
--                        Edge Function after it creates a brand-new
--                        phone + PIN account for the invitee
-- update_member_role / set_member_active / remove_member
--                        roster management with owner safeguards

-- Nigerian phone numbers -> digits in international form (234XXXXXXXXXX),
-- matching how Supabase Auth stores auth.users.phone.
create function normalize_ng_phone(p_phone text)
returns text
language sql immutable
set search_path = ''
as $$
  select case
    when p_phone is null then null
    when regexp_replace(p_phone, '\D', '', 'g') like '0%'
      then '234' || substr(regexp_replace(p_phone, '\D', '', 'g'), 2)
    else regexp_replace(p_phone, '\D', '', 'g')
  end;
$$;

-- =========================================================================
-- Create organization
-- =========================================================================

create function create_tenant(p_name text)
returns tenants
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tenant tenants;
  v_slug text;
begin
  if v_uid is null then
    raise exception 'Sign in to create an organization' using errcode = '42501';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'Organization name is required';
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(btrim(p_name)), '[^a-z0-9]+', '-', 'g'));
  v_slug := left(coalesce(nullif(v_slug, ''), 'org'), 40) || '-' || substr(md5(gen_random_uuid()::text), 1, 6);

  insert into tenants (name, slug, created_by)
  values (btrim(p_name), v_slug, v_uid)
  returning * into v_tenant;

  insert into tenant_members (tenant_id, user_id, role)
  values (v_tenant.id, v_uid, 'owner');

  -- Starter catalog: one finished-goods item per product, linked so that
  -- production adds to it and sales/load-outs deduct from it. Raw
  -- materials are added by each organization itself.
  insert into stock_items (tenant_id, name, category, unit, product_type)
  values
    (v_tenant.id, '50cl Sachet', 'finished_goods', 'bags', 'sachet50cl'),
    (v_tenant.id, '75cl Bottle', 'finished_goods', 'packs', 'bottle75cl'),
    (v_tenant.id, '1.5L Bottle', 'finished_goods', 'packs', 'bottle1_5l'),
    (v_tenant.id, '5L Bottle', 'finished_goods', 'bottles', 'bottle5l');

  return v_tenant;
end;
$$;

-- =========================================================================
-- Invitations
-- =========================================================================

create function generate_invite_code()
returns text
language plpgsql volatile
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes bytea := extensions.gen_random_bytes(10);
  v_code text := '';
  i integer;
begin
  for i in 0..9 loop
    v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % length(v_alphabet)) + 1, 1);
  end loop;
  return v_code;
end;
$$;

create function create_invitation(
  p_tenant_id uuid,
  p_full_name text,
  p_phone text,
  p_email text,
  p_role staff_role
)
returns tenant_invitations
language plpgsql
security definer set search_path = public
as $$
declare
  v_invitation tenant_invitations;
  v_code text;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'invite members');
  if p_role = 'owner' then
    raise exception 'Invite as Admin, then an owner can promote them to Owner';
  end if;
  if p_full_name is null or btrim(p_full_name) = '' then
    raise exception 'Name is required';
  end if;
  if nullif(btrim(p_phone), '') is null and nullif(btrim(p_email), '') is null then
    raise exception 'A phone number or email is required';
  end if;

  loop
    v_code := generate_invite_code();
    exit when not exists (select 1 from tenant_invitations where code = v_code);
  end loop;

  insert into tenant_invitations (tenant_id, code, full_name, phone, email, role, created_by)
  values (p_tenant_id, v_code, btrim(p_full_name), nullif(btrim(p_phone), ''),
          lower(nullif(btrim(p_email), '')), p_role, auth.uid())
  returning * into v_invitation;

  return v_invitation;
end;
$$;

create function revoke_invitation(p_tenant_id uuid, p_invitation_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'revoke invitations');

  update tenant_invitations set revoked_at = now()
  where tenant_id = p_tenant_id and id = p_invitation_id
    and accepted_at is null and revoked_at is null;
  if not found then
    raise exception 'Invitation not found, or already used or revoked';
  end if;
end;
$$;

-- Locks and returns a usable invitation, or raises. One generic message
-- for every failure, so a guessed code reveals nothing.
create function claim_invitation(p_code text)
returns tenant_invitations
language plpgsql
security definer set search_path = public
as $$
declare
  v_invitation tenant_invitations;
begin
  select * into v_invitation from tenant_invitations
  where code = upper(btrim(p_code))
  for update;

  if v_invitation.id is null
     or v_invitation.accepted_at is not null
     or v_invitation.revoked_at is not null
     or v_invitation.expires_at < now() then
    raise exception 'This invite code is invalid or has expired. Ask your admin for a new one.';
  end if;
  return v_invitation;
end;
$$;

create function complete_invitation(p_invitation tenant_invitations, p_user_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
begin
  if exists (
    select 1 from tenant_members
    where tenant_id = p_invitation.tenant_id and user_id = p_user_id
  ) then
    raise exception 'You are already a member of this organization';
  end if;

  insert into tenant_members (tenant_id, user_id, role, invited_by)
  values (p_invitation.tenant_id, p_user_id, p_invitation.role, p_invitation.created_by);

  update tenant_invitations
  set accepted_by = p_user_id, accepted_at = now()
  where id = p_invitation.id;

  return p_invitation.tenant_id;
end;
$$;

-- Existing account joins. The invite is addressed to a phone and/or
-- email; the signed-in account must match one of them, so a leaked code
-- can't be redeemed by a stranger's account.
create function accept_invitation(p_code text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_invitation tenant_invitations;
  v_user record;
begin
  if v_uid is null then
    raise exception 'Sign in to join an organization' using errcode = '42501';
  end if;

  v_invitation := claim_invitation(p_code);

  select phone, lower(email) as email into v_user from auth.users where id = v_uid;
  if not (
    (v_invitation.phone is not null and normalize_ng_phone(v_invitation.phone) = normalize_ng_phone(v_user.phone))
    or (v_invitation.email is not null and v_invitation.email = v_user.email)
  ) then
    raise exception 'This invite was sent to a different phone number or email.';
  end if;

  return complete_invitation(v_invitation, v_uid);
end;
$$;

-- Service role only (accept-invite Edge Function). Returns the
-- invitation so the function can create the account it describes.
create function peek_invitation(p_code text)
returns tenant_invitations
language plpgsql
security definer set search_path = public
as $$
declare
  v_invitation tenant_invitations;
begin
  select * into v_invitation from tenant_invitations where code = upper(btrim(p_code));
  if v_invitation.id is null
     or v_invitation.accepted_at is not null
     or v_invitation.revoked_at is not null
     or v_invitation.expires_at < now() then
    raise exception 'This invite code is invalid or has expired. Ask your admin for a new one.';
  end if;
  return v_invitation;
end;
$$;

create function redeem_invitation_for_new_user(p_code text, p_user_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
begin
  return complete_invitation(claim_invitation(p_code), p_user_id);
end;
$$;

-- =========================================================================
-- Member management
-- =========================================================================

-- Locks the tenant row (serialises concurrent roster changes) and checks
-- the caller may act on p_user_id.
create function guard_member_change(p_tenant_id uuid, p_user_id uuid, p_action text)
returns tenant_members
language plpgsql
security definer set search_path = public
as $$
declare
  v_target tenant_members;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], p_action);
  perform 1 from tenants where id = p_tenant_id for update;

  select * into v_target from tenant_members
  where tenant_id = p_tenant_id and user_id = p_user_id for update;
  if v_target.user_id is null then
    raise exception 'Member not found';
  end if;
  if v_target.role = 'owner' and not has_tenant_role(p_tenant_id, array['owner']::staff_role[]) then
    raise exception 'Only an owner can change another owner';
  end if;
  return v_target;
end;
$$;

create function active_owner_count(p_tenant_id uuid)
returns integer
language sql stable
security definer set search_path = public
as $$
  select count(*)::integer from tenant_members
  where tenant_id = p_tenant_id and role = 'owner' and is_active;
$$;

create function update_member_role(p_tenant_id uuid, p_user_id uuid, p_role staff_role)
returns tenant_members
language plpgsql
security definer set search_path = public
as $$
declare
  v_target tenant_members;
begin
  v_target := guard_member_change(p_tenant_id, p_user_id, 'change roles');

  if p_role = 'owner' and not has_tenant_role(p_tenant_id, array['owner']::staff_role[]) then
    raise exception 'Only an owner can make someone an owner';
  end if;
  if v_target.role = 'owner' and p_role <> 'owner' and v_target.is_active
     and active_owner_count(p_tenant_id) <= 1 then
    raise exception 'An organization needs at least one owner. Make someone else an owner first.';
  end if;

  update tenant_members set role = p_role
  where tenant_id = p_tenant_id and user_id = p_user_id
  returning * into v_target;
  return v_target;
end;
$$;

create function set_member_active(p_tenant_id uuid, p_user_id uuid, p_active boolean)
returns tenant_members
language plpgsql
security definer set search_path = public
as $$
declare
  v_target tenant_members;
begin
  v_target := guard_member_change(p_tenant_id, p_user_id,
    case when p_active then 'reactivate members' else 'deactivate members' end);

  if not p_active and p_user_id = auth.uid() then
    raise exception 'You can''t deactivate your own account';
  end if;
  if not p_active and v_target.role = 'owner' and active_owner_count(p_tenant_id) <= 1 then
    raise exception 'An organization needs at least one active owner.';
  end if;

  update tenant_members set is_active = p_active
  where tenant_id = p_tenant_id and user_id = p_user_id
  returning * into v_target;
  return v_target;
end;
$$;

-- Removes the membership only (the person's account remains, and they
-- keep any other organizations). Members with history are deactivated
-- instead, so records keep pointing at a real member.
create function remove_member(p_tenant_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_target tenant_members;
begin
  v_target := guard_member_change(p_tenant_id, p_user_id, 'remove members');

  if p_user_id = auth.uid() then
    raise exception 'You can''t remove your own account';
  end if;
  if v_target.role = 'owner' and active_owner_count(p_tenant_id) <= 1 then
    raise exception 'An organization needs at least one active owner.';
  end if;
  if member_has_history(p_tenant_id, p_user_id) then
    raise exception 'This person has recorded activity and can''t be removed. Deactivate them instead.';
  end if;

  delete from tenant_members where tenant_id = p_tenant_id and user_id = p_user_id;
end;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

revoke execute on function generate_invite_code() from public, anon, authenticated;
revoke execute on function claim_invitation(text) from public, anon, authenticated;
revoke execute on function complete_invitation(tenant_invitations, uuid) from public, anon, authenticated;
revoke execute on function guard_member_change(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function active_owner_count(uuid) from public, anon, authenticated;

-- Edge Function only.
revoke execute on function peek_invitation(text) from public, anon, authenticated;
revoke execute on function redeem_invitation_for_new_user(text, uuid) from public, anon, authenticated;
grant execute on function peek_invitation(text) to service_role;
grant execute on function redeem_invitation_for_new_user(text, uuid) to service_role;

do $$
declare
  f text;
begin
  foreach f in array array[
    'create_tenant(text)',
    'create_invitation(uuid, text, text, text, staff_role)',
    'revoke_invitation(uuid, uuid)',
    'accept_invitation(text)',
    'update_member_role(uuid, uuid, staff_role)',
    'set_member_active(uuid, uuid, boolean)',
    'remove_member(uuid, uuid)'
  ]
  loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
