"""HydroTrack — live check of offline device sync over the real API.

Sets up a device for a throwaway organization (owner signs in with a real
JWT and calls register_device), downloads its data through the
device-sync Edge Function, sends an offline sale twice (must apply once),
and checks a wrong key is refused. Always deletes the throwaway owner and
organization afterwards.

Run from the project root:  python3 -I supabase/tests/device_sync_test.py
"""

import secrets
import sys
import uuid
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import api_isolation_test as t  # noqa: E402  (shared helpers + safety checks)


def sync(body):
    return t.http("POST", "/functions/v1/device-sync", None, body)


def main():
    run = secrets.token_hex(4)
    email = f"device-{run}@hydrotrack-test.invalid"
    password = secrets.token_urlsafe(16)
    user_id = None
    try:
        user_id = t.create_confirmed_user(email, password, "Device Owner")
        owner = t.sign_in(email, password)
        _, tenant = t.http("POST", "/rest/v1/rpc/create_tenant", owner, {"p_name": f"Device Test {run}"})
        status, device = t.http("POST", "/rest/v1/rpc/register_device", owner,
                                {"p_tenant_id": tenant["id"], "p_name": "Test tablet"})
        t.check(status == 200 and len(device["key"]) == 64, "Owner sets up a device and gets its key once")

        _, items = t.http("GET", f"/rest/v1/stock_items?select=id&tenant_id=eq.{tenant['id']}&name=eq.50cl%20Sachet", owner)
        t.http("POST", "/rest/v1/rpc/add_stock", owner, {
            "p_tenant_id": tenant["id"], "p_item_id": items[0]["id"], "p_quantity": 100,
            "p_note": "Opening", "p_expiry_date": None})

        status, data = sync({"action": "pull", "device_key": device["key"]})
        t.check(status == 200 and data["organization"]["id"] == tenant["id"],
                "Device downloads its organization's data")
        t.check(len(data["members"]) == 1 and data["members"][0]["role"] == "owner",
                "with the staff list")
        t.check(len(data["tables"]["stock_items"]) == 4, "and its stock items")
        t.check(len(data["tables"]["products"]) == 4
                and all(i["products"]["name"] for i in data["tables"]["stock_items"]),
                "and its products, with each stock item's product name")

        op = {"op_id": str(uuid.uuid4()), "type": "sale", "actor_id": user_id,
              "recorded_at": "2026-10-30T09:15:00+01:00",
              "payload": {"customer_type": "walk_in", "customer_name": None, "total": 4000,
                          "amount_paid": 4000, "payment_method": "cash", "balance": 0,
                          "lines": [{"product": "sachet50cl", "quantity": 10, "unit_price": 400}],
                          "paid_channel": None}}
        status, pushed = sync({"action": "push", "device_key": device["key"], "operations": [op]})
        t.check(status == 200 and pushed["results"][0]["status"] == "applied", "An offline sale is sent and applied")
        sync({"action": "push", "device_key": device["key"], "operations": [op]})
        _, sales = t.http("GET", f"/rest/v1/sales?select=id,date_time&tenant_id=eq.{tenant['id']}", owner)
        t.check(len(sales) == 1, "Sending it again doesn't duplicate it")
        t.check(sales[0]["date_time"].startswith("2026-10-30T08:15:00"), "It keeps the time it was made offline")

        status, _ = sync({"action": "pull", "device_key": "0" * 64})
        t.check(status == 403, "A wrong device key is refused")
    finally:
        if user_id:
            t.sql(f"delete from public.tenants where created_by = '{user_id}';"
                  f" delete from auth.users where id = '{user_id}';")
            left = t.sql(f"select count(*)::int as n from auth.users where id = '{user_id}'")[0]["n"]
            print(f"cleanup: removed throwaway owner and organization ({left} left)")

    failed = [d for ok, d in t.results if not ok]
    print(f"-- {len(t.results) - len(failed)} passed, {len(failed)} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
