import { createClient } from "npm:@supabase/supabase-js@2";

// Service-role client — the only way to actually delete an auth.users row
// (client-side anon-key clients can never do this; the key never leaves
// this Edge Function runtime). Same factory shape as
// send-push-notification/shared/supabaseAdmin.ts.
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
