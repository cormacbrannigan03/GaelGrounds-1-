// create-portal-session — hands a signed-in premium user a link to
// Stripe's hosted Customer Portal, where they can update payment details
// or cancel. Same auth pattern as create-checkout-session (verify_jwt=true,
// user-scoped client via the caller's own JWT).
//
// Deliberately does not implement cancellation itself -- Stripe's portal
// already handles that, including region-specific requirements around
// making cancellation easy to find, so there's no reason to rebuild it.

import { createClient } from "npm:@supabase/supabase-js@2";
import { createAdminClient, json } from "../_shared/supabaseAdmin.ts";
import { createStripeClient } from "../_shared/stripeClient.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "unauthorized" }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "server misconfigured" }, 500);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);

  const admin = createAdminClient();
  const { data: profile } = await admin
    .from("user_profiles")
    .select("stripe_customer_id")
    .eq("id", userData.user.id)
    .single();

  if (!profile?.stripe_customer_id) {
    return json({ error: "no Stripe subscription found for this account" }, 404);
  }

  try {
    const stripe = createStripeClient();
    const origin = req.headers.get("origin") ?? "https://gaelgrounds.app";
    const portalSession = await stripe.billingPortal.sessions.create({
      customer: profile.stripe_customer_id,
      return_url: `${origin}/profile`,
    });
    return json({ url: portalSession.url });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
