import { createClient } from "npm:@supabase/supabase-js@2";

// Service-role client, same convention as
// supabase/functions/sync-matches/shared/supabaseAdmin.ts -- bypasses RLS
// by design. Lifted into a cross-function _shared/ folder (Supabase's own
// documented convention for code shared between Edge Functions) since this
// is the first time two functions in this repo need the same helper.
export function createAdminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceRoleKey) {
    throw new Error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not available in the function environment");
  }

  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false },
  });
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
