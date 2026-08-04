// send-waitlist-email -- sends the "thanks for joining" email the moment
// someone signs up on the website's waiting list. Fired by a Postgres
// trigger (see supabase/migrations/..._notify_on_waitlist_signup.sql) via
// pg_net immediately after the insert, same dispatch pattern as
// send-push-notification: the database is the source of truth for "did
// someone actually sign up," this function just sends the email it's told
// to.
//
// Invocation: POST /functions/v1/send-waitlist-email
//   { "email": "someone@example.com" }
//
// Auth: deployed with verify_jwt=false (invoked by a Postgres trigger via
// pg_net, not a signed-in user) and instead checks the
// `x-waitlist-secret` header against the WAITLIST_EMAIL_SECRET Edge
// Function secret, same pattern as PUSH_NOTIFY_SECRET / SYNC_SECRET.

import { sendEmail } from "./shared/resend.ts";

interface WaitlistEvent {
  email: string;
}

Deno.serve(async (req) => {
  const expectedSecret = Deno.env.get("WAITLIST_EMAIL_SECRET");
  const providedSecret = req.headers.get("x-waitlist-secret");
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  let event: WaitlistEvent;
  try {
    event = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  if (!event.email) {
    return json({ error: "email required" }, 400);
  }

  try {
    const result = await sendEmail(event.email, subject, html, text);
    return json(result, result.ok ? 200 : 502);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});

const subject = "Fáilte — you're on the GaelGrounds waiting list";

const html = `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; color: #16241D;">
  <h1 style="color: #0B3D2E; font-size: 1.4rem; margin: 0 0 16px;">You're on the list</h1>
  <p style="font-size: 0.98rem; line-height: 1.6; margin: 0 0 16px;">
    Thanks so much for the support — you're officially on the GaelGrounds waiting list.
    We'll email you the moment the app is live on the App Store.
  </p>
  <p style="font-size: 0.98rem; line-height: 1.6; margin: 0 0 20px;">
    In the meantime, follow along for match-day check-ins, ground spots and updates:
  </p>
  <p style="margin: 0 0 28px;">
    <a href="https://www.instagram.com/gaelgrounds/" style="display: inline-block; margin-right: 12px; padding: 10px 18px; border-radius: 999px; background: #0B3D2E; color: #fff; text-decoration: none; font-weight: 700; font-size: 0.9rem;">Instagram</a>
    <a href="https://www.tiktok.com/@gaelgrounds" style="display: inline-block; padding: 10px 18px; border-radius: 999px; background: #0B3D2E; color: #fff; text-decoration: none; font-weight: 700; font-size: 0.9rem;">TikTok</a>
  </p>
  <p style="font-size: 0.95rem; line-height: 1.6; margin: 0;">
    Beir bua,<br>
    Foireann GaelGrounds
  </p>
</div>
`;

const text = `You're on the list

Thanks so much for the support — you're officially on the GaelGrounds waiting list. We'll email you the moment the app is live on the App Store.

In the meantime, follow along for match-day check-ins, ground spots and updates:
Instagram: https://www.instagram.com/gaelgrounds/
TikTok: https://www.tiktok.com/@gaelgrounds

Beir bua,
Foireann GaelGrounds`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
