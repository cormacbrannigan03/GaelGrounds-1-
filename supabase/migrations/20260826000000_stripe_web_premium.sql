-- Tracks the Stripe customer/subscription behind a website-purchased
-- premium subscription. Premium itself is still just is_premium/
-- premium_expires_at on user_profiles (added 2026-08-01) -- the same
-- columns iOS's StoreKit flow writes -- so a purchase on either platform
-- unlocks the same account everywhere, per the product decision to link
-- premium to the account rather than the platform.
--
-- Unlike iOS's PremiumStore (which writes is_premium directly from the
-- client after StoreKit verifies a purchase -- see ios/README.md's
-- "Honest caveats" for that accepted tradeoff), the web purchase flow
-- does NOT trust the client: only the stripe-webhook Edge Function
-- (running as service_role, which bypasses RLS entirely) ever sets
-- is_premium/premium_expires_at for a Stripe-driven purchase. That
-- function needs stripe_customer_id to know which user a given Stripe
-- webhook event belongs to (Stripe's subscription objects don't carry
-- our user id directly), and stripe_subscription_id to detect renewals
-- vs. a genuinely new subscription and to support a future "manage
-- subscription" link to Stripe's customer portal.
alter table public.user_profiles
  add column if not exists stripe_customer_id text,
  add column if not exists stripe_subscription_id text;

create unique index if not exists user_profiles_stripe_customer_id_idx
  on public.user_profiles (stripe_customer_id)
  where stripe_customer_id is not null;

-- Client code never reads/writes these directly (no UI needs to), and the
-- existing "users can update their own profile" policy would otherwise
-- let a signed-in user overwrite their own stripe_customer_id -- pointless
-- for them, but worth closing off since it's a stripe_customer_id, i.e.
-- something meant to be a trustworthy link back to a real paying Stripe
-- customer. Revoking column-level access forces every write through the
-- service-role webhook function instead.
revoke update (stripe_customer_id, stripe_subscription_id) on public.user_profiles from authenticated;
