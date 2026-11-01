-- HydroTrack — 0017: staff PIN reset by a code from an admin (agreed).
--
-- An Owner/Admin issues a one-time reset code for a staff member (like an
-- invite code). The staff member enters it on the sign-in screen with a
-- new PIN; the `reset-pin` Edge Function checks the code and sets the PIN.
-- Codes work once, for 2 days, and issuing a new one cancels the old.
-- Owners and others who sign in with email use "Forgot password" instead.
--
-- Resetting also removes the person's offline sign-in check, so their
-- old PIN stops working on offline devices once those sync.

create table pin_reset_codes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  user_id uuid not null,
  code text not null unique,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '2 days',
  used_at timestamptz,
  revoked_at timestamptz,
  unique (tenant_id, id),
  foreign key (tenant_id, user_id) references tenant_members (tenant_id, user_id) on delete cascade
);
create index pin_reset_codes_user_idx on pin_reset_codes (tenant_id, user_id);

-- No policies: only the functions below read or write it.
alter table pin_reset_codes enable row level security;

-- Owner/Admin: a reset code for a member who signs in with phone + PIN.
create function create_pin_reset(p_tenant_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  v_member tenant_members;
  v_phone text;
  v_code pin_reset_codes;
begin
  perform require_tenant_role(p_tenant_id, array['admin']::staff_role[], 'reset staff PINs');

  select * into v_member from tenant_members where tenant_id = p_tenant_id and user_id = p_user_id;
  if v_member.user_id is null then
    raise exception 'Staff member not found';
  end if;
  if v_member.role = 'owner' and not has_tenant_role(p_tenant_id, array['owner']::staff_role[]) then
    raise exception 'Only an owner can reset an owner''s PIN' using errcode = '42501';
  end if;
  select phone into v_phone from auth.users where id = p_user_id;
  if v_phone is null or v_phone = '' then
    raise exception 'This person signs in with email. They can use "Forgot password" on the sign-in screen.';
  end if;

  update pin_reset_codes set revoked_at = now()
  where tenant_id = p_tenant_id and user_id = p_user_id and used_at is null and revoked_at is null;

  insert into pin_reset_codes (tenant_id, user_id, code, created_by)
  values (p_tenant_id, p_user_id, generate_invite_code(), auth.uid())
  returning * into v_code;

  return jsonb_build_object('code', v_code.code, 'expires_at', v_code.expires_at);
end;
$$;

-- Edge Function only: who a valid code is for.
create function peek_pin_reset(p_code text)
returns jsonb
language plpgsql stable
security definer set search_path = public
as $$
declare
  v_code pin_reset_codes;
  v_phone text;
begin
  select * into v_code from pin_reset_codes where code = upper(btrim(p_code));
  if v_code.id is null or v_code.used_at is not null or v_code.revoked_at is not null
     or v_code.expires_at < now()
     or not exists (
       select 1 from tenant_members
       where tenant_id = v_code.tenant_id and user_id = v_code.user_id and is_active
     ) then
    raise exception 'This reset code is invalid or has expired. Ask your admin for a new one.';
  end if;
  select phone into v_phone from auth.users where id = v_code.user_id;
  return jsonb_build_object('user_id', v_code.user_id, 'phone', v_phone);
end;
$$;

-- Edge Function only, after the new PIN is set.
create function complete_pin_reset(p_code text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_user uuid;
begin
  update pin_reset_codes set used_at = now()
  where code = upper(btrim(p_code)) and used_at is null
  returning user_id into v_user;
  delete from offline_credentials where user_id = v_user;
end;
$$;

revoke all on function create_pin_reset(uuid, uuid) from public, anon;
grant execute on function create_pin_reset(uuid, uuid) to authenticated;
revoke all on function peek_pin_reset(text) from public, anon, authenticated;
revoke all on function complete_pin_reset(text) from public, anon, authenticated;
grant execute on function peek_pin_reset(text) to service_role;
grant execute on function complete_pin_reset(text) to service_role;
