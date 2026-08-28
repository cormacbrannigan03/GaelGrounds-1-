// send-launch-email -- one-off "the webapp is live" announcement sent to
// waiting-list signups. Same dispatch shape as send-waitlist-email (invoked
// via pg_net with the x-waitlist-secret header, not a signed-in user) but a
// separate function/subject/body since it's a distinct message sent later,
// not the "you're on the list" welcome email.
//
// Invocation: POST /functions/v1/send-launch-email
//   { "email": "someone@example.com" }

import { sendEmail } from "./shared/resend.ts";

interface LaunchEvent {
  email: string;
}

Deno.serve(async (req) => {
  const expectedSecret = Deno.env.get("WAITLIST_EMAIL_SECRET");
  const providedSecret = req.headers.get("x-waitlist-secret");
  if (!expectedSecret || !providedSecret || providedSecret !== expectedSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  let event: LaunchEvent;
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

const subject = "GaelGrounds is live — check in now";

const html = `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 480px; margin: 0 auto; color: #16241D;">
  <h1 style="color: #0B3D2E; font-size: 1.4rem; margin: 0 0 16px;">We're live</h1>
  <p style="font-size: 0.98rem; line-height: 1.6; margin: 0 0 16px;">
    Thanks for waiting — GaelGrounds is up and running. Check in at grounds and matches,
    track every county and sport you've supported, and start unlocking achievements.
  </p>
  <p style="margin: 0 0 24px;">
    <a href="https://app.gaelgrounds.ie/" style="display: inline-block; padding: 12px 22px; border-radius: 999px; background: #0B3D2E; color: #fff; text-decoration: none; font-weight: 700; font-size: 0.95rem;">Open GaelGrounds</a>
  </p>
  <p style="font-size: 0.95rem; line-height: 1.6; margin: 0;">
    Beir bua,<br>
    Foireann GaelGrounds
  </p>
</div>
`;

const text = `We're live

Thanks for waiting — GaelGrounds is up and running. Check in at grounds and matches, track every county and sport you've supported, and start unlocking achievements.

Open GaelGrounds: https://app.gaelgrounds.ie/

Beir bua,
Foireann GaelGrounds`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
