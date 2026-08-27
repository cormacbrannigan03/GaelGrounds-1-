// Shared CORS headers for the two Stripe functions the browser calls
// directly (create-checkout-session, create-portal-session) from
// https://app.gaelgrounds.ie. Wildcard origin is fine here -- these
// endpoints are authenticated via a Bearer token in the Authorization
// header (verified server-side against Supabase Auth), not cookies, so
// there's no CSRF exposure a stricter allow-list would prevent.
//
// stripe-webhook doesn't need this at all (Stripe calls it server-to-
// server, no browser, no preflight) and doesn't import this file.
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
