# HydroTrack

Multi-tenant water factory management system: production, inventory,
sales, customer debts, finance, distribution, expenses, reports and staff.
Flutter (mobile + web + desktop) + Supabase + Riverpod.

## Running

`flutter run` (or Run in VS Code / Android Studio). The hydrotrack
project's URL and publishable key are built in
(`lib/core/constants/supabase_config.dart`); the publishable key is public
by design and row-level security protects the data.

To use a different Supabase project, copy `.env.json.example` to
`.env.json`, fill in its URL and publishable key (never the service-role
key) and run with `--dart-define-from-file=.env.json`. The app refuses to
start if that file still holds placeholders.

## Tests

- `flutter test` — models, formatters, validators, aggregation logic.
- `python3 -I supabase/tests/device_sync_test.py` — live check of offline
  device sync (throwaway organization, always deleted).
- `python3 -I supabase/tests/pin_reset_test.py` — live check of staff PIN
  reset through the `reset-pin` Edge Function (throwaway accounts).
- `./supabase/tests/run_linked.sh` — database suites (pgTAP: isolation,
  debt reminders, offline sync, products and prices, PIN reset)
  against the linked hydrotrack project. Runs in one transaction and rolls
  back; nothing persists. With Docker: `supabase test db --linked`.
- `python3 -I supabase/tests/api_isolation_test.py` — the same boundaries
  over the real public API with real sign-ins. Creates two throwaway
  accounts and always deletes them.

## Debt reminders (SMS)

Each morning (08:00–10:30 Lagos), customers who still owe 14 days after
their last payment get an SMS, then every 7 days, up to 4 times; any
payment restarts the count. Rules and message text:
`supabase/migrations/0014_debt_reminders.sql`. Sending:
`supabase/functions/send-debt-reminders`, called by the pg_cron job
`send-debt-reminders`. Each organization adds its bank details under
Organization → Debt reminders.

One-time setup per Supabase project (never commit these values):

1. A shared secret for the scheduled job, e.g.
   `python3 -c "import secrets;print(secrets.token_urlsafe(32))"`.
2. `supabase secrets set DEBT_REMINDERS_CRON_SECRET=<secret>`
3. In the SQL editor:
   `select vault.create_secret('<secret>', 'debt_reminders_cron_secret');`
   `select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');`
4. Termii: create the account, get a sender ID approved (e.g.
   `HydroTrack`) and enable the DND route, then
   `supabase secrets set TERMII_API_KEY=<key> TERMII_SENDER_ID=<sender>`
   (optional: `TERMII_BASE_URL`, `TERMII_CHANNEL=generic`).

Until step 4 is done the function sends nothing and uses up no
customer's reminders.

## Offline use

An owner or admin sets a device up under Organization → "Offline use on
this device" (web or installed app). The device downloads the
organization's data, staff list and each member's offline sign-in check
(a salted PBKDF2 hash, never the PIN/password) through the `device-sync`
Edge Function using its own device key.

- Staff sign in on that device without internet with their usual phone +
  PIN (or email + password). Someone must have signed in online once since
  this feature shipped for their offline check to exist.
- Offline: sales, debt payments, expenses, production, new customers,
  stock in, stock counts, load-outs and driver returns. Online only:
  staff, settings, voids, edits and deletes.
- Records are saved on the device first and sent automatically (in order,
  exactly once, as the staff member who made them, at the time they were
  made) whenever there's internet; then fresh data is downloaded.
- Sales/production that synced with stock or raw material short, or a
  credit sale that took a customer over their limit, are saved and shown
  under "Needs checking" on Home for owners/admins/managers.
- A record the server refuses is kept on the device ("Records on this
  device") and in `device_operations`, to retry or remove.
- In a browser, records waiting to sync are lost if the site data is
  cleared; prefer the installed app on devices that are often offline.
- Admins can switch off a lost device in Organization settings.

Server: `supabase/migrations/0015_offline_devices.sql`,
`supabase/functions/device-sync` (deploy with `--no-verify-jwt`).

## Products, accounts and setup

- **Products & prices** (Owner/Admin, More → Products & prices): each
  organization's own products, each with a unit, a walk-in and a
  distributor price, and its own finished-goods stock. Sales fill in the
  price for the customer type; only Owner/Admin/Manager can change it on a
  sale (the line keeps the list price). Retire to hide a product from new
  records; delete only if it was never used.
- **Forgot PIN** (staff): Owner/Admin taps Reset PIN on the staff member
  and shares the one-time code (2 days); the staff member enters it under
  "Forgot your PIN?". Edge Function `reset-pin` (`--no-verify-jwt`).
- **Forgot password** (owners/email accounts): emailed link, then "Set a
  new password". Supabase's built-in email service is for testing only
  (low hourly limit); set up custom SMTP under Authentication → Emails
  before real customers rely on it.
- **Business profile** (Organization → Business profile): address,
  phone, email, CAC/RC and NAFDAC numbers, and logo; printed on receipts,
  report exports and (phone) the reminder SMS.
- **Lists** load the shown day/month or the last 30 days ("Show 30 more
  days"); Home's all-time totals come from `organization_totals`.
- **Setup checklist**: owners see "Finish setting up" on Home until the
  business profile is complete (or they dismiss it).
