// HydroTrack — send-debt-reminders Edge Function.
//
// Called by the `send-debt-reminders` pg_cron job (migration 0014), never
// by the app. Claims the reminders due today (claim_due_debt_reminders
// decides who and writes the message) and sends each as an SMS through
// HydroTrack's Termii account, then records the result.
//
// Deploy with JWT verification off; the shared cron secret is the
// authorization instead:
//   supabase functions deploy send-debt-reminders --no-verify-jwt
//
// Secrets (supabase secrets set ...):
//   DEBT_REMINDERS_CRON_SECRET  must match the Vault secret
//                               'debt_reminders_cron_secret'
//   TERMII_API_KEY              from the Termii dashboard
//   TERMII_SENDER_ID            the approved sender name, e.g. HydroTrack
//   TERMII_BASE_URL             optional, default https://v3.api.termii.com
//   TERMII_CHANNEL              optional, default "dnd" (reaches numbers on
//                               Do-Not-Disturb; needs DND enabled on the
//                               Termii account). Use "generic" otherwise.
//
// Until TERMII_API_KEY and TERMII_SENDER_ID are set it does nothing, so no
// customer's reminder count is used up while sending isn't possible.
import { createClient } from "npm:@supabase/supabase-js@2";

interface DueReminder {
  id: string;
  phone: string;
  message: string;
}

// Each call claims at most this many; the loop stops before the
// function's time limit and the next scheduled run picks up the rest.
const BATCH_SIZE = 100;
const TIME_BUDGET_MS = 100_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function sameSecret(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function sendSms(
  reminder: DueReminder,
  config: { apiKey: string; senderId: string; baseUrl: string; channel: string },
): Promise<{ sent: boolean; messageId?: string; error?: string }> {
  try {
    const response = await fetch(`${config.baseUrl}/api/sms/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: config.apiKey,
        to: reminder.phone,
        from: config.senderId,
        sms: reminder.message,
        type: "plain",
        channel: config.channel,
      }),
    });
    const body = await response.json().catch(() => ({}));
    if (response.ok && body.message_id) {
      return { sent: true, messageId: String(body.message_id) };
    }
    return {
      sent: false,
      error: `Termii ${response.status}: ${body.message ?? JSON.stringify(body)}`,
    };
  } catch (error) {
    return { sent: false, error: `Request failed: ${error}` };
  }
}

Deno.serve(async (request) => {
  const expectedSecret = Deno.env.get("DEBT_REMINDERS_CRON_SECRET") ?? "";
  const givenSecret = request.headers.get("x-cron-secret") ?? "";
  if (!expectedSecret || !sameSecret(givenSecret, expectedSecret)) {
    return json({ error: "Not allowed" }, 401);
  }

  const apiKey = Deno.env.get("TERMII_API_KEY");
  const senderId = Deno.env.get("TERMII_SENDER_ID");
  if (!apiKey || !senderId) {
    console.log("send-debt-reminders: Termii is not configured; nothing sent.");
    return json({ configured: false, sent: 0, failed: 0 });
  }
  const config = {
    apiKey,
    senderId,
    baseUrl: (Deno.env.get("TERMII_BASE_URL") ?? "https://v3.api.termii.com")
      .replace(/\/+$/, ""),
    channel: Deno.env.get("TERMII_CHANNEL") ?? "dnd",
  };

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
      const result = await sendSms(reminder, config);
      const { error: finishError } = await admin.rpc("finish_debt_reminder", {
        p_id: reminder.id,
        p_sent: result.sent,
        p_provider_message_id: result.messageId ?? null,
        p_error: result.error ?? null,
      });
      if (finishError) {
        console.error("finish_debt_reminder failed:", finishError.message);
      }
      if (result.sent) sent++;
      else failed++;
    }
  }

  console.log(`send-debt-reminders: ${sent} sent, ${failed} failed.`);
  return json({ configured: true, sent, failed });
});
