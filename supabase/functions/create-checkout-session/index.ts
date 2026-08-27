// create-checkout-session — starts a Stripe Checkout session for the
// GaelGrounds Premium monthly subscription, for a signed-in website user.
//
// Invocation: POST /functions/v1/create-checkout-session, called via
// `supabase.functions.invoke('create-checkout-session')` from
// src/pages/Premium.tsx, which forwards the caller's Supabase session JWT
// automatically. Deployed with the default verify_jwt=true (unlike
// sync-matches, which is invoked by pg_cron rather than a signed-in user).
//
// This function only creates the Checkout session and hands back its URL
// for the browser to redirect to -- it never itself sets is_premium. Only
// the stripe-webhook function does that, once Stripe confirms the payment
// actually went through. See supabase/functions/README.md.

import { createClient } from "npm:@supabase/supabase-js@2";
import { createAdminClient, json } from "../_shared/supabaseAdmin.ts";
import { createStripeClient } from "../_shared/stripeClient.ts";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  // The browser sends this before the real POST whenever a cross-origin
  // request carries custom headers (Authorization, apikey, content-type,
  // all of which supabase-js adds) -- without an explicit 2xx-with-CORS-
  // headers response here, the browser blocks the actual request before
  // it's ever sent, which is exactly what was happening: Subscribe looked
  // like it did nothing because the preflight silently failed.
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "unauthorized" }, 401);

  // A user-scoped client (anon key + the caller's own JWT) so
  // `auth.getUser()` verifies the token against Supabase Auth itself
  // rather than trusting a client-decoded claim.
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) return json({ error: "server misconfigured" }, 500);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);
  const user = userData.user;

  const priceId = Deno.env.get("STRIPE_PRICE_ID");
  if (!priceId) return json({ error: "server misconfigured: STRIPE_PRICE_ID not set" }, 500);

  const admin = createAdminClient();
  const stripe = createStripeClient();

  try {
    const { data: profile } = await admin
      .from("user_profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .single();

    let customerId = profile?.stripe_customer_id ?? null;

    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;
      await admin.from("user_profiles").update({ stripe_customer_id: customerId }).eq("id", user.id);
    }

    const origin = req.headers.get("origin") ?? "https://app.gaelgrounds.ie";

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      client_reference_id: user.id,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${origin}/premium?checkout=success`,
      cancel_url: `${origin}/premium?checkout=cancelled`,
      subscription_data: {
        metadata: { supabase_user_id: user.id },
      },
    });

    if (!session.url) return json({ error: "Stripe did not return a checkout URL" }, 500);
    return json({ url: session.url });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});
