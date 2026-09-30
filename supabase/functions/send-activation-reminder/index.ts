// send-activation-reminder -- sends the "you signed up but haven't logged
// a match yet, here's your referral code" email. Fired hourly by pg_cron
// (see supabase/migrations/20260930230030_schedule_activation_reminder_cron.sql)
// via pg_net once a user crosses the 48-hour mark with zero matches
// logged and isn't premium -- the database decides who qualifies, this
// function just sends the email it's told to, same dispatch pattern as
// send-waitlist-email and send-push-notification.
//
// Invocation: POST /functions/v1/send-activation-reminder
//   { "email": "someone@example.com", "displayName": "Sarah", "referralCode": "57H8KM" }
//
// Auth: deployed with verify_jwt=false (invoked by a Postgres cron job via
// pg_net, not a signed-in user) and instead checks the
// `x-activation-reminder-secret` header against the
// ACTIVATION_REMINDER_SECRET Edge Function secret, same pattern as
// WAITLIST_EMAIL_SECRET / SYNC_SECRET.

import { sendEmail } from "./shared/resend.ts";

interface ActivationReminderEvent {
  email: string;
  displayName?: string | null;
  referralCode: string;
}

Deno.serve(async (req) => {
  const expectedSecret = Deno.env.get("ACTIVATION_REMINDER_SECRET");
  const providedSecret = req.headers.get("x-activation-reminder-secret");
  if (!expectedSecret || !providedSecret || providedSecret !== expectedSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  let event: ActivationReminderEvent;
  try {
    event = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  if (!event.email || !event.referralCode) {
    return json({ error: "email and referralCode required" }, 400);
  }

  try {
    const { subject, html, text } = buildEmail(event.displayName, event.referralCode);
    const result = await sendEmail(event.email, subject, html, text);
    return json(result, result.ok ? 200 : 502);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});

function buildEmail(displayName: string | null | undefined, referralCode: string) {
  const firstName = (displayName ?? "").trim().split(/\s+/)[0] || "";
  const greeting = firstName ? `Hey ${escapeHtml(firstName)} — you're missing out` : "Hey — you're missing out";
  const subject = "Get Premium free — just for inviting 3 mates";
  const code = escapeHtml(referralCode);
  const shareUrl = `https://app.gaelgrounds.ie/?ref=${encodeURIComponent(referralCode)}`;

  const html = `
<div style="font-family: -apple-system, Helvetica, Arial, sans-serif; max-width: 560px; margin: 0 auto; color: #1a1a1a;">
  <div style="text-align:center; padding: 24px 0 8px;">
    <span style="display:inline-flex; align-items:center; justify-content:center; width:40px; height:40px; border-radius:8px; background:linear-gradient(135deg,#1c7c4f,#2fa86a); color:#fff; font-weight:800; font-size:0.9rem;">GG</span>
  </div>
  <h1 style="font-size: 22px; margin: 16px 0 8px;">${greeting}</h1>
  <p style="font-size: 15px; line-height: 1.5;">You signed up to GaelGrounds but haven't logged a match yet. That's the whole point of the app — your own record of every ground and game you've been at, building up over time.</p>
  <p style="font-size: 15px; line-height: 1.5;">Takes about 30 seconds: pick the match, tick the ground, done.</p>
  <table role="presentation" style="width:100%; margin: 24px 0;">
    <tr>
      <td style="text-align:center; padding: 0 6px;"><a href="https://apps.apple.com/app/id6799921807" style="background:#1c7c4f; color:#fff; text-decoration:none; padding:12px 20px; border-radius:999px; font-weight:700; font-size:14px; display:inline-block;">Open on iOS</a></td>
      <td style="text-align:center; padding: 0 6px;"><a href="https://app.gaelgrounds.ie" style="background:#1c1c1c; color:#fff; text-decoration:none; padding:12px 20px; border-radius:999px; font-weight:700; font-size:14px; display:inline-block;">Open on the Web</a></td>
    </tr>
  </table>
  <div style="background:#f4f9f6; border:1px solid #d9ecdf; border-radius:12px; padding:20px; margin: 28px 0;">
    <h2 style="font-size: 18px; margin: 0 0 10px; color:#1c7c4f;">Here's the bit that costs you nothing</h2>
    <p style="font-size: 15px; line-height: 1.5; margin: 0 0 12px;">You don't have to pay a cent for Premium. Get <strong>3 friends</strong> to sign up using your code and log a match each, and you get <strong>1 month of Premium free</strong> — automatically, no card details, no catch.</p>
    <p style="font-size: 15px; line-height: 1.5; margin: 0 0 12px;">Premium unlocks unlimited match logging, matches from before 2019, adding friends, and the leaderboard — normally €1.99/month, free for you if you just share your code.</p>
    <p style="font-size: 17px; margin: 16px 0 4px;">Your code: <strong style="color:#1c7c4f;">${code}</strong></p>
    <p style="font-size: 15px; line-height: 1.5; margin: 0;">Share link: <a href="${shareUrl}">${shareUrl.replace("https://", "")}</a></p>
  </div>
  <p style="font-size: 13px; color:#777; margin-top: 32px;">GaelGrounds — not affiliated with the GAA.</p>
</div>
`;

  const text = `${greeting.replace(" — you're missing out", " — you're missing out")}

You signed up to GaelGrounds but haven't logged a match yet. That's the whole point of the app — your own record of every ground and game you've been at, building up over time.

Takes about 30 seconds: pick the match, tick the ground, done.

Open on iOS: https://apps.apple.com/app/id6799921807
Open on the Web: https://app.gaelgrounds.ie

---

HERE'S THE BIT THAT COSTS YOU NOTHING

You don't have to pay a cent for Premium. Get 3 friends to sign up using your code and log a match each, and you get 1 month of Premium free — automatically, no card details, no catch.

Premium unlocks unlimited match logging, matches from before 2019, adding friends, and the leaderboard — normally €1.99/month, free for you if you just share your code.

Your code: ${referralCode}
Share link: ${shareUrl}

GaelGrounds — not affiliated with the GAA.`;

  return { subject, html, text };
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
