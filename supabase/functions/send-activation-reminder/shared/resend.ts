// Same bare-fetch Resend dispatch as send-waitlist-email/shared/resend.ts --
// no SDK needed for a single POST. Kept as its own copy rather than a
// shared import since Supabase Edge Functions each deploy independently
// and don't share a module graph across function directories.

export interface ResendResult {
  ok: boolean;
  status: number;
  id?: string;
  error?: string;
}

export async function sendEmail(to: string, subject: string, html: string, text: string): Promise<ResendResult> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) throw new Error("RESEND_API_KEY not set");

  const from = Deno.env.get("WAITLIST_EMAIL_FROM") ?? "GaelGrounds <hello@gaelgrounds.ie>";

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "authorization": `Bearer ${apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ from, to, subject, html, text }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    return { ok: false, status: response.status, error: body };
  }

  const payload = await response.json().catch(() => ({}));
  return { ok: true, status: response.status, id: payload.id };
}
