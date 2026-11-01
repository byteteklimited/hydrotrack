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
