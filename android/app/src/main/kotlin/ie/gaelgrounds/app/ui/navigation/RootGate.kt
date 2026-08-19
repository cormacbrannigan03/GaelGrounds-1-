package ie.gaelgrounds.app.ui.navigation

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.data.service.ProximityCheckInService
import ie.gaelgrounds.app.ui.auth.AuthViewModel
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.launch

/**
 * The whole tab shell is browsable signed out, same as iOS's MainTabView --
 * only the Profile tab swaps in the Auth screen when there's no session
 * (see ProfileScreen). This just resolves the current user id/email from
 * Supabase's own session state, mirrors RootView.swift / how
 * ProtectedRoute.tsx + AuthContext gate the web app.
 *
 * Also owns the proximity check-in prompt (mirrors RootView.swift's own
 * alert): requests location permission once a session exists, then checks
 * for a nearby today's match on sign-in and on every app resume.
 */
@Composable
fun RootGate() {
    val authViewModel: AuthViewModel = viewModel()
    val sessionStatus by authViewModel.sessionStatus.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val nearbyPrompt by ProximityCheckInService.nearbyPrompt.collectAsState()
    val isCheckingIn by ProximityCheckInService.isCheckingIn.collectAsState()

    val userId = (sessionStatus as? SessionStatus.Authenticated)?.session?.user?.id

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { _ ->
        // Whatever the user chose, ProximityCheckInService checks the real
        // grant state itself before doing anything -- nothing to do here.
    }

    LaunchedEffect(userId) {
        if (userId != null) {
            locationPermissionLauncher.launch(
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            )
            ProximityCheckInService.checkForNearbyMatchToday(context, userId)
        }
    }

    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, userId) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && userId != null) {
                scope.launch { ProximityCheckInService.checkForNearbyMatchToday(context, userId) }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    when (val status = sessionStatus) {
        is SessionStatus.Initializing -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        is SessionStatus.Authenticated -> {
            GaelGroundsNavHost(
                userEmail = status.session.user?.email,
                userId = status.session.user?.id,
                onSignOut = { authViewModel.signOut() },
            )
        }
        else -> {
            GaelGroundsNavHost(userEmail = null, userId = null, onSignOut = {})
        }
    }

    if (nearbyPrompt != null && userId != null) {
        val prompt = remember(nearbyPrompt) { nearbyPrompt }
        AlertDialog(
            onDismissRequest = { ProximityCheckInService.dismissPrompt() },
            title = { Text("Check in at ${prompt?.groundName}?") },
            text = { Text("There's a match on today and you're nearby — want to check in?") },
            confirmButton = {
                TextButton(
                    enabled = !isCheckingIn,
                    onClick = { scope.launch { ProximityCheckInService.confirmCheckIn(userId) } },
                ) { Text(if (isCheckingIn) "Checking in…" else "Check In") }
            },
            dismissButton = {
                TextButton(onClick = { ProximityCheckInService.dismissPrompt() }) { Text("Not Now") }
            },
        )
    }
}
