"""HydroTrack — live check of subscriptions over the real API.

A throwaway owner creates an organization: it starts on a Standard trial
and can record, sees the plans, chooses one, and can't add a second
location or change prices; the admin console is refused to them; their subscription can't be
edited directly. Then the trial is moved into the past (as if 30 days went
by): recording is refused with the read-only message, reading still works.
Always deletes the throwaway account and organization.

Run from the project root:  python3 -I supabase/tests/subscriptions_test.py
"""

import pathlib
import secrets
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import api_isolation_test as t  # noqa: E402  (shared helpers + safety checks)


def main():
    run = secrets.token_hex(4)
    email = f"sub-owner-{run}@hydrotrack-test.invalid"
    password = secrets.token_urlsafe(16)
    owner_id = None
    try:
        owner_id = t.create_confirmed_user(email, password, "Sub Owner")
        owner = t.sign_in(email, password)
        _, tenant = t.http("POST", "/rest/v1/rpc/create_tenant", owner, {"p_name": f"Sub Test {run}"})
        tenant_id = tenant["id"]
        expense = {"p_tenant_id": tenant_id, "p_date": "2026-11-01", "p_category": "fuel_diesel",
                   "p_description": "Diesel", "p_amount": 500, "p_method": "cash"}

        status, sub = t.http("POST", "/rest/v1/rpc/my_subscription", owner, {"p_tenant_id": tenant_id})
        t.check(status == 200 and sub["status"] == "trial" and sub["can_record"], "A new organization is on a trial")
        status, _ = t.http("POST", "/rest/v1/rpc/record_expense", owner, expense)
        t.check(status == 200, "and can record")

        t.check(sub["plan"]["key"] == "standard" and sub["account_number"] == "8137131177",
                "on Standard, with HydroTrack's bank account")
        status, plans = t.http("GET", "/rest/v1/plans?select=key,monthly_price&order=position", owner)
        t.check(status == 200 and [(p["key"], p["monthly_price"]) for p in plans]
                == [("starter", 15000), ("standard", 25000), ("premium", 50000)],
                "Owners see the three plans and prices")
        status, sub = t.http("POST", "/rest/v1/rpc/request_plan", owner,
                             {"p_tenant_id": tenant_id, "p_plan_key": "premium"})
        t.check(status == 200 and sub["requested_plan_key"] == "premium" and sub["plan"]["key"] == "standard",
                "The owner chooses Premium; it waits for payment")
        status, body = t.http("POST", "/rest/v1/locations", owner,
                              {"tenant_id": tenant_id, "name": "Kano depot", "kind": "depot"})
        t.check(status == 400 and body.get("hint") == "plan_limit", "Standard can't add a second location")
        t.http("PATCH", "/rest/v1/plans?key=eq.starter", owner, {"monthly_price": 1})
        price = t.sql("select monthly_price::int as p from public.plans where key = 'starter'")[0]["p"]
        t.check(price == 15000, "Owners can't change plan prices")

        status, body = t.http("POST", "/rest/v1/rpc/admin_organizations", owner, {})
        t.check(status in (401, 403) and body.get("code") == "42501", "Owners can't open the admin console")
        status, is_admin = t.http("POST", "/rest/v1/rpc/is_platform_admin", owner, {})
        t.check(status == 200 and is_admin is False, "and aren't platform admins")
        t.http("PATCH", f"/rest/v1/tenant_subscriptions?tenant_id=eq.{tenant_id}", owner,
               {"paid_until": "2099-01-01T00:00:00Z"})
        paid = t.sql(f"select paid_until from public.tenant_subscriptions where tenant_id = '{tenant_id}'")[0]
        t.check(paid["paid_until"] is None, "Owners can't extend their own subscription")

        t.sql(f"update public.tenant_subscriptions set trial_ends_at = now() - interval '30 days' "
              f"where tenant_id = '{tenant_id}'")
        status, sub = t.http("POST", "/rest/v1/rpc/my_subscription", owner, {"p_tenant_id": tenant_id})
        t.check(status == 200 and sub["status"] == "expired", "After trial and grace it has ended")
        status, body = t.http("POST", "/rest/v1/rpc/record_expense", owner, expense)
        t.check(status == 400 and "subscription has ended" in body.get("message", ""),
                "Recording is refused with the read-only message")
        status, rows = t.http("GET", f"/rest/v1/expenses?tenant_id=eq.{tenant_id}&select=id", owner)
        t.check(status == 200 and len(rows) == 1, "Records can still be read")
    finally:
        if owner_id:
            t.sql(f"delete from public.tenants where created_by = '{owner_id}';"
                  f" delete from auth.users where id = '{owner_id}';")
            left = t.sql(f"select count(*)::int as n from public.tenants where created_by = '{owner_id}'")[0]["n"]
            print(f"cleanup: removed throwaway owner and organization ({left} left)")

    failed = [d for ok, d in t.results if not ok]
    print(f"-- {len(t.results) - len(failed)} passed, {len(failed)} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
