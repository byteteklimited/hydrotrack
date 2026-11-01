# HydroTrack

Multi-tenant water factory management system: production, inventory,
sales, customer debts, finance, distribution, expenses, reports and staff.
Flutter (mobile + web + desktop) + Supabase + Riverpod.

## Running

1. Copy `.env.json.example` to `.env.json` and fill in the **hydrotrack**
   Supabase project's URL and publishable key (never the service-role key).
2. `flutter run --dart-define-from-file=.env.json` (or use the VS Code
   "hydrotrack" launch configurations, which already pass that flag).

The app refuses to start with an empty or placeholder config.

## Tests

- `flutter test` — models, formatters, validators, aggregation logic.
- `./supabase/tests/run_linked.sh` — database isolation suite (pgTAP)
  against the linked hydrotrack project. Runs in one transaction and rolls
  back; nothing persists. With Docker: `supabase test db --linked`.
- `python3 -I supabase/tests/api_isolation_test.py` — the same boundaries
  over the real public API with real sign-ins. Creates two throwaway
  accounts and always deletes them.
