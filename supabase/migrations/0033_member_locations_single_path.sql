-- HydroTrack — 0033: member_locations' own foreign key to tenants made it
-- a second path between tenant_members and tenants, so the API refused
-- `tenant_members?select=tenants(...)` as ambiguous (the app's "your
-- organizations" query). Its key to tenant_members already ties it to the
-- tenant (and cascades), so the direct one goes.
alter table member_locations drop constraint member_locations_tenant_id_fkey;
