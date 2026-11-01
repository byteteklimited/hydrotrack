// HydroTrack — send-debt-reminders Edge Function.
//
// Called by the `send-debt-reminders` pg_cron job (migration 0014), never
// by the app. Claims the reminders due today (claim_due_debt_reminders
// decides who and writes the message) and sends each as an SMS through
// HydroTrack's Termii account (_shared/termii.ts), then records the result.
// Until Termii is configured it does nothing, so no customer's reminder
// count is used up while sending isn't possible.
//
// Deploy with JWT verification off; the shared cron secret authorizes:
//   supabase functions deploy send-debt-reminders --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2";
import { isFromScheduler, json, sendSms, termiiConfig } from "../_shared/termii.ts";

interface DueReminder {
  id: string;
  phone: string;
  message: string;
}

const BATCH_SIZE = 100;
const TIME_BUDGET_MS = 100_000;

Deno.serve(async (request) => {
  if (!isFromScheduler(request)) return json({ error: "Not allowed" }, 401);

  const config = termiiConfig();
  if (!config) {
    console.log("send-debt-reminders: Termii is not configured; nothing sent.");
    return json({ configured: false, sent: 0, failed: 0 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const started = Date.now();
  let sent = 0;
  let failed = 0;
  while (Date.now() - started < TIME_BUDGET_MS) {
    const { data, error } = await admin.rpc("claim_due_debt_reminders", {
      p_limit: BATCH_SIZE,
    });
    if (error) {
      console.error("claim_due_debt_reminders failed:", error.message);
      return json({ error: "Couldn't load due reminders", sent, failed }, 500);
    }
    const due = (data ?? []) as DueReminder[];
    if (due.length === 0) break;

    for (const reminder of due) {
      const result = await sendSms(config, reminder.phone, reminder.message);
      const { error: finishError } = await admin.rpc("finish_debt_reminder", {
        p_id: reminder.id,
        p_sent: result.sent,
        p_provider_message_id: result.messageId ?? null,
        p_error: result.error ?? null,
      });
      if (finishError) console.error("finish_debt_reminder failed:", finishError.message);
      if (result.sent) sent++;
      else failed++;
    }
  }

  console.log(`send-debt-reminders: ${sent} sent, ${failed} failed.`);
  return json({ configured: true, sent, failed });
});
