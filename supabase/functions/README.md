# Supabase Edge Functions

- `sync-matches/` — the GAA results ingestion pipeline. See its own README.
- `create-checkout-session/`, `stripe-webhook/`, `create-portal-session/` — the website's Stripe-based Premium subscription flow. See below.
- `_shared/` — code used by more than one function (`supabaseAdmin.ts`, `stripeClient.ts`).

## Website Premium (Stripe)

Premium is one subscription that unlocks the same account everywhere — website, iOS, and Android all read/write the same `is_premium`/`premium_expires_at` columns on `user_profiles`. iOS's StoreKit flow (`ios/GaelGrounds/Services/PremiumStore.swift`) writes those columns client-side after verifying a purchase locally — an accepted tradeoff documented in `ios/README.md`. The website flow below does **not** trust the client the same way: only `stripe-webhook`, running as `service_role`, ever writes `is_premium`/`premium_expires_at` for a Stripe-driven purchase. `20260826000000_stripe_web_premium.sql` also revoked client-side write access to `stripe_customer_id`/`stripe_subscription_id` specifically, so those can only be set by the webhook or by `create-checkout-session`'s own service-role client — a signed-in user can't point their account at someone else's Stripe customer via the browser.

**How it fits together:**
1. `src/pages/Premium.tsx` calls `create-checkout-session`, which creates (or reuses) a Stripe Customer for the signed-in user and returns a Checkout Session URL. The browser redirects there.
2. Stripe's own hosted Checkout page collects payment.
3. Stripe calls `stripe-webhook` (not the browser) once the subscription is actually created/renewed/cancelled. That function verifies Stripe's signature, then updates `is_premium`/`premium_expires_at`/`stripe_subscription_id`.
4. The browser is redirected back to `/premium?checkout=success`, but the page notes the upgrade may take a few seconds to land, since step 3 happens async and isn't guaranteed to have completed yet.
5. `create-portal-session` (used from the "Manage subscription" link on `/premium` and Profile) hands an existing subscriber a link to Stripe's own hosted billing portal to update payment details or cancel — deliberately not reimplemented here, since Stripe's portal already handles regional requirements around making cancellation easy to find.

### One-time manual setup (not doable from this sandbox)

This sandbox has a live-mode Stripe MCP connection but it disconnected mid-build and there's no tool here to set Edge Function secrets — both of the following need to happen in the Stripe/Supabase dashboards directly:

1. **Stripe Dashboard → Product catalog**: create a Product ("GaelGrounds Premium") with a recurring monthly Price at €1.99 (matching `PremiumStore.monthlyProductId`'s iOS price point). Copy the Price ID (`price_...`).
2. **Stripe Dashboard → Developers → API keys**: copy the live **Secret key** (`sk_live_...`).
3. **Stripe Dashboard → Developers → Webhooks → Add endpoint**: URL = `https://wksahsfkldxhusiftosj.supabase.co/functions/v1/stripe-webhook`, events = `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`. Copy the **Signing secret** (`whsec_...`) it generates.
4. **Supabase Dashboard → Edge Functions → Secrets**, set:
   - `STRIPE_SECRET_KEY` = the value from step 2
   - `STRIPE_WEBHOOK_SECRET` = the value from step 3
   - `STRIPE_PRICE_ID` = the value from step 1
   (`SUPABASE_URL`/`SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY` are already available to every Edge Function automatically.)

Until those secrets are set, `create-checkout-session` fails closed with a clear "server misconfigured" error rather than a confusing one, and `stripe-webhook` returns 401 for every request (safe default — better than silently accepting unverified webhook calls).

### Honest verification caveat

Written with no way to actually run a Deno process in this sandbox (same constraint documented in `android/README.md` and `ios/README.md`). The Stripe API calls follow Stripe's own published Node/edge-runtime SDK documentation (`Stripe.createFetchHttpClient()`, `constructEventAsync` for signature verification without Node's `crypto` module) rather than decompiled/run confirmation. `npx tsc --noEmit` and `npm run build` were run for real against `src/pages/Premium.tsx` and the `Profile.tsx`/`App.tsx`/`Navbar.tsx` changes and both passed clean — but that only proves the *website* TypeScript compiles, not that the *Edge Functions* (Deno, a different runtime) behave correctly at request time. Treat the first real Stripe test payment (Stripe Dashboard has a full test mode with test card numbers, separate from the live account this project is connected to) as the first real verification of this code path.
