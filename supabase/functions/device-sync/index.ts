// HydroTrack — device-sync Edge Function.
//
// The only way a device set up for offline use talks to the server when
// nobody may be signed in online. Its secret device key (issued by
// register_device, migration 0015) is the authorization; it's sent in the
// JSON body. Deploy with JWT verification off:
//   supabase functions deploy device-sync --no-verify-jwt
//
// Actions:
//   {"action": "pull", "device_key": "..."}
//     -> the organization's data for offline use: staff (with offline
//        sign-in checks), stock, customers, drivers, vehicles, recipes,
//        open flags, and the last 90 days of sales, payments, cash,
//        expenses, production, stock movements and load-outs, in the same
//        shape the app's own queries return.
//   {"action": "push", "device_key": "...", "operations": [...]}
//     -> applies queued records in order (apply_device_operation) and
//        returns each one's result. Stops at the first error that isn't
//        a refusal, so nothing after it is applied out of order.
//
// Every query here is filtered to the device's own organization.
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

const HISTORY_DAYS = 90;
const PAGE_SIZE = 1000; // PostgREST's maximum rows per request
const MAX_OPERATIONS_PER_PUSH = 100;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

type Query = (from: number, to: number) => PromiseLike<{
  data: unknown[] | null;
  error: { message: string } | null;
}>;

// Reads every page of a query.
async function fetchAll(query: Query): Promise<unknown[]> {
  const rows: unknown[] = [];
  for (let from = 0;; from += PAGE_SIZE) {
    const { data, error } = await query(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(error.message);
    rows.push(...(data ?? []));
    if (!data || data.length < PAGE_SIZE) return rows;
  }
}

async function pull(admin: SupabaseClient, deviceKey: string, tenantId: string) {
  const since = new Date(Date.now() - HISTORY_DAYS * 86_400_000);
  const sinceTime = since.toISOString();
  const sinceDate = sinceTime.slice(0, 10);
  const t = (table: string, select = "*") =>
    admin.from(table).select(select).eq("tenant_id", tenantId);

  const [
    organization,
    members,
    financePosition,
    lastCount,
  ] = await Promise.all([
    admin.from("tenants")
      .select("id, name, logo_path, bank_name, bank_account_number, bank_account_name")
      .eq("id", tenantId).single(),
    admin.rpc("device_members", { p_device_key: deviceKey }),
    admin.rpc("device_finance_position", { p_device_key: deviceKey }),
    t("stock_movements", "at").eq("type", "adjustment")
      .order("at", { ascending: false }).limit(1),
  ]);
  for (const result of [organization, members, financePosition, lastCount]) {
    if (result.error) throw new Error(result.error.message);
  }

  const tables: Record<string, Query> = {
    stock_items: (a, b) => t("stock_items").order("id").range(a, b),
    stock_batches: (a, b) =>
      t("stock_batches")
        .or(`quantity_remaining.gt.0,received_at.gte.${sinceTime}`)
        .order("id").range(a, b),
    production_recipes: (a, b) =>
      t("production_recipes", "*, stock_items(name, unit)").order("id").range(a, b),
    customers: (a, b) => t("customers").order("id").range(a, b),
    ledger_entries: (a, b) =>
      t("ledger_entries", "*, customers(name)").gte("date", sinceDate)
        .order("id").range(a, b),
    sales: (a, b) =>
      t(
        "sales",
        "*, sale_lines(*), profiles!recorded_by(full_name), " +
          "voided_by_profile:profiles!voided_by(full_name)",
      ).gte("date_time", sinceTime).order("id").range(a, b),
    cash_entries: (a, b) =>
      t("cash_entries", "*, profiles!recorded_by(full_name)")
        .gte("date_time", sinceTime).order("id").range(a, b),
    expenses: (a, b) =>
      t("expenses", "*, profiles!recorded_by(full_name)")
        .gte("date", sinceDate).order("id").range(a, b),
    production_runs: (a, b) =>
      t("production_runs", "*, profiles!recorded_by(full_name)")
        .gte("recorded_at", sinceTime).order("id").range(a, b),
    stock_movements: (a, b) =>
      t("stock_movements", "*, profiles!by_whom(full_name)")
        .gte("at", sinceTime).order("id").range(a, b),
    drivers: (a, b) => t("drivers").order("id").range(a, b),
    vehicles: (a, b) => t("vehicles").order("id").range(a, b),
    load_outs: (a, b) =>
      t("load_outs").or(`status.eq.on_road,date_time.gte.${sinceTime}`)
        .order("id").range(a, b),
    sync_flags: (a, b) => t("sync_flags").is("checked_at", null).order("id").range(a, b),
  };

  const names = Object.keys(tables);
  const results = await Promise.all(names.map((name) => fetchAll(tables[name])));

  return {
    pulled_at: new Date().toISOString(),
    history_since: sinceTime,
    organization: organization.data,
    members: members.data,
    finance_position: financePosition.data,
    last_stock_count_at: (lastCount.data?.[0] as { at?: string } | undefined)?.at ?? null,
    tables: Object.fromEntries(names.map((name, i) => [name, results[i]])),
  };
}

async function push(admin: SupabaseClient, deviceKey: string, operations: unknown[]) {
  const results: unknown[] = [];
  for (const operation of operations.slice(0, MAX_OPERATIONS_PER_PUSH)) {
    const { data, error } = await admin.rpc("apply_device_operation", {
      p_device_key: deviceKey,
      p_op: operation,
    });
    if (error) {
      // Not a refusal of this record (those come back as data) but the
      // device being switched off or the database being unreachable:
      // stop, so later records aren't applied before this one.
      return { results, stopped: error.message };
    }
    results.push(data);
  }
  return { results };
}

Deno.serve(async (request) => {
  const preflight = handleCorsPreflight(request);
  if (preflight) return preflight;

  let body: { action?: string; device_key?: string; operations?: unknown[] };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Send a JSON body." }, 400);
  }
  const deviceKey = body.device_key ?? "";

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: device, error: deviceError } = await admin.rpc("device_for_key", {
    p_device_key: deviceKey,
  });
  if (deviceError || !device) {
    return json(
      { error: deviceError?.message ?? "This device is not set up for offline use" },
      403,
    );
  }

  try {
    if (body.action === "pull") {
      return json(await pull(admin, deviceKey, device.tenant_id));
    }
    if (body.action === "push") {
      if (!Array.isArray(body.operations)) {
        return json({ error: "operations must be a list" }, 400);
      }
      return json(await push(admin, deviceKey, body.operations));
    }
    return json({ error: "Unknown action" }, 400);
  } catch (error) {
    console.error("device-sync failed:", error);
    return json({ error: "Sync failed on the server. Try again shortly." }, 500);
  }
});
