"""HydroTrack — end-to-end isolation check over the real public API.

The pgTAP suite (database/tenant_isolation.test.sql) simulates signed-in
users inside Postgres. This checks the same boundaries the way the app
actually reaches them: GoTrue password sign-in for real JWTs, then
PostgREST reads/writes/RPCs with the publishable key and the app's own
query shapes.

It creates two throwaway email accounts and two organizations, and ALWAYS
deletes them again (in a finally block), even when a check fails.

Run from the project root (linked to the hydrotrack project, .env.json
filled in):   python3 -I supabase/tests/api_isolation_test.py
"""

import json
import pathlib
import secrets
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SASH_PROJECT_REF = "freamtqnexxlbyfxowcl"


def load_config():
    ref = (ROOT / "supabase/.temp/project-ref").read_text().strip()
    if ref == SASH_PROJECT_REF:
        sys.exit("Refusing to run: linked to the sash_water project.")
    env = json.loads((ROOT / ".env.json").read_text())
    if env["SUPABASE_URL"] != f"https://{ref}.supabase.co":
        sys.exit(".env.json does not point at the linked project.")
    return env["SUPABASE_URL"], env["SUPABASE_PUBLISHABLE_KEY"]


URL, KEY = load_config()


def sql(query):
    """Runs SQL as the database owner through the CLI (setup/cleanup only)."""
    out = subprocess.run(
        ["supabase", "db", "query", "--linked", query],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out[out.find("{"):]).get("rows", [])


def http(method, path, token=None, body=None):
    """Calls the public API with curl (works regardless of how this
    Python install handles TLS certificates). Returns (status, json)."""
    args = ["curl", "-s", "-X", method, URL + path, "-H", f"apikey: {KEY}",
            "-H", "Content-Type: application/json", "-w", "\n%{http_code}"]
    if token:
        args += ["-H", f"Authorization: Bearer {token}"]
    if method == "POST" and path.startswith("/rest/v1/") and "/rpc/" not in path:
        args += ["-H", "Prefer: return=representation"]
    if body is not None:
        args += ["--data", json.dumps(body)]
    out = subprocess.run(args, capture_output=True, text=True, check=True).stdout
    raw, _, status = out.rpartition("\n")
    return int(status), (json.loads(raw) if raw.strip() else None)


results = []


def check(condition, description):
    results.append((bool(condition), description))
    print(("ok     " if condition else "NOT OK ") + description)


def create_confirmed_user(email, password, name):
    rows = sql(f"""
      with u as (
        insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
          email_confirmed_at, raw_user_meta_data, raw_app_meta_data, created_at, updated_at,
          confirmation_token, recovery_token, email_change_token_new, email_change)
        values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated',
          'authenticated', '{email}', extensions.crypt('{password}', extensions.gen_salt('bf')),
          now(), '{{"full_name": "{name}"}}', '{{"provider": "email", "providers": ["email"]}}',
          now(), now(), '', '', '', '')
        returning id
      )
      insert into auth.identities (provider_id, user_id, identity_data, provider, created_at, updated_at)
      select id::text, id, jsonb_build_object('sub', id::text, 'email', '{email}'), 'email', now(), now()
      from u returning user_id::text as id;
    """)
    return rows[0]["id"]


def sign_in(email, password):
    status, body = http("POST", "/auth/v1/token?grant_type=password",
                        body={"email": email, "password": password})
    if status != 200:
        raise RuntimeError(f"sign-in failed for {email}: {status} {body}")
    return body["access_token"]


def main():
    run_id = secrets.token_hex(4)
    password = secrets.token_urlsafe(16)
    alice_email = f"alice-{run_id}@hydrotrack-test.invalid"
    bob_email = f"bob-{run_id}@hydrotrack-test.invalid"
    user_ids = []
    try:
        user_ids.append(create_confirmed_user(alice_email, password, "Alice Test"))
        user_ids.append(create_confirmed_user(bob_email, password, "Bob Test"))
        alice, bob = sign_in(alice_email, password), sign_in(bob_email, password)
        check(True, "Both throwaway owners sign in with email + password (real JWTs)")

        _, tenant_a = http("POST", "/rest/v1/rpc/create_tenant", alice, {"p_name": f"API Test A {run_id}"})
        _, tenant_b = http("POST", "/rest/v1/rpc/create_tenant", bob, {"p_name": f"API Test B {run_id}"})
        a, b = tenant_a["id"], tenant_b["id"]
        check(a and b and a != b, "Each creates an organization through create_tenant")

        # Alice records real data in A, the way the app does.
        _, items = http("GET", f"/rest/v1/stock_items?select=*&tenant_id=eq.{a}&name=eq.50cl%20Sachet", alice)
        sachet = items[0]["id"]
        status, _ = http("POST", "/rest/v1/rpc/add_stock", alice,
                         {"p_tenant_id": a, "p_item_id": sachet, "p_quantity": 100, "p_note": "API test", "p_expiry_date": None})
        check(status == 200, "Alice adds stock in A")
        status, customer = http("POST", "/rest/v1/customers", alice,
                                {"tenant_id": a, "name": "API Distributor", "phone": "08000000000",
                                 "area": "Kano", "credit_limit": 50000, "balance": 0})
        check(status == 201, "Alice adds a customer in A (direct insert, like the app)")
        status, sale_id = http("POST", "/rest/v1/rpc/record_sale", alice, {
            "p_tenant_id": a, "p_customer_type": "distributor", "p_customer_name": "API Distributor",
            "p_total": 4000, "p_amount_paid": 0, "p_payment_method": "credit", "p_balance": 4000,
            "p_lines": [{"product": "sachet50cl", "quantity": 10, "unit_price": 400}], "p_paid_channel": None})
        check(status == 200, "Alice records a credit sale in A")

        # Bob, using the app's own query shapes, sees none of it.
        for path in [
            "/rest/v1/sales?select=*,sale_lines(*),profiles!recorded_by(full_name),voided_by_profile:profiles!voided_by(full_name)",
            "/rest/v1/customers?select=*",
            "/rest/v1/ledger_entries?select=amount,date,customers(name)",
            "/rest/v1/stock_movements?select=*,profiles!by_whom(full_name)",
            "/rest/v1/cash_entries?select=*,profiles!recorded_by(full_name)",
            "/rest/v1/tenant_members?select=role,is_active,user_id,tenants(id,name,logo_path),profiles!user_id(full_name,phone,email)",
            "/rest/v1/audit_trail?select=*",
            "/rest/v1/tenants?select=*",
            "/rest/v1/profiles?select=*",
        ]:
            status, rows = http("GET", f"{path}&tenant_id=eq.{a}" if "tenants?" not in path and "profiles?" not in path else path, bob)
            leaked = [r for r in (rows or []) if r.get("tenant_id") == a or r.get("id") in (a, user_ids[0])]
            check(status == 200 and not leaked, f"Bob reads nothing of A via {path.split('?')[0]}")

        status, _ = http("POST", "/rest/v1/customers", bob,
                         {"tenant_id": a, "name": "Planted", "phone": "0", "area": "x", "balance": 0})
        check(status in (401, 403), f"Bob cannot insert a customer into A (HTTP {status})")
        status, body = http("POST", "/rest/v1/rpc/record_expense", bob, {
            "p_tenant_id": a, "p_date": "2026-10-31", "p_category": "other",
            "p_description": "x", "p_amount": 1, "p_method": "cash"})
        check(status >= 400 and body and body.get("code") == "42501", "Bob cannot record an expense in A")
        status, body = http("POST", "/rest/v1/rpc/void_sale", bob,
                            {"p_tenant_id": b, "p_sale_id": sale_id, "p_reason": "x"})
        check(status >= 400 and body and "not found" in body.get("message", ""),
              "Bob cannot void A's sale through his own organization")
        status, _ = http("PATCH", f"/rest/v1/tenants?id=eq.{a}", bob, {"name": "Hacked"})
        _, a_rows = http("GET", f"/rest/v1/tenants?select=name&id=eq.{a}", alice)
        check(a_rows and a_rows[0]["name"] == f"API Test A {run_id}", "Bob cannot rename A")

        # Invite flow by email: Bob joins A as a cashier and then (only then)
        # sees A's data — with cashier rights only.
        _, invite = http("POST", "/rest/v1/rpc/create_invitation", alice, {
            "p_tenant_id": a, "p_full_name": "Bob Test", "p_phone": None,
            "p_email": bob_email, "p_role": "cashier"})
        status, joined = http("POST", "/rest/v1/rpc/accept_invitation", bob, {"p_code": invite["code"]})
        check(status == 200 and joined == a, "Bob joins A with an invite sent to his email")
        _, rows = http("GET", f"/rest/v1/customers?select=*&tenant_id=eq.{a}", bob)
        check(len(rows or []) == 1, "As a member, Bob now sees A's customer")
        status, body = http("POST", "/rest/v1/rpc/record_expense", bob, {
            "p_tenant_id": a, "p_date": "2026-10-31", "p_category": "other",
            "p_description": "x", "p_amount": 1, "p_method": "cash"})
        check(status >= 400 and body.get("code") == "42501", "…but only with cashier rights in A")
        _, own = http("GET", f"/rest/v1/customers?select=*&tenant_id=eq.{b}", bob)
        check(own == [], "Joining A leaves Bob's own organization B untouched (still no customers)")
    finally:
        if user_ids:
            ids = ",".join(f"'{i}'" for i in user_ids)
            sql(f"delete from public.tenants where created_by in ({ids});"
                f" delete from auth.users where id in ({ids});")
            left = sql(f"select count(*)::int as n from auth.users where id in ({ids})")[0]["n"]
            print(f"cleanup: removed test organizations and accounts ({left} left)")

    failed = [d for ok, d in results if not ok]
    print(f"-- {len(results) - len(failed)} passed, {len(failed)} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
