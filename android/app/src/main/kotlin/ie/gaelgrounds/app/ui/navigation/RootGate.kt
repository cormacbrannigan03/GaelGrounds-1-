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
import ie.gaelgrounds.app.ui.auth.AuthViewModel
import io.github.jan.supabase.auth.status.SessionStatus

/**
 * The whole tab shell is browsable signed out, same as iOS's MainTabView --
 * only the Profile tab swaps in the Auth screen when there's no session
 * (see ProfileScreen). This just resolves the current user id/email from
 * Supabase's own session state, mirrors RootView.swift / how
 * ProtectedRoute.tsx + AuthContext gate the web app.
 */
@Composable
fun RootGate() {
    val authViewModel: AuthViewModel = viewModel()
    val sessionStatus by authViewModel.sessionStatus.collectAsState()

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
}
