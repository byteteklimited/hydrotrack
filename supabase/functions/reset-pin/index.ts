// HydroTrack — reset-pin Edge Function.
//
// A staff member who forgot their PIN enters the one-time reset code an
// Owner/Admin gave them (create_pin_reset, migration 0017) and a new
// 6-digit PIN. The code is the authorization, so this is called without a
// signed-in session. Deploy with JWT verification off:
//   supabase functions deploy reset-pin --no-verify-jwt
//
// Setting a password needs auth.admin, i.e. the service-role key, which
// Supabase injects here; it never reaches the app.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

const PIN_PATTERN = /^\d{6}$/;

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

// Local Nigerian format (080…) for the app to sign in with.
function toLocalPhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  return digits.startsWith("234") ? `0${digits.slice(3)}` : digits;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: { code?: string; pin?: string };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body" }, 400);
  }
  const code = body.code?.trim().toUpperCase();
  const pin = body.pin?.trim();
  if (!code) return jsonResponse({ error: "Enter your reset code." }, 400);
  if (!pin || !PIN_PATTERN.test(pin)) {
    return jsonResponse({ error: "PIN must be exactly 6 digits." }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: target, error: peekError } = await admin.rpc("peek_pin_reset", {
    p_code: code,
  });
  if (peekError || !target) {
    return jsonResponse(
      {
        error: peekError?.message ??
          "This reset code is invalid or has expired. Ask your admin for a new one.",
      },
      400,
    );
  }

  const { error: updateError } = await admin.auth.admin.updateUserById(
    target.user_id,
    { password: pin },
  );
  if (updateError) {
    return jsonResponse({ error: "Couldn't set the new PIN. Try again." }, 500);
  }

  await admin.rpc("complete_pin_reset", { p_code: code });
  return jsonResponse({ phone: toLocalPhone(target.phone ?? "") }, 200);
});
