-- HydroTrack — 0010: tighten function grants (found by `supabase db
-- advisors` after the first push).
--
-- Supabase's default privileges grant EXECUTE on new public functions to
-- anon and authenticated. 0002 granted the RLS helpers to authenticated
-- but never revoked anon, and handle_new_user (a trigger function) kept
-- both. None of these leaked data (with no auth.uid() they return false),
-- but there is no reason to expose them.

revoke execute on function handle_new_user() from public, anon, authenticated;
revoke execute on function is_tenant_member(uuid) from public, anon;
revoke execute on function has_tenant_role(uuid, staff_role[]) from public, anon;
revoke execute on function shares_tenant_with(uuid) from public, anon;
revoke execute on function normalize_ng_phone(text) from public, anon;
revoke execute on function storage_path_tenant(text) from public, anon;

-- member_has_history answered for any tenant id; now only for tenants
-- the caller is an active member of (false otherwise), so it can't be
-- used to probe another organization's roster.
create or replace function member_has_history(p_tenant_id uuid, p_user_id uuid)
returns boolean
language sql stable
security definer set search_path = public
as $$
  select is_tenant_member(p_tenant_id) and (
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
    )
  );
$$;
