-- HydroTrack — 0011: direct actor -> profiles foreign keys.
--
-- Every "who did it" column already has a composite FK to
-- tenant_members (tenant_id, user_id) — that's the isolation guarantee.
-- The app also embeds the person's name through PostgREST, e.g.
-- `profiles!recorded_by(full_name)`, which needs a direct FK from the
-- column to profiles(id). These add it alongside the composite one; they
-- change nothing about what can be written (a tenant member always has a
-- profile).

alter table production_runs add constraint production_runs_recorded_by_profile_fkey
  foreign key (recorded_by) references profiles (id);
alter table stock_batches add constraint stock_batches_created_by_profile_fkey
  foreign key (created_by) references profiles (id);
alter table sales add constraint sales_recorded_by_profile_fkey
  foreign key (recorded_by) references profiles (id);
alter table sales add constraint sales_voided_by_profile_fkey
  foreign key (voided_by) references profiles (id);
alter table ledger_entries add constraint ledger_entries_recorded_by_profile_fkey
  foreign key (recorded_by) references profiles (id);
alter table cash_entries add constraint cash_entries_recorded_by_profile_fkey
  foreign key (recorded_by) references profiles (id);
alter table expenses add constraint expenses_recorded_by_profile_fkey
  foreign key (recorded_by) references profiles (id);
alter table load_outs add constraint load_outs_recorded_by_profile_fkey
  foreign key (recorded_by) references profiles (id);
alter table stock_movements add constraint stock_movements_by_whom_profile_fkey
  foreign key (by_whom) references profiles (id);
alter table staff_audit_log add constraint staff_audit_log_actor_profile_fkey
  foreign key (actor_id) references profiles (id);
alter table staff_audit_log add constraint staff_audit_log_target_profile_fkey
  foreign key (target_id) references profiles (id) on delete cascade;

-- tenant_members and tenant_invitations already reference profiles(id)
-- directly (0002); the Members screen embeds
-- `profiles!user_id(full_name, phone, email)`.
