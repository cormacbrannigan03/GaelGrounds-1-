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
- **Fixture/result model matches how the backend actually structures
  matches**: `Models/Match.swift` carries `competitionId`/`season`/`round`/
  `matchDate`/`throwInTime`/`province`/`status`/`winner` rather than a single
  timestamp. There's no "live" badge or in-play score concept anywhere in
  the app — this app only ever shows an upcoming fixture (no score) or a
  completed result (final score); `status` comes from the server, it's never
  guessed from the current time on-device.
- The Supabase URL and anon key are hardcoded in `Config/SupabaseConfig.swift`
  (same reasoning as the web app: the anon key is safe client-side, every
  table is behind Row Level Security).

## Honest caveats

This was written without access to Xcode, an iOS SDK, or even a Swift
compiler — the sandbox this was built in is Linux-only, so **none of this
Swift code has been compiled or run**. Two things are most likely to need a
small fix on first build:

1. **The `supabase-swift` API surface.** Method names used here
   (`signInWithPassword`, `client.from(_:)`, `client.realtimeV2.channel(_:)`,
   `.postgresChange(AnyAction.self, ...)`, `SupabaseClientOptions(db: .init(decoder:encoder:))`,
   and — new in the ground-photos feature — `client.storage.from(_:).upload(_:data:options:)`
   and `.getPublicURL(path:)`)
   were checked against the current SDK docs/source, but this library has
   renamed things across major versions before. If Xcode flags a signature
   mismatch, check `Sources/Supabase/Types.swift` and `Sources/Auth/AuthClient.swift`
   in the `supabase-swift` repo for whatever version Xcode resolves.
2. **Date decoding.** `Services/SupabaseManager.swift` tries ISO 8601 with
   and without fractional seconds. If a decode ever fails, it's almost
   always this.

Everything else — the data model, the RLS-respecting query shapes, the
achievement/check-in logic — mirrors the web app's already-tested behavior
against the live database, so it should be functionally correct even where
the exact Swift syntax needs a tweak.
