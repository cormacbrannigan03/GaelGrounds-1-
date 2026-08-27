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
    // Confirmed necessary, not just cautious: stripe-node@17's own bundled
    // default (2025-02-24.acacia, used when apiVersion is omitted) throws
    // "Managed Payments is not supported on API version ... acacia" against
    // this account -- Stripe requires 2025-03-31.basil or later for it. The
    // account's actual current dashboard version, 2026-07-29.dahlia, is
    // well past that floor, so pinning here isn't a guess this time, it's
    // what a real checkout attempt against this account requires.
    apiVersion: "2026-07-29.dahlia" as Stripe.LatestApiVersion,
  });
}
