// delete-account — permanently deletes the calling user's own account and
// all their data. Required by App Store Review Guideline 5.1.1(v): any app
// that lets someone create an account must also let them delete it from
// within the app.
//
// Invocation: POST /functions/v1/delete-account (no body needed)
//
// Auth: deployed with the default verify_jwt=true, so Supabase's gateway
// already rejects any request without a valid signed-in user's JWT before
// this code runs. The caller's own id is then resolved from that same JWT
// via a request-scoped client — never trusted from a client-supplied body,
// since this is a destructive, self-service-only operation (a user can
// only ever delete themselves, never anyone else).
//
// Every user-data table (user_profiles, user_visits, user_match_attendance,
// user_achievements, friendships, user_personal_matches, match_reports) has
// `on delete cascade` back to auth.users, so a single
// admin.auth.admin.deleteUser call removes all of it in one step — no
// per-table cleanup needed. The one exception is
// manual_match_submissions.submitted_by, which is `on delete no action`
// (it's admin-reviewed historical sync-pipeline data, not personal content
// tied to the account) — nulled out first so it can never block the delete.

import { createClient } from "npm:@supabase/supabase-js@2";
import { createAdminClient } from "./shared/supabaseAdmin.ts";

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return json({ error: "server misconfigured" }, 500);
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) {
    return json({ error: "unauthorized" }, 401);
  }
  const userId = userData.user.id;

  const admin = createAdminClient();

  try {
    await admin
      .from("manual_match_submissions")
      .update({ submitted_by: null })
      .eq("submitted_by", userId);

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    if (deleteError) {
      return json({ error: deleteError.message }, 500);
    }

    return json({ deleted: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
