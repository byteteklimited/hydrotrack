# CLAUDE.md — HydroTrack

Multi-tenant water factory management system (sachet/bottled water).
Flutter (mobile + web + desktop) + Supabase + Riverpod. One app serves many
separate organizations ("tenants"); each tenant's data is fully isolated.

HydroTrack started as a duplicate of the single-tenant `sash_water` app.
**That app and its Supabase project (`sash-water`, ref `freamtqnexxlbyfxowcl`)
are live production and must never be read from, written to, linked, or
deployed to from this repo.** HydroTrack uses its own Supabase project,
`hydrotrack`, only.

## Workflow rules (non-negotiable)

1. **One phase at a time.** Finish one phase, show the result, then STOP and
   wait for explicit approval. Never build ahead or "also add" unasked work.
2. **Ask before assuming** business rules (pricing, roles, products, shifts).
3. **Ask before anything destructive or irreversible** (dropping data,
   deleting files that aren't clearly dead, touching a live database).
4. The app must build and run after every phase: `flutter analyze`,
   `dart format`, `flutter test`, and
   `flutter build web --release --dart-define-from-file=.env.json`.
5. After finishing a phase, update the "Progress" section at the bottom.

## Tech stack

- Flutter/Dart, single codebase for mobile + web + desktop
- Supabase: auth, Postgres, storage, Edge Functions
- Riverpod (`flutter_riverpod`) for ALL shared/business state
- `intl` for ₦ and date formatting; `pdf`/`printing`/`file_saver` for exports
- Config: hydrotrack URL + publishable key are built-in defaults in
  `supabase_config.dart` (public by design); `--dart-define-from-file=.env.json`
  overrides them (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`). The service-role key is
  never in the Flutter app — only inside Edge Functions, injected by Supabase.

## Folder structure (strict)

```
lib/
  core/
    theme/          # colors, typography, spacing, app theme — the ONLY place styles live
    widgets/        # shared reusable widgets
    utils/          # formatters, validators, helpers
    constants/      # app-wide constants
  features/<feature>/
    data/{models,repositories,providers}
    view/{screens,widgets}
  main.dart
supabase/
  migrations/       # ordered SQL for the hydrotrack project
  functions/        # Edge Functions
  tests/            # pgTAP tests (incl. cross-tenant isolation)
```

## Architecture rules

- Screens and widgets NEVER call Supabase. Screen → Riverpod provider →
  repository → Supabase.
- Models own all JSON serialization.
- Zero widget repetition; break widgets over ~100 lines into smaller ones.
- No magic numbers, no dead code, no hardcoded colors/text styles in screens.

## Multi-tenant rules

- Every tenant-owned table has `tenant_id` (not null, indexed) and RLS that
  restricts access to members of that tenant. Never add a table without both.
- Every repository query is tenant-scoped (`tenant_id` filter on reads,
  `tenant_id` set on inserts, `p_tenant_id` passed to RPCs), using the
  current tenant from the tenant-context provider.
- Every `security definer` function checks tenant membership and role itself
  — it bypasses RLS, so it must enforce isolation on its own.
- Roles are per tenant (a user can hold different roles in different tenants).

## Design system

- Colors (all in `core/theme/app_colors.dart`): navy `#002179` primary,
  cyan `#02BDFB` accent (never as text on white), red/amber/green only for
  their real meanings (destructive/overdue, warning/threshold, positive).
- Font: Helvetica with a fallback chain, applied once in the theme.
- Tokens: `AppSpacing`, `AppRadius` (input 4 / button 6 / panel 8 / sheet 10),
  `AppDurations`. Breakpoints in `AppBreakpoints` (<600 / 600–839 / ≥840).
- Use the factory's own vocabulary ("bags produced today", "money outside",
  "load-out", "driver returns", "wastage"). Buttons say what they do.
- Empty states say exactly what to do; errors say what went wrong and how
  to fix it.
- Logo: `AppBrand.logo` — currently a generated PLACEHOLDER.

## Progress

- [x] Phase 0 — Analysis: structure summary, Supabase dependency inventory,
      multi-tenant schema/RLS/migration plan. Approved decisions: app ID
      `com.example.hydrotrack` (placeholder); email + password sign-up for
      organization owners, phone + PIN for staff; members join via invite
      code; the 4 fixed product sizes stay shared for now (per-tenant
      products deferred); keep the navy/cyan theme; delete the old sash
      migrations; HydroTrack will get its own separate git repo.
- [x] Phase 1 — Rebrand + safety cleanup (see summary in chat):
      removed the Supabase CLI link to the live sash-water project and the
      sash credentials from `.env.json` (placeholders now; the app refuses
      to start until real hydrotrack values are filled in); renamed package
      `sash_water` → `hydrotrack` and all IDs → `com.example.hydrotrack`
      on Android/iOS/macOS/Linux/Windows; display name "HydroTrack"
      everywhere; placeholder logo + app icons generated.
- [x] Phase 2a — Multi-tenant schema written (not yet applied): the 30
      sash migrations deleted and replaced by 9 consolidated files in
      `supabase/migrations/` (types; tenancy core with membership-based
      RLS helpers; business tables with tenant_id + composite FKs;
      RLS; FIFO stock internals; 16 tenant-aware business RPCs; audit
      trigger + security_invoker `audit_trail` view; onboarding/
      invitation/member RPCs; tenant-prefixed storage bucket). Old
      `create-staff`/`delete-staff` Edge Functions replaced by
      `accept-invite` (deploy with `--no-verify-jwt`); removing a member
      is now the `remove_member` RPC. Syntax-checked offline with
      libpg_query (pglast).
- [x] Phase 2b — Applied to the hydrotrack project (ref
      `yvkwepipmpivybhhrhxr`, Postgres 17), verified empty beforehand.
      All 10 migrations applied cleanly (0010 added after
      `supabase db advisors` flagged anon-executable helpers; it also
      scopes `member_has_history` to the caller's own tenants). Live
      check: 19 tables, all with RLS; 29 table policies + 4 storage
      policies; `audit_trail` is security_invoker; no internal helper is
      callable by clients. Remaining advisor warnings (27) are the
      intended client-facing RPCs and the RLS helpers. `accept-invite`
      deployed with `--no-verify-jwt`; CORS preflight and invalid-code /
      invalid-PIN paths verified live. `.env.json` now holds the
      hydrotrack URL + publishable key (git-ignored).
- [x] Phase 3 — Multi-tenant app logic:
      - New `features/organizations/` (Organization/Membership/Invitation
        models, repository, providers). `currentOrganizationProvider` is
        the tenant context; `currentTenantIdProvider` feeds every
        repository provider, so switching organization rebuilds every
        repository and data provider (no stale cross-tenant data).
        `enterApp()` after sign-in: last-used org (kept in the user's auth
        metadata) or the only one → Home; otherwise the picker.
      - Every Supabase repository takes the tenant id: reads filter
        `tenant_id`, inserts set it, RPCs pass `p_tenant_id`. Dashboard/
        Reports aggregators now take the providers' repositories (they used
        to build their own). All 23 RPC calls cross-checked live against
        the deployed function signatures.
      - Auth: sign in with phone+PIN or email+password; new "Create an
        owner account" (email) and "Join your team" (invite code + PIN,
        via `accept-invite`) screens; organization picker with create /
        join-with-code; Organization settings (rename) for Owner/Admin;
        switch organization + sign out in the sidebar footer and in a new
        Home account menu on phones (phones had no sign-out before).
      - Roles: `owner` added; `isAdminLevel`/`canManage` helpers replace
        every hard-coded admin/manager check.
      - Staff = members of the current org: "Invite staff" issues a code
        (no PIN chosen by the admin any more), pending invites with
        show/revoke, change role (Owner only offered to owners), deactivate,
        "Remove from organization" (was delete account).
      - Receipts, PDF/CSV exports and Home show the organization's name.
      - DB follow-ups: 0011 adds direct actor→profiles FKs so existing
        `profiles!recorded_by(...)` embeds keep working; 0012 lets
        deactivated members still see their organization's name.
        `accept-invite` now returns the phone/email to sign in with.
      - 176 tests (was 155): new Membership/Organization/Invitation and
        Validators tests; staff tests updated to the membership row shape.
        `flutter analyze` clean, `flutter build web --release` succeeds.
        Not yet exercised in the running app — needs the Auth settings
        below enabled first.
- [x] Phase 4 — Testing incl. cross-tenant isolation tests:
      - `supabase/tests/database/tenant_isolation.test.sql` — pgTAP
        (xUnit `runtests`), 20 tests / 207 assertions: reads, inserts,
        updates/deletes across tenants, composite-FK cross references,
        all 21 member-facing RPCs with a foreign tenant id, RPCs reaching
        foreign rows via the caller's own tenant, per-tenant roles,
        deactivated/removed/no-org/anon users, invitations (wrong person,
        reuse, revoked, expired, no owner invites), owner safeguards,
        tenant-scoped storage, internal functions not callable. Runs in one
        transaction that rolls back — nothing persists.
        Run: `./supabase/tests/run_linked.sh` (no Docker; refuses to run if
        linked to sash) or `supabase test db --linked` (needs Docker).
      - `supabase/tests/api_isolation_test.py` — 22 checks over the real
        public API with real JWTs and the app's own query shapes; creates
        two throwaway email accounts and always deletes them.
      - The suite found two real bugs, fixed in migration 0013: an
        email-only account could redeem an invite addressed to a phone
        number (NULL comparison let it through); removing any member
        failed on their own 'added' audit row (actor FK now deferred).
      - Verified afterwards: hydrotrack DB holds 0 users / 0 tenants / no
        test schema or pgTAP extension. Flutter: 176 tests pass, analyze
        clean.
- [x] Wrap-up (2026-11-01): fresh git repo (copied sash history deleted,
      `git init -b main`, no remote yet); `.gitignore` now keeps
      `.env.json.example` and excludes `supabase/.temp/`. Screens no longer
      import Supabase (error text via `readableErrorMessage`). Phone
      provider enabled with placeholder Twilio values (no SMS is ever sent;
      swap for a real provider, e.g. Termii, if SMS features are added).
      Live staff flow verified: invite by phone → `accept-invite` with PIN
      → phone+PIN sign-in → correct role; code reuse rejected. Placeholder
      logo/icons and `com.example.hydrotrack` stay for now.
- [x] Debt reminders phase (2026-11-01): automatic SMS via one HydroTrack
      Termii account. Migration 0014: tenant bank details (all-or-none,
      10-digit NUBAN), `debt_reminders` log (members read own tenant; only
      service role writes), `claim_due_debt_reminders` /
      `finish_debt_reminder` (service role only; rules: 14 days overdue →
      every 7 days → max 4 since last payment; failed sends retry next
      day, max 3 failures; once per day), pg_cron job 08:00–10:30 Lagos.
      Edge Function `send-debt-reminders` (deployed `--no-verify-jwt`,
      cron-secret header). App: Organization → "Debt reminders" card +
      bank details form. Tests: `debt_reminders.test.sql` (25 checks),
      217 Flutter tests. Pending manual setup: cron secret + Vault
      secrets, Termii key/sender (README "Debt reminders").
      Next agreed phase: offline daily recording (sales, debt payments,
      expenses, production; credit sales allowed offline, flagged on
      sync if over limit).
- [x] Offline phase (2026-11-01): installed apps and web. Owner/Admin sets
      a device up (`register_device`; device key, hash only on server);
      `device-sync` Edge Function (`--no-verify-jwt`) pulls the org data
      (90 days of history, all customers/stock/staff) and pushes queued
      records; `apply_device_operation` replays each one exactly once as
      its recorder (role checks apply), at its offline time; short stock /
      raw material and over-credit-limit are recorded and flagged
      (`sync_flags`, "Needs checking" on Home + tags on records); refused
      records kept (`device_operations` + device list with Retry/Remove).
      Offline sign-in via `offline_credentials` (PBKDF2-SHA256, 60k
      iterations, saved after each online sign-in). App: offline-aware
      repositories (server when reachable, device copy otherwise; daily
      records always saved on device first), sembast storage
      (IndexedDB/web, file elsewhere), offline banner, device card,
      "Records on this device" screen. Online only: staff, settings,
      voids, edits, deletes, recipes, new drivers/vehicles/items.
      Tests: offline_sync.test.sql (52), device_sync_test.py (8 live),
      29 new Flutter tests (246 total). Termii secrets left unset
      (reminders send nothing until configured).
- [x] Phase A (2026-11-01), five parts, each committed:
      1. Products & prices per organization (migration 0016): products
         table (walk-in + distributor price, retire, delete if unused),
         own finished-goods stock item each; enum product_type removed,
         records point at product ids (legacy_key keeps old queued
         offline records working); cashiers must sell at list price
         (server-enforced), sale_lines.list_price kept. Products screen.
      2. PIN reset by admin code (0017, `reset-pin` Edge Function) and
         password reset by email (+ "Set a new password" screen).
      3. Business profile (0018): address, phone, email, RC, NAFDAC,
         logo upload (file_picker → tenant-files/<tenant>/logo-*.ext);
         on receipts, report PDF/CSV, reminder SMS (phone).
      4. Lists load by day/month/30-day window ("Show 30 more days");
         organization_totals (0019) for Home's all-time figures;
         removed the old demo network delays.
      5. Setup checklist on Home (owner): one step, complete the
         business profile; dismissal kept in auth user metadata.
      Tests: pgTAP 326 assertions across 5 suites; live checks 22 + 9 +
      7; 261 Flutter tests. Manual: custom SMTP before production.
- [x] Phase B (2026-11-01), four parts, each committed:
      1. Cash counts (0020): per cashier, expected = own cash in − own
         cash out since last count today (cash_entries.created_at =
         record time; offline = device time via hydrotrack.recorded_at /
         effective_now()); note required on mismatch; shortage flag
         ('cash_short'); managers confirm; offline 'cash_count' op.
      2. Suppliers & purchases (0021): credit purchases, supplier_ledger,
         pay_supplier; average cost (trigger on stock_movements), run
         material_cost, sale_lines.unit_cost; profit = revenue − cost of
         bags sold − expenses (materials_purchase excluded). Online only.
      3. Alerts (0022): owners only; generate_alerts via pg_cron every 15
         min (low stock once/day/item; summary from 20:00 Lagos);
         send-alerts Edge Function (Termii, business phone, no backlog);
         Termii code shared in functions/_shared/termii.ts.
      4. Bluetooth ESC/POS receipt printing (Android; print_bluetooth_
         thermal + esc_pos_utils_plus, conditional import so web builds);
         printer + paper width per phone (shared_preferences).
      Next: Phase C (subscriptions, admin console), then D.
- [x] Phase C (2026-11-01): subscriptions and admin console (agreed:
      one monthly plan, manual payment recorded by the admin, 14-day
      trial, then 7 days' grace, then read-only; only the operator account
      is platform admin; console inside the app; offline records made in
      time are always accepted). Migration 0023: platform_admins,
      platform_settings, tenant_subscriptions (trial started by trigger on
      tenants; existing organizations got 14 days from now),
      subscription_events; `guard_subscription` trigger on 22 business
      tables (not on membership, sign-in/offline credentials, devices,
      alerts, audit) — background jobs (no auth.uid) never blocked,
      offline records judged at their recorded time; my_subscription,
      device_subscription (in device-sync pull), admin_* RPCs. 0024 pins
      a search_path. App: features/subscriptions (banner under the offline
      banner, Subscription screen + card in Organization settings; device
      refuses records after access ends, refreshing first when online),
      features/admin (console, organization detail with Record payment /
      Free days / Suspend-Resume, Plan and price). Tests: pgTAP
      subscriptions (55), all 9 suites pass; live subscriptions_test.py
      (8), api_isolation (22), pin_reset (7), device_sync (9); 283 Flutter
      tests. Before launch: set the price and payment instructions in the
      console. Next: Phase D.
