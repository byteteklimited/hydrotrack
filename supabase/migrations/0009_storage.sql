-- HydroTrack — 0009: tenant-scoped file storage.
--
-- One private bucket. Every object path starts with the owning tenant's
-- id: `<tenant_id>/logo.png`, `<tenant_id>/receipts/...`. Policies read
-- that first path segment and apply the same membership/role helpers as
-- the tables. First use: the organization logo (tenants.logo_path).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tenant-files', 'tenant-files', false, 5242880,
  array['image/png', 'image/jpeg', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

-- The tenant id an object path belongs to, or null if the first segment
-- isn't a uuid (such paths then match no policy at all).
create function storage_path_tenant(p_name text)
returns uuid
language sql immutable
set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_name, '/', 1)::uuid
  end;
$$;

grant execute on function storage_path_tenant(text) to authenticated;

create policy tenant_files_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'tenant-files'
    and public.is_tenant_member(public.storage_path_tenant(name))
  );

create policy tenant_files_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'tenant-files'
    and public.has_tenant_role(public.storage_path_tenant(name), array['admin', 'manager']::public.staff_role[])
  );

create policy tenant_files_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'tenant-files'
    and public.has_tenant_role(public.storage_path_tenant(name), array['admin', 'manager']::public.staff_role[])
  )
  with check (
    bucket_id = 'tenant-files'
    and public.has_tenant_role(public.storage_path_tenant(name), array['admin', 'manager']::public.staff_role[])
  );

create policy tenant_files_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'tenant-files'
    and public.has_tenant_role(public.storage_path_tenant(name), array['admin']::public.staff_role[])
  );
