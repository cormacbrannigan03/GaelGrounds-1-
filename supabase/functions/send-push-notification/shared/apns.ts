import { importPKCS8, SignJWT } from "npm:jose@5";

// APNs' HTTP/2 provider API requires an ES256-signed auth token per Apple's
// token-based (.p8 key) auth scheme -- no certificates, no long-lived
// connections to manage ourselves. Deno's native fetch negotiates HTTP/2
// automatically over TLS ALPN when the server supports it (which
// api.push.apple.com does), so a plain `fetch` call is enough; no HTTP/2
// client library needed.

export interface ApnsResult {
  token: string;
  ok: boolean;
  status: number;
  /** True for tokens Apple says are dead (uninstalled/reset) -- caller should delete the row. */
  shouldRemoveToken: boolean;
}

let cachedKey: CryptoKey | null = null;

async function getSigningKey(): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  const pem = Deno.env.get("APNS_PRIVATE_KEY");
  if (!pem) throw new Error("APNS_PRIVATE_KEY not set");
  // Secrets set via `supabase secrets set` are single-line, so the PEM's
  // newlines are typically escaped as literal "\n" -- un-escape them back
  // into real line breaks before handing the key to jose.
  cachedKey = await importPKCS8(pem.replace(/\\n/g, "\n"), "ES256");
  return cachedKey;
}

async function buildAuthToken(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  if (!keyId || !teamId) throw new Error("APNS_KEY_ID / APNS_TEAM_ID not set");

  const key = await getSigningKey();
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuedAt()
    .setIssuer(teamId)
    .sign(key);
}

export async function sendPush(deviceToken: string, title: string, body: string): Promise<ApnsResult> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID");
  if (!bundleId) throw new Error("APNS_BUNDLE_ID not set");

  const environment = Deno.env.get("APNS_ENVIRONMENT") ?? "production";
  const host = environment === "sandbox" ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const authToken = await buildAuthToken();

  const response = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${authToken}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: { title, body },
        sound: "default",
      },
    }),
  });

  // 410 = device unregistered. 400 can also mean a dead token
  // (BadDeviceToken/Unregistered) rather than a real request error --
  // either way, prune it so it doesn't get retried forever.
  let shouldRemoveToken = response.status === 410;
  if (response.status === 400) {
    try {
      const payload = await response.clone().json();
      if (payload.reason === "BadDeviceToken" || payload.reason === "Unregistered") {
        shouldRemoveToken = true;
      }
    } catch {
      // Non-JSON body -- nothing more we can learn from it.
    }
  }

  return { token: deviceToken, ok: response.ok, status: response.status, shouldRemoveToken };
}
