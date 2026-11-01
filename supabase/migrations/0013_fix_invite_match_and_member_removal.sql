-- HydroTrack — 0013: two bugs found by the cross-tenant isolation tests.
--
-- 1. accept_invitation let ANY account with no phone number (e.g. an
--    email-only owner) redeem an invite addressed to a phone number.
--    The identity check was `not (phone matches or email matches)`; with
--    the account's phone NULL, "phone matches" evaluated to NULL, the
--    whole condition to NULL, and `if NULL` doesn't fire — so the
--    mismatch was never raised and the stranger joined. Every comparison
--    is now forced to a real true/false.
--
-- 2. remove_member failed for every member, even ones with no recorded
--    activity: joining logs an 'added' row where the member is both actor
--    and target. Deleting the membership cascades that row away (target
--    FK), but the actor FK's check could run first and see it still
--    there. The actor FK is now checked at the end of the transaction,
--    after the cascade — it still blocks removing anyone who acted on
--    someone else.

create or replace function accept_invitation(p_code text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_invitation tenant_invitations;
  v_phone text;
  v_email text;
  v_matches boolean;
begin
  if v_uid is null then
    raise exception 'Sign in to join an organization' using errcode = '42501';
  end if;

  v_invitation := claim_invitation(p_code);

  select phone, lower(email) into v_phone, v_email from auth.users where id = v_uid;
  v_matches :=
    coalesce(
      v_invitation.phone is not null and v_phone is not null
        and normalize_ng_phone(v_invitation.phone) = normalize_ng_phone(v_phone),
      false
    )
    or coalesce(
      v_invitation.email is not null and v_email is not null
        and v_invitation.email = v_email,
      false
    );
  if not v_matches then
    raise exception 'This invite was sent to a different phone number or email.';
  end if;

  return complete_invitation(v_invitation, v_uid);
end;
$$;

alter table staff_audit_log
  alter constraint staff_audit_log_tenant_id_actor_id_fkey deferrable initially deferred;
