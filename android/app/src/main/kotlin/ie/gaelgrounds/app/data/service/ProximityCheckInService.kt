package ie.gaelgrounds.app.data.service

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CancellationTokenSource
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine

data class NearbyMatchPrompt(val matchId: String, val groundName: String)

/**
 * Watches for a simple case: the app comes to the foreground, the user is
 * signed in, and they happen to be within 2km of a ground hosting a match
 * today. When that happens, surfaces a one-tap "want to check in?" prompt
 * instead of making them find the match manually. Mirrors
 * ios/GaelGrounds/Services/ProximityCheckInService.swift.
 *
 * Never requests location permission on its own initiative -- the caller
 * (RootGate) is responsible for the runtime permission prompt; this only
 * proceeds if permission is already granted, and stays silent otherwise.
 */
object ProximityCheckInService {
    private const val PROXIMITY_THRESHOLD_METERS = 2000.0

    private val _nearbyPrompt = MutableStateFlow<NearbyMatchPrompt?>(null)
    val nearbyPrompt: StateFlow<NearbyMatchPrompt?> = _nearbyPrompt.asStateFlow()

    private val _isCheckingIn = MutableStateFlow(false)
    val isCheckingIn: StateFlow<Boolean> = _isCheckingIn.asStateFlow()

    // Matches already prompted for (accepted or dismissed) this app
    // session, so "Not Now" doesn't nag again every time the app is
    // reopened while still in range.
    private val handledMatchIds = mutableSetOf<String>()

    suspend fun checkForNearbyMatchToday(context: Context, userId: String) {
        if (_nearbyPrompt.value != null) return
        if (!hasLocationPermission(context)) return

        val location = getCurrentLocation(context) ?: return

        try {
            val matches = MatchService.fetchTodaysMatches()
            if (matches.isEmpty()) return

            val groundIds = matches.mapNotNull { it.groundId }.distinct()
            val grounds = MatchService.fetchGrounds(groundIds)
            val attendedMatchIds = MatchService.attendedMatchIds(userId, matches.map { it.id })
            val groundById = grounds.associateBy { it.id }

            val nearest = matches
                .mapNotNull { match ->
                    val groundId = match.groundId ?: return@mapNotNull null
                    val ground = groundById[groundId] ?: return@mapNotNull null
                    if (attendedMatchIds.contains(match.id) || handledMatchIds.contains(match.id)) return@mapNotNull null
                    val distance = distanceMeters(location.latitude, location.longitude, ground.latitude, ground.longitude)
                    if (distance > PROXIMITY_THRESHOLD_METERS) return@mapNotNull null
                    Triple(match.id, ground.name, distance)
                }
                .minByOrNull { it.third }
                ?: return

            _nearbyPrompt.value = NearbyMatchPrompt(matchId = nearest.first, groundName = nearest.second)
        } catch (e: Exception) {
            // Swallow -- silently skip the prompt on failure.
        }
    }

    suspend fun confirmCheckIn(userId: String) {
        val prompt = _nearbyPrompt.value ?: return
        _nearbyPrompt.value = null
        handledMatchIds.add(prompt.matchId)

        _isCheckingIn.value = true
        try {
            MatchService.checkIn(prompt.matchId, userId)
        } catch (e: Exception) {
            // Swallow -- the prompt has already been dismissed either way.
        }
        _isCheckingIn.value = false
    }

    fun dismissPrompt() {
        _nearbyPrompt.value?.let { handledMatchIds.add(it.matchId) }
        _nearbyPrompt.value = null
    }

    private fun hasLocationPermission(context: Context): Boolean {
        val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    private suspend fun getCurrentLocation(context: Context): Location? = suspendCancellableCoroutine { cont ->
        val client = LocationServices.getFusedLocationProviderClient(context)
        val cancellationTokenSource = CancellationTokenSource()
        client.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, cancellationTokenSource.token)
            .addOnSuccessListener { location -> if (cont.isActive) cont.resumeWith(Result.success(location)) }
            .addOnFailureListener { if (cont.isActive) cont.resumeWith(Result.success(null)) }
        cont.invokeOnCancellation { cancellationTokenSource.cancel() }
    }

    private fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val results = FloatArray(1)
        Location.distanceBetween(lat1, lon1, lat2, lon2, results)
        return results[0].toDouble()
    }
}
