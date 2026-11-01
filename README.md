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
- `./supabase/tests/run_linked.sh` — database isolation suite (pgTAP)
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
