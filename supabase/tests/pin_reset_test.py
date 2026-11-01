"""HydroTrack — live check of staff PIN reset over the real API.

Owner invites a throwaway cashier (accept-invite), issues a reset code
(create_pin_reset), the cashier resets their PIN through the reset-pin
Edge Function, then: new PIN signs in, old PIN doesn't, the code can't be
reused. Always deletes the throwaway accounts and organization.

Run from the project root:  python3 -I supabase/tests/pin_reset_test.py
"""

import pathlib
import random
import secrets
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import api_isolation_test as t  # noqa: E402  (shared helpers + safety checks)


def pin():
    return "".join(random.choice("0123456789") for _ in range(6))


def main():
    run = secrets.token_hex(4)
    email = f"reset-owner-{run}@hydrotrack-test.invalid"
    password = secrets.token_urlsafe(16)
    phone_local = "0809" + "".join(random.choice("0123456789") for _ in range(7))
    phone_e164 = "+234" + phone_local[1:]
    old_pin, new_pin = pin(), pin()
    owner_id = None
    try:
        owner_id = t.create_confirmed_user(email, password, "Reset Owner")
        owner = t.sign_in(email, password)
        _, tenant = t.http("POST", "/rest/v1/rpc/create_tenant", owner, {"p_name": f"Reset Test {run}"})
        _, invite = t.http("POST", "/rest/v1/rpc/create_invitation", owner, {
            "p_tenant_id": tenant["id"], "p_full_name": "Reset Cashier", "p_phone": phone_local,
            "p_email": None, "p_role": "cashier"})
        status, _ = t.http("POST", "/functions/v1/accept-invite", None, {"code": invite["code"], "pin": old_pin})
        t.check(status == 200, "A cashier joins with a PIN")
        _, cashier = t.http("POST", "/auth/v1/token?grant_type=password", None, {"phone": phone_e164, "password": old_pin})
        cashier_id = cashier["user"]["id"]

        status, reset = t.http("POST", "/rest/v1/rpc/create_pin_reset", owner,
                               {"p_tenant_id": tenant["id"], "p_user_id": cashier_id})
        t.check(status == 200 and len(reset["code"]) == 10, "The owner gets a reset code")

        status, body = t.http("POST", "/functions/v1/reset-pin", None, {"code": reset["code"], "pin": new_pin})
        t.check(status == 200 and body["phone"] == phone_local, "The cashier sets a new PIN with the code")

        status, _ = t.http("POST", "/auth/v1/token?grant_type=password", None, {"phone": phone_e164, "password": new_pin})
        t.check(status == 200, "The new PIN signs in")
        status, _ = t.http("POST", "/auth/v1/token?grant_type=password", None, {"phone": phone_e164, "password": old_pin})
        t.check(status == 400, "The old PIN no longer works")
        status, _ = t.http("POST", "/functions/v1/reset-pin", None, {"code": reset["code"], "pin": pin()})
        t.check(status == 400, "The code can't be used twice")
        status, _ = t.http("POST", "/functions/v1/reset-pin", None, {"code": "WRONGCODE1", "pin": pin()})
        t.check(status == 400, "A made-up code is refused")
    finally:
        if owner_id:
            t.sql(f"delete from public.tenants where created_by = '{owner_id}';"
                  f" delete from auth.users where id = '{owner_id}' or phone in "
                  f"('{phone_e164[1:]}', '{phone_e164}');")
            left = t.sql(f"select count(*)::int as n from auth.users where id = '{owner_id}' "
                         f"or phone in ('{phone_e164[1:]}', '{phone_e164}')")[0]["n"]
            print(f"cleanup: removed throwaway accounts and organization ({left} left)")

    failed = [d for ok, d in t.results if not ok]
    print(f"-- {len(t.results) - len(failed)} passed, {len(failed)} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
