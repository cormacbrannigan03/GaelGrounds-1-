# GaelGrounds for iOS

Native SwiftUI rewrite of GaelGrounds, talking to the same Supabase project
as the (now-retired) web app. All the Swift source lives under
`ios/GaelGrounds/` — there's no `.xcodeproj` checked in, because Xcode
project files aren't something that can be safely hand-written outside
Xcode itself. Setup takes about two minutes:

## 1. Create the Xcode project

1. Open Xcode → **File → New → Project… → iOS → App**.
2. Product Name: `GaelGrounds`. Interface: **SwiftUI**. Language: **Swift**.
   Uncheck "Use Core Data" and "Include Tests" (not used here).
3. Save it anywhere convenient — you'll delete Xcode's generated source
   files in the next step and replace them with the ones in this folder.

## 2. Swap in this source tree

1. In the new project, delete the two files Xcode generated for you:
   `GaelGroundsApp.swift` and `ContentView.swift` (Move to Trash).
2. In Finder, drag the **contents** of this repo's `ios/GaelGrounds/`
   folder (the `App`, `Config`, `Models`, `Services`, `Utilities`, `Views`
   subfolders) into the Xcode project navigator, dropped onto the
   `GaelGrounds` group.
3. In the dialog: check **"Copy items if needed"**, choose
   **"Create groups"**, and make sure the `GaelGrounds` target is checked.

## 3. Add the Supabase package

1. **File → Add Package Dependencies…**
2. URL: `https://github.com/supabase/supabase-swift`
3. Dependency rule: **Up to Next Major Version**.
4. When prompted for which library products to add, select **`Supabase`**
   and add it to the `GaelGrounds` target.

## 4. Set the deployment target

Project settings → target `GaelGrounds` → General → **Minimum Deployments**:
set to **iOS 16.0** or later (the code uses `NavigationStack`,
`.refreshable`, and Swift Concurrency throughout).

## 5. Build & run

⌘R. Sign-up requires a valid email (Supabase sends a confirmation link) —
use a real inbox you can access on the simulator/device, or disable email
confirmation for this project in the Supabase dashboard under
**Authentication → Providers → Email** while developing.

---

## What's already wired up

- **Auth** — email/password sign up & sign in (`Services/AuthViewModel.swift`).
- **Live check-ins** — `Views/Matches/CheckInPanel.swift` and
  `Views/Grounds/GroundCheckInPanel.swift` subscribe to Postgres changes via
  `client.realtimeV2.channel(...).postgresChange(...)`, so check-ins from
  other users appear without a refresh.
- **User-submitted ground photos** — `GroundCheckInPanel` also has a Photos
  section: `PhotosPicker` lets a signed-in user pick a photo, which is
  re-encoded as JPEG and uploaded to the public `ground-photos` storage
  bucket by `Services/GroundPhotoService.swift`, then attached to that
  user's `user_visits.photo_urls` row for the ground (adding a photo also
  counts as checking in, if you haven't already). The gallery shown is
  every visitor's photos for that ground, aggregated client-side from the
  same `user_visits` rows the check-in list already loads.
- **Live match/fixture updates** — Dashboard, MatchesView and
  MatchDetailView subscribe to the `matches` table the same way (via the
  shared `Services/RealtimeWatcher.swift` helper), so results and new
  fixtures written by the server-side `sync-matches` ingestion pipeline
  (`supabase/functions/sync-matches/`) appear without the app needing to
  poll or know anything about where the data came from.
- **Counties → teams → grounds → roll of honour**, **fixtures/results with
  search**, and a **profile** with stats + achievements — one-to-one with
  the feature set of the web app.
- **County-colour match banners** — `Views/Components/MatchCardView.swift`
  washes each side of a fixture/result card with that county's own colours
  (`counties.primary_colour`/`secondary_colour`): primary colour at that
  team's edge, fading through the county's secondary colour to fully
  transparent by the card's midpoint, so the card's own background shows
  through rather than a hardcoded white — this is what keeps it looking
  right in dark mode too. `Color(hex:)` (`Utilities/Theme.swift`) parses
  the stored hex strings; `MatchService.resolveSummaries` resolves each
  side's `CountyColours` alongside the team name it already looked up.
  Club fixtures (no county colours tracked) and any county missing colour
  data just render with no wash.
- **Bounded, cached match loading** — `MatchesView` used to fetch every row
  in `matches` (an ~8,000-row archive at this point) on every visit, which
  was the main reason the Results tab was slow. `MatchService.fetchRecent`
  now loads only the most recent matches by default; typing a search runs
  `MatchService.search`, a dedicated server-side query (by competition
  text, season year, or team/ground name resolved via cached reference
  data) that still reaches the full history without requiring it all in
  memory. `counties`/`county_teams`/`grounds` — small, slow-changing
  tables reused by every `resolveSummaries` call — are now fetched once
  and cached for the app's lifetime rather than re-fetched on every load;
  the tradeoff is that a colour/name/ground change made server-side while
  the app is running won't show up until the app restarts.
- **Fixture/result model**: `Models/Match.swift` carries `matchType`,
  `homeCountyTeamId`/`awayCountyTeamId` (or `homeClubId`/`awayClubId` for
  club fixtures), `groundId`, `competition`, `round`, `playedAt`, and
  `homeScore`/`awayScore`. `isLive`/`isUpcoming`/`isPast` are computed
  client-side from `playedAt` and whether a score is recorded — `isLive`
  specifically means "not yet scored, and it's been 0–2.5 hours since
  `playedAt`," which is the same definition the push-notification triggers
  below reproduce in SQL, so "live" means one consistent thing everywhere.
  (Earlier revisions of this file described a different shape with no live
  concept at all — that's no longer accurate as of the current model.)
- The Supabase URL and anon key are hardcoded in `Config/SupabaseConfig.swift`
  (same reasoning as the web app: the anon key is safe client-side, every
  table is behind Row Level Security).
- **Premium subscription (€1.99/mo)** — `Services/PremiumStore.swift` drives
  a single StoreKit 2 auto-renewable subscription (`com.gaelgrounds.premium.monthly`)
  and syncs the result onto the signed-in user's `user_profiles.is_premium`/
  `premium_expires_at`. Verification is **client-side only**: StoreKit 2 does
  real on-device cryptographic verification of each transaction, but there's
  no backend receipt check, so a technically sophisticated free user could in
  principle call the Supabase API directly and set their own `is_premium` to
  `true` without ever paying. That's a deliberately accepted tradeoff for
  this pass — everything the flag actually gates is still enforced
  server-side regardless of how `is_premium` got set:
  - The combined 10-match free-tier cap (official check-ins +
    `user_personal_matches`, via `public.total_match_count()`) and the
    pre-2019 logging cutoff are restrictive Postgres RLS policies
    (`supabase/migrations/20260801023511_free_tier_match_limits.sql`) —
    not just a client-side check.
  - Sending a friend request requires `is_premium = true`, enforced by the
    `friendships` table's insert policy
    (`supabase/migrations/20260801023442_create_friendships_table.sql`).
  - The leaderboard (`Views/Leaderboard/LeaderboardView.swift`) only ranks
    premium profiles — a client-side filter, since it's a display concern,
    not a data-access one (the underlying `user_profiles` rows stay
    publicly readable, same as before, since check-in attendee lists and
    friend search both still need to read any user's display name).

  Two things need doing manually before this works, same spirit as the
  Xcode project itself not being checked in:
  1. Create the `com.gaelgrounds.premium.monthly` auto-renewable
     subscription product in App Store Connect (Monetization →
     Subscriptions), priced at €1.99/month.
  2. In Xcode: **Signing & Capabilities → + Capability → In-App Purchase**
     on the `GaelGrounds` target. For local testing without a live App
     Store Connect product, add `ios/GaelGrounds.storekit` (already in this
     repo, matching the real product ID/price) to the scheme's
     **Run → Options → StoreKit Configuration**.
- **Push notifications** — exactly two triggers, both decided at the
  database level so a buggy or bypassed client can't skip them:
  a friend request received, and a friend checking into a match while it's
  genuinely **live** (not a retroactive check-in, and never for anything
  added via the personal "Add Match" feature — manually-logged matches are
  never a live event). `Services/PushNotificationService.swift` requests
  notification permission and registers for APNs once someone's signed in
  (`GaelGroundsApp.swift`'s `.task(id: auth.userId)`, same pattern as
  `PremiumStore.userId`), uploading the device token to
  `device_push_tokens`. Two Postgres trigger functions
  (`supabase/migrations/20260804162310_notify_on_friend_request.sql`,
  `..._notify_on_live_checkin.sql`) call the new
  `send-push-notification` Edge Function via `net.http_post` — the same
  pg_cron-calls-an-Edge-Function pattern already used by `sync-matches` —
  authenticated with a Vault-stored shared secret. See
  `supabase/functions/send-push-notification/README.md` for exactly how
  it fires and what "live" means in SQL.

  Like the premium subscription, this **cannot be tested end-to-end
  without an Apple Developer Program membership** (not set up yet, per
  earlier conversation) — Push Notifications needs an Xcode capability
  plus an APNs Auth Key generated in the Apple Developer portal. The full
  manual setup (capability, key generation, five Edge Function secrets) is
  in that same Edge Function README rather than duplicated here.

## Honest caveats

This was written without access to Xcode, an iOS SDK, or even a Swift
compiler — the sandbox this was built in is Linux-only, so **none of this
Swift code has been compiled or run**. Two things are most likely to need a
small fix on first build:

1. **The `supabase-swift` API surface.** Method names used here
   (`signInWithPassword`, `client.from(_:)`, `client.realtimeV2.channel(_:)`,
   `.postgresChange(AnyAction.self, ...)`, `SupabaseClientOptions(db: .init(decoder:encoder:))`,
   and — new in the ground-photos feature — `client.storage.from(_:).upload(_:data:options:)`
   and `.getPublicURL(path:)`; and new in the premium/friends work —
   `client.rpc(_:params:)` (`MatchService.matchCount`, calling the
   `total_match_count` Postgres function) and `.ilike(_:value:)`/
   `.neq(_:value:)`/`.or(_:)` on the Postgrest filter builder
   (`FriendService.searchUsers`))
   were checked against the current SDK docs/source, but this library has
   renamed things across major versions before. If Xcode flags a signature
   mismatch, check `Sources/Supabase/Types.swift` and `Sources/Auth/AuthClient.swift`
   in the `supabase-swift` repo for whatever version Xcode resolves. Also
   new: `.upsert(_:onConflict:)` (`PushNotificationService`, upserting
   `device_push_tokens` keyed on the `token` column rather than the row's
   `id`).
2. **Date decoding.** `Services/SupabaseManager.swift` tries ISO 8601 with
   and without fractional seconds. If a decode ever fails, it's almost
   always this.
3. **StoreKit 2** (`Services/PremiumStore.swift`) is Apple's own framework,
   not a third-party dependency, so the risk of an API mismatch is much
   lower — but it's still unverified against a real compiler. The pattern
   used (`Product.products(for:)`, `product.purchase()`,
   `Transaction.currentEntitlements`/`Transaction.updates` as
   `AsyncSequence`s of `VerificationResult<Transaction>`, `AppStore.sync()`
   for restore) matches Apple's documented StoreKit 2 API as of iOS 16+.
4. **Push notifications' UIKit/UserNotifications surface**
   (`AppDelegate.swift`, `PushNotificationService.swift`): same
   lower-but-nonzero risk as StoreKit — `@UIApplicationDelegateAdaptor`,
   `UNUserNotificationCenter.requestAuthorization`,
   `UIApplication.registerForRemoteNotifications()`, and the
   `UNUserNotificationCenterDelegate` completion-handler-based
   `willPresent` signature (used instead of guessing at an async overlay
   that may not exist for this specific delegate method) all match
   documented, stable-since-iOS-10-or-earlier Apple APIs.
5. **`npm:jose` for APNs JWT signing** (`supabase/functions/send-push-notification/shared/apns.ts`):
   the one genuinely third-party piece of the push-notification work,
   unverified against a real Deno runtime for the same reason nothing in
   this repo has been (no compiler/runtime access in this sandbox). The
   APNs auth-token shape itself (ES256, `kid`/`iss`/`iat`, bearer token to
   `api.push.apple.com`) is Apple's documented token-based provider auth,
   not guessed.

Everything else — the data model, the RLS-respecting query shapes, the
achievement/check-in logic — mirrors the web app's already-tested behavior
against the live database, so it should be functionally correct even where
the exact Swift syntax needs a tweak.
