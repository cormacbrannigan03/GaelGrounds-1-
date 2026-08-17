package ie.gaelgrounds.app.ui.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp

@Composable
fun AuthScreen(viewModel: AuthViewModel) {
    val state by viewModel.uiState

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = if (state.mode == AuthMode.SIGN_UP) "Create your account" else "Welcome back",
            style = MaterialTheme.typography.headlineMedium,
        )

        Spacer(Modifier.height(24.dp))

        if (state.mode == AuthMode.SIGN_UP) {
            OutlinedTextField(
                value = state.displayName,
                onValueChange = { name -> viewModel.update { it.copy(displayName = name) } },
                label = { Text("Display name") },
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(12.dp))
        }

        OutlinedTextField(
            value = state.email,
            onValueChange = { email -> viewModel.update { it.copy(email = email) } },
            label = { Text("Email") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(12.dp))

        OutlinedTextField(
            value = state.password,
            onValueChange = { password -> viewModel.update { it.copy(password = password) } },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            modifier = Modifier.fillMaxWidth(),
        )

        if (state.mode == AuthMode.SIGN_UP) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 12.dp),
            ) {
                Checkbox(
                    checked = state.confirmedAge16,
                    onCheckedChange = { checked -> viewModel.update { it.copy(confirmedAge16 = checked) } },
                )
                Text("I confirm I am 16 years of age or older.")
            }
        }

        state.errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 12.dp))
        }
        state.infoMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 12.dp))
        }

        Spacer(Modifier.height(20.dp))

        val canSubmit = state.email.isNotBlank() &&
            state.password.isNotBlank() &&
            (state.mode == AuthMode.SIGN_IN || state.confirmedAge16) &&
            !state.isSubmitting

        Button(
            onClick = { viewModel.submit() },
            enabled = canSubmit,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.isSubmitting) {
                CircularProgressIndicator(modifier = Modifier.padding(4.dp))
            } else {
                Text(if (state.mode == AuthMode.SIGN_UP) "Create account" else "Sign in")
            }
        }

        TextButton(
            onClick = {
                viewModel.update {
                    it.copy(
                        mode = if (it.mode == AuthMode.SIGN_UP) AuthMode.SIGN_IN else AuthMode.SIGN_UP,
                        errorMessage = null,
                        infoMessage = null,
                    )
                }
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                if (state.mode == AuthMode.SIGN_UP) "Already have an account? Sign in"
                else "New here? Create an account",
            )
        }
    }
}
