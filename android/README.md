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
- `UserProfile` model mirroring the `user_profiles` table
- Full email/password auth flow (`ui/auth/`) with the same 16+ age
  confirmation gate as iOS (`AuthView.swift`) and web (`AuthPage.tsx`),
  and the same post-signup `user_profiles` row insert as `AuthContext.tsx`
- A `RootGate` that switches between the Auth screen and a placeholder
  Home screen based on Supabase's own session state, matching how
  `RootView.swift` / `ProtectedRoute.tsx` gate access
- Brand colors matching `Theme.swift` exactly (`ui/theme/Color.kt`)

## What's not built yet

Dashboard, Matches, Grounds, Counties, Leaderboard, and the full Profile
screen (achievements, friends, Best Game Ever, avatar upload, account
deletion, Premium) -- the same feature set as iOS, still to come.
Location-based proximity check-in and push notifications (FCM) also
aren't ported yet.

## Honest verification caveats

This was written with **no Android SDK available** in the build
environment -- `com.android.application` and all AndroidX artifacts live
on Google's Maven repo (`dl.google.com`), which this sandbox's network
proxy returns `403 Forbidden` on. That means:

- **Not verified**: anything Android-Gradle-Plugin-specific -- resource
  linking, manifest merging, R8/D8, actually producing an APK. This needs
  Android Studio (or a CI runner with real Android SDK access) to build
  for the first time.
- **Actually verified**, unlike the rest of this session's Swift work:
  every Supabase Kotlin API call in this code (`signUpWith`, `signInWith`,
  `signOut`, `sessionStatus`, `Email` provider fields, `from().insert()`,
  `SessionStatus.Authenticated.session.user`) was checked against the
  real decompiled library bytecode for version `3.0.3`, not written from
  memory. Package names, method signatures, and field names are confirmed
  correct as of that version.
- One real mistake this did catch and fix: `Row` was initially imported
  from the wrong Compose package (`material3` instead of
  `foundation.layout`) -- fixed before commit.

**First thing to do in Android Studio**: open this `android/` folder,
let Gradle sync (it'll need the real Android SDK, which Android Studio
installs automatically), and confirm it actually compiles and runs on an
emulator/device. Given the verification gap above, treat the first sync
as the real first test of this code.

## Dependencies

- Jetpack Compose (Material 3), BOM `2024.09.02`
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
