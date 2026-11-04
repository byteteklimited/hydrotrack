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
- `python3 -I supabase/tests/subscriptions_test.py` — live check of the
  trial, read-only after it ends, and the admin console being refused to
  owners (throwaway account).
- `./supabase/tests/run_linked.sh` — database suites (pgTAP: isolation,
  debt reminders, offline sync, products and prices, PIN reset, cash
  counts, purchases and costs, alerts, subscriptions, quality, machines, payroll, forecast, locations)
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

## Daily control (Phase B)

- **Cash counts**: Home → "Count cash" (cashiers, managers, admins). The
  server works out what the person should hold (cash in they recorded −
  cash out they paid, since their last count today); a note is required
  when it doesn't match; shortages go to the owner's "Needs checking";
  managers confirm counts in Finance. Works offline.
- **Purchases** (More → Purchases; store keepers in the main bar):
  suppliers, purchases paid now / on credit / part, what we owe each
  supplier, paying suppliers. Stock uses average cost; production runs
  get a material cost and cost per bag; sale lines keep their cost; the
  profit report subtracts the cost of bags sold (materials-purchase
  expenses are left out to avoid counting them twice). Needs internet.
- **Alerts** (owners; bell on Home): daily summary from 8 pm Lagos time
  and low stock (once a day per item), made by the `generate-alerts`
  pg_cron job. SMS copies go to the business phone in the profile via
  `send-alerts` once Termii and the cron secret are set (README "Debt
  reminders"); alerts older than 2 hours are never texted.
- **Receipt printers** (Android app): receipt → "Print receipt" sends to
  a paired Bluetooth ESC/POS printer (58 or 80 mm, chosen once per phone).
  Other devices use Print / Share.

Android build note: this machine's newest Android Studio ("Android
Studio 2") bundles Java 25, which Gradle 8.14 can't run on. Build with
Java 21, e.g. `flutter config --jdk-dir="/Applications/Android
Studio.app/Contents/jbr/Contents/Home"`, or upgrade Gradle.

## Subscriptions and admin console (Phase C)

- **Plan**: one monthly price. New organizations get a free trial (14
  days by default); when the trial or paid time ends there are 7 days of
  grace; after that the organization is **read-only** — everyone can still
  sign in, view and export, but nothing can be recorded, edited or deleted
  until it pays. Owners can still deactivate or remove staff.
- **Paying** is manual: owners see the price and "How to pay" under
  Organization → Subscription, pay by transfer and send the receipt;
  the HydroTrack admin records the payment, which adds the months after
  the trial or current paid time (or from today if it has run out).
- **Banner**: read-only shows to everyone; "payment due" and "trial ends
  in 3 days or less" show to Owner/Admin, who can tap through to renew.
- **Offline**: a set-up device gets the status with each download and
  stops recording once access has ended. Records made offline before that
  are accepted whenever they sync; ones made after are kept on the device
  (refused) and go through on retry once the organization has paid.
- **Admin console** (platform admins only — the operator account set in
  migration 0023; add others with
  `insert into platform_admins (user_id) …`): "HydroTrack admin" in the
  account menu / sidebar footer / organization picker. Every organization
  with owner contact, staff count, last activity and status (search and
  filter); Record payment, Give free days, Suspend (with a reason the
  organization sees) / Resume, and history. "Plan and price" sets the
  monthly price, trial days (new organizations), grace days (everyone)
  and the payment instructions owners see. **Set the price and payment
  instructions before going live.** The console gives no access to any
  organization's own records.

## Phase D — operations

1. **Quality and compliance** (More → Quality; owners, admins, managers,
   store keepers):
   - **Water tests** each shift (pH, TDS, residual chlorine) against the
     organization's limits — NIS 554 by default (pH 6.5–8.5, TDS ≤ 500
     mg/L, chlorine 0.2–0.25 mg/L), changed under Quality → settings. A
     failed test is flagged and the owner alerted; production can still be
     recorded. Works offline.
   - **Batch numbers** on every production run (`261101-M-1` = date,
     shift, run). Sales take stock oldest batch first and remember the
     batches (printed on receipts); **Trace a batch** (owners, admins,
     managers) lists every customer, phone and driver that got it.
   - **Permits** (NAFDAC, SON, water board, fire…): the owner is alerted
     60, 30 and 7 days before expiry and on the day.
   - **Sanitation checklist**: each organization's own list (starts with 8
     suggested items), ticked off daily. Works offline.
   - The 8 pm summary adds failed or missing water tests and a missed
     checklist.
2. **Machines and generator** (More → Machines; owners, admins, managers,
   store keepers):
   - Each organization's **machine list** (starts with Machine 1, Machine
     2 and Generator; managers add, rename, retire). Production runs pick
     their machine from it.
   - **Maintenance** tasks every N days per machine; due and overdue tasks
     show on Home and Machines and alert the owner once when they fall
     due. "Mark done" can carry a cost (posted as a maintenance expense).
   - **Breakdowns**: which machine, when it stopped, why; "Mark fixed"
     with the restart time and repair cost (posted as a maintenance
     expense). Downtime hours per machine this month.
   - **Diesel**: litres and cost put in (posted as a diesel expense — don't
     also add it under Expenses), optional run-hours. This month's diesel
     per 100 bags and diesel cost per bag.
   - Diesel, maintenance done and breakdowns work offline; this month's
     figures need internet.
3. **Staff and payroll** (More → Workers & pay):
   - **Workers**: packers, loaders, security without the app, and app
     staff (linked to their account). Each is paid a monthly salary, a
     daily wage, or per bag. Only owners and admins see rates, advances
     and payroll; pay never goes onto offline devices.
   - **Attendance** (present / half day / absent) and **bag counts** per
     per-bag worker, by day — managers and store keepers; work offline.
   - **Advances** (owners/admins): paid out as wages when given, taken
     off the next payroll.
   - **Monthly payroll** (owners/admins): Prepare works out each person's
     pay — monthly salary less salary ÷ working days (Mon–Sat) per day
     marked absent (half for a half day); daily wage × days present;
     rate × bags — less advances, plus any adjustment (with a reason).
     "Pay everyone" records each net amount as a wages expense (cash or
     transfer) and closes the month. Payslips as PDF (Share).
4. **Forecasting — when stock runs out** (Inventory): every item shows
   "about N days left" at the last 30 days' rate (sales, load-outs and
   production use; stock counts left out; newer items averaged over the
   days since their first movement), in amber under a week, with the
   daily rate on the item's page. The owner is alerted once a week per
   item when it will run out within 7 days (items already at their
   reorder level get the low-stock alert instead). Works offline from the
   device's own copy.
5. **Factories and depots** (Organization → Locations; owners/admins):
   - Every organization starts with **Main factory** (existing records
     are there). Add factories (make and sell) and depots (hold and sell),
     rename or close them, and choose **who works where**. Owners and
     admins work everywhere; other staff only see and record at their
     locations.
   - Kept per location: stock, sales, production, expenses, cash and cash
     counts, customers and their debts, load-outs and purchases. Shared:
     products and prices, drivers, vehicles, suppliers, quality, machines,
     workers and payroll.
   - The app works in one location at a time (switch on Home when you
     can use several). It sends it with every request (`x-location-id`);
     the database stamps new records with it, only shows that location,
     and only lets a record be changed (void, edit, settle) from its own
     location.
   - **Transfers** (Inventory → ⇄): send stock to another location (it
     leaves straight away, oldest batches first), and the other location
     receives it with the same batch numbers, expiry and cost — tracing a
     batch follows it. Needs internet.
   - An offline device belongs to the location it was set up at:
     it downloads only that location and only its staff (plus owners and
     admins) can sign in on it.
   - Stock forecasts and low-stock alerts are per location (alerts name
     the location when there are several).

## Branding (white label)

Each organization wears its own brand inside the app:

- **Name, logo, main and accent color** — set in a short skippable setup
  right after creating an organization ("Make it yours", then business
  details), and any time under Organization → Branding (owners/admins),
  with a live preview. Colors come from ready-made swatches or a typed
  `#RRGGBB` code; text in the main color is darkened automatically when
  needed so it stays readable, and text on buttons switches to dark on
  light colors.
- **Where it shows**: the whole app's colors (buttons, menus, highlights,
  charts), the sidebar and phone Home header (logo — or initials on the
  brand color until a logo is uploaded — and name), the organization list,
  the browser tab title, receipts, report and payslip PDFs, and shared
  file names. Invite and PIN-reset messages name the organization.
- **HydroTrack itself** appears only on the splash and sign-in screens
  (before an organization is known), as a small "Powered by HydroTrack"
  line on sign-in and in settings, and on the owner's Subscription screen
  (billing).
- **Not per organization**: the installed app's icon and home-screen name
  are fixed when the app is built; branding those per customer needs a
  separate build for each.

Storage: `tenants.brand_primary` / `brand_accent` (migration 0035; null =
HydroTrack's navy and cyan). In code: `BrandPalette` (core/theme) is a
theme extension built from the organization's colors; widgets read
`context.brand`, never fixed brand colors.
