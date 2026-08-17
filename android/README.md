# GaelGrounds for Android

Native Android build (Kotlin + Jetpack Compose), targeting the exact same
Supabase project as the iOS app (`ios/GaelGrounds/Config/SupabaseConfig.swift`)
and the website (`src/lib/supabaseClient.ts`). No backend changes needed --
it's a third client against the same data.

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
  `AchievementsService` (the full achievement-evaluation logic --
  ground/match counts, home/road county achievements, province and
  county/country completionist achievements -- ported rule-for-rule from
  `AchievementsService.swift`), and `LeaderboardService`.
- A bottom-nav shell (`ui/navigation/GaelGroundsNavHost.kt`) mirroring the
  6-tab layout in `MainTabView.swift`: Home, Matches, Grounds, Counties,
  Leaderboard, Profile. `RootGate` now always shows this shell -- like
  iOS, only the Profile tab swaps in the Auth screen when signed out, the
  rest of the app is browsable without an account.
- Real screens for every tab, each with its own `ViewModel`
  (`StateFlow`-backed) and Compose screen:
  - **Dashboard** -- upcoming/live fixtures, stat tiles when signed in.
  - **Matches** -- search, sport filter, Upcoming/Fixtures/Results tabs;
    tapping a match opens **Match detail**, which shows attendees and a
    check-in/undo button wired to the same achievement-evaluation flow
    as iOS's `CheckInPanel`.
  - **Grounds** -- searchable list with visited badges; **Ground detail**
    shows games you've seen there and a check-in-here flow with notes,
    mirroring `GroundCheckInPanel.swift`.
  - **Counties** -- grouped by province; **County detail** shows teams,
    home grounds and roll of honour; **Team detail** shows that team's
    upcoming fixtures and recent results.
  - **Leaderboard** -- Overall / My County / per-province tabs, Everyone
    vs Friends scope, sort by matches or grounds.
  - **Profile** -- stats, supported county picker, achievements with
    pin/unpin (same 4-achievement cap as iOS), a Friends link, sign out,
    and account deletion via the same `delete-account` Edge Function iOS
    uses.
  - **Friends** -- search, send/accept/decline requests, remove a friend
    (premium-to-send is enforced server-side by RLS, same as iOS).

## What's not built yet

- **Best Game Ever** (starring a specific attended match on your
  profile) and **avatar upload** -- both need a photo-picker flow
  (`PhotosPicker` on iOS) that hasn't been ported.
- **Live updates via Supabase Realtime** -- iOS subscribes to
  `postgres_changes` on `matches`/`user_match_attendance`/`user_visits` so
  check-ins and results appear without a manual refresh; Android reloads
  on demand instead for now.
- **Match filters (county/competition/venue), year/month result grouping,
  and "My Matches" (personal, unofficial match logging)** on the Matches
  screen -- MatchesView.swift's full filtering/grouping UI wasn't ported;
  the underlying `MatchService.fetchPersonalMatches/insert/deletePersonalMatch`
  calls exist in the service layer, just not wired to a screen yet.
- **Leaderboard achievement-tier tabs** (Most Bronze / Most Silver / Top
  Gold) -- the province and My County tabs are ported, the tier ones
  aren't.
- **Premium / StoreKit equivalent** -- iOS gates friend requests, the
  leaderboard, and match-history limits behind a subscription
  (`PremiumStore.swift`, Play Billing on Android). RLS still enforces the
  real limits server-side either way, but there's no Android purchase
  flow or paywall UI yet -- this needs a Google Play Console listing and
  Play Billing integration, analogous to the App Store Connect blocker
  already documented for iOS.
- **Location-based proximity check-in** (`ProximityCheckInService.swift`)
  and **push notifications** (FCM) -- not ported.
- **Map view** for Grounds (`GroundsMapView` on iOS).

## Honest verification caveats

This was written with **no Android SDK available** in the build
environment -- `com.android.application` and all AndroidX artifacts live
on Google's Maven repo (`dl.google.com`), which this sandbox's network
proxy returns `403 Forbidden` on. That means:

- **Not verified**: anything Android-Gradle-Plugin-specific -- resource
  linking, manifest merging, R8/D8, actually producing an APK. This needs
  Android Studio (or a CI runner with real Android SDK access) to build
  for the first time. Compose Navigation (`androidx.navigation:navigation-compose`)
  and the extended Material icon pack (`material-icons-extended`) are
  used but, being AndroidX-only artifacts, could not be checked against
  real bytecode the way the Supabase client calls below were.
- **Actually verified**: every Supabase Kotlin API call in this code --
  `signUpWith`, `signInWith`, `signOut`, `sessionStatus`, `currentSessionOrNull`,
  the Postgrest `select`/`filter`/`eq`/`neq`/`gte`/`isIn`/`ilike`/`or`/`order`/
  `limit`/`single`/`decodeList`/`decodeSingle`, `Columns.raw` for partial
  selects, `Functions.invoke`, and `UserSession.user` -- was checked
  against the real decompiled library bytecode for version `3.0.3` (via a
  scratch Gradle project pulling the real `.aar`s from Maven Central with
  `isTransitive = false`, then `javap -p`), not written from memory.
  Package names, method signatures, and field names are confirmed correct
  as of that version.
- Real mistakes this caught and fixed before commit: `Row` initially
  imported from the wrong Compose package (`material3` instead of
  `foundation.layout`); the filter builder's "is in a list" method is
  named `isIn`, not `in` (a reserved word in Kotlin); raw partial-column
  selects need `Columns.raw(...)`, not a nested `select("...")` call
  inside the request builder.

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
  `material-icons-extended` for the bottom-nav icon set
- `androidx.navigation:navigation-compose` for the tab/detail navigation
- `io.github.jan-tennert.supabase` (Kotlin Multiplatform Supabase client)
  `3.0.3` -- Postgrest, Auth, Storage, Functions
- Ktor Android client engine
- Coroutines, kotlinx.serialization
- Coil (image loading, for avatars/ground photos once built)

## Branch discipline

This lives on the `android-playstore` branch of `GaelGrounds-1-`,
isolated from the iOS app (in review on the App Store as of this
writing) and never merged into `main`. Only files under `android/` are
ever touched from this branch's commits -- nothing under `ios/`,
`GaelGrounds.xcodeproj/`, or `GaelGrounds/` gets modified here.
