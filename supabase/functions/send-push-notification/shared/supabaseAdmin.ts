import { createClient } from "npm:@supabase/supabase-js@2";

// Service-role client — deliberately the only kind of Supabase client this
// function ever creates. It bypasses RLS by design: device_push_tokens
// only grants owner-scoped access to the app's anon-key clients, and this
// is the one path in via the service_role key, which never leaves the
// Edge Function runtime.
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
