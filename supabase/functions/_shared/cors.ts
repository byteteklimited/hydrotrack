// HydroTrack — shared CORS handling for every Edge Function.
//
// The Flutter web build calls these functions from its own origin
// (e.g. http://localhost:xxxxx in development), which is cross-origin
// to *.supabase.co — the browser sends a CORS preflight OPTIONS request
// before the real POST. Without these headers (and without answering
// OPTIONS at all), the preflight fails with no Access-Control-Allow-Origin
// header and the browser blocks the POST before it ever reaches the
// function — surfacing to the app as a generic network/connection error,
// not whatever the function would have actually said. Mobile builds
// never hit this, since their HTTP clients don't enforce CORS — this is
// a web-only gap.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  // x-location-id: the app sends its current location with every request
  // (migration 0029), so the browser asks before sending it here too.
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-location-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function handleCorsPreflight(req: Request): Response | null {
  return req.method === "OPTIONS"
    ? new Response(null, { status: 204, headers: corsHeaders })
    : null;
}
