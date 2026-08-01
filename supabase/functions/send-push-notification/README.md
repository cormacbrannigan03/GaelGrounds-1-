# send-push-notification

Sends exactly two kinds of push: a new friend request, and a friend
checking into a match while it's actually live. Both events are decided
entirely at the database level by trigger functions — this function never
re-decides "does this qualify," it just looks up who to notify and sends.

```
supabase/functions/send-push-notification/
  index.ts                  entry point: friend_request / live_checkin branches
  shared/supabaseAdmin.ts   service-role client (bypasses RLS by design)
  shared/apns.ts            ES256 JWT signing (npm:jose) + the actual APNs HTTP call
```

## How it fires

1. `supabase/migrations/20260804162310_notify_on_friend_request.sql` adds a
   trigger on `friendships` — any new row (`status = 'pending'`, which is
   every insert by default) calls this function with
   `{ type: "friend_request", requester_id, addressee_id }`.
2. `supabase/migrations/20260804162325_notify_on_live_checkin.sql` adds a
   trigger on `user_match_attendance` that reproduces
   `ios/GaelGrounds/Models/Match.swift`'s `isLive` exactly in SQL (not yet
   scored, `now()` within 2.5 hours after `played_at`) and only fires when
   that's true. A retroactive check-in into a 2022 match, or a check-in
   before throw-in, triggers nothing — there's no trigger on
   `user_personal_matches` at all, since manually-logged matches are never
   a live event.

Both triggers call this function via `net.http_post` (the same pg_cron →
Edge Function pattern already used for `sync-matches`), authenticated with
a Vault-stored shared secret (`push_notify_secret`), not a signed-in
user's JWT — this function is deployed with `verify_jwt=false`.

## Outstanding manual steps

None of the following can be done from a migration or from this sandbox —
each has to happen once, by hand, same as `sync-matches`'s `SYNC_SECRET`:

**1. Set the shared trigger secret:**
```bash
# get the value the triggers are already sending:
#   select decrypted_secret from vault.decrypted_secrets where name = 'push_notify_secret';
supabase secrets set PUSH_NOTIFY_SECRET=<that value>
```

**2. Generate an APNs Auth Key** (requires an active Apple Developer
Program membership — not yet set up as of writing, same blocker already
noted for the premium subscription's StoreKit setup):
- Apple Developer portal → Certificates, IDs & Profiles → Keys → create a
  new key with the "Apple Push Notifications service (APNs)" capability
  enabled. Note the **Key ID**, download the **.p8** file (Apple only lets
  you download it once), and note your **Team ID** (top-right of the
  portal).
- In Xcode, once the project exists: target → Signing & Capabilities → **+
  Capability → Push Notifications**, and also add **Background Modes →
  Remote notifications**.

**3. Set the APNs secrets:**
```bash
supabase secrets set APNS_KEY_ID=<Key ID from the portal>
supabase secrets set APNS_TEAM_ID=<Team ID from the portal>
supabase secrets set APNS_BUNDLE_ID=<the app's bundle identifier, e.g. com.gaelgrounds.app>
supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_XXXXXXXXXX.p8)"
supabase secrets set APNS_ENVIRONMENT=sandbox   # or "production" once shipping via TestFlight/App Store
```

**Until all of the above is done, `device_push_tokens` will happily fill
up with real device tokens (once the app is built in Xcode and someone
signs in), but every send attempt will fail** — `shared/apns.ts` throws
immediately if `APNS_KEY_ID`/`APNS_TEAM_ID`/`APNS_BUNDLE_ID`/
`APNS_PRIVATE_KEY` aren't set, and `index.ts` catches that and returns a
500 rather than silently pretending to succeed.

## Checking on it

```sql
select * from device_push_tokens order by created_at desc limit 20;
```

Edge Function logs (Supabase dashboard → Edge Functions →
send-push-notification → Logs, or the `get_logs` MCP tool) show each
send attempt, including which tokens got pruned as dead.
