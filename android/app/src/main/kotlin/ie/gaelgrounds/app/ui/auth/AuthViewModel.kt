package ie.gaelgrounds.app.ui.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.Supa
import ie.gaelgrounds.app.data.model.UserProfile
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

enum class AuthMode { SIGN_IN, SIGN_UP }

data class AuthUiState(
    val mode: AuthMode = AuthMode.SIGN_IN,
    val displayName: String = "",
    val email: String = "",
    val password: String = "",
    // GDPR Article 8: Ireland sets the digital age of consent at 16 --
    // mirrors the same confirmation gate in AuthView.swift and AuthPage.tsx.
    val confirmedAge16: Boolean = false,
    val isSubmitting: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null,
)

@Serializable
private data class UserProfileInsert(val id: String, @kotlinx.serialization.SerialName("display_name") val displayName: String)

class AuthViewModel : ViewModel() {
    val sessionStatus: StateFlow<SessionStatus> = Supa.client.auth.sessionStatus

    var uiState = androidx.compose.runtime.mutableStateOf(AuthUiState())
        private set

    fun update(transform: (AuthUiState) -> AuthUiState) {
        uiState.value = transform(uiState.value)
    }

    fun submit() {
        val state = uiState.value
        update { it.copy(errorMessage = null, infoMessage = null) }

        if (state.mode == AuthMode.SIGN_UP && !state.confirmedAge16) {
            update { it.copy(errorMessage = "You must confirm you are 16 or older to create an account.") }
            return
        }

        update { it.copy(isSubmitting = true) }
        viewModelScope.launch {
            try {
                if (state.mode == AuthMode.SIGN_UP) {
                    Supa.client.auth.signUpWith(Email) {
                        email = state.email.trim()
                        password = state.password
                    }
                    val userId = Supa.client.auth.currentUserOrNull()?.id
                    if (userId != null) {
                        val name = state.displayName.ifBlank { state.email.substringBefore("@") }
                        Supa.client.from("user_profiles").insert(UserProfileInsert(id = userId, displayName = name))
                    }
                    update {
                        it.copy(
                            isSubmitting = false,
                            infoMessage = "Account created! Check your inbox to confirm your email, then sign in.",
                        )
                    }
                } else {
                    Supa.client.auth.signInWith(Email) {
                        email = state.email.trim()
                        password = state.password
                    }
                    update { it.copy(isSubmitting = false) }
                }
            } catch (e: Exception) {
                update { it.copy(isSubmitting = false, errorMessage = e.message ?: "Something went wrong. Please try again.") }
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            Supa.client.auth.signOut()
        }
    }
}
