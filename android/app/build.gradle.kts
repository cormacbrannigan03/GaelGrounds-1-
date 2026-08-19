plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Loaded from local.properties (gitignored) so the real Maps API key is
// never committed -- see android/README.md for the one-time setup step.
// Falls back to an empty string, which the Maps SDK will simply reject at
// runtime (the map won't render) rather than failing the build.
val localProperties = java.util.Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY", "")

android {
    namespace = "ie.gaelgrounds.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "ie.gaelgrounds.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    sourceSets["main"].apply {
        kotlin.srcDirs("src/main/kotlin")
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.09.02")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.6")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.navigation:navigation-compose:2.8.1")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    // Extended icon pack -- the bottom nav uses a few icons (EmojiEvents,
    // SportsSoccer, Flag) outside the small curated set in material-icons-core.
    implementation("androidx.compose.material:material-icons-extended")

    // Supabase (Kotlin Multiplatform client) -- mirrors the same Postgrest/
    // Auth/Storage/Functions surface the iOS app uses via supabase-swift,
    // talking to the exact same project.
    val supabaseBom = platform("io.github.jan-tennert.supabase:bom:3.0.3")
    implementation(supabaseBom)
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:storage-kt")
    implementation("io.github.jan-tennert.supabase:functions-kt")
    implementation("io.github.jan-tennert.supabase:realtime-kt")
    implementation("io.ktor:ktor-client-android:2.3.12")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")

    implementation("io.coil-kt:coil-compose:2.7.0")

    // Proximity check-in: one-shot location fix to find matches near the
    // user, mirroring CLLocationManager's role in
    // ProximityCheckInService.swift.
    implementation("com.google.android.gms:play-services-location:21.3.0")

    // Grounds map -- mirrors GroundsMapView.swift's MapKit view. Needs a
    // Maps SDK for Android API key (see MAPS_API_KEY above) that isn't set
    // up yet; the map screen won't render tiles until it is.
    implementation("com.google.android.gms:play-services-maps:19.0.0")
    implementation("com.google.maps.android:maps-compose:6.4.4")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
