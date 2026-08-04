// send-push-notification — sends a push for exactly two events: a new
// friend request, and a friend checking into a match while it's actually
// live. Both are decided at the database level (see the trigger functions
// in supabase/migrations/20260804162310_notify_on_friend_request.sql and
// 20260804162325_notify_on_live_checkin.sql) -- this function trusts the
// event it's given rather than re-deciding anything, since the triggers
// are the single source of truth for "does this qualify."
//
// Invocation: POST /functions/v1/send-push-notification
//   { "type": "friend_request", "requester_id": "...", "addressee_id": "..." }
//   { "type": "live_checkin", "user_id": "...", "match_id": "..." }
//
// Auth: deployed with verify_jwt=false (invoked by a Postgres trigger via
// pg_net, not a signed-in user) and instead checks the `x-push-secret`
// header against the PUSH_NOTIFY_SECRET Edge Function secret, same
// pattern as sync-matches/SYNC_SECRET.

import { createAdminClient } from "./shared/supabaseAdmin.ts";
import { sendPush } from "./shared/apns.ts";

type SupabaseAdmin = ReturnType<typeof createAdminClient>;

interface FriendRequestEvent {
  type: "friend_request";
  requester_id: string;
  addressee_id: string;
}

interface LiveCheckinEvent {
  type: "live_checkin";
  user_id: string;
  match_id: string;
}

type PushEvent = FriendRequestEvent | LiveCheckinEvent;

Deno.serve(async (req) => {
  const expectedSecret = Deno.env.get("PUSH_NOTIFY_SECRET");
  const providedSecret = req.headers.get("x-push-secret");
  if (!expectedSecret || providedSecret !== expectedSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  let event: PushEvent;
  try {
    event = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const supabase = createAdminClient();

  try {
    const result = event.type === "friend_request"
      ? await handleFriendRequest(supabase, event)
      : await handleLiveCheckin(supabase, event);
    return json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return json({ error: message }, 500);
  }
});

async function handleFriendRequest(supabase: SupabaseAdmin, event: FriendRequestEvent) {
  const { data: requester } = await supabase
    .from("user_profiles")
    .select("display_name")
    .eq("id", event.requester_id)
    .single();

  const requesterName = requester?.display_name ?? "A fan";
  return await dispatchToUsers(
    supabase,
    [event.addressee_id],
    "New friend request",
    `${requesterName} sent you a friend request`,
  );
}

async function handleLiveCheckin(supabase: SupabaseAdmin, event: LiveCheckinEvent) {
  const { data: profile } = await supabase
    .from("user_profiles")
    .select("display_name")
    .eq("id", event.user_id)
    .single();
  const userName = profile?.display_name ?? "A friend";

  const matchLabel = await describeMatch(supabase, event.match_id);

  const { data: friendships } = await supabase
    .from("friendships")
    .select("requester_id, addressee_id")
    .eq("status", "accepted")
    .or(`requester_id.eq.${event.user_id},addressee_id.eq.${event.user_id}`);

  const friendIds = (friendships ?? []).map((f) =>
    f.requester_id === event.user_id ? f.addressee_id : f.requester_id
  );

  if (friendIds.length === 0) {
    return { sent: 0, reason: "no accepted friends" };
  }

  return await dispatchToUsers(
    supabase,
    friendIds,
    "Live check-in",
    `${userName} just checked in${matchLabel ? ` at ${matchLabel}` : ""}`,
  );
}

/** Builds "Dublin v Kerry" (plus ground, if known) the same way MatchService.resolveSummaries joins client-side, just server-side and best-effort. */
async function describeMatch(supabase: SupabaseAdmin, matchId: string): Promise<string | null> {
  const { data: match } = await supabase
    .from("matches")
    .select("home_county_team_id, away_county_team_id, ground_id")
    .eq("id", matchId)
    .single();
  if (!match) return null;

  const teamIds = [match.home_county_team_id, match.away_county_team_id].filter(Boolean) as string[];
  const { data: teams } = teamIds.length
    ? await supabase.from("county_teams").select("id, county_id").in("id", teamIds)
    : { data: [] as { id: string; county_id: string }[] };

  const countyIds = (teams ?? []).map((t) => t.county_id);
  const { data: counties } = countyIds.length
    ? await supabase.from("counties").select("id, name").in("id", countyIds)
    : { data: [] as { id: string; name: string }[] };

  const countyNameByTeamId = new Map(
    (teams ?? []).map((t) => [t.id, counties?.find((c) => c.id === t.county_id)?.name]),
  );
  const homeName = match.home_county_team_id ? countyNameByTeamId.get(match.home_county_team_id) : undefined;
  const awayName = match.away_county_team_id ? countyNameByTeamId.get(match.away_county_team_id) : undefined;

  if (!homeName || !awayName) return null;

  let label = `${homeName} v ${awayName}`;
  if (match.ground_id) {
    const { data: ground } = await supabase.from("grounds").select("name").eq("id", match.ground_id).single();
    if (ground?.name) label += ` (${ground.name})`;
  }
  return label;
}

async function dispatchToUsers(supabase: SupabaseAdmin, userIds: string[], title: string, body: string) {
  const { data: tokenRows } = await supabase
    .from("device_push_tokens")
    .select("token")
    .in("user_id", userIds);

  const tokens = (tokenRows ?? []).map((r) => r.token);
  if (tokens.length === 0) {
    return { sent: 0, reason: "no registered devices" };
  }

  const staleTokens: string[] = [];
  let sent = 0;

  for (const token of tokens) {
    try {
      const result = await sendPush(token, title, body);
      if (result.ok) sent++;
      if (result.shouldRemoveToken) staleTokens.push(token);
    } catch (err) {
      console.error(`push send failed for token ${token}:`, err instanceof Error ? err.message : err);
    }
  }

  if (staleTokens.length > 0) {
    await supabase.from("device_push_tokens").delete().in("token", staleTokens);
  }

  return { sent, attempted: tokens.length, prunedTokens: staleTokens.length };
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}
