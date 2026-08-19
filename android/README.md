# GaelGrounds for Android

Native Android build (Kotlin + Jetpack Compose), targeting the exact same
Supabase project as the iOS app (`ios/GaelGrounds/Config/SupabaseConfig.swift`)
and the website (`src/lib/supabaseClient.ts`). No backend changes needed --
it's a third client against the same data.

## Setup: Grounds map API key

The Grounds map screen needs a Google Maps SDK for Android API key to
render tiles. Get one from the [Google Cloud Console](https://console.cloud.google.com/)
(enable the "Maps SDK for Android" API on a project, create a key), then
add it to `android/local.properties` (already gitignored, auto-created by
Android Studio on first sync):

```
MAPS_API_KEY=your-key-here
```

Without it, every other screen works fine -- only the map surface stays
blank.

## What's here so far

- Full Gradle project skeleton (`settings.gradle.kts`, root and `app`
  `build.gradle.kts`, a real generated Gradle wrapper)
- Real launcher icons generated from the actual app icon
  (`../` website repo's `AppIcon-1024.png`), not a placeholder
- Supabase client wiring (`data/Supa.kt`), matching the iOS/web project
  URL and anon key exactly
- Full email/password auth flow (`ui/auth/`) with the same 16+ age
  confirmation gate as iOS (`AuthView.swift`) and web (`AuthPage.tsx`),
  and the same post-signup `user_profiles` row insert as `AuthContext.tsx`
- Data models mirroring every table iOS/web use (`data/model/`) --
  Match, MatchSummary, Ground, GroundSummary, County, CountyTeam,
  Competition, Honour, UserProfile, UserVisit, UserMatchAttendance,
  UserPersonalMatch, AchievementDefinition/UserAchievement, Friendship,
  MatchReport -- all as `@Serializable` data classes with the same
  `snake_case` column mapping as the Postgrest wire format.
- A service layer (`data/service/`) mirroring the iOS `Services/` folder:
  `MatchService`, `GroundService`, `CountyService`, `FriendService`,
  `AvatarService`, `AchievementsService` (the full achievement-evaluation
  logic -- ground/match counts, home/road county achievements, province
  and county/country completionist achievements -- ported rule-for-rule
  from `AchievementsService.swift`), `LeaderboardService` (including the
  Bronze/Silver/Gold tier tallying), `ProximityCheckInService`, and
  `RealtimeWatcher`.
- A bottom-nav shell (`ui/navigation/GaelGroundsNavHost.kt`) mirroring the
  6-tab layout in `MainTabView.swift`: Home, Matches, Grounds, Counties,
  Leaderboard, Profile. `RootGate` always shows this shell -- like iOS,
  only the Profile tab swaps in the Auth screen when signed out, the rest
  of the app is browsable without an account. `RootGate` also owns the
  proximity check-in prompt (a global alert, same as `RootView.swift`).
- Full-parity screens for every tab:
  - **Dashboard** -- upcoming/live fixtures (live via Realtime on
    `matches`), stat tiles when signed in.
  - **Matches** -- search, sport filter, county/competition/venue filters,
    Upcoming/Fixtures/Results tabs, year-grouped results, personal match
    logging ("My Matches" -- add via dialog, long-press to delete).
    Tapping a match opens **Match detail**: attendees (live via Realtime
    on `user_match_attendance`) and a check-in/undo button wired to the
    same achievement-evaluation flow as iOS's `CheckInPanel`.
  - **Grounds** -- searchable list with visited badges, a **Grounds map**
    (coloured pins: green visited / grey not, bigger + bordered for a
    county's primary ground -- needs the API key above). **Ground
    detail** shows games you've seen there and a check-in-here flow with
    notes and live visitor updates (Realtime on `user_visits`), mirroring
    `GroundCheckInPanel.swift`.
  - **Counties** -- grouped by province; **County detail** shows teams,
    home grounds and roll of honour; **Team detail** shows that team's
    upcoming fixtures and recent results.
  - **Leaderboard** -- Overall / My County / per-province / Most Bronze /
    Most Silver / Top Gold tabs, Everyone vs Friends scope, sort by
    matches or grounds.
  - **Profile** -- editable display name, avatar upload (Android's Photo
    Picker, no runtime permission needed), stats, supported county
    picker, achievements with pin/unpin (same 4-achievement cap as iOS),
    Best Game Ever (starrable from the matches-attended list), matches
    attended and grounds visited history, a Friends link, sign out, and
    account deletion via the same `delete-account` Edge Function iOS
    uses.
  - **Friends** -- search, send/accept/decline requests, remove a friend
    (premium-to-send is enforced server-side by RLS, same as iOS).
  - **Proximity check-in** -- a location permission request and a "check
    in at X?" prompt when within 2km of a ground hosting a match today,
    fired on sign-in and every app resume, mirroring
    `ProximityCheckInService.swift`.

## What's not built yet

- **Premium / Play Billing** -- iOS gates friend requests, the
  leaderboard, and match-history limits behind a StoreKit subscription.
  RLS still enforces the real limits server-side either way, but there's
  no Android purchase flow or paywall UI yet -- this needs a Google Play
  Console listing and Play Billing integration, analogous to the App
  Store Connect + Paid Applications Agreement blocker already worked
  through for iOS (see the main session history: banking verification
  and a W-8BEN tax form were both required before iOS purchases would
  even resolve -- expect a similar non-code setup step for Play Billing).
- **Push notifications** (FCM) -- not ported.
- **Month-level sub-grouping** within a year on the Matches Results tab
  -- only year headers are ported, not year-then-month like iOS.
- **Free-tier match-limit re-check before the proximity prompt** -- iOS
  calls `canLogAnotherMatch` before showing the prompt; Android skips
  this client-side prediction since there's no premium UI to react to it
  yet, but RLS still enforces the real 10-match cap either way.

## Honest verification caveats

This was written with **no Android SDK available** in the build
environment -- `com.android.application` and all AndroidX/Google Play
Services artifacts live on Google's Maven repo (`dl.google.com`), which
this sandbox's network proxy returns `403 Forbidden` on. That means:

- **Not verified**: anything Android-Gradle-Plugin-specific -- resource
  linking, manifest merging, R8/D8, actually producing an APK. This needs
  Android Studio (or a CI runner with real Android SDK access) to build
  for the first time. Compose Navigation, the extended Material icon
  pack, `play-services-location`, `play-services-maps`, and
  `maps-compose` are all AndroidX/Google-Maven-only artifacts and
  couldn't be checked against real bytecode the way the Supabase client
  calls below were -- the location and map integrations in particular
  (`FusedLocationProviderClient.getCurrentLocation`, `MarkerComposable`,
  `GoogleMap`) are written from well-established, extensively-documented
  API knowledge, not decompiled confirmation.
- **Actually verified**: every Supabase Kotlin API call in this code --
  `signUpWith`, `signInWith`, `signOut`, `sessionStatus`, `currentSessionOrNull`,
  the Postgrest `select`/`filter`/`eq`/`neq`/`gte`/`isIn`/`ilike`/`or`/`order`/
  `limit`/`single`/`decodeList`/`decodeSingle`, `Columns.raw` for partial
  selects, `Functions.invoke`, `UserSession.user`, `Storage.from().upload()`/
  `.publicUrl()`, and Realtime's `channel()`/`postgresChangeFlow<T>()`/
  `subscribe()`/`unsubscribe()` -- was checked against the real decompiled
  library bytecode for version `3.0.3` (via a scratch Gradle project
  pulling the real `.aar`s from Maven Central with `isTransitive = false`,
  then `javap -p`), not written from memory. Package names, method
  signatures, and field names are confirmed correct as of that version.
- Real mistakes this caught and fixed before commit: `Row` initially
  imported from the wrong Compose package (`material3` instead of
  `foundation.layout`); the filter builder's "is in a list" method is
  named `isIn`, not `in` (a reserved word in Kotlin); raw partial-column
  selects need `Columns.raw(...)`, not a nested `select("...")` call
  inside the request builder; `private val` at file scope in Kotlin is
  file-private, not package-private like a similar Swift/Java pattern
  might suggest -- caught when `LeaderboardScreen.kt` needed a lookup
  table declared in `LeaderboardViewModel.kt`.

**First thing to do in Android Studio**: open this `android/` folder,
let Gradle sync (it'll need the real Android SDK, which Android Studio
installs automatically), and confirm it actually compiles and runs on an
emulator/device. Given the verification gap above, treat the first sync
as the real first test of this code -- Compose UI code in particular
(every screen under `ui/`) has had no automated or decompiled check at
all, only careful manual review against the same conventions used
throughout `data/`.

## Dependencies

- Jetpack Compose (Material 3), BOM `2024.09.02`, plus
  `material-icons-extended` for icons used outside the small curated core
  set
- `androidx.navigation:navigation-compose` for the tab/detail navigation
- `io.github.jan-tennert.supabase` (Kotlin Multiplatform Supabase client)
  `3.0.3` -- Postgrest, Auth, Storage, Functions, Realtime
- Ktor Android client engine
- Coroutines, kotlinx.serialization
- Coil (image loading, for avatars/ground photos)
- `com.google.android.gms:play-services-location` (proximity check-in)
- `com.google.android.gms:play-services-maps` + `com.google.maps.android:maps-compose`
  (Grounds map -- needs `MAPS_API_KEY`, see Setup above)

## Branch discipline

This lives on the `android-playstore` branch of `GaelGrounds-1-`,
isolated from the iOS app (in review on the App Store as of this
writing) and never merged into `main`. Only files under `android/` are
ever touched from this branch's commits -- nothing under `ios/`,
`GaelGrounds.xcodeproj/`, or `GaelGrounds/` gets modified here.
