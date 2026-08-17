package ie.gaelgrounds.app.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import ie.gaelgrounds.app.ui.auth.AuthScreen
import ie.gaelgrounds.app.ui.auth.AuthViewModel
import ie.gaelgrounds.app.ui.home.HomeScreen
import io.github.jan.supabase.auth.status.SessionStatus

/**
 * Switches between the signed-out (Auth) and signed-in (Home) flows based
 * on Supabase's own session state -- mirrors RootView.swift / how
 * ProtectedRoute.tsx + AuthContext gate the web app.
 */
@Composable
fun RootGate() {
    val authViewModel: AuthViewModel = viewModel()
    val sessionStatus by authViewModel.sessionStatus.collectAsState()

    when (val status = sessionStatus) {
        is SessionStatus.Authenticated -> {
            HomeScreen(
                email = status.session.user?.email,
                onSignOut = { authViewModel.signOut() },
            )
        }
        is SessionStatus.Initializing -> {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }
        else -> {
            AuthScreen(viewModel = authViewModel)
        }
    }
}
