// HydroTrack — send-alerts Edge Function.
//
// Called by the `send-alerts` pg_cron job (migration 0022). Texts new
// owner alerts (daily summary, low stock) to each organization's business
// phone through Termii. Without Termii it does nothing (alerts still show
// in the app). Deploy with JWT verification off:
//   supabase functions deploy send-alerts --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2";
import { isFromScheduler, json, sendSms, termiiConfig } from "../_shared/termii.ts";

interface AlertSms {
  id: string;
  phone: string;
  message: string;
}

Deno.serve(async (request) => {
  if (!isFromScheduler(request)) return json({ error: "Not allowed" }, 401);

  const config = termiiConfig();
  if (!config) return json({ configured: false, sent: 0, failed: 0 });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data, error } = await admin.rpc("claim_alert_sms", { p_limit: 200 });
  if (error) {
    console.error("claim_alert_sms failed:", error.message);
    return json({ error: "Couldn't load alerts" }, 500);
  }

  let sent = 0;
  let failed = 0;
  for (const alert of (data ?? []) as AlertSms[]) {
    const result = await sendSms(config, alert.phone, alert.message);
    await admin.rpc("finish_alert_sms", {
      p_id: alert.id,
      p_sent: result.sent,
      p_error: result.error ?? null,
    });
    if (result.sent) sent++;
    else failed++;
  }
  return json({ configured: true, sent, failed });
});
