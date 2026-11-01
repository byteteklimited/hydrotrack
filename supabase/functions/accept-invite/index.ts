// HydroTrack — accept-invite Edge Function.
//
// Lets someone WITHOUT an account join an organization using the invite
// code an owner/admin gave them, choosing their own PIN. The code itself
// is the authorization (single use, expiring, addressed to one phone or
// email), so this function is called without a signed-in session.
// Deploy with JWT verification off:
//   supabase functions deploy accept-invite --no-verify-jwt
//
// People who already have an account don't come here: they sign in and
// enter the code in the app, which calls the accept_invitation RPC.
//
// Creating an account needs auth.admin.createUser, i.e. the service-role
// key. Supabase injects it into this function's environment; it is never
// sent to, or stored in, the Flutter app.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflight } from "../_shared/cors.ts";

interface AcceptInviteRequest {
  code?: string;
  pin?: string;
}

interface Invitation {
  tenant_id: string;
  full_name: string;
  phone: string | null;
  email: string | null;
}

const PIN_PATTERN = /^\d{6}$/;

function toE164Nigeria(localPhone: string): string {
  const digits = localPhone.replace(/[^\d]/g, "");
  const withoutLeadingZero = digits.startsWith("0") ? digits.slice(1) : digits;
  return withoutLeadingZero.startsWith("234")
    ? `+${withoutLeadingZero}`
    : `+234${withoutLeadingZero}`;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  let body: AcceptInviteRequest;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body" }, 400);
  }

  const code = body.code?.trim().toUpperCase();
  const pin = body.pin?.trim();
  if (!code) {
    return jsonResponse({ error: "Enter your invite code." }, 400);
  }
  if (!pin || !PIN_PATTERN.test(pin)) {
    return jsonResponse({ error: "PIN must be exactly 6 digits." }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: invitation, error: peekError } = await admin
    .rpc("peek_invitation", { p_code: code })
    .single<Invitation>();
  if (peekError || !invitation) {
    return jsonResponse(
      {
        error: peekError?.message ??
          "This invite code is invalid or has expired. Ask your admin for a new one.",
      },
      400,
    );
  }

  const identity = invitation.phone
    ? { phone: toE164Nigeria(invitation.phone), phone_confirm: true }
    : { email: invitation.email!, email_confirm: true };

  const { data: created, error: createError } = await admin.auth.admin
    .createUser({
      ...identity,
      password: pin,
      user_metadata: {
        full_name: invitation.full_name,
        phone: invitation.phone,
      },
    });

  if (createError || !created?.user) {
    const alreadyExists = createError?.message?.toLowerCase().includes(
      "already",
    );
    return jsonResponse(
      {
        error: alreadyExists
          ? "An account with this phone number already exists. Sign in, then enter the code under \"Join an organization\"."
          : createError?.message ?? "Couldn't create your account.",
      },
      alreadyExists ? 409 : 400,
    );
  }

  const { data: tenantId, error: redeemError } = await admin.rpc(
    "redeem_invitation_for_new_user",
    { p_code: code, p_user_id: created.user.id },
  );

  if (redeemError) {
    // Don't leave an account behind that belongs to no organization.
    await admin.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: redeemError.message }, 400);
  }

  // What the app signs in with next (local phone format, or email).
  return jsonResponse(
    { tenantId, phone: invitation.phone, email: invitation.email },
    200,
  );
});
