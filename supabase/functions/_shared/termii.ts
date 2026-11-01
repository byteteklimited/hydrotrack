// HydroTrack — shared SMS sending through HydroTrack's Termii account
// (debt reminders, owner alerts) and the cron-secret check both use.
//
// Secrets: TERMII_API_KEY, TERMII_SENDER_ID (required to send),
// TERMII_BASE_URL (default https://v3.api.termii.com), TERMII_CHANNEL
// (default "dnd"), DEBT_REMINDERS_CRON_SECRET (shared by scheduled jobs).

export interface TermiiConfig {
  apiKey: string;
  senderId: string;
  baseUrl: string;
  channel: string;
}

/// Null until Termii is configured; callers then send nothing.
export function termiiConfig(): TermiiConfig | null {
  const apiKey = Deno.env.get("TERMII_API_KEY");
  const senderId = Deno.env.get("TERMII_SENDER_ID");
  if (!apiKey || !senderId) return null;
  return {
    apiKey,
    senderId,
    baseUrl: (Deno.env.get("TERMII_BASE_URL") ?? "https://v3.api.termii.com")
      .replace(/\/+$/, ""),
    channel: Deno.env.get("TERMII_CHANNEL") ?? "dnd",
  };
}

export async function sendSms(
  config: TermiiConfig,
  to: string,
  message: string,
): Promise<{ sent: boolean; messageId?: string; error?: string }> {
  try {
    const response = await fetch(`${config.baseUrl}/api/sms/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: config.apiKey,
        to,
        from: config.senderId,
        sms: message,
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

/// True when the request carries the scheduled jobs' shared secret.
export function isFromScheduler(request: Request): boolean {
  const expected = Deno.env.get("DEBT_REMINDERS_CRON_SECRET") ?? "";
  const given = request.headers.get("x-cron-secret") ?? "";
  if (!expected || given.length !== expected.length) return false;
  let difference = 0;
  for (let i = 0; i < expected.length; i++) {
    difference |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  }
  return difference === 0;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
