-- HydroTrack — 0012: let deactivated members still see the organization's
-- name.
--
-- The organization picker lists every membership, including ones an
-- admin deactivated (shown as "Deactivated", not openable). Under 0002's
-- policy a deactivated member couldn't read the tenants row at all, so
-- the picker had no name to show. This widens SELECT on `tenants` only —
-- to any membership row for the caller, active or not. All business data
-- stays behind is_tenant_member(), which still requires an active
-- membership.

drop policy tenants_select on tenants;

create policy tenants_select on tenants
  for select to authenticated
  using (
    exists (
      select 1 from tenant_members
      where tenant_members.tenant_id = tenants.id
        and tenant_members.user_id = (select auth.uid())
    )
  );
