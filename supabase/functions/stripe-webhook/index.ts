// stripe-webhook — the only thing that ever activates or deactivates a
// website-purchased premium subscription. Trusts Stripe's signed webhook
// payload, not anything the client claims -- deliberately the opposite
// trust model from iOS's PremiumStore.swift (which writes is_premium
// client-side after StoreKit verifies locally; see ios/README.md's
// "Honest caveats"). Writes go through the service-role admin client,
// which is also the only thing still allowed to write
// stripe_customer_id/stripe_subscription_id after
// 20260826000000_stripe_web_premium.sql revoked client column access.
//
// Deployed with verify_jwt=false (Stripe calls this directly, no Supabase
// session) -- authenticated instead by verifying the `stripe-signature`
// header against STRIPE_WEBHOOK_SECRET, which Stripe generates when the
// webhook endpoint is registered in the Stripe Dashboard. See
// supabase/functions/README.md for that one-time setup step.
//
// Handles the three events that matter for is_premium/premium_expires_at:
//   checkout.session.completed   -- first successful subscription payment
//   customer.subscription.updated -- renewal, plan change, or a status
//                                    change (e.g. past_due, canceled)
//   customer.subscription.deleted -- subscription actually ended
// Every other event type is acknowledged (200) and ignored, matching
// Stripe's own guidance to always return 2xx for events you don't handle
// so Stripe doesn't keep retrying them.

import { createAdminClient, json } from "../_shared/supabaseAdmin.ts";
import { createStripeClient } from "../_shared/stripeClient.ts";
import type Stripe from "npm:stripe@17";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const signature = req.headers.get("stripe-signature");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!signature || !webhookSecret) return json({ error: "unauthorized" }, 401);

  const stripe = createStripeClient();
  const rawBody = await req.text();

  let event: Stripe.Event;
  try {
    // constructEventAsync, not the sync constructEvent -- Deno has no
    // Node `crypto` module, which the sync verifier needs.
    event = await stripe.webhooks.constructEventAsync(rawBody, signature, webhookSecret);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: `signature verification failed: ${message}` }, 400);
  }

  const admin = createAdminClient();

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.mode !== "subscription" || !session.subscription) break;

        const userId = session.client_reference_id ?? session.subscription_data?.metadata?.supabase_user_id;
        const subscriptionId =
          typeof session.subscription === "string" ? session.subscription : session.subscription.id;
        const subscription = await stripe.subscriptions.retrieve(subscriptionId);

        await activatePremium(admin, { userId, customerId: session.customer, subscription });
        break;
      }

      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        await activatePremium(admin, {
          userId: subscription.metadata?.supabase_user_id ?? null,
          customerId: subscription.customer,
          subscription,
        });
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        await deactivatePremium(admin, {
          userId: subscription.metadata?.supabase_user_id ?? null,
          customerId: subscription.customer,
        });
        break;
      }

      default:
        break;
    }

    return json({ received: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("stripe-webhook failed:", message);
    return json({ error: message }, 500);
  }
});

const ACTIVE_STATUSES: Stripe.Subscription.Status[] = ["active", "trialing", "past_due"];

async function activatePremium(
  admin: ReturnType<typeof createAdminClient>,
  opts: { userId: string | null; customerId: string | Stripe.Customer | Stripe.DeletedCustomer | null; subscription: Stripe.Subscription },
) {
  const { subscription } = opts;
  const customerId = typeof opts.customerId === "string" ? opts.customerId : opts.customerId?.id ?? null;
  const isActive = ACTIVE_STATUSES.includes(subscription.status);

  const update = {
    is_premium: isActive,
    premium_expires_at: new Date(subscription.current_period_end * 1000).toISOString(),
    stripe_subscription_id: subscription.id,
    ...(customerId ? { stripe_customer_id: customerId } : {}),
  };

  await writeToMatchingUser(admin, opts.userId, customerId, update);
}

async function deactivatePremium(
  admin: ReturnType<typeof createAdminClient>,
  opts: { userId: string | null; customerId: string | Stripe.Customer | Stripe.DeletedCustomer | null },
) {
  const customerId = typeof opts.customerId === "string" ? opts.customerId : opts.customerId?.id ?? null;
  await writeToMatchingUser(admin, opts.userId, customerId, { is_premium: false });
}

// Resolves which user_profiles row a Stripe event belongs to. Prefers the
// supabase_user_id we stamped into Checkout/subscription metadata; falls
// back to matching on stripe_customer_id (set the first time that
// customer ever checked out, in create-checkout-session) for events where
// metadata isn't present -- e.g. a subscription update triggered from
// Stripe's own customer portal rather than our Checkout flow.
async function writeToMatchingUser(
  admin: ReturnType<typeof createAdminClient>,
  userId: string | null,
  customerId: string | null,
  update: Record<string, unknown>,
) {
  if (userId) {
    const { error } = await admin.from("user_profiles").update(update).eq("id", userId);
    if (!error) return;
  }
  if (customerId) {
    await admin.from("user_profiles").update(update).eq("stripe_customer_id", customerId);
  }
}
