import Stripe from "npm:stripe@17";

// Deno (what Supabase Edge Functions run on) has no Node `http`/`crypto`
// module the way stripe-node's default HTTP client expects, so this
// explicitly opts into Stripe's Fetch-based client -- the documented way
// to run stripe-node on Deno/Cloudflare Workers/other edge runtimes.
// httpClient/webhook signature verification here follow Stripe's published
// edge-runtime guidance; unlike the Supabase client calls elsewhere in this
// repo, this hasn't been checked against decompiled library bytecode (this
// sandbox can reach npm but there's no way to actually run a Deno process
// here) -- treat first real deploy as the first real test, same caveat as
// everything else in supabase/functions.
export function createStripeClient(): Stripe {
  const secretKey = Deno.env.get("STRIPE_SECRET_KEY");
  if (!secretKey) {
    throw new Error("STRIPE_SECRET_KEY not available in the function environment");
  }
  return new Stripe(secretKey, {
    httpClient: Stripe.createFetchHttpClient(),
    apiVersion: "2024-06-20",
  });
}
