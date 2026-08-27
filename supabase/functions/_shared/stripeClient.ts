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
    // Matches the GaelGrounds Stripe account's actual API version -- when
    // the webhook destination was created in the Stripe Dashboard,
    // 2024-06-20 (this file's original pin) wasn't even a selectable
    // option, meaning the account has moved well past it. Keeping this
    // explicit (rather than omitting apiVersion, which would silently
    // follow whatever the account's default happens to be at any given
    // moment) so a future account-level default change can't silently
    // change the shape of data this code parses without a deliberate edit
    // here.
    apiVersion: "2026-07-29.dahlia" as Stripe.LatestApiVersion,
  });
}
