-- HydroTrack — 0002: tenancy core.
--
-- tenants            one row per organization (a water factory business)
-- profiles           global identity, one row per auth.users row
-- tenant_members     who belongs to which tenant, with a per-tenant role
-- tenant_invitations single-use codes an admin issues to add someone
--
-- Isolation model: the "current tenant" is client state. Every query and
-- RPC names the tenant explicitly, and RLS checks the caller is an
-- active member of that tenant (is_tenant_member / has_tenant_role
-- below). No JWT custom claims, so a removed or deactivated member loses
-- access immediately, and switching tenants needs no token refresh.

-- =========================================================================
-- Tables
-- =========================================================================

create table tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  slug text not null unique,
  -- Storage path inside the private `tenant-files` bucket, always
  -- prefixed with this tenant's id (see 0009_storage.sql).
  logo_path text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  phone text,
  email text,
  created_at timestamptz not null default now()
);

create table tenant_members (
  tenant_id uuid not null references tenants (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  role staff_role not null,
  is_active boolean not null default true,
  invited_by uuid references profiles (id) on delete set null,
  joined_at timestamptz not null default now(),
  primary key (tenant_id, user_id)
);

create index tenant_members_user_idx on tenant_members (user_id);

create table tenant_invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants (id) on delete cascade,
  -- 10 characters from a 31-symbol alphabet with no look-alikes
  -- (≈ 49 bits). Single use, expires, and can be revoked.
  code text not null unique,
  full_name text not null,
  phone text,  -- local Nigerian format, as typed (e.g. 08031234567)
  email text,
  role staff_role not null check (role <> 'owner'),
  created_by uuid not null references profiles (id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_by uuid references profiles (id),
  accepted_at timestamptz,
  revoked_at timestamptz,
  check (phone is not null or email is not null)
);

create index tenant_invitations_tenant_idx on tenant_invitations (tenant_id);

-- =========================================================================
-- Helpers used by every RLS policy and RPC.
-- security definer so they can read tenant_members without recursing
-- through tenant_members' own RLS. Empty search_path = no hijacking.
-- =========================================================================

create function is_tenant_member(p_tenant_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.tenant_members
    where tenant_id = p_tenant_id
      and user_id = (select auth.uid())
      and is_active
  );
$$;

-- True when the caller is an active member of the tenant with one of
-- p_roles. Owners pass every role check.
create function has_tenant_role(p_tenant_id uuid, p_roles public.staff_role[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.tenant_members
    where tenant_id = p_tenant_id
      and user_id = (select auth.uid())
      and is_active
      and (role = 'owner' or role = any (p_roles))
  );
$$;

-- Raising version for use at the top of RPCs.
create function require_tenant_role(p_tenant_id uuid, p_roles public.staff_role[], p_action text)
returns void
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_tenant_id is null or not public.has_tenant_role(p_tenant_id, p_roles) then
    raise exception 'Not authorized to %', p_action using errcode = '42501';
  end if;
end;
$$;

-- True when the caller and p_user_id share at least one tenant (so the
-- caller may see that person's name/phone, e.g. on "recorded by").
create function shares_tenant_with(p_user_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.tenant_members mine
    join public.tenant_members theirs on theirs.tenant_id = mine.tenant_id
    where mine.user_id = (select auth.uid())
      and mine.is_active
      and theirs.user_id = p_user_id
  );
$$;

grant execute on function is_tenant_member(uuid) to authenticated;
grant execute on function has_tenant_role(uuid, staff_role[]) to authenticated;
grant execute on function shares_tenant_with(uuid) to authenticated;
revoke execute on function require_tenant_role(uuid, staff_role[], text) from public, anon, authenticated;

-- =========================================================================
-- New auth user -> profile. Only identity fields are copied; nothing in
-- user-editable metadata can grant a role (roles live in tenant_members).
-- =========================================================================

create function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, phone, email)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), new.email, new.phone, 'New user'),
    coalesce(new.raw_user_meta_data ->> 'phone', new.phone),
    new.email
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- =========================================================================
-- RLS
-- =========================================================================

alter table tenants enable row level security;
alter table profiles enable row level security;
alter table tenant_members enable row level security;
alter table tenant_invitations enable row level security;

-- tenants: members read; owner/admin rename / change logo. Creating a
-- tenant goes through create_tenant() so the creator becomes its owner
-- atomically.
create policy tenants_select on tenants
  for select to authenticated using (is_tenant_member(id));
create policy tenants_update on tenants
  for update to authenticated
  using (has_tenant_role(id, array['admin']::staff_role[]))
  with check (has_tenant_role(id, array['admin']::staff_role[]));

-- profiles: yourself, or anyone you share a tenant with. You may edit
-- your own name only (phone/email follow auth).
create policy profiles_select on profiles
  for select to authenticated
  using (id = (select auth.uid()) or shares_tenant_with(id));
create policy profiles_update_self on profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- tenant_members: see your own memberships (even inactive ones, so the
-- app can say "deactivated") and the rosters of tenants you're active
-- in. All writes go through RPCs (0008) — they enforce owner/last-owner
-- rules a policy can't express.
create policy tenant_members_select on tenant_members
  for select to authenticated
  using (user_id = (select auth.uid()) or is_tenant_member(tenant_id));

-- tenant_invitations: owner/admin of that tenant only. Created/revoked/
-- redeemed through RPCs (0008) and the accept-invite Edge Function.
create policy tenant_invitations_select on tenant_invitations
  for select to authenticated
  using (has_tenant_role(tenant_id, array['admin']::staff_role[]));
