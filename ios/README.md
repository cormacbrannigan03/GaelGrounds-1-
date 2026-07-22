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
- **Counties → teams → grounds → roll of honour**, **fixtures/results with
  search**, and a **profile** with stats + achievements — one-to-one with
  the feature set of the web app.
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
   `.postgresChange(AnyAction.self, ...)`, `SupabaseClientOptions(db: .init(decoder:encoder:))`)
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
